# Min Launcher

Fullscreen app launcher overlay for [Omarchy](https://omarchy.org) (Quickshell).

**Layout** matches the Design Engineer Tools multi-column card. **Items** are your installed native apps only (Omarchy `AppLibrary` / `.desktop` entries) — no web URLs.

Apps are grouped by FreeDesktop category (Development, Graphics, Internet, Office, Multimedia, System, Utility, Games, Apps).

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

- Type to filter across all sections
- Click an app or **Enter** to launch via `AppLibrary.launch`
- **↑↓** move selection · **Esc** clear filter / close

## Structure

```
manifest.json
Launcher.qml    Design Engineer–style multi-column overlay
Tools.js        AppLibrary list, filter, category grouping
README.md
LICENSE
```

## License

MIT
