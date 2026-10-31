# Installer notes — kept OUT of MANIFEST.md on purpose

`MANIFEST.md` describes the edition as built and tested on the test laptop. This file holds the installer-side facts.

## shell.json keys the edition writes (installer source of truth = `layout.json` + MANIFEST §2)
`bar.position` = bottom · `bar.layout` = `layout.json` · `disabledPlugins` = `["omarchy.dock"]` (via `omarchy plugin disable omarchy.dock`; the byte-exact shell.json restore on uninstall re-enables it).
Untouched: `bar.transparent`, `plugins` (empty list; plugins load from folder + layout), `dock` (pinned list stays for guy.favorites), `idle`, `version`.

## Outside shell.json
- `~/.local/state/omarchy/workspace-layouts/default.lua` ← `omarchy hyprland workspace layout default floating`; uninstall restores the backup (or removes the file if it was absent) and runs `... default dwindle`.
- `~/.config/hypr/hyprland.lua` (user file, stock) ← marked block `-- omnemo-os:begin … -- omnemo-os:end` with `o.window({ float = true }, { center = true, max_size = { W, H } })`; W/H computed at install from `hyprctl monitors -j` + `getoption general:gaps_out` / `general:border_size` (MANIFEST §2 formula; a 1366×768 laptop → 1346×700). Uninstall restores the backup byte-exact (or strips the block if the file was created by us).

- `~/.config/omarchy/extensions/omarchy-menu.jsonc` (user file, seeded once by Omarchy) ← marked block (`// omnemo-os:begin … // omnemo-os:end`) with the `apps` entry, inserted before the final `}`; seeded from `/usr/share/omarchy/config/omarchy/extensions/omarchy-menu.jsonc` when absent; refuses if `"apps"` is already defined. Uninstall restores the backup byte-exact (or removes the file if it was absent), then `omarchy-menu refresh`.
- `~/.config/hypr/bindings.lua` + `~/.config/hypr/looknfeel.lua` (user files, stock-seeded) ← the same `-- omnemo-os:begin/end` block pattern as hyprland.lua: Super+Alt+Space → `omarchy-menu toggle apps`; `cursor.no_warps = true`. Uninstall restores the backups byte-exact.
- Hot reload trap: plugin edits only load after `omarchy-restart-shell`; the installer already restarts the shell last.

## Still owed before packaging
- Rename plugins to one product namespace (`omnemo-os.*`) and bump versions.
- Run install/uninstall for real on the test laptop (`--allow-rc`), then `git diff` the stock files to prove byte-exact restore.
