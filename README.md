# kOMA Plugins

Omarchy-style plugin management for KDE Plasma 6, built on KDE's own plugin
ecosystem (KDE Store, kpackagetool6) instead of Omarchy's Quickshell plugins.

- **Panel widget** (`com.columbiafoundry.komaplugins`): the kOMA mark (an "O"
  in the theme highlight color with a "k" in the text color; `contents/icons/`)
  with a badge: highlight-colored with the number of pending updates, red with
  the number of plugins that failed to load. The popup ("Manage Plugins") has
  three tabs: Installed (by type, with status, version and origin; "Add-ons"
  or "All"), Get new, and Updates.
- **CLI** `komaplugin` (`contents/code/komaplugin`, Python 3 stdlib only):
  `list [--all] [--type T] [--json]`, `status ID [--json]`,
  `enable ID`, `disable ID`, `use ID`, `remove ID [--yes]`,
  `browse [TYPE]`, `add URL [--path DIR] [--enable] [--yes]`, `clone ID`,
  `reload ID`.
- **Get new** (popup tab): one button per plugin type opens KDE's own store
  window (`knewstuff-dialog6`, so installs are tracked like System Settings'
  "Get New"); "Add from git" clones a repo, finds the plugin package (also in
  subfolders like `package/`), refuses symlinks, duplicates and repos with no
  or several plugins (pick one with `--path`), installs it switched off, and
  keeps the checkout in `~/.local/share/komaplugin/src/<id>/` for updates.
- **Clone** copies a QML/JS plugin to `<user>.<name>` ("My …") in
  `~/.local/share/komaplugin/src/`; edit it there and `komaplugin reload ID`.
  Where git and cloned plugins came from is kept in
  `~/.local/share/komaplugin/sources.json`.
- **Actions in the popup:** hover a row for Enable / Disable / Use and Remove
  (with an inline "Remove?" confirm). Enabling a widget places it on every
  panel left of the tray; panels restart for a moment to apply the order.
  Remove turns the plugin off and moves your copy to
  `~/.local/share/komaplugin/removed/` (store installs are also dropped from
  KDE's store registry). System packages are refused with the pacman command.

Plugin types: Plasma widgets, KWin scripts, KWin effects (including compiled
ones), window decorations (incl. Aurorae themes), wallpaper plugins, window
switchers. Origins: `store` (KNewStuff registry), `local` (~/.local),
`package` (third-party distro package), `kde` (ships with KDE).

Network use is limited to `komaplugin refresh`, run by the systemd user timer
`komaplugin-refresh.timer` 2 minutes after login and then hourly (or "Check
now" in the Updates tab). It asks the KDE Store API about store installs and
runs `git fetch` for git installs, then writes `~/.cache/komaplugin/updates.json`.
Everything else, including the widget and its badge, reads that cache.
`komaplugin update ID|--all` fast-forwards git plugins (refuses local changes,
rolls back if the new version fails validation) and opens KDE's store window
on store plugins so KDE keeps tracking them.

## Install

    bin/install             # install/upgrade, link ~/.local/bin/komaplugin,
                            # place on every panel left of the system tray
    bin/install --no-place  # install/upgrade only
    bin/dev-reload          # reinstall + restart plasmashell

## Roadmap

1. List + status (v0.1, done)
2. Enable / disable / use / remove (v0.2, done)
3. Get new: KDE Store browser, add from git, clone, reload (v0.3, done)
4. Update checks (login + hourly, cached), Updates tab and badge (v0.4, done)
