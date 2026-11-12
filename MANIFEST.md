# Omnemo OS — edition inventory (built on Omarchy, MIT)
v0.9.3 Public Preview · updated 2026-11-09 PST · base: Omarchy 4.5.0 stable (4.5.0-3; installer gate = 4.5.0-1)
Rule: a layer on stock Omarchy, no fork. Everything below is user-level (no sudo), backed up at install, and put back byte-for-byte by `omnemo-os uninstall` (cold run #7: every path identical, content AND file modes).

## 1. Plugins we ship (~/.config/omarchy/plugins/)
| Plugin | Where on the bar | What it does |
|---|---|---|
| guy.taskbar | left | AI, Browsers, Web apps pop up choices; Files, Apps, Settings (= the full Omarchy menu); one icon per open window (click = focus/minimize/restore; right-click = Minimize / Close / Add to or Remove from Favorites). When windows don't fit, the rest go behind a "+N" button (the active window always stays visible). AI entries only show what works: Claude = CLI or claude.ai web app, ChatGPT = desktop app or chatgpt.com web app, Codex/OpenCode only when installed |
| guy.tools | center, left of ? | "Tools ▴": Calculator, Screenshot (saved in Pictures), Record screen, Color picker, Emoji, Clipboard, Keyboard shortcuts, Terminal, Theme & wallpaper, Lock, Restart or shut down |
| guy.help | center | "?": a plain-words guide to every bar icon, plus a "Built in" Memory row with live numbers (`omnemo stats --json`, read at load and on each open, 3 s cap, words only when unavailable; local 12-hour time). Also gives Omarchy's unlabeled stock icons hover labels at runtime (see §6). Shows an Update row only when an update is ready |
| guy.favorites | center, right of ? | "Favorites ▴": All apps + pinned apps (read live via `omarchy dock pinned`). Right-click a tile → "Remove?" → click to unpin |
| guy.utils | right, after the ‹ | Wrench: pops up Wi-Fi & internet, Bluetooth, Display, Sound, Weather, World clocks, Calendar and All settings, each with its name. Opens Omarchy's own panels (see §6) |
| guy.clock | right, before power | Clock icon; hover = day/date/time; click = month calendar |
| guy.flag | left, first (takes no room) | The flag bar: "?"-icon blue #435ECE (Guy 11-07; plugin default Old Glory #3C3B6E) behind each icon group, 5 red/white horizontal stripes in the open space, painted on its own click-through layer under the (clear) bar. Groups found by walking the bar for widget moduleNames, re-checked every 0.7 s. 0.9.3: the stripes ripple like cloth (a small shader, `flag.frag`, shipped with its compiled form `flag.frag.qsb`), the blue fields are glass with a white star in each end that has room, and a glint crosses the bar about every 40 s. Overrides: shell.toml [flag] red / white / blue / stripes (3-7), e.g. blue = Omnemo azure #0B6BDD; motion = auto (default: full on mains; still on battery and on a computer that draws without a graphics card, told by `drawn-by.sh` in the plugin folder) / full / calm / off; stars = 0; depth = 0 (the flat 0.9.2 flag, no motion). Motion stops while a fullscreen window covers the bar |
Stock widgets placed by us: omarchy.agents (AI usage meter) at the far left; omarchy.tray (‹) on the right, holding Network, Bluetooth, Display, Weather and World clocks in its drawer, plus any background-app tray icons.
Not shipped: omnemo.memory (Guy, 10-30: "User does not need a memory display"), guy.start, guy.apps, guy.dock.
Every edition plugin shows a colored Papirus icon (§3a) and falls back to its one-color glyph when the icon is missing. Tools, wrench, Favorites and ? can be opened with `omarchy-shell shell summon <id> {}` (closed with `shell hide <id>`).
Rename to one product namespace (e.g. omnemo-os.*) after CC's name check.

## 2. Settings we change
| Setting | Value | How (installer) | Undo |
|---|---|---|---|
| Bar position | bottom | `omarchy bar position bottom` | shell.json backup |
| Bar background | solid (opaque) | `omarchy bar background opaque` | shell.json backup |
| Bar look | THE FLAG (Guy 11-07: "Perfect"): guy.flag paints "?"-icon blue #435ECE (Guy 11-07; plugin default Old Glory #3C3B6E) behind each icon group and 5 red/white stripes (#C21F35/#FFFFFF; #B22234 until 0.9.2) between them, on its own click-through layer under a clear bar. From 0.9.3 the stripes ripple, the fields are glass with stars, and the look file lists the motion choices as commented lines. White bar text; navy #0B0E14 menu cards; azure #0B6BDD active-window marker and card hairline. Variants A (navy) and B (azure) ship as system/omnemo-look-A.toml / -B.toml, unused | guy.flag first in layout.json left + marked block appended to ~/.config/omarchy/shell.toml from system/omnemo-look-flag.toml (bar background-alpha 0) | plugin dir removed; shell.toml file backup (byte-exact; removed if it was absent) |
| Bar layout | see layout.json | `bar.layout` in ~/.config/omarchy/shell.json | shell.json backup |
| Removed from bar | omarchy.menu, omarchy.workspaces, omarchy.clock (→ guy.clock) | layout | shell.json backup |
| Right side | only ‹ (hidden icons), wrench, Sound, clock, power; Update, recording and keyboard-language icons appear only when they matter. Network, Bluetooth, Display, Weather, World clocks move into the ‹ drawer (`bar.layout.tray`) | layout | shell.json backup |
| Stock dock | disabled (it duplicated Favorites/Tools and popped up on bottom-edge hover). `.dock.pinned` is KEPT: Favorites reads it | `omarchy plugin disable omarchy.dock` | shell.json backup (disabledPlugins lives there) |
| Workspaces | floating by default | `omarchy hyprland workspace layout default floating` | workspace-layouts dir backup (or removed if it was absent) |
| Window fit | new floating windows open centered and fit above the bar | marked block in ~/.config/hypr/hyprland.lua, max_size computed from the monitor at install | file backup |
| Apps list | "Apps" entry in the Omarchy menu (the app grid lived in the disabled dock) | marked block in ~/.config/omarchy/extensions/omarchy-menu.jsonc (seeded from /usr/share/omarchy/config/... if absent) | file backup |
| Super+Alt+Space | opens the Apps list (stock pointed at the dock) | marked block in ~/.config/hypr/bindings.lua | file backup |
| Super+M | minimizes the window to our taskbar on every kind of workspace (stock 4.5 minimizes only on a floating one) | `o.rebind` line in the same marked block in ~/.config/hypr/bindings.lua; runs ~/.local/bin/omnemo-window-minimize | file backup |
| Pointer | no jump to the window centre on a taskbar switch | `cursor.no_warps = true` block in ~/.config/hypr/looknfeel.lua | file backup |

## 3. Everyday-user extras
| What | File | Why |
|---|---|---|
| One-bar guard | ~/.local/bin/omnemo-one-bar + ~/.config/systemd/user/omnemo-one-bar.{service,timer} (every 30 s) | Quickshell never cleans its runtime folders; when /run/user tmpfs fills, every restart stacks another bar. The guard keeps one launcher (TERM, never KILL, own processes only) and removes dead instance folders |
| Minimize program | ~/.local/bin/omnemo-window-minimize | what Super+M runs: Omarchy's own minimize without its "floating workspaces only" rule. The taskbar brings the window back on any layout |
| Friendly names | ~/.local/share/applications/{foot,omacalc,omawrite}.desktop → Terminal, Calculator, Writer | "foot" means nothing to a non-developer. Marked with `# omnemo-os: friendly name` |
| Text files open in Writer | ~/.config/mimeapps.list (`xdg-mime default omawrite.desktop text/plain`) | stock opens .txt in nvim inside a terminal |
| Icon-set stand-ins | ~/.local/share/icons/Yaru-gray, Yaru-grey (index.theme, Inherits=Yaru,hicolor) | stock White and Vantablack themes name icon sets that aren't installed, so app icons vanish (upstream report to file) |

## 3a. Colored icons (0.9.2)
| What | Where | Notes |
|---|---|---|
| Papirus 48x48 set (GPL-3.0) | ~/.local/share/omnemo-os/icons (+ VERSION, LICENSE) | downloaded at install from GitHub, release 20260801, sha256 646f622e…08f9 checked; ~33 MB file (about 35 MB on the wire), 56 MB on disk. Our own folder, not an icon theme: nothing else on the computer changes |
| Updater | ~/.local/bin/omnemo-icons-update | `--pin TAG SHA` (install), plain = newest release. Checks every icon the bar names, refuses non-SVG files and links that point outside the set, swaps the folder in whole. No timer (Guy: no rush; the Sunday scout flags new releases) |
Offline install: record `icons: failed`, the bar shows glyphs, status flags it, repair downloads. Uninstall removes the folder only if the record says we downloaded it (`icons_was: present` = left alone).

## 3b. Wallpaper choice (0.9.2, Guy 11-03: "Yes, add it")
wallpapers/hwy180-west-golden.jpg (2752x1536, 1.1 MB; AI-made with Gamma for Project Sparks: Highway 180 west into the Fresno valley at golden hour). Installed with the app copy; a link to it goes into ~/.config/omarchy/backgrounds/<theme>/ for every stock and user theme, so it shows in Theme & wallpaper (Super+Ctrl+W) whatever the theme. Never set as the current wallpaper. A same-named file already there is skipped. Record `wallpaper.links` / `wallpaper.dirs`; uninstall removes only those links (still pointing at our copy) and the folders it created, if empty.

## 4. Commands
`omnemo-os install [--allow-rc]` · `update [--allow-rc]` · `uninstall` · `status` · `repair`
- install copies bin/, plugins/, system/ and layout.json to ~/.local/share/omnemo-os/app and links ~/.local/bin/omnemo-os there (on PATH in Omarchy's bash envs), so the clone can be deleted. Uninstall removes both last (record `command_link: true`); status flags a broken link, repair relinks.
- Omarchy's "omarchy-shell is not responding" line from a busy shell is hidden on the first try of each shell step; it shows only if the retry also fails.
- status also reports the icons; flags when an Omarchy update reset the friendly names (omarchy-refresh-applications re-copies foot.desktop) or the guard is off.
- repair puts both back and checks its own result; safe to run any time, any number of times.
- install says what it will download, and how big, before it changes anything (a bit under 200 MB in all: memory program about 130 MB, icons about 35 MB), and names the AI helpers it will not download.
- status and the end of install say which AI helpers have the memory and which are not on the computer yet; both print the one-line `sudo pacman -D --asexplicit omarchy` advice when (and only when) Omarchy is marked as installed-as-a-dependency (omarchy#18154).

## 4b. Update (0.9.3)
`omnemo-os update` moves an installed edition to a newer one, in place, with no questions.
- From the installed command: looks up the newest release tag, downloads it to a temporary folder, and hands over to that copy. Already newest = says so and stops. No internet = says so, changes nothing.
- From a downloaded copy (`./bin/omnemo-os update`): applies that copy. This is how an edition from before 0.9.3 (which has no update command) moves up.
- The install-day backup and record stay the baseline, so uninstall after any number of updates still goes back to the computer as it was before the first install. Files this version manages that the installed one did not are noted first (present = copied into the backup, absent = listed for removal).
- Ours, so replaced: the plugins, our small programs, the guard units, the marked blocks in hyprland.lua (window size worked out again for today's screen), bindings.lua, looknfeel.lua and the menu file, the installed copy and the command link.
- The person's, so kept: a bar layout or bar-colour block that no longer matches what the installed version wrote stays as it is (one line says so). A plugin that differs from the installed version's copy is saved to ~/.local/state/omnemo-os/replaced/<time>/plugins/ before ours replaces it, and the last lines of the update name it.
- Memory: only if the record says we installed Omnemo, and only when the pinned commit moved: `pip install --upgrade` of the new pin into the same venv, then `omnemo setup`. The store is never touched. Failure leaves the old program working.
- Never goes backwards (an older copy refuses).

## 4a. Omnemo memory (0.9.1)
- install: if the Omnemo program is absent (no ~/.local/share/omnemo-venv, no ~/.local/bin/omnemo), set it up the INSTALL.md way, no sudo: venv + `pip install git+https://github.com/GuyMannDude/omnemo@<OMNEMO_REF>` (pinned, reviewed commit; 0.9.3 pins `86de3209`, main of 2026-11-09: the one code change since the last pin keeps the memory widget off the bar unless asked for, the rest is documents) + link + `omnemo setup` (skill + links in ~/.agents ~/.claude ~/.codex ~/.pi/agent, omnemo.memory plugin dir, omnemo-warm.service, MCP registration for claude/codex/opencode/crush/gemini). Runs BEFORE the layout write, so omnemo.memory is installed but never on the bar.
- Only helpers that are really on the computer (0.9.3, #5). Omarchy lists claude, codex and others as commands from day one, but they are stand-ins that download the real program (hundreds of MB) on first run, and `omnemo setup` runs each helper it finds. The installer now counts a helper only when its command leads to a real program (or its folder under ~/.local/share/mise/installs/ exists), and runs `omnemo setup` and `omnemo disconnect` with the stand-ins of the others hidden from PATH. A helper that arrives later gets the memory from `omnemo-os repair`.
- The helpers' own settings files (0.9.3, #4): ~/.claude.json, ~/.codex/config.toml, ~/.config/crush/crush.json, ~/.config/opencode/opencode.json, ~/.gemini/settings.json. Before the first `omnemo setup` each is copied into the backup (folder mode 700) or listed as absent, and its checksum is noted after setup. At uninstall, after `omnemo disconnect`: a file still exactly as setup left it goes back byte for byte (or is removed if it was absent, with its folder when that was absent and is now empty); a file used since then is the person's and stays, unless the only difference from its install-day self is the empty `mcp`/`mcpServers` key, in which case the install-day copy goes back. These files hold sign-ins and history, so they are never restored blindly. Uninstall deletes the copies when it is done.
- Already present: recorded `omnemo_was: present`, nothing run, uninstall leaves it alone.
- Offline/failure: the desktop install goes on, record says `omnemo: failed`, status flags it, repair retries.
- uninstall (only when the record says we installed it): `omnemo disconnect --all-pieces`, then remove the link and the venv. The store ~/.local/share/omnemo (memories + skill copy) is NEVER removed; uninstall prints where it is. A later install finds and keeps it.
- Cold run #8 (10-31): install 1m24s; save + recall from the CLI, a new `claude -p` and `codex exec`; serve RSS 56 MB idle, 329 MB with the model loaded; uninstall byte+mode identical (all edition paths, every Omnemo path, the four harness config files, claude's mcpServers, the warm unit) except the store, which is the one intended leftover; reinstall over a kept store recalls the old memory.
- Keep or fresh (0.9.2, CC #5730): install asks "Found N memories from before. Keep them? [Y/n]" when it installs Omnemo onto an existing store; uninstall asks "Keep your memories? [Y/n]" when it removes the Omnemo it installed. Enter, any answer but n, no terminal, or anything but a typed DELETE at the second question = keep. Delete = tar to ~/omnemo-memories-<date>.tar.gz, `tar -t` check, then remove; a fresh install then reruns `omnemo setup`. Omnemo that was there before Omnemo OS is never asked about or touched.

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
- What 1.0 waits for (same sentence as the README): a full Omarchy version update taken on a stock computer with the edition on.
- Already passed: the reboot check and an `omarchy-update` with Omnemo OS on (10-30; 6 app packages moved, Omarchy itself did not). An Omarchy version bump with the edition on is the part not yet done; status/repair and tests/bar-check.sh are the backstop (foot.desktop reset is the known case).
- Chrome site notifications arrive as critical and stay until dismissed; turn them off per site in Chrome. Upstream suggestion drafted, unposted (~/omnemo-os-pending/upstream-issue-notifications.md).
- quickshell logs "Module path ... is outside of the config folder" for every user plugin: harmless, stock behaviour.
- Plugin manifests at 0.9.3 (guy.flag keeps its own number, 0.2.0).
- What the moving flag costs, measured on one computer only (a 2015 two-core laptop, Intel HD 520, 1366x768, mains power, full motion): the shell went from under 1% to about 9% of one processor core, and its memory stood at about 300 MB. On battery the flag holds still by default, and the same laptop's shell then measured under 2% of a core. On a computer that draws without a graphics card (a virtual machine, 2 processors) any motion was heavy, because the whole desktop repaints in software: the shell and Hyprland together took 85 to 95% of one core at full motion, about 67% at calm, and nothing with a still flag. So the flag holds still there by default too; `motion = "full"` or `"calm"` overrides that. Calm mode on a graphics card, the pause under a fullscreen window, and the effect on battery life are not measured yet. `motion = "off"` in shell.toml gives a still flag.
- The bar stayed solid for some minutes after one first install (#6), hiding the flag. Cause not found. From 0.9.3 the installer nudges the shell to read shell.toml again after its restart and prints the one-line cure (`omarchy restart shell`); whether the nudge prevents it is not proven, because it was seen only once.
- An edition installed by 0.9.2 or earlier and then updated: what that older install left in the helpers' settings files and the helper programs it downloaded (#4, #5) are not cleaned up by update or by a later uninstall; nothing recorded how those files were before.
