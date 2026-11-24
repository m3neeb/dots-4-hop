# Desktop Icons

Files, folders and `.desktop` launchers on your Noctalia desktop, with a right-click menu.

- Shows everything in a folder (default `~/Desktop`): folders, files, image thumbnails, app launchers
- Double-click opens (single-click mode available); files use `xdg-open`, launchers use `gio launch`
- Right-click an icon: Open · Open in terminal (folders) · Copy path · Rename… · Move to trash
- Right-click empty desktop (opt-in, see `empty_menu`): New folder… · New text file… · Open desktop folder · Open in terminal · Refresh · your own entries
- Rescans every 2 seconds, so files dropped in by other programs show up on their own

Requires **Noctalia v5.4.0 or newer** (plugin API 43). It does not work on the old Quickshell-based v4.
Optional tools: `xdg-utils` (open), `glib2` / `gio` (launchers, trash), or `trash-cli` as a trash fallback.

## Install

```sh
mkdir -p "${XDG_DATA_HOME:-$HOME/.local/share}/noctalia/plugins"
cp -r desktop-icons "${XDG_DATA_HOME:-$HOME/.local/share}/noctalia/plugins/"
```

Then enable **Desktop Icons** in Settings → Plugins. Edits to `.luau` files hot-reload.
Before publishing anywhere, change `you` in `plugin.toml` (`id` and `author`) to your own handle.

## Settings

Settings → Plugins → gear on the plugin's row.

| Setting | Default | Notes |
|---|---|---|
| `directory` | `~/Desktop` | Any folder. |
| `output` | empty | A connector such as `DP-1`. Empty shows icons on every monitor. |
| `icon_style` | `image` | `image`: theme icons and thumbnails. `glyph`: monochrome glyphs, but the whole tile takes right-clicks. See below. |
| `cell_size`, `icon_size` | 96, 48 | Slot and icon size in px. |
| `show_hidden`, `sort`, `folders_first` | off, name, on | `sort` is name, modified or type. |
| `thumbnails`, `thumbnail_max_mb` | on, 8 | Images are shown as their own picture, up to the size limit. |
| `empty_menu` | off | Adds the right-click menu on empty desktop. It works by tiling the empty desktop with invisible buttons, which makes the cursor a hand everywhere, so it is off by default. |
| `label_backing` | 0 | Opacity of the translucent plate behind each icon name, so it stays readable on bright wallpapers. 0 turns it off. |
| `single_click`, `double_click_ms` | off, 450 | |
| `extra_menu` | empty | One `Label = command` per line, added to the empty-desktop menu. |
| `rows` | 0 | Icons per column. 0 = work it out from monitor height. |
| `padding_top/left/bottom` | 8 / 8 / 48 | Bottom padding stands in for your bar or dock when counting rows. |
| `hit_divisions`, `hit_opacity` | 1, 0.02 | Only used with `empty_menu`: right-click precision and how visible the click areas are. |

`extra_menu` example:

```
Change wallpaper = noctalia msg wallpaper-panel-toggle
Lock screen = loginctl lock-session
```

## How it works

Noctalia desktop widgets are small tiles that each own one surface, with no context-menu API, so they cannot see a click on empty desktop. This plugin uses plugin-owned layer surfaces (plugin API 36) instead.

| Entry | Kind | Job |
|---|---|---|
| `desktop` | `[[layer]]`, bottom | Full-output surface that draws the icon grid and receives clicks |
| `menu` | `[[layer]]`, top | Small surface that is moved and resized for each right-click, then hidden again |
| `scanner` | `[[service]]` | Watches the folder, resolves icons, runs every file operation |

Layers and the service are separate VMs and talk through `noctalia.state` (`items`, `dir`, `menu`, `cmd`).

## Known limitations

These come from what the current plugin API exposes, not from choices I would rather have made.

1. **The menu opens near the pointer, not exactly at it.** `ui.button.onRightClick` is the only right-click hook for UI controls and it reports no coordinates. Empty space is therefore tiled with near-invisible buttons and the menu opens at the centre of the one you hit (off by up to about half a slot, roughly 48 px, at the default). `hit_divisions = 2` or `3` tightens it, but every extra node counts against Noctalia's per-callback CPU budget; a layer that overruns it repeatedly is disabled by the shell.
2. **Image icons only take right-click on the name below them.** `ui.image` and containers only take left clicks. Set `icon_style = "glyph"` if you want right-click anywhere on the tile.
3. **No drag to reposition, no drag between folders.** Drag and drop exists only in panels and bar widgets. Icons are laid out automatically, column by column.
4. **No cut/copy/paste of files, no "Open with…", no properties dialog.**
5. **The menu closes when you pick an entry or click the desktop.** There is no Escape handling in layers, and clicking a window or the bar does not dismiss it.
6. **The cursor over empty desktop cannot be changed.** Cursors belong to the host, not to plugin controls, and a `ui.button` always shows the pointer hand. That is why the empty-desktop menu is opt-in (`empty_menu`).
7. The desktop layer shares the bottom layer with Noctalia's desktop widgets. Which one is on top is up to the compositor, and the top one gets the clicks.

## Troubleshooting

- **Logs:** `tail -f ~/.cache/noctalia/noctalia.log | grep -i -E "desktop-icons|error|budget"`. Every launch logs how long spawning the process took, and the scanner logs each time it republishes.
- **"exceeded its CPU budget" / "layer disabled after repeated script failures":** Noctalia aborts any script callback that runs too long. Keep `hit_divisions` at 1 and leave `empty_menu` off if you see it, then send the log lines.

- **Nothing is drawn.** The surface may be under the wallpaper. In `plugin.toml`, try `layer = "background"` on the `desktop` entry, or `"top"` to test.
- **Right-click on empty desktop does nothing.** Set `hit_opacity = 1` in settings: you should now see a faint tint on hover over empty areas. If you do, the clicks work and the 0.02 opacity is being culled by your build, so use something like 0.05. If you see nothing at all, the buttons are not receiving input; please report it.
- **Icons run off the bottom or stop early.** Set `rows` explicitly, or adjust `padding_bottom`. This usually means monitor height and UI scale do not match what `noctalia.outputs()` reports.
- **Watch the log** for `desktop-icons` lines, and drive the scanner by hand with `noctalia msg plugin you/desktop-icons:scanner all refresh`.
