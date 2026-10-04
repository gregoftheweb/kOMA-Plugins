"""Shared fixtures: load the komaplugin script as a module inside a sandbox.

Every test gets fresh XDG folders under tmp_path and fakes for the parts that
talk to the running desktop (plasmashell, KWin, pacman, kpackagetool6), so the
suite never touches the real session or the network.
"""

import importlib.machinery
import importlib.util
import json
import os
import shutil
import subprocess
from pathlib import Path

import pytest

CLI = Path(__file__).resolve().parents[1] / "contents" / "code" / "komaplugin"


def load_cli():
    loader = importlib.machinery.SourceFileLoader("komaplugin", str(CLI))
    spec = importlib.util.spec_from_loader("komaplugin", loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


class Desktop:
    """Fake desktop state the CLI reads through its helper functions."""

    def __init__(self):
        self.placements = {}  # widget id -> count on panels/desktops
        self.loaded = set()  # KWin scripts/effects that are loaded
        self.owners = {}  # system path -> (package, origin)
        self.installed = []  # (kpackage type, source dir, upgrade?)


@pytest.fixture
def kp(tmp_path, monkeypatch):
    home = tmp_path / "home"
    data, config, cache = home / ".local/share", home / ".config", home / ".cache"
    system = tmp_path / "usr/share"
    qt = tmp_path / "usr/lib/qt6/plugins"
    for d in (data, config, cache, system, qt):
        d.mkdir(parents=True)
    monkeypatch.setenv("HOME", str(home))
    monkeypatch.setenv("XDG_DATA_HOME", str(data))
    monkeypatch.setenv("XDG_DATA_DIRS", str(system))
    monkeypatch.setenv("XDG_CONFIG_HOME", str(config))
    monkeypatch.setenv("XDG_CACHE_HOME", str(cache))
    for k, v in {
        "GIT_AUTHOR_NAME": "t",
        "GIT_AUTHOR_EMAIL": "t@t",
        "GIT_COMMITTER_NAME": "t",
        "GIT_COMMITTER_EMAIL": "t@t",
        "GIT_CONFIG_NOSYSTEM": "1",
    }.items():
        monkeypatch.setenv(k, v)

    mod = load_cli()
    desk = Desktop()
    mod.desk = desk
    mod.root = tmp_path
    monkeypatch.setattr(mod, "qt_plugin_dir", lambda: qt)
    monkeypatch.setattr(mod, "widget_placements", lambda: dict(desk.placements))
    monkeypatch.setattr(mod, "kwin_bool", lambda obj, method, pid: pid in desk.loaded)
    monkeypatch.setattr(mod, "kwin_effect_ids", lambda: [])
    monkeypatch.setattr(
        mod, "package_owners", lambda paths: {str(p): desk.owners.get(str(p), ("pkg", "package")) for p in paths}
    )

    def fake_install(ptype, pkg, upgrade=False):
        desk.installed.append((ptype, Path(pkg), upgrade))
        pid = json.loads((Path(pkg) / "metadata.json").read_text())["KPlugin"]["Id"]
        dest = data / mod.TYPES[ptype][2] / pid
        if dest.exists():
            shutil.rmtree(dest)
        shutil.copytree(pkg, dest)

    monkeypatch.setattr(mod, "kpackage_install", fake_install)
    return mod


def write_package(where, pid, *, ptype="Plasma/Applet", name=None, version="1.0", main=True):
    """Create a minimal KDE package folder and return it."""
    where = Path(where)
    where.mkdir(parents=True, exist_ok=True)
    md = {"KPackageStructure": ptype, "KPlugin": {"Id": pid, "Name": name or pid, "Version": version}}
    (where / "metadata.json").write_text(json.dumps(md))
    if main and ptype == "Plasma/Applet":
        (where / "contents/ui").mkdir(parents=True, exist_ok=True)
        (where / "contents/ui/main.qml").write_text("import QtQuick\nItem {}\n")
    return where


def git(repo, *args):
    return subprocess.run(["git", "-C", str(repo), *args], check=True, capture_output=True, text=True).stdout.strip()


def make_repo(path, pid="org.example.widget", subdir="package"):
    """A git repo holding one widget in `subdir`, with one commit."""
    path.mkdir(parents=True)
    git(path, "init", "-q", "-b", "main")
    write_package(path / subdir if subdir else path, pid, name="Example")
    git(path, "add", "-A")
    git(path, "commit", "-q", "-m", "first")
    return path


@pytest.fixture
def helpers():
    class H:
        pass

    h = H()
    h.write_package, h.git, h.make_repo = write_package, git, make_repo
    return h


os.environ.setdefault("GIT_TERMINAL_PROMPT", "0")
