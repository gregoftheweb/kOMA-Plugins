"""The local store catalog: `sync` copies it, `store` reads it without the network."""

import json
import xml.etree.ElementTree as ET
from xml.sax.saxutils import escape

CATEGORIES = (
    "<ocs><data>"
    + "".join(
        f"<category><id>{i}</id><name>{n}</name></category>"
        for i, n in ((705, "Plasma 6 Extensions"), (720, "Kwin Scripts Plasma 6"))
    )
    + "</data></ocs>"
)


def content(cid, name, **extra):
    fields = {
        "id": cid,
        "name": name,
        "personid": "someone",
        "version": "1.0",
        "changed": "2026-09-01T10:00:00+00:00",
        "downloads": "42",
        "score": "70",
        "summary": "",
        "description": "<p>Shows the <b>time</b> &amp; date</p>",
        "detailpage": f"https://store.kde.org/p/{cid}",
        "smallpreviewpic1": f"https://images.pling.com/cache/770x540-4/img/{cid}/shot.png",
        **extra,
    }
    return "<content>" + "".join(f"<{k}>{escape(v)}</{k}>" for k, v in fields.items()) + "</content>"


def write_knsrc(kp, name, group, categories):
    d = kp.DATA_DIRS[0] / "knsrcfiles"
    d.mkdir(parents=True, exist_ok=True)
    (d / name).write_text(f"[{group}]\nName=x\nCategories={categories}\n")


def fake_store(kp, monkeypatch, pages, fail=()):
    """pages: category id -> list of page bodies (lists of <content> strings)."""
    calls, thumbs = [], []

    def ocs_get(path, params=None):
        calls.append((path, params))
        if path == "categories":
            return ET.fromstring(CATEGORIES)
        cid = params["categories"]
        if cid in fail:
            raise OSError("connection reset")
        body = pages.get(cid, [[]])
        batch = body[params["page"]] if params["page"] < len(body) else []
        total = sum(len(p) for p in body)
        return ET.fromstring(f"<ocs><meta><totalitems>{total}</totalitems></meta><data>{''.join(batch)}</data></ocs>")

    class Resp:
        def __init__(self, url):
            self.url = url

        def __enter__(self):
            return self

        def __exit__(self, *a):
            return False

        def read(self):
            return b"png"

    def urlopen(req, timeout=None):
        thumbs.append(req.full_url)
        return Resp(req.full_url)

    monkeypatch.setattr(kp, "ocs_get", ocs_get)
    monkeypatch.setattr("urllib.request.urlopen", urlopen)
    return calls, thumbs


def setup_catalogs(kp):
    for ptype in list(kp.KNSRC):
        if ptype not in ("widget", "kwin-script"):
            kp.KNSRC.pop(ptype)
    write_knsrc(kp, "plasmoids.knsrc", "KNewStuff", "Plasma 6 Extensions")
    write_knsrc(kp, "kwinscripts.knsrc", "KNewStuff3", "Kwin Scripts Plasma 6")


def test_sync_pages_through_every_type(kp, monkeypatch):
    setup_catalogs(kp)
    widgets = [[content(str(i), f"W{i}") for i in range(100)], [content("100", "W100")]]
    calls, thumbs = fake_store(kp, monkeypatch, {"705": widgets, "720": [[content("900", "Tiler")]]})
    assert "102 plugin(s)" in kp.do_sync(quiet=True)
    data = json.loads(kp.CATALOG.read_text())
    assert {i["type"] for i in data["items"]} == {"widget", "kwin-script"}
    assert [p["page"] for path, p in calls if path == "data" and p["categories"] == "705"] == [0, 1]
    item = next(i for i in data["items"] if i["storeId"] == "900")
    assert item["summary"] == "Shows the time & date"
    assert item["catalog"] == "kwinscripts"
    # previews are fetched small, not at the store's 770x540
    assert all(f"/cache/{kp.THUMB_SIZE}/" in u for u in thumbs)
    assert (kp.THUMBS / "900.png").exists()


def test_resync_skips_unchanged_thumbnails_and_drops_gone_ones(kp, monkeypatch):
    setup_catalogs(kp)
    fake_store(kp, monkeypatch, {"705": [[content("1", "A"), content("2", "B")]]})
    kp.do_sync(quiet=True)
    _, thumbs = fake_store(kp, monkeypatch, {"705": [[content("1", "A")]]})
    kp.do_sync(quiet=True)
    assert thumbs == []
    assert (kp.THUMBS / "1.png").exists()
    assert not (kp.THUMBS / "2.png").exists()


def test_failed_type_keeps_its_previous_entries(kp, monkeypatch):
    setup_catalogs(kp)
    fake_store(kp, monkeypatch, {"705": [[content("1", "Clock")]], "720": [[content("9", "Tiler")]]})
    kp.do_sync(quiet=True)
    fake_store(kp, monkeypatch, {"705": [[content("1", "Clock")]]}, fail=("720",))
    msg = kp.do_sync(quiet=True)
    assert "1 error(s)" in msg
    names = {i["name"] for i in json.loads(kp.CATALOG.read_text())["items"]}
    assert names == {"Clock", "Tiler"}


def test_store_marks_installed_and_searches_offline(kp, monkeypatch):
    setup_catalogs(kp)
    fake_store(kp, monkeypatch, {"705": [[content("1", "Clock"), content("2", "Weather")]]})
    kp.do_sync(quiet=True)
    reg = kp.DATA_HOME / "knewstuff3"
    reg.mkdir()
    (reg / "plasmoids.knsregistry").write_text(
        "<hotnewstuffregistry><stuff><id>2</id><version>1.0</version>"
        f"<installedfile>{kp.DATA_HOME}/plasma/plasmoids/org.weather/*</installedfile></stuff></hotnewstuffregistry>"
    )
    monkeypatch.setattr(kp, "ocs_get", lambda *a: (_ for _ in ()).throw(AssertionError("network used")))
    data = kp.load_catalog("widget")
    assert {i["name"]: i["installed"] for i in data["items"]} == {"Clock": False, "Weather": True}
    assert data["items"][0]["thumb"].endswith("1.png")
    assert [i["name"] for i in kp.load_catalog(None, "WEATHER someone")["items"]] == ["Weather"]
    assert kp.load_catalog("kwin-script")["items"] == []


def test_store_without_catalog_is_empty(kp):
    assert kp.load_catalog() == {"syncedAt": "", "items": []}
