# Changelog

All notable changes to kOMA Plugins. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow [Semantic Versioning](https://semver.org/).

## [0.8.0] - 2026-10-14

### Added

- Get new browses the KDE Store from a local copy of its catalog: filter by plugin type, search as you type, sort by downloads, recent updates, rating or name, and install in the widget with KDE's own installer. KDE's live store window is still available from the page.
- `komaplugin sync` copies the store catalog and small thumbnails to `~/.cache/komaplugin/`; the `komaplugin-sync.timer` systemd user timer runs it at 7:00 and 19:00. `komaplugin store` searches the copy from the command line. Without the timer (a KDE Store install), the Get new tab refreshes a copy older than 12 hours itself.

### Changed

- Rows in the Installed and Get new lists keep their icon and buttons aligned to the top, so hovering to expand a description no longer makes them jump.

## [0.4.2] - 2026-10-07

### Fixed

- plasmashell no longer slows down the longer it runs. Commands ran under a new name every time (`cmd # Date.now()`), and Plasma's command engine never forgets a name: every widget's command runner on the engine rebuilds a property for each name ever used on every removal, so CPU and memory grew all day until plasmashell pinned a core. Commands now keep one fixed name and run through the shared `CommandQueue`, which serializes repeat runs of the same command.

## [0.4.1] - 2026-10-05

### Fixed

- KDE Store updates can be installed inside the Updates and Installed tabs instead of opening a separate store window. Installation progress and errors stay in the widget, and successful updates clear the badge and reload active plugins.
- The bulk git action is labeled **Update git plugins** and no longer opens store windows for unrelated pending updates.

## [0.4.0] - 2026-10-04

### Added

- Hourly update checks: `komaplugin refresh`, run by the `komaplugin-refresh.timer` systemd user timer 2 minutes after login and then hourly. It is the only command that uses the network; results are cached in `~/.cache/komaplugin/updates.json`.
- Updates tab with last-checked time, Check now and Update all; an update badge on the panel icon.
- `komaplugin update`: git plugins fast-forward (refusing local changes, rolling back if the new version fails validation); store plugins open KDE's store window on the entry.
- The kOMA mark icon: an "O" in the theme highlight color around a "k" in the text color.
- Unit tests, linting and formatting gates (`make check`), a pre-commit hook and `make package`.

### Changed

- The Add-ons / All switch moved from the header to its own row on the Installed tab.
- The installed icon name is now `com.columbiafoundry.komaplugins`.

## [0.3.0] - 2026-10-04

### Added

- Get new tab: the KDE Store window per plugin type, and adding a plugin from a git URL.
- `komaplugin add`, `clone` and `reload`; sources of git and cloned plugins kept in `~/.local/share/komaplugin/sources.json`.

## [0.2.0] - 2026-10-04

### Added

- Enable, disable, use and remove, from the popup (hover a row) and the CLI. Removed plugins are moved to `~/.local/share/komaplugin/removed/`.

## [0.1.0] - 2026-10-04

### Added

- Panel widget and `komaplugin list` / `status`: installed widgets, KWin scripts, effects, window decorations, wallpaper plugins and window switchers, with status and origin.

[0.4.0]: https://github.com/gregoftheweb/kOMA-Plugins/releases/tag/v0.4.0
[0.3.0]: https://github.com/gregoftheweb/kOMA-Plugins/releases/tag/v0.3.0
[0.2.0]: https://github.com/gregoftheweb/kOMA-Plugins/releases/tag/v0.2.0
[0.1.0]: https://github.com/gregoftheweb/kOMA-Plugins/releases/tag/v0.1.0
[0.4.1]: https://github.com/gregoftheweb/kOMA-Plugins/releases/tag/v0.4.1
[0.4.2]: https://github.com/gregoftheweb/kOMA-Plugins/releases/tag/v0.4.2
[0.8.0]: https://github.com/gregoftheweb/kOMA-Plugins/releases/tag/v0.8.0
