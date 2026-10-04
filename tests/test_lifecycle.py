"""add / clone / reload / refresh / update / remove, against real local git repos."""

import json

import pytest


def by_id(kp, pid):
    return {r["id"]: r for r in kp.discover(include_kde=False)}[pid]


def test_add_installs_from_subfolder_switched_off(kp, helpers):
    repo = helpers.make_repo(kp.root / "upstream")
    msg = kp.do_add(str(repo), None, enable=False, yes=True)
    assert "switched off" in msg
    src = kp.load_sources()["org.example.widget"]
    assert (src["kind"], src["path"], src["url"]) == ("git", "package", str(repo))
    r = by_id(kp, "org.example.widget")
    assert (r["origin"], r["status"]) == ("git", "off")
    assert (kp.STATE_DIR / "src/org.example.widget/.git").is_dir()


def test_add_refuses_duplicates(kp, helpers):
    repo = helpers.make_repo(kp.root / "upstream")
    kp.do_add(str(repo), None, enable=False, yes=True)
    with pytest.raises(kp.Refused, match="already installed"):
        kp.do_add(str(repo), None, enable=False, yes=True)


def test_add_refuses_repo_without_plugin(kp, helpers):
    repo = kp.root / "empty"
    repo.mkdir()
    helpers.git(repo, "init", "-q", "-b", "main")
    (repo / "README.md").write_text("nothing here")
    helpers.git(repo, "add", "-A")
    helpers.git(repo, "commit", "-q", "-m", "x")
    with pytest.raises(kp.Refused, match="no KDE plugin"):
        kp.do_add(str(repo), None, enable=False, yes=True)
    assert not list((kp.CACHE_DIR / "staging").iterdir())  # staging cleaned up


def test_add_with_several_plugins_needs_path(kp, helpers):
    repo = helpers.make_repo(kp.root / "multi", pid="org.a", subdir="a")
    helpers.write_package(repo / "b", "org.b")
    helpers.git(repo, "add", "-A")
    helpers.git(repo, "commit", "-q", "-m", "b")
    with pytest.raises(kp.Refused, match="several plugins"):
        kp.do_add(str(repo), None, enable=False, yes=True)
    kp.do_add(str(repo), "b", enable=False, yes=True)
    assert kp.load_sources()["org.b"]["kind"] == "git"


def test_add_refuses_symlinks(kp, helpers):
    repo = helpers.make_repo(kp.root / "sneaky")
    (repo / "package/contents/ui/evil.qml").symlink_to("/etc/passwd")
    helpers.git(repo, "add", "-A")
    helpers.git(repo, "commit", "-q", "-m", "link")
    with pytest.raises(kp.Refused, match="symlink"):
        kp.do_add(str(repo), None, enable=False, yes=True)


def test_add_refuses_widget_without_main_qml(kp, helpers):
    repo = kp.root / "nomain"
    repo.mkdir()
    helpers.git(repo, "init", "-q", "-b", "main")
    helpers.write_package(repo, "org.nomain", main=False)
    helpers.git(repo, "add", "-A")
    helpers.git(repo, "commit", "-q", "-m", "x")
    with pytest.raises(kp.Refused, match=r"main\.qml"):
        kp.do_add(str(repo), None, enable=False, yes=True)


def test_add_without_confirmation_off_a_terminal_is_refused(kp, helpers):
    repo = helpers.make_repo(kp.root / "upstream")
    with pytest.raises(kp.Refused, match="confirmation"):
        kp.do_add(str(repo), None, enable=False, yes=False)


def test_refresh_and_update_fast_forward(kp, helpers):
    repo = helpers.make_repo(kp.root / "upstream")
    kp.do_add(str(repo), None, enable=False, yes=True)
    # upstream moves on
    md = json.loads((repo / "package/metadata.json").read_text())
    md["KPlugin"]["Version"] = "2.0"
    (repo / "package/metadata.json").write_text(json.dumps(md))
    helpers.git(repo, "commit", "-qam", "Release 2.0")

    assert "1 update(s) available" in kp.do_refresh(quiet=True)
    r = by_id(kp, "org.example.widget")
    assert r["update"]["behind"] == 1
    assert "Release 2.0" in r["update"]["log"]

    kp.do_update(r, yes=True)
    assert by_id(kp, "org.example.widget")["version"] == "2.0"
    assert by_id(kp, "org.example.widget")["update"] is None
    assert kp.load_sources()["org.example.widget"]["commit"] == helpers.git(repo, "rev-parse", "--short", "HEAD")


def test_update_refuses_local_changes(kp, helpers):
    repo = helpers.make_repo(kp.root / "upstream")
    kp.do_add(str(repo), None, enable=False, yes=True)
    (repo / "package/x.txt").write_text("new")
    helpers.git(repo, "add", "-A")
    helpers.git(repo, "commit", "-qm", "more")
    kp.do_refresh(quiet=True)
    (kp.STATE_DIR / "src/org.example.widget/package/metadata.json").write_text("{}")
    with pytest.raises(kp.Refused, match="local changes"):
        kp.do_update(by_id(kp, "org.example.widget"), yes=True)


def test_update_rolls_back_when_new_version_is_bad(kp, helpers):
    repo = helpers.make_repo(kp.root / "upstream")
    kp.do_add(str(repo), None, enable=False, yes=True)
    before = kp.load_sources()["org.example.widget"]["commit"]
    (repo / "package/contents/ui/link.qml").symlink_to("/etc/passwd")
    helpers.git(repo, "add", "-A")
    helpers.git(repo, "commit", "-qm", "bad")
    kp.do_refresh(quiet=True)
    with pytest.raises(kp.Refused, match="symlink"):
        kp.do_update(by_id(kp, "org.example.widget"), yes=True)
    assert kp.git_head(kp.STATE_DIR / "src/org.example.widget") == before


def test_refresh_records_errors_without_failing(kp, helpers):
    repo = helpers.make_repo(kp.root / "upstream")
    kp.do_add(str(repo), None, enable=False, yes=True)
    import shutil

    shutil.rmtree(repo)  # upstream gone
    msg = kp.do_refresh(quiet=True)
    assert "1 error" in msg
    assert kp.load_updates()["errors"]


def test_clone_and_reload(kp, helpers, monkeypatch):
    monkeypatch.setenv("USER", "Greg")
    helpers.write_package(kp.DATA_HOME / "plasma/plasmoids/org.ex.clock", "org.ex.clock", name="Clock")
    msg = kp.do_clone(by_id(kp, "org.ex.clock"), yes=True)
    assert "greg.clock" in msg
    r = by_id(kp, "greg.clock")
    assert (r["name"], r["origin"]) == ("My Clock", "clone")
    # a second clone gets a fresh id
    kp.do_clone(by_id(kp, "org.ex.clock"), yes=True)
    assert by_id(kp, "greg.clock2")
    # edit the source, reload installs it
    src = kp.STATE_DIR / "src/greg.clock/metadata.json"
    md = json.loads(src.read_text())
    md["KPlugin"]["Version"] = "9"
    src.write_text(json.dumps(md))
    kp.do_reload(by_id(kp, "greg.clock"))
    assert by_id(kp, "greg.clock")["version"] == "9"


def test_remove_moves_plugin_and_source_aside(kp, helpers):
    repo = helpers.make_repo(kp.root / "upstream")
    kp.do_add(str(repo), None, enable=False, yes=True)
    msg = kp.do_remove(by_id(kp, "org.example.widget"))
    assert "removed" in msg
    assert "org.example.widget" not in kp.load_sources()
    removed = list((kp.STATE_DIR / "removed").iterdir())
    assert {p.name.endswith(".source") for p in removed} == {True, False}
    assert "org.example.widget" not in {r["id"] for r in kp.discover(include_kde=False)}


def test_remove_refuses_system_packages(kp, helpers):
    pkg = helpers.write_package(kp.root / "usr/share/plasma/plasmoids/org.sys", "org.sys")
    kp.desk.owners[str(pkg)] = ("some-pkg", "package")
    with pytest.raises(kp.Refused, match="pacman -R some-pkg"):
        kp.do_remove(by_id(kp, "org.sys"))


def test_remove_of_store_install_prunes_registry(kp, helpers):
    pkg = helpers.write_package(kp.DATA_HOME / "plasma/plasmoids/org.nice", "org.nice")
    reg = kp.DATA_HOME / "knewstuff3"
    reg.mkdir()
    (reg / "plasmoids.knsregistry").write_text(
        f"<hotnewstuffregistry><stuff><id>9</id><installedfile>{pkg}/*</installedfile></stuff>"
        "<stuff><id>10</id><installedfile>/elsewhere/*</installedfile></stuff></hotnewstuffregistry>"
    )
    kp.do_remove(by_id(kp, "org.nice"))
    text = (reg / "plasmoids.knsregistry").read_text()
    assert "<id>9</id>" not in text
    assert "<id>10</id>" in text
