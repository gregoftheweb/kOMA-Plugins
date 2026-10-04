"""Finding installed plugins, working out where they came from and their state."""

import json


def by_id(recs):
    return {r["id"]: r for r in recs}


def test_lists_user_widgets_as_local_and_reads_names(kp, helpers):
    helpers.write_package(kp.DATA_HOME / "plasma/plasmoids/org.ex.clock", "org.ex.clock", name="Clock", version="3")
    r = by_id(kp.discover(include_kde=False))["org.ex.clock"]
    assert (r["name"], r["version"], r["origin"], r["type"]) == ("Clock", "3", "local", "widget")


def test_widget_status_follows_placement(kp, helpers):
    helpers.write_package(kp.DATA_HOME / "plasma/plasmoids/org.ex.a", "org.ex.a")
    helpers.write_package(kp.DATA_HOME / "plasma/plasmoids/org.ex.b", "org.ex.b")
    kp.desk.placements = {"org.ex.a": 2}
    recs = by_id(kp.discover(include_kde=False))
    assert recs["org.ex.a"]["status"] == "active"
    assert recs["org.ex.a"]["actions"][0] == "disable"
    assert recs["org.ex.b"]["status"] == "off"
    assert recs["org.ex.b"]["actions"][0] == "enable"


def test_kwin_script_enabled_but_not_loaded_is_an_error(kp, helpers):
    helpers.write_package(kp.DATA_HOME / "kwin/scripts/tiler", "tiler", ptype="KWin/Script")
    (kp.CONFIG_HOME / "kwinrc").write_text("[Plugins]\ntilerEnabled=true\n")
    r = by_id(kp.discover(include_kde=False))["tiler"]
    assert r["status"] == "error"
    kp.desk.loaded.add("tiler")
    assert by_id(kp.discover(include_kde=False))["tiler"]["status"] == "active"


def test_disabled_kwin_script_is_off(kp, helpers):
    helpers.write_package(kp.DATA_HOME / "kwin/scripts/tiler", "tiler", ptype="KWin/Script")
    (kp.CONFIG_HOME / "kwinrc").write_text("[Plugins]\ntilerEnabled=false\n")
    r = by_id(kp.discover(include_kde=False))["tiler"]
    assert (r["status"], r["actions"][0]) == ("off", "enable")


def test_current_decoration_is_active_and_cannot_be_used_again(kp, helpers):
    helpers.write_package(kp.DATA_HOME / "kwin/decorations/org.ex.deco", "org.ex.deco", ptype="KWin/Decoration")
    helpers.write_package(kp.DATA_HOME / "kwin/decorations/org.ex.other", "org.ex.other", ptype="KWin/Decoration")
    (kp.CONFIG_HOME / "kwinrc").write_text("[org.kde.kdecoration2]\nlibrary=org.kde.kwin.aurorae\ntheme=org.ex.deco\n")
    recs = by_id(kp.discover(include_kde=False))
    assert recs["org.ex.deco"]["status"] == "active"
    assert "use" not in recs["org.ex.deco"]["actions"]
    assert recs["org.ex.other"]["actions"][0] == "use"


def test_store_installs_are_marked_store(kp, helpers):
    pkg = helpers.write_package(kp.DATA_HOME / "plasma/plasmoids/org.nice", "org.nice")
    reg = kp.DATA_HOME / "knewstuff3"
    reg.mkdir()
    (reg / "plasmoids.knsregistry").write_text(
        f"<hotnewstuffregistry><stuff><id>9</id><installedfile>{pkg}/*</installedfile></stuff></hotnewstuffregistry>"
    )
    r = by_id(kp.discover(include_kde=False))["org.nice"]
    assert r["origin"] == "store"
    assert r["store"]["storeId"] == "9"


def test_aurorae_themes_are_decorations(kp):
    theme = kp.DATA_HOME / "aurorae/themes/Shiny"
    theme.mkdir(parents=True)
    (theme / "metadata.desktop").write_text("[Desktop Entry]\nName=Shiny\n")
    r = by_id(kp.discover(include_kde=False))["__aurorae__svg__Shiny"]
    assert (r["type"], r["name"]) == ("decoration", "Shiny")
    assert "clone" not in r["actions"]  # SVG themes are not kpackages


def test_kde_packages_hidden_unless_all(kp, helpers):
    sys_pkg = helpers.write_package(kp.root / "usr/share/plasma/plasmoids/org.kde.thing", "org.kde.thing")
    kp.desk.owners[str(sys_pkg)] = ("plasma-workspace", "kde")
    assert "org.kde.thing" not in by_id(kp.discover(include_kde=False))
    r = by_id(kp.discover(include_kde=True))["org.kde.thing"]
    assert (r["origin"], r["package"], r["scope"]) == ("kde", "plasma-workspace", "system")
    assert "remove" not in r["actions"]


def test_user_copy_overrides_system_copy(kp, helpers):
    helpers.write_package(kp.root / "usr/share/plasma/plasmoids/org.x", "org.x", version="1")
    helpers.write_package(kp.DATA_HOME / "plasma/plasmoids/org.x", "org.x", version="2")
    r = by_id(kp.discover(include_kde=True))["org.x"]
    assert (r["version"], r["scope"]) == ("2", "user")


def test_compiled_plugins_listed_from_qt_plugin_dir(kp):
    so_dir = kp.qt_plugin_dir() / "kwin/effects/plugins"
    so_dir.mkdir(parents=True)
    (so_dir / "kwin4_effect_shiny.so").write_bytes(b"no metadata")
    r = by_id(kp.discover(include_kde=False))["kwin4_effect_shiny"]
    assert (r["type"], r["compiled"], r["origin"]) == ("effect", True, "package")
    assert "clone" not in r["actions"]


def test_cached_update_is_attached_and_offered_first(kp, helpers):
    helpers.write_package(kp.DATA_HOME / "plasma/plasmoids/org.u", "org.u")
    kp.CACHE_DIR.mkdir(parents=True)
    kp.UPDATES.write_text(json.dumps({"items": {"org.u": {"available": True, "latest": "2"}}}))
    r = by_id(kp.discover(include_kde=False))["org.u"]
    assert r["update"]["latest"] == "2"
    assert r["actions"][0] == "update"
