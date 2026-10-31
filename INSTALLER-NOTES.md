# Installer notes — kept OUT of MANIFEST.md on purpose

`MANIFEST.md` describes the edition as built and tested on the test laptop. This file holds the installer-side facts.

## shell.json keys the edition writes (installer source of truth = `layout.json` + MANIFEST §2)
`bar.position` = bottom · `bar.layout` = `layout.json` · `disabledPlugins` = `["omarchy.dock"]` (via `omarchy plugin disable omarchy.dock`; the byte-exact shell.json restore on uninstall re-enables it).
Untouched: `bar.transparent`, `plugins` (empty list; plugins load from folder + layout), `dock` (pinned list stays for guy.favorites), `idle`, `version`.

## Outside shell.json
- `~/.local/state/omarchy/workspace-layouts/` (whole dir) ← `omarchy hyprland workspace layout default floating` writes default.lua and pins every workspace that has windows (2.lua …); uninstall restores the dir byte-exact from the backup (or removes it if it was absent). No `... default dwindle` on uninstall: it rewrites default.lua after the restore.
- `~/.config/hypr/hyprland.lua` (user file, stock) ← marked block `-- omnemo-os:begin … -- omnemo-os:end` with `o.window({ float = true }, { center = true, max_size = { W, H } })`; W/H computed at install from `hyprctl monitors -j` + `getoption general:gaps_out` / `general:border_size` (MANIFEST §2 formula; a 1366×768 laptop → 1346×700). Uninstall restores the backup byte-exact (or strips the block if the file was created by us).

- `~/.config/omarchy/extensions/omarchy-menu.jsonc` (user file, seeded once by Omarchy) ← marked block (`// omnemo-os:begin … // omnemo-os:end`) with the `apps` entry, inserted before the final `}`; seeded from `/usr/share/omarchy/config/omarchy/extensions/omarchy-menu.jsonc` when absent; refuses if `"apps"` is already defined. Uninstall restores the backup byte-exact (or removes the file if it was absent), then `omarchy-menu refresh`.
- `~/.config/hypr/bindings.lua` + `~/.config/hypr/looknfeel.lua` (user files, stock-seeded) ← the same `-- omnemo-os:begin/end` block pattern as hyprland.lua: Super+Alt+Space → `omarchy-menu toggle apps`; `cursor.no_warps = true`. Uninstall restores the backups byte-exact.
- Hot reload trap: plugin edits only load after `omarchy-restart-shell`; the installer already restarts the shell last.

## Cold run 2026-10-30 (stock Omarchy 4.5.0rc2 laptop, `--allow-rc`)
Install, clicks (taskbar left/right, Favorites, Apps, Super+Alt+Space, Browsers, cursor), uninstall, sha256 diff of every touched path. Everything byte-exact or absent-as-before except three findings, fixed in v0.9:
1. The 'already carries an omnemo-os block' guards were dead: `grep -qxF "$RULE_BEGIN"` with a marker starting in `--` made grep read it as an option (exit 2, `&& die` never fired). Now `grep -qxF -e`.
2. The windowrule is computed before the bar moves, and on a stock box the bar is on TOP, so `reserved[3]` was 0 and max_h came out 30 px too tall. Now: bottom reservation, else top, else 30.
3. workspace-layouts: `layout default floating` also pins workspaces (2.lua), and uninstall's `layout default dwindle` rewrote default.lua after the restore. Now the whole dir is backed up and restored.
4. (found in cold run #2) `omarchy plugin disable omarchy.dock` right after `omarchy bar position bottom` hit 'omarchy-shell is not responding' (the bar rebuild outlasted the shell's IPC timeout); `set -e` killed install HALF-APPLIED with no record, so uninstall refused and a re-run refused. Now every shell command goes through `shell_step` (wait for `omarchy-shell shell ping`, up to 30 s, then retry once; all three commands are idempotent), and `installed.json` is written right after the backup and BEFORE any change, so a run that dies partway is always undoable.

Cold run #3 on the fixed script: install exit 0 with no grep noise, a re-install attempt refused correctly, uninstall exit 0, byte-diff PASS on all 12 entries including the workspace-layouts dir.

## Still owed
- Rename plugins to one product namespace (`omnemo-os.*`).
