# kOMA Plugins

**Manage your KDE Plasma add-ons from the panel**: see every widget, KWin script, effect and window decoration you've installed, turn them on and off, get new ones from the KDE Store or a git repo, and get told when updates are out.

kOMA Plugins brings [Omarchy](https://omarchy.org)'s plugin manager to KDE Plasma 6, built on KDE's own plugin system and the [KDE Store](https://store.kde.org) rather than a separate ecosystem. It's part of kOMA (KDE + Omarchy), a set of add-ons that make Plasma look and drive like Omarchy.

## Features

- **Installed**: everything you added, by type, with a status dot (active, off, or failed to load), version and where it came from (KDE Store, git, a local copy, or a distro package). Switch to **All** to include what ships with KDE.
- **Turn plugins on and off**: hover a row. Enabling a widget places it on every panel, left of the system tray. Decorations and window switchers get **Use**.
- **Remove** asks first, turns the plugin off, and moves your copy to `~/.local/share/komaplugin/removed/` instead of deleting it. Plugins installed by your distro are left to your package manager.
- **Get new**: KDE's store window for each plugin type, or **Add from git**: paste a repo URL and kOMA finds the plugin (also in subfolders like `package/`), checks it, and installs it switched off.
- **Updates**: press **Update** to download and install a KDE Store update inside the widget. KDE tracks the installed version, and active widgets reload with a brief panel restart. Git plugins update in place (with a rollback if the new version fails checks); **Update git plugins** applies all pending git updates.
- **Clone** any QML plugin to your own copy, edit it, and `komaplugin reload` it.
- **Follows your theme**: the icon and status colors use your color scheme's highlight color.

## Privacy and network use

kOMA Plugins checks for updates with `komaplugin refresh`. A systemd user timer runs it 2 minutes after login and then once an hour; you can also press **Check now**. It asks the KDE Store API about plugins you installed from the store and runs `git fetch` for plugins you added from git. Results are cached, so listing plugins needs no network access. Downloading updates, browsing the store, or adding from git happens only when you ask.

## Requirements

- KDE Plasma 6 (Wayland or X11)
- Python 3.11 or newer (standard library only)
- `kpackagetool6`, `qdbus6`, `kwriteconfig6`, `knewstuff-dialog6` (part of a normal Plasma install; `qdbus6` is in `qt6-tools` on Arch)
- `git`, for adding plugins from git
- systemd user session, for the hourly update check

## Install

KDE Store publication is planned. The release `.plasmoid` can be installed locally with `kpackagetool6 --type Plasma/Applet --install <file.plasmoid>` or through **Add or Manage Widgets → Install Widget From Local File**. This installs the widget; for the `komaplugin` command on your PATH and the hourly update check, install from source as below.

From source:

```sh
git clone https://github.com/gregoftheweb/kOMA-Plugins
cd kOMA-Plugins
bin/install            # widget, CLI in ~/.local/bin, icon, update timer, and places it on your panels
bin/install --no-place # the same, without touching your panels
```

## Command line

```text
komaplugin list [--all] [--type TYPE] [--json]   installed plugins and their state
komaplugin status ID                             one plugin in detail
komaplugin enable | disable ID                   turn a plugin on or off
komaplugin use ID                                make a decoration or window switcher current
komaplugin remove ID                             turn off and move your copy aside
komaplugin browse [TYPE]                         open the KDE Store for a plugin type
komaplugin add URL [--path DIR] [--enable]       install a plugin from a git repo
komaplugin clone ID | reload ID                  copy a plugin to edit / reinstall after edits
komaplugin refresh                               check for updates (the only networked command)
komaplugin updates                               what the last check found
komaplugin update ID | --all                     apply updates
```

Plugin types: `widget`, `kwin-script`, `effect`, `decoration`, `wallpaper`, `window-switcher`.

## Development

```sh
make setup    # pytest + ruff in .venv, prettier + shellcheck in node_modules, git hook
make check    # every gate: ruff, qmllint, qmlformat, prettier, shellcheck, metadata, tests
make format   # apply every formatter
make package  # dist/com.columbiafoundry.komaplugins-<version>.plasmoid for the KDE Store
bin/dev-reload  # reinstall and restart plasmashell
```

The pre-commit hook runs `make check`. Qt 6's `qmllint` and `qmlformat` are taken from `/usr/lib/qt6/bin`; set `QT_BIN` if yours live elsewhere.

## License

MIT © 2026 Columbia Foundry. See [LICENSE](LICENSE).
