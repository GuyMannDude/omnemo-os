# Omnemo OS — edition inventory (built on Omarchy, MIT)
v0.9.0 Public Preview · updated 2026-10-30 22:15 PDT · base: Omarchy 4.5.0rc2 (rc channel; stable gate = 4.5.0-1)
Rule: a layer on stock Omarchy, no fork. Everything below is user-level (no sudo), backed up at install, and put back byte-for-byte by `omnemo-os uninstall` (cold run #7: every path identical, content AND file modes).

## 1. Plugins we ship (~/.config/omarchy/plugins/)
| Plugin | Where on the bar | What it does |
|---|---|---|
| guy.taskbar | left | AI, Browsers, Web apps pop up choices; Files, Apps, Settings (= the full Omarchy menu); one icon per open window (click = focus/minimize/restore; right-click = Minimize / Close / Add to or Remove from Favorites). When windows don't fit, the rest go behind a "+N" button (the active window always stays visible). AI entries only show what works: Claude = CLI or claude.ai web app, ChatGPT = desktop app or chatgpt.com web app, Codex/OpenCode only when installed |
| guy.tools | center, left of ? | "Tools ▴": Calculator, Screenshot (saved in Pictures), Record screen, Color picker, Emoji, Clipboard, Keyboard shortcuts, Terminal, Theme & wallpaper, Lock, Restart or shut down |
| guy.help | center | "?": a plain-words guide to every bar icon. Also gives Omarchy's unlabeled stock icons hover labels at runtime (see §6). Shows an Update row only when an update is ready |
| guy.favorites | center, right of ? | "Favorites ▴": All apps + pinned apps (read live via `omarchy dock pinned`). Right-click a tile → "Remove?" → click to unpin |
| guy.utils | right, after the ‹ | Wrench: pops up Wi-Fi & internet, Bluetooth, Display, Sound, Weather, World clocks, Calendar and All settings, each with its name. Opens Omarchy's own panels (see §6) |
| guy.clock | right, before power | Clock icon; hover = day/date/time; click = month calendar |
Stock widgets placed by us: omarchy.agents (AI usage meter) at the far left; omarchy.tray (‹) on the right, holding Network, Bluetooth, Display, Weather and World clocks in its drawer, plus any background-app tray icons.
Not shipped: omnemo.memory (Guy, 10-30: "User does not need a memory display"), guy.start, guy.apps, guy.dock.
Rename to one product namespace (e.g. omnemo-os.*) after CC's name check.

## 2. Settings we change
| Setting | Value | How (installer) | Undo |
|---|---|---|---|
| Bar position | bottom | `omarchy bar position bottom` | shell.json backup |
| Bar layout | see layout.json | `bar.layout` in ~/.config/omarchy/shell.json | shell.json backup |
| Removed from bar | omarchy.menu, omarchy.workspaces, omarchy.clock (→ guy.clock) | layout | shell.json backup |
| Right side | only ‹ (hidden icons), wrench, Sound, clock, power; Update, recording and keyboard-language icons appear only when they matter. Network, Bluetooth, Display, Weather, World clocks move into the ‹ drawer (`bar.layout.tray`) | layout | shell.json backup |
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

## 4a. Omnemo memory (0.9.1)
- install: if the Omnemo program is absent (no ~/.local/share/omnemo-venv, no ~/.local/bin/omnemo), set it up the INSTALL.md way, no sudo: venv + `pip install git+https://github.com/GuyMannDude/omnemo@<OMNEMO_REF>` (pinned, reviewed commit) + link + `omnemo setup` (skill + links in ~/.agents ~/.claude ~/.codex ~/.pi/agent, omnemo.memory plugin dir, omnemo-warm.service, MCP registration for claude/codex/opencode/crush/gemini). Runs BEFORE the layout write, so omnemo.memory is installed but never on the bar.
- Already present: recorded `omnemo_was: present`, nothing run, uninstall leaves it alone.
- Offline/failure: the desktop install goes on, record says `omnemo: failed`, status flags it, repair retries.
- uninstall (only when the record says we installed it): `omnemo disconnect --all-pieces`, then remove the link and the venv. The store ~/.local/share/omnemo (memories + skill copy) is NEVER removed; uninstall prints where it is. A later install finds and keeps it.
- Cold run #8 (10-31): install 1m24s; save + recall from the CLI, a new `claude -p` and `codex exec`; serve RSS 56 MB idle, 329 MB with the model loaded; uninstall byte+mode identical (all edition paths, every Omnemo path, the four harness config files, claude's mcpServers, the warm unit) except the store, which is the one intended leftover; reinstall over a kept store recalls the old memory.
- 0.9.2: keep-or-fresh prompt (typed DELETE, tar first), `?` Memory row with live stats, ~/.local/bin/omnemo-os on PATH.

## 5. Not touched
No system files, no sudo, no Omarchy source edits, no desktop icons (Guy's veto). One keybinding is re-pointed (Super+Alt+Space); nothing else.

## 6. Deliberate tricks (document in README)
- guy.help hover labels: the plugin API only reaches a plugin's own widget, so guy.help walks the bar's item tree every 10 s and sets tooltipText ONLY where it is empty, inside try/catch. May stop working (silently) if Omarchy renames moduleName/tooltipText or sandboxes plugins.
- guy.taskbar measures free room by walking to the next widget's x; uses hyprctl polling (1.5 s, paused while its menu is open), hl.dsp.* dispatchers and special:minimized. Re-check on every Omarchy release.
- Repeater modelData arrays fail Array.isArray: run() in taskbar/favorites copies any non-string into a plain array before launching (argv, never sh -c).
- Menu rows do their work in a root function, not in the row's onClicked (closing the menu destroys the row mid-handler).
- guy.utils (wrench) opens panels with `omarchy-shell shell summon <id> {}`. Omarchy only opens a panel whose widget is LIVE on the bar (journal when it isn't: `summon: no live bar widget for: omarchy.clock`), and widgets in the tray drawer stay live only while omarchy.tray is on the bar. That's why the ‹ stays. If Omarchy changes this, the wrench entries quietly do nothing (no crash), and the panels still open from the ‹ drawer.
- shell.json is 600 after any Omarchy bar command (the shell's own writer); ours carries the mode through and uninstall puts the original mode back (cold run #6/#7).

## 7. Security review (CC #5565): no blockers
Window address validated before every dispatch; launches built as argv; help walk documented + try/catch; DEBUG logging stripped (10-30).

## 8. Known issues / open
- Gate: Omarchy 4.5 stable. Reboot check PASSED and `omarchy-update` PASSED 10-30 (6 app packages moved, Omarchy itself did not).
- omarchy-update ran clean with Omnemo OS on; an Omarchy version bump is untested until 4.5 stable, and status/repair is the backstop (foot.desktop reset is the known case).
- Chrome site notifications arrive as critical and stay until dismissed; turn them off per site in Chrome. Upstream suggestion drafted, unposted (~/omnemo-os-pending/upstream-issue-notifications.md).
- quickshell logs "Module path ... is outside of the config folder" for every user plugin: harmless, stock behaviour.
- Plugin versions all 0.1.0; bump when packaging.
