"""The command line itself: help, exit codes and messages."""

import os
import subprocess
import sys

from conftest import CLI


def run(*args, env=None):
    return subprocess.run(
        [sys.executable, str(CLI), *args], capture_output=True, text=True, env=env or os.environ, check=False
    )


def sandbox_env(tmp_path):
    env = dict(os.environ)
    for k, sub in {"XDG_DATA_HOME": "d", "XDG_CONFIG_HOME": "c", "XDG_CACHE_HOME": "x"}.items():
        (tmp_path / sub).mkdir()
        env[k] = str(tmp_path / sub)
    env["XDG_DATA_DIRS"] = str(tmp_path / "none")
    return env


def test_help_lists_every_command():
    out = run("--help").stdout
    for cmd in (
        "list",
        "status",
        "enable",
        "disable",
        "use",
        "remove",
        "browse",
        "add",
        "clone",
        "reload",
        "refresh",
        "updates",
        "update",
    ):
        assert cmd in out


def test_unknown_plugin_exits_1_with_message(tmp_path):
    res = run("status", "no.such.plugin", env=sandbox_env(tmp_path))
    assert res.returncode == 1
    assert "no plugin with id no.such.plugin" in res.stderr


def test_updates_before_any_check(tmp_path):
    res = run("updates", env=sandbox_env(tmp_path))
    assert res.returncode == 0
    assert "never" in res.stdout


def test_update_needs_id_or_all(tmp_path):
    res = run("update", env=sandbox_env(tmp_path))
    assert res.returncode == 1
    assert "--all" in res.stderr


def test_browse_rejects_unknown_type():
    res = run("browse", "toaster")
    assert res.returncode == 2
