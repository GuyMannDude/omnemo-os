# Omnemo OS — edition inventory (built on Omarchy, MIT)
Draft v0.2 · 2026-10-27 · written on the test laptop · base: Omarchy 4.5.0rc2 (rc channel)
Rule: layer on stock Omarchy, no fork. Everything below is user-level and reversible.

## 1. Plugins we ship (~/.config/omarchy/plugins/)
| Plugin | Where on the bar | What it does |
|---|---|---|
| guy.taskbar | left | AI (brain), Browsers, Web apps pop up choices; Files, Apps, Settings (= full Omarchy menu), Utils; one icon per open window (click = focus/minimize/restore; right-click = Minimize/Close) |
| guy.tools | center, left of ? | "Tools ▴": Calculator, Screenshot, Record screen, Color picker, Emoji, Clipboard, Keyboard shortcuts, Terminal, Theme & wallpaper, Lock, Restart or shut down |
| guy.help | center | "?": two-column guide to every bar icon. ALSO, deliberately, gives Omarchy's unlabeled stock icons hover labels at runtime (see §6) |
| guy.favorites | center, right of ? | "Favorites ▴": All apps + the dock's pinned apps (read live via `omarchy dock pinned`) |
| guy.clock | right, before power | Clock icon; hover = day/date/time; click = its own month calendar (`omarchy-shell shell summon guy.clock` works) |
| omnemo.memory | right | Omnemo memory count (ships with Omnemo itself, not this repo) |
Stock widget placed by us: omarchy.agents (AI usage meter) at the far LEFT, beside the AI button.
Retired (do NOT ship): guy.start (removed 10-27 22:46, redundant with Settings; its extras moved into guy.tools), guy.apps, guy.dock.
Rename to one product namespace (e.g. omnemo-os.*).

## 2. Settings we change
| Setting | Value | How (installer) | Undo |
|---|---|---|---|
| Bar position | bottom | `omarchy bar position bottom` | `... top` |
| Bar layout | see "Layout today" | write `bar.layout` in ~/.config/omarchy/shell.json | restore backup |
| Tray | omarchy.tray REMOVED from the bar: no ‹ drawer ever (new apps are found in the 9-square Apps grid) | layout | restore backup |
| Removed from bar | omarchy.menu, omarchy.workspaces, omarchy.clock (→ guy.clock), omarchy.tray | layout | restore backup |
| Stock dock | DISABLED (2026-10-30: it duplicated Favorites + Tools and popped up on bottom-edge hover, since every workspace floats). Sanctioned first-party switch: shell.json `disabledPlugins: ["omarchy.dock"]`; no stock files touched. KEEP `.dock.pinned`: guy.favorites reads it via `omarchy dock pinned`, which works with the plugin off | `omarchy plugin disable omarchy.dock` | `omarchy plugin enable omarchy.dock` |
| Workspaces | floating by default (all) | `omarchy hyprland workspace layout default floating` (writes default.lua AND pins every workspace that has windows, e.g. 2.lua) | restore the whole workspace-layouts dir byte-exact from the install backup (or remove it if it was absent); never `... default dwindle`, it rewrites default.lua |
| Window fit (Hyprland rule) | new floating windows open centered and no larger than the work area | append a marker-delimited block to ~/.config/hypr/hyprland.lua (see below) | remove the block, `hyprctl reload` |
| Apps menu entry | the app grid lived in the (now off) dock, so `omarchy-menu toggle apps` and every Apps button went dead; an `apps` entry with all five fields (icon, label, aliases, provider, action) brings it back | marked block before the final brace of ~/.config/omarchy/extensions/omarchy-menu.jsonc (seeded from /usr/share/omarchy/config/… if absent; refuses if `apps` is already defined), then `omarchy-menu refresh` | restore backup byte-exact, refresh |
| Apps shortcut | Super+Alt+Space opens that Apps list | marked block appended to ~/.config/hypr/bindings.lua: unbind, then `o.bind("SUPER + ALT + SPACE", "Apps", "omarchy-menu toggle apps")` | restore backup |
| Cursor | the pointer no longer jumps to the window centre on a taskbar switch (Windows does not do that) | marked block appended to ~/.config/hypr/looknfeel.lua: `hl.config({ cursor = { no_warps = true } })` | restore backup |
Layout today: left [omarchy.agents, guy.taskbar] · center [guy.tools, guy.help, guy.favorites] · right [omarchy.indicators, omarchy.elsewhen, omarchy.weather, omarchy.system-update, omarchy.keyboard-layout, omnemo.memory, omarchy.monitor, omarchy.audio, omarchy.network, omarchy.bluetooth, guy.clock, omarchy.power] · tray [].

### Window-fit rule (as written on the test laptop)
File: ~/.config/hypr/hyprland.lua. It EXISTED before (stock Omarchy user file); the rule is appended at TOP LEVEL at the very end, after the stock "Add any other personal Hyprland configuration below." comment and its commented qemu example. Not inside any function. Backup: hyprland.lua.bak.1793165890.
```lua
-- Omnemo OS: a new floating window opens centered and never bigger than the
-- screen above the bottom bar, so its titlebar buttons are always reachable
-- (sized for 1366x768: 1366 wide, 768 minus the bar and gaps tall).
o.window({ float = true }, { center = true, max_size = { 1346, 700 } })
```
Formula for the installer: max_w = monitor.width - 2*gaps_out; max_h = monitor.height - reserved_bottom - 2*gaps_out - 2*border_size - titlebar headroom.
On the test laptop (1366×768): gaps_out 10 (`hyprctl getoption general:gaps_out`), border_size 2, reserved [0,0,0,30] (bar = 30 px, `hyprctl monitors -j`). So w-20, h-68 = 30 bar + 20 gaps + 4 borders + 14 headroom for the 4.5 floating titlebar. max_size takes plain numbers only (expressions are for size/move), so compute it at install time.

## 3. Omnemo
Omnemo 0.2.1.dev3 (~/Omnemo, `omnemo serve` MCP), omnemo.memory widget. Installed by Omnemo itself, not this repo.

## 4. Not touched
No system files, no sudo, no Omarchy source edits, no Hyprland keybinding changes, no desktop layer (no desktop icons, by design).

## 5. Installer/uninstaller must
1. Refuse unless `pacman -Q omarchy` vercmp ≥ 4.5.0-1 (--allow-rc for test boxes). Never read /usr/share/omarchy/version (stale).
2. Back up shell.json (timestamped) before writing; uninstall restores it, reverses §2, removes plugin folders and the hyprland.lua block.
3. Never strip `.dock` from shell.json (Favorites' pin list lives there).
4. Run `omarchy restart shell` once at the end (hot reload misses widget edits) and `hyprctl reload` + `hyprctl configerrors` after the rule.

## 6. Deliberate tricks (document in README)
- guy.help hover labels: the plugin API's moduleWidgets() only reaches a plugin's own widget, so guy.help walks the bar's item tree (up to the top, then down to items whose moduleName matches) every 10 s, and sets WidgetButton.tooltipText ONLY where it's empty, inside try/catch. Omarchy's files are untouched. It may stop working (silently) if Omarchy renames moduleName/tooltipText or sandboxes plugins. Labeled: weather, omnemo.memory, agents, monitor, audio, network, bluetooth, power.
- guy.taskbar uses hyprctl polling (1.5 s, skipped while its menu is open), hl.dsp.* dispatchers and special:minimized: re-check on every Omarchy release.

## 7. Security review v0.1: no blockers. Status of the asks
- (2) window address validated (/^0x[0-9a-f]+$/) before every dispatch: DONE 22:53.
- (3) uwsm-app launches built as argv in guy.taskbar + guy.favorites: DONE 22:53.
- (4) guy.help walk documented (§6), try/catch, interval 4 s → 10 s: DONE 22:53.
- (1) strip the guy.taskbar DEBUG console.logs (window titles in the shell log): PENDING the right-click Close test.

## 8. Known open items
- Taskbar right-click → Close: rebuilt on stock PopupCard, awaiting the click test.
- Reboot-survival check.
- Gemini left out of the AI group (by design). AI entries should hide when the binary is missing (todo).
- Plugin versions all 0.1.0; bump when packaging.
- Super+M minimize with the dock disabled: it uses special:minimized (no dock needed), but hasn't been re-clicked since 10-30.
- KNOWN ISSUE: Chrome site notifications show as critical and stay until dismissed; turn them off per site in Chrome. (Stock Omarchy has no timeout setting for critical; upstream suggestion drafted, unposted.)
- Correction: the v0.1 note 'the stock dock can't be disabled from config' was wrong; `disabledPlugins[]` is the switch.
- GOTCHA: the plugin hot-reload logs 'reloading' but keeps running the OLD code. Only `omarchy-restart-shell` loads plugin edits.
- The menu jsonc is seeded ONCE per user and goes stale against the package seed (comment lines differ already), so nothing may byte-match it against the seed.
