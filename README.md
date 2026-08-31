# Min Launcher

Fullscreen **native app launcher** overlay for [Omarchy](https://omarchy.org) (Quickshell).

Lists **installed applications only** — the same `.desktop` entries Omarchy’s menu Apps section uses via `shell.appLibrary`. No web URLs.

## Install

```bash
omarchy plugin add https://github.com/maiosx/min-launcher.git --enable
```

Update:

```bash
omarchy plugin update min-launcher
```

## Summon

```bash
omarchy-shell shell toggle min-launcher
```

Suggested keybind in `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + SHIFT + L", "Min Launcher", "omarchy-shell shell toggle min-launcher")
```

## Usage

- Type to filter by name / keywords
- **↑↓** or mouse to select
- **Enter** or click to launch via `AppLibrary.launch` (uwsm-app / gtk-launch)
- **Esc** closes (or clears the search first)

## How it works

Apps come from Omarchy’s shared `AppLibrary` (DesktopEntries), identical to the built-in menu’s Apps provider. Launch uses `appLibrary.launch(appId, name)` so session wrapping and launch feedback match the rest of the shell.

## Structure

```
manifest.json   Omarchy overlay plugin manifest
Launcher.qml    Fullscreen overlay UI
Tools.js        App list / filter helpers
README.md
LICENSE
```

## License

MIT
