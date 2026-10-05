"""Completion must follow KDE's registry, not a successful UI callback alone."""

import json

import pytest


def store_plugin(kp, helpers, version="1.0"):
    pid = "org.example.store"
    pkg = helpers.write_package(kp.DATA_HOME / "plasma/plasmoids" / pid, pid, version=version)
    reg = kp.DATA_HOME / "knewstuff3"
    reg.mkdir(exist_ok=True)
    (reg / "plasmoids.knsregistry").write_text(
        f"<hotnewstuffregistry><stuff><id>9</id><version>{version}</version>"
        f"<installedfile>{pkg}/*</installedfile></stuff></hotnewstuffregistry>"
    )
    kp.CACHE_DIR.mkdir(exist_ok=True)
    kp.UPDATES.write_text(
        json.dumps({"items": {pid: {"kind": "store", "available": True, "latest": "2.0", "current": "1.0"}}})
    )
    return kp.find_one(pid)


def test_failed_store_update_remains_available(kp, helpers):
    plugin = store_plugin(kp, helpers)
    with pytest.raises(kp.Refused, match="has not recorded"):
        kp.do_finish_update(plugin)
    assert kp.load_updates()["items"][plugin["id"]]["available"]


def test_successful_store_update_clears_badge_without_network(kp, helpers):
    plugin = store_plugin(kp, helpers, version="2.0")
    assert kp.do_finish_update(plugin) == "updated to 2.0"
    update = kp.load_updates()["items"][plugin["id"]]
    assert update["available"] is False
    assert update["current"] == "2.0"
    assert kp.find_one(plugin["id"])["update"] is None


def test_active_store_update_restarts_panels_after_completion(kp, helpers, monkeypatch):
    plugin = store_plugin(kp, helpers, version="2.0")
    plugin["status"] = "active"
    commands = []
    monkeypatch.setattr(kp.subprocess, "run", lambda command, **kwargs: commands.append(command))
    assert "panels restart" in kp.do_finish_update(plugin)
    assert commands[0][0] == "systemd-run"


def test_finish_update_refuses_non_store_plugin(kp, helpers):
    helpers.write_package(kp.DATA_HOME / "plasma/plasmoids/org.local", "org.local")
    with pytest.raises(kp.Refused, match="not installed from"):
        kp.do_finish_update(kp.find_one("org.local"))
