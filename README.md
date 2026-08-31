# Min Launcher

Fullscreen **Design Engineer Tools** overlay for [Omarchy](https://omarchy.org) (Quickshell).

A dark, curated launcher inspired by [designengineer.tools](https://designengineer.tools) — inspiration sites, AI coding tools, component libraries, web/desktop utilities, video capture, and whiteboards — opened as a single fullscreen overlay.

## Install

```bash
omarchy plugin add https://github.com/maiosx/min-launcher.git --enable
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

- **Click** a tool to open its URL in your default browser and dismiss the overlay
- **Esc** or click the dimmed backdrop to close

## Structure

```
manifest.json   Omarchy plugin manifest (kind: overlay)
Launcher.qml    Fullscreen overlay UI + launch logic
Tools.js        Curated tool list with categories and URLs
README.md
LICENSE
```

## License

MIT
