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

## Cold run #9 — 2026-11-07 (fresh Omarchy 4.5.0-3 stable, QEMU VM, 4 GB / 2 vCPU)
A stranger's run from the README on today's ISO (sha256 + GPG verified), whole-home snapshot before and after, then the same around uninstall. Lab record and screenshots are kept with the lab VM (not in this repo).
- **Install (04d51c7): PASS, 0 human fixes.** Flag bar, Tools / ? / Favorites / wrench menus, `omnemo-os status` all as spec. Second install needed 1 human fix: Omarchy's 5-minute idle lock engaged during the 12-minute Omnemo download, and `omarchy restart shell` refuses while locked; under `set -e` the install died one line before "installed." with everything applied. Fixed in a17dfe8 (both restart call sites print "the bar did not restart (screen locked?); unlock, then run: omarchy restart shell" instead of dying) and re-verified: clean install in 39 s. Same commit: no "Keep them?" question when the store holds 0 memories.
- **Reboot with the edition: PASS.** Exactly one bar process, one-bar guard timer firing, flag at +25 s / +60 s / +5 min.
- **Uninstall: every managed path byte-exact (content + mode).** The strict whole-home compare found two edition paths left behind: `~/.local/share/icons` as an empty dir (created as the parent of the Yaru-gray/grey shims) and `~/.local/state/omarchy/workspace-layout-notification` (written by Omarchy when the installer sets the default layout). Fixed in 08c8436: both go through `managed_files` / `absent.list`, plus an `icons-dir.absent` marker in the backup. **Re-run on 08c8436: PASS** — both gone after uninstall, flag bar at spec straight away, 1 quickshell.
- **Known leftovers, Omnemo-side, not the edition's (issues #4, #5):** `omnemo setup` creates/changes AI-helper configs (`~/.claude.json`, `~/.codex/config.toml`, `~/.config/crush/crush.json`, `~/.config/opencode/opencode.json` gains `"mcp": {}`), and running `claude` / `codex` through Omarchy's mise shims downloads Claude Code (~325 MB) and Codex (~516 MB) into `~/.local/share/mise/installs`. Uninstall does not undo these. Documented for 0.9.2; fix in Omnemo for 0.9.3.
- **Flag bar first paint (issue #6):** right after the FIRST install the bar stayed opaque theme-colour for several minutes, then cleared with the same quickshell PID; after a restart the flag shows within 15 s. Unexplained; did not recur on the re-run.
- quickshell idle RSS ≈ 670–750 MB in the VM (software rendering); stock measured 705 MB, so it is the VM, not the edition.
- Lab traps worth keeping: a 12-minute unattended install trips Omarchy's idle lock (screensaver 150 s, lock 300 s) — Stay Awake (`omarchy-toggle-idle`) before a long install in a VM; a `set -e` installer must never die after the record is written and before "installed." (it now doesn't).

## Still owed
- Rename plugins to one product namespace (`omnemo-os.*`).
