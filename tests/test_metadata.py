"""Reading plugin metadata, KDE config files and the store registry."""

import struct

# --- a tiny CBOR encoder, enough to build Qt-style plugin metadata -----------


def cbor(v):
    def head(major, n):
        if n < 24:
            return bytes([major << 5 | n])
        if n < 256:
            return bytes([major << 5 | 24, n])
        if n < 65536:
            return bytes([major << 5 | 25]) + struct.pack(">H", n)
        return bytes([major << 5 | 26]) + struct.pack(">I", n)

    if v is True:
        return b"\xf5"
    if v is False:
        return b"\xf4"
    if isinstance(v, int):
        return head(0, v) if v >= 0 else head(1, -1 - v)
    if isinstance(v, str):
        b = v.encode()
        return head(3, len(b)) + b
    if isinstance(v, list):
        return head(4, len(v)) + b"".join(cbor(x) for x in v)
    if isinstance(v, dict):
        return head(5, len(v)) + b"".join(cbor(k) + cbor(x) for k, x in v.items())
    raise TypeError(v)


def qt_metadata_blob(meta):
    # Qt 6 stores {2: IID, 3: class name, 4: metadata} as an indefinite-length map
    return b"\xbf" + cbor(2) + cbor("org.kde.Factory") + cbor(4) + cbor(meta) + b"\xff"


def test_cbor_decodes_scalars_and_containers(kp):
    data = cbor({"a": [1, -5, "x", True, False], "n": 300, "big": 70000})
    value, end = kp._cbor(data, 0)
    assert value == {"a": [1, -5, "x", True, False], "n": 300, "big": 70000}
    assert end == len(data)


def test_cbor_indefinite_map(kp):
    data = b"\xbf" + cbor("k") + cbor("v") + b"\xff"
    assert kp._cbor(data, 0)[0] == {"k": "v"}


def test_so_metadata_finds_embedded_plugin_json(kp, tmp_path):
    meta = {"KPlugin": {"Name": "Rounded Corners", "Category": "Appearance"}}
    so = tmp_path / "effect.so"
    so.write_bytes(b"\x7fELF junk " * 20 + qt_metadata_blob(meta) + b" trailing")
    assert kp.so_metadata(so)["KPlugin"]["Name"] == "Rounded Corners"


def test_so_metadata_without_metadata_is_empty(kp, tmp_path):
    so = tmp_path / "plain.so"
    so.write_bytes(b"no plugin here")
    assert kp.so_metadata(so) == {}


def test_json_metadata_reads_metadata_json(kp, helpers, tmp_path):
    pkg = helpers.write_package(tmp_path / "w", "org.example.w", name="Widget W", version="2.1")
    assert kp.json_metadata(pkg)["KPlugin"]["Version"] == "2.1"


def test_json_metadata_falls_back_to_metadata_desktop(kp, tmp_path):
    theme = tmp_path / "SomeAurorae"
    theme.mkdir()
    (theme / "metadata.desktop").write_text(
        "[Desktop Entry]\nName=Some Aurorae\nComment=A theme\nX-KDE-PluginInfo-Version=1.1\n"
    )
    kp_ = kp.json_metadata(theme)["KPlugin"]
    assert (kp_["Name"], kp_["Description"], kp_["Version"]) == ("Some Aurorae", "A theme", "1.1")


def test_json_metadata_broken_file_is_empty(kp, tmp_path):
    (tmp_path / "metadata.json").write_text("{not json")
    assert kp.json_metadata(tmp_path) == {}


def test_read_kconfig_groups_and_nested_groups(kp, tmp_path):
    f = tmp_path / "kwinrc"
    f.write_text("# comment\n[Plugins]\nkrohnkiteEnabled=true\n\n[org.kde.kdecoration2]\ntheme=Foo\n[A][B]\nk = v\n")
    cfg = kp.read_kconfig(f)
    assert cfg["Plugins"]["krohnkiteEnabled"] == "true"
    assert cfg["org.kde.kdecoration2"]["theme"] == "Foo"
    assert cfg["A][B"]["k"] == "v"


def test_read_kconfig_missing_file(kp, tmp_path):
    assert kp.read_kconfig(tmp_path / "nope") == {}


def test_store_registry_maps_installed_files(kp):
    reg = kp.DATA_HOME / "knewstuff3"
    reg.mkdir(parents=True)
    (reg / "plasmoids.knsregistry").write_text(
        """<?xml version="1.0"?><hotnewstuffregistry><stuff category="705">
        <name>Nice Widget</name><id>12345</id><version>1.2</version><releasedate>2026-01-02</releasedate>
        <installedfile>/home/u/.local/share/plasma/plasmoids/org.nice/*</installedfile>
        </stuff></hotnewstuffregistry>"""
    )
    entry = kp.store_registry()["/home/u/.local/share/plasma/plasmoids/org.nice"]
    assert entry["storeId"] == "12345"
    assert entry["version"] == "1.2"
    assert entry["catalog"] == "plasmoids"


def test_store_is_newer(kp):
    assert kp.store_is_newer("1.0", "2026-01-01", {"version": "1.1", "changed": "2026-01-01"})
    assert not kp.store_is_newer("1.1", "2026-01-01", {"version": "1.1", "changed": "2026-06-01"})
    # no versions: compare dates
    assert kp.store_is_newer("", "2026-01-01", {"version": "", "changed": "2026-02-01"})
    assert not kp.store_is_newer("", "2026-03-01", {"version": "", "changed": "2026-02-01"})
    assert not kp.store_is_newer("", "", {"version": "", "changed": "2026-02-01"})
