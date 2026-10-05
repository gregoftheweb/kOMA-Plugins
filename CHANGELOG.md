# Changelog

All notable changes to kOMA Plugins. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow [Semantic Versioning](https://semver.org/).

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
