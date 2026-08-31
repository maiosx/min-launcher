# Min Launcher

Fullscreen **Design Engineer Tools** overlay for [Omarchy](https://omarchy.org) (Quickshell).

Curated launcher inspired by [designengineer.tools](https://designengineer.tools). **Native apps** (Cursor, Zed, OBS, LocalSend, …) launch via `uwsm-app` / `gtk-launch` when installed; everything else opens in the browser.

## Install

```bash
omarchy plugin add https://github.com/maiosx/min-launcher.git --enable
```

Or update an existing install:

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

## Launch order

For each tool the overlay tries, in order:

1. **Desktop entry** — `uwsm-app -- gtk-launch <id>.desktop` (Omarchy session wrapper)
2. **Exec command** — same wrapper around the binary name
3. **URL** — `Qt.openUrlExternally` in the default browser

Tools that can run natively show a small ⌘ mark in the list.

## Customize

Edit `Tools.js` in the plugin directory (or fork the repo) to add/remove tools or change desktop IDs / exec names for your install.

```js
{ name: "Cursor", desktop: "cursor", exec: "cursor", url: "https://cursor.com/" }
```

## Structure

```
manifest.json   Omarchy plugin manifest (kind: overlay)
Launcher.qml    Fullscreen overlay + launch logic
Tools.js        Categories, desktop IDs, exec names, URLs
README.md
LICENSE
```

## License

MIT
