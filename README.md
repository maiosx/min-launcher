# Min Launcher
<img width="1366" height="768" alt="Preview" src="Preview.png" />
Fullscreen app launcher overlay for [Omarchy](https://omarchy.org) (Quickshell).

**Layout** inspired by Design Engineer Tools. **Items** are installed native apps (Omarchy `AppLibrary`) plus a curated **Web Apps** section that opens in the browser.

Native apps are grouped by FreeDesktop category (Development, Graphics, Internet, Office, Multimedia, System, Utility, Games, Apps). Browser tools appear under **Web Apps**.

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
o.bind("SUPER + M", "Min Launcher", "omarchy-shell shell toggle min-launcher")
```

## Usage

- Type to filter across all sections
- Click an app or **Enter** to launch (native via `AppLibrary.launch`, web via browser)
- **↑↓** move selection · **Esc** clear filter / close

Edit the `WEB_APPS` list in `Tools.js` to add or remove browser tools.

## Remove

Disable and uninstall the plugin:

```bash
omarchy plugin disable min-launcher
omarchy plugin remove min-launcher
```

If you added a keybind, delete it from `~/.config/hypr/bindings.lua`.

To wipe any leftover config under your home directory:

```bash
rm -rf ~/.config/omarchy/plugins/min-launcher
```

(Paths may vary slightly by Omarchy version; `omarchy plugin list` shows installed plugins.)

## Structure

```
manifest.json
Launcher.qml    Fullscreen multi-column overlay
Tools.js        AppLibrary list, Web Apps, filter, category grouping
Preview.png     Screenshot
README.md
LICENSE
```

## License

MIT
