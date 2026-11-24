# Start Menu

A Windows 10 style start menu for Noctalia v5: side rail, A-Z app list, pinned tiles in named groups,
and a search bar along the bottom. Requires **Noctalia v5.4.0 or newer** (plugin API 43).

- **App list:** every installed app, grouped under letter headers. Click a letter to open the alphabet grid and jump to it. A "Most used" block sits on top once you have launched a few things.
- **Tiles:** right-click an app, choose *Pin to Start*. Right-click a tile (on its name) to make it wide or medium, move it earlier or later, move it to another group, or unpin it. Pins, sizes, groups and launch counts persist.
- **Search:** just type. Matches app names, generic names and keywords: substring matches rank by position (name starts and word starts first), and letters-in-order also work (`ffx` finds Firefox). With several words, every word has to match. The best match is shown as a card on the right and **Enter** launches it.
- **Rail:** user button (locks the screen), your folders, Settings, Power. Power opens Noctalia's own session menu.
- **Launching** runs the app's `Exec` line directly, honouring `Terminal=` and `Path=`.

## Install

```sh
mkdir -p "${XDG_DATA_HOME:-$HOME/.local/share}/noctalia/plugins"
unzip start-menu.zip -d "${XDG_DATA_HOME:-$HOME/.local/share}/noctalia/plugins/"
```

Check that you end up with `.../plugins/start-menu/plugin.toml`, `lib/util.luau` and `translations/en.json`.
Enable **Start Menu** in Settings → Plugins. The app list is ready within a fraction of a second; icons fill in right after.
Needs `sh`, `find`, `sort` and `awk` (any awk, including mawk) on `PATH`.

If you change `you` in `plugin.toml` (`id` and `author`) to your own handle, also change **Panel id** in the
plugin settings, and use your id in the commands below.

## Opening the menu

**Bar button.** Add the widget to your bar config:

```toml
[widget.start]
type = "you/start-menu:button"

[bar.default]
start = ["start", "workspaces"]   # put "start" first in whichever list you use
```

**Keybind** (bind your Super key in your compositor to this command):

```sh
noctalia msg panel-toggle you/start-menu:menu
```

Where the panel appears is a standard panel setting: Settings → Plugins → gear on the row → Position
(default bottom left), Attached/Floating, Layer.

## Settings

| Setting | Default | Notes |
|---|---|---|
| `group_names` | Life at a glance / Play and explore | One per line. Tiles are laid out in these groups. |
| `tile_style` | accent | Accent colour or neutral tiles. |
| `most_used_count` | 4 | 0 hides the "Most used" block. |
| `rail_folders` | Documents, Pictures, Downloads | `Label\|glyph\|path` per line. Missing folders are skipped. |
| `lock_command` | `loginctl lock-session` | Run by the user button. |
| `settings_command` | empty | Empty opens Noctalia's control center. |
| `extra_app_dirs` | empty | More folders of `.desktop` files, on top of XDG, Flatpak and Snap. |
| `row_height` | 40 | App list row height in px. |
| `panel_id` | `you/start-menu:menu` | Used by the bar button. |

The panel size (700 x 740) is fixed in `plugin.toml` because panel size is host-owned. If you change the
height there, also change `PANEL_H` at the top of `panel.luau`.

## How it works

| Entry | Kind | Job |
|---|---|---|
| `apps` | `[[service]]` | Lists apps (there is no host API for it) with one `find \| awk` process, then resolves icons in the background |
| `menu` | `[[panel]]` | The start menu UI |
| `button` | `[[widget]]` | The bar button |

Noctalia aborts any script callback that runs too long, so the work is split up on purpose:

- **Typing:** matching is plain Lua string work, not calls into the host. (An earlier version called the host's `fuzzyScore` once per app per keystroke; with a few hundred apps that was enough to make Noctalia abort the keystroke handler for taking too long.)
- **App scan:** one `find | awk` process reads every `.desktop` file in a single pass. Around 650 apps take about 25 ms, and the list appears as soon as it exits. Icons are resolved afterwards in 6 ms slices and streamed to the panel, so rows show a placeholder glyph for a moment and then fill in. The icon map is cached, so after a restart icons are there from the first frame.
- The panel renders only about 30 list rows around the scroll position, with fixed-height spacers above and below so the scrollbar still spans the full list. The rail and tiles are built once and reused.

## Known limitations

1. **Right-click works on app names and on a tile's name strip, not on the icon.** `ui.button` is the only control that reports right-clicks, and it cannot hold an image. Left-click works everywhere.
2. **Tiles are medium and wide only.** No small or large tiles, no live tiles, and no drag to reorder (use the context menu).
3. **No arrow-key navigation** through search results. Enter launches the best match, or click one.
4. **The user button locks the screen** rather than opening an account menu. Sign out and restart are in the Power menu.
5. Search covers apps only: no files, settings or web results. (For files, `fzf` in a terminal does the job better.)

## Troubleshooting

- **Logs:** `tail -f ~/.cache/noctalia/noctalia.log | grep -i -E "start-menu|budget|disabled"`. The service logs each time it publishes, and every launch logs how long spawning took.
- **App list empty:** check the log for `publishing N apps (parsed in … ms)` or `app scan failed`. A failed scan also shows a notification; it usually means `awk` or `find` is missing. Rescan by hand with `noctalia msg plugin you/start-menu:apps all rescan`.
- **Icons stay as glyphs:** the icon theme has no match for that app's `Icon=` name. The lookup is Noctalia's own, so the same app would be iconless in its launcher too.
- **`exceeded its CPU budget` / `disabled after repeated timeouts` in the log:** a script callback ran too long. The log line names the callback; send it to me.
- **An app is missing:** it must have `Type=Application`, an `Exec` line, and no `NoDisplay=true`. Apps installed somewhere unusual need `extra_app_dirs`.
- **List looks blank for a moment when you scroll very fast:** the visible window is re-centred on each scroll event, so a huge flick can outrun it. It fills in as soon as you stop. If it happens on slower setups, a larger `row_height` means fewer rows per screen.
- **The menu opens in a bad place:** change Position in the plugin's panel settings.
