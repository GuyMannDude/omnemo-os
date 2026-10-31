# Installer notes — kept OUT of MANIFEST.md on purpose

`MANIFEST.md` describes the edition as built and tested on the test laptop. This file holds the installer-side facts.

## shell.json keys the edition writes (installer source of truth = `layout.json` + MANIFEST §2)
`bar.position` = bottom · `bar.layout` = `layout.json` · `dock.autohide` = true · `dock.position` = bottom.
Untouched: `bar.transparent`, `plugins` (empty list; plugins load from folder + layout), `idle`, `version`.

## Outside shell.json
- `~/.local/state/omarchy/workspace-layouts/default.lua` ← `omarchy hyprland workspace layout default floating`; uninstall restores the backup (or removes the file if it was absent) and runs `... default dwindle`.
- `~/.config/hypr/hyprland.lua` (user file, stock) ← marked block `-- omnemo-os:begin … -- omnemo-os:end` with `o.window({ float = true }, { center = true, max_size = { W, H } })`; W/H computed at install from `hyprctl monitors -j` + `getoption general:gaps_out` / `general:border_size` (MANIFEST §2 formula; a 1366×768 laptop → 1346×700). Uninstall restores the backup byte-exact (or strips the block if the file was created by us).

## Still owed before packaging
- Strip guy.taskbar DEBUG `console.log` lines (right-click Close test first).
- Rename plugins to one product namespace (`omnemo-os.*`) and bump versions.
- Run install/uninstall for real on the test laptop (`--allow-rc`), then `git diff` the stock files to prove byte-exact restore.
