# Omnemo OS — edition inventory (built on Omarchy, MIT)
v0.9.0 Public Preview · updated 2026-10-30 21:30 PDT · base: Omarchy 4.5.0rc2 (rc channel; stable gate = 4.5.0-1)
Rule: a layer on stock Omarchy, no fork. Everything below is user-level (no sudo), backed up at install, and put back byte-for-byte by `omnemo-os uninstall` (cold run #5: 23 paths identical).

## 1. Plugins we ship (~/.config/omarchy/plugins/)
| Plugin | Where on the bar | What it does |
|---|---|---|
| guy.taskbar | left | AI, Browsers, Web apps pop up choices; Files, Apps, Settings (= the full Omarchy menu), Utils; one icon per open window (click = focus/minimize/restore; right-click = Minimize / Close / Add to or Remove from Favorites). When windows don't fit, the rest go behind a "+N" button (the active window always stays visible). AI entries only show what works: Claude = CLI or claude.ai web app, ChatGPT = desktop app or chatgpt.com web app, Codex/OpenCode only when installed |
| guy.tools | center, left of ? | "Tools ▴": Calculator, Screenshot (saved in Pictures), Record screen, Color picker, Emoji, Clipboard, Keyboard shortcuts, Terminal, Theme & wallpaper, Lock, Restart or shut down |
| guy.help | center | "?": a plain-words guide to every bar icon. Also gives Omarchy's unlabeled stock icons hover labels at runtime (see §6). Shows an Update row only when an update is ready |
| guy.favorites | center, right of ? | "Favorites ▴": All apps + pinned apps (read live via `omarchy dock pinned`). Right-click a tile → "Remove?" → click to unpin |
| guy.clock | right, before power | Clock icon; hover = day/date/time; click = month calendar |
Stock widget placed by us: omarchy.agents (AI usage meter) at the far left.
Not shipped: omnemo.memory (Guy, 10-30: "User does not need a memory display"), guy.start, guy.apps, guy.dock.
Rename to one product namespace (e.g. omnemo-os.*) after CC's name check.

## 2. Settings we change
| Setting | Value | How (installer) | Undo |
|---|---|---|---|
| Bar position | bottom | `omarchy bar position bottom` | shell.json backup |
| Bar layout | see layout.json | `bar.layout` in ~/.config/omarchy/shell.json | shell.json backup |
| Removed from bar | omarchy.menu, omarchy.workspaces, omarchy.clock (→ guy.clock), omarchy.tray | layout | shell.json backup |
| Stock dock | disabled (it duplicated Favorites/Tools and popped up on bottom-edge hover). `.dock.pinned` is KEPT: Favorites reads it | `omarchy plugin disable omarchy.dock` | shell.json backup (disabledPlugins lives there) |
| Workspaces | floating by default | `omarchy hyprland workspace layout default floating` | workspace-layouts dir backup (or removed if it was absent) |
| Window fit | new floating windows open centered and fit above the bar | marked block in ~/.config/hypr/hyprland.lua, max_size computed from the monitor at install | file backup |
| Apps list | "Apps" entry in the Omarchy menu (the app grid lived in the disabled dock) | marked block in ~/.config/omarchy/extensions/omarchy-menu.jsonc (seeded from /usr/share/omarchy/config/... if absent) | file backup |
| Super+Alt+Space | opens the Apps list (stock pointed at the dock) | marked block in ~/.config/hypr/bindings.lua | file backup |
| Pointer | no jump to the window centre on a taskbar switch | `cursor.no_warps = true` block in ~/.config/hypr/looknfeel.lua | file backup |

## 3. Everyday-user extras
| What | File | Why |
|---|---|---|
| One-bar guard | ~/.local/bin/omnemo-one-bar + ~/.config/systemd/user/omnemo-one-bar.{service,timer} (every 30 s) | Quickshell never cleans its runtime folders; when /run/user tmpfs fills, every restart stacks another bar. The guard keeps one launcher (TERM, never KILL, own processes only) and removes dead instance folders |
| Friendly names | ~/.local/share/applications/{foot,omacalc,omawrite}.desktop → Terminal, Calculator, Writer | "foot" means nothing to a non-developer. Marked with `# omnemo-os: friendly name` |
| Text files open in Writer | ~/.config/mimeapps.list (`xdg-mime default omawrite.desktop text/plain`) | stock opens .txt in nvim inside a terminal |
| Icon-set stand-ins | ~/.local/share/icons/Yaru-gray, Yaru-grey (index.theme, Inherits=Yaru,hicolor) | stock White and Vantablack themes name icon sets that aren't installed, so app icons vanish (upstream report to file) |

## 4. Commands
`omnemo-os install [--allow-rc]` · `uninstall` · `status` · `repair`
- status flags when an Omarchy update reset the friendly names (omarchy-refresh-applications re-copies foot.desktop) or the guard is off.
- repair puts both back and checks its own result; safe to run any time, any number of times.

## 5. Not touched
No system files, no sudo, no Omarchy source edits, no desktop icons (Guy's veto). One keybinding is re-pointed (Super+Alt+Space); nothing else.

## 6. Deliberate tricks (document in README)
- guy.help hover labels: the plugin API only reaches a plugin's own widget, so guy.help walks the bar's item tree every 10 s and sets tooltipText ONLY where it is empty, inside try/catch. May stop working (silently) if Omarchy renames moduleName/tooltipText or sandboxes plugins.
- guy.taskbar measures free room by walking to the next widget's x; uses hyprctl polling (1.5 s, paused while its menu is open), hl.dsp.* dispatchers and special:minimized. Re-check on every Omarchy release.
- Repeater modelData arrays fail Array.isArray: run() in taskbar/favorites copies any non-string into a plain array before launching (argv, never sh -c).
- Menu rows do their work in a root function, not in the row's onClicked (closing the menu destroys the row mid-handler).

## 7. Security review (CC #5565): no blockers
Window address validated before every dispatch; launches built as argv; help walk documented + try/catch; DEBUG logging stripped (10-30).

## 8. Known issues / open
- Gate: Omarchy 4.5 stable, plus a reboot + `omarchy-update` survival check (pending, needs Guy).
- Chrome site notifications arrive as critical and stay until dismissed; turn them off per site in Chrome. Upstream suggestion drafted, unposted (~/omnemo-os-pending/upstream-issue-notifications.md).
- quickshell logs "Module path ... is outside of the config folder" for every user plugin: harmless, stock behaviour.
- Plugin versions all 0.1.0; bump when packaging.
