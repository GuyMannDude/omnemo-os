# Security review — Omnemo OS plugins v0.1

Static review · 2026-10-27 · static read of 6 × BarWidget.qml + 6 × manifest.json (1,279 QML lines).
Hashes verified against the build machine's list (12/12). **Not run on a box; Omarchy/Quickshell API semantics not exercised.**
Scope: what the plugins execute, what they read, what they write, what they log. Out of scope: Omarchy's own code, the installer (reviewed separately when it has run on a box).

## Verdict
**No blocking finding.** No network use, no file writes, no privilege escalation, no reads outside the user session. Every string shown on screen uses `Text.PlainText`. Three hardening items and one design concern before public release.

## Findings

| # | Sev | Where | What | Fix |
|---|---|---|---|---|
| 1 | MED (privacy) | guy.taskbar 173, 211, 217, 434 | `console.log(... JSON.stringify(w))` writes window titles (browser tabs, document names) into the shell log on disk | Strip all four DEBUG lines before packaging (planned after the Close test) |
| 2 | LOW-MED (hardening) | guy.taskbar 152, 159, 165–168, 174 | Window `address` from `hyprctl clients -j` is spliced into dispatcher strings; `restoreWindow` goes through `sh -c` with the address inside a double-quoted shell string. Source is the compositor (trusted), but one validation closes the class | Accept only `/^0x[0-9a-f]+$/` in `windowClicked`/menu paths; drop anything else |
| 3 | LOW (hardening) | guy.taskbar 68 · guy.favorites 28 | `uwsm-app -- '<id>.desktop'` built as a shell string with `'` stripped. Sound as written (single quotes), but needless shell | `Quickshell.execDetached(["uwsm-app", "--", id + ".desktop"])`; same for any command that takes no shell syntax |
| 4 | MED (design / upstream relations) | guy.help 47–91 | Every 4 s walks the whole bar item tree from the root and sets `tooltipText` on **other plugins' and Omarchy's own** buttons. Not a security hole, but it reaches outside its own widget and mutates stock UI at runtime; a future Omarchy plugin sandbox would break it, and upstream may read it as hostile | Keep for the edition, but: make it an explicit, documented behaviour in README; guard with `try`; consider a longer interval or a one-shot after bar (re)build; propose a tooltip hook upstream |
| 5 | INFO (compat) | guy.taskbar 117, 129–130, 152–175 | Depends on Hyprland `hl.dsp.*` dispatcher syntax, `focusHistoryID`, and the `special:minimized` workspace trick; polls `hyprctl clients -j` every 1.5 s | Acceptance "survives an Omarchy update" needs a smoke test per Omarchy release; later: Hyprland event socket instead of polling |
| 6 | INFO | guy.taskbar 48–51 | AI entries launch `claude`, `codex`, `opencode` in a terminal; missing binaries flash a terminal and exit | Hide entries whose command is not on PATH, or show "not installed" |

## Checked and clean
- Imports: QtQuick, Quickshell, Quickshell.Io (Process/StdioCollector only), Quickshell.Widgets, qs.Commons, qs.Ui. No network, no file I/O modules.
- Processes spawned: `hyprctl`, `omarchy …`, `omarchy-shell …`, `omarchy-menu …`, `uwsm-app`, `xdg-terminal-exec`, `omacalc`, `hyprpicker`, `pkill hyprpicker`, `jq`. All user-level, all Omarchy stock or Arch repo.
- All user-visible text is `Text.PlainText`; window titles and app names never reach a rich-text or shell path.
- Manifests: schemaVersion 1, `bar-widget` kind only, author Project Sparks, version 0.1.0.

## Not checked (negative space)
Runtime behaviour on Omarchy 4.5.x; what `qs.Ui` components (`PopupCard`, `WidgetButton`, `BarIconButton`) do with the strings they receive; Quickshell `DesktopEntries` trust model; the installer itself (pending a box).

## Addendum — v0.2 (verified in the diff 2026-10-27)
- Finding 2 (address validation): **closed.** `validAddress()` regex guards focus/minimize/restore/close.
- Finding 3 (shell-free launches): **closed.** `uwsm-app` launches are argv arrays; `run()` only uses `sh -c` for the fixed, hard-coded tool commands.
- Finding 4 (guy.help tree walk): **mitigated.** try/catch, 10 s interval, documented in MANIFEST §6 as a deliberate reach.
- Finding 1 (DEBUG logs of window titles): **open**, pending the right-click Close test.
- guy.start retired; guy.tools gained Terminal / Theme / Lock / Restart entries, all fixed strings. No new findings.

## Addendum — v0.3 (guy.taskbar + guy.favorites, verified in the diff 2026-10-30)
- Finding 1 (DEBUG logs of window titles): **closed.** Zero `console.log` lines remain in either file.
- Regression from the finding-3 fix, now fixed: an argv array that arrives through a Repeater's `modelData` is a Qt list, so `Array.isArray()` was false and the launch fell through to `sh -c` with the array joined by commas. Every Favorites / Browsers / Web apps launch was dead. `run()` now copies any non-string into a plain array before `execDetached`; strings still go through `sh -c` only for the fixed, hard-coded commands. Same shape as before: no user-controlled string reaches a shell.
- Right-click Minimize/Close: the menu row was destroyed mid-handler when the menu closed; the work moved into `root.menuAction()`. No new process or file access.
- Installer v0.9 (cold-run on a stock box 2026-10-30, see INSTALLER-NOTES): three more user files get a marked block with backup + byte-exact restore: `extensions/omarchy-menu.jsonc` (an `apps` entry; refuses if the file already defines one), `hypr/bindings.lua`, `hypr/looknfeel.lua`. Still user-level, no sudo.

## Addendum — 0.9.3 (2026-11-09)

Written by the edition's maintainers alongside the 0.9.3 changes. It is a statement of what the edition does, checked against the code; it is not an independent review, and the installer has still not had one.

**The "No network use" verdict above is about the bar plugins only, and only as they stood on 2026-10-27. It was never true of the edition as a whole, and it should not be read that way.** What reaches the network today:

| When | What | From | Checked how |
|---|---|---|---|
| install, repair | the Omnemo memory program | `pip install` of one pinned commit of github.com/GuyMannDude/omnemo | the commit id pins our code. Its dependencies come from PyPI at whatever versions pip picks; they are not pinned or hash-checked |
| first use of the memory | Omnemo's language model (about 65 MB) | fetched by Omnemo's own library, not by the edition | not checked by the edition |
| install, repair | colored icons (Papirus, 33 MB) | one release archive from the Papirus makers on GitHub | sha256 of the archive is compared with the value written in the installer; a mismatch is refused |
| `omnemo-icons-update`, run by hand | the newest Papirus release | same | no checksum (there is nothing to compare a new release with); only the 48x48 folder is unpacked, into the edition's own folder |
| `omnemo-os update` | the newest release of the edition | `git ls-remote` and `git clone` of github.com/GuyMannDude/omnemo-os over HTTPS | nothing beyond HTTPS and the GitHub account: the same trust as the first `git clone`. Releases are not signed |

Nothing else in the edition opens a connection. The bar plugins still do not: no network modules, no file writes. One plugin runs one more local command than before: the "?" guide runs `omnemo stats --json` (three-second limit) to show how many memories are saved.

**Still true:** user-level only. The edition never runs `sudo`. `omnemo-os status` may print one `sudo pacman -D --asexplicit omarchy` line for the person to run themselves (see the README); the edition does not run it.

**New in 0.9.3, worth a reader's attention:**

- *AI helpers are no longer started by install.* Omarchy's helper commands are stand-ins that download the real program on first run. The installer now runs Omnemo's setup with the stand-ins of not-yet-downloaded helpers hidden: for the length of that one command it builds a temporary folder of links under `$TMPDIR` and puts it on `PATH` in place of the folder holding the stand-in, then deletes it. Nothing is written into Omarchy's or mise's own folders.
- *Copies of the helpers' settings files.* Before Omnemo's setup first runs, `~/.claude.json`, `~/.codex/config.toml`, `~/.config/crush/crush.json`, `~/.config/opencode/opencode.json` and `~/.gemini/settings.json` (those that exist) are copied into `~/.local/state/omnemo-os/backup/<time>/helpers/`, a folder only the owner can read (mode 700), with the files' own permissions kept. These files can name the account a helper is signed in with. The copies are used once, at uninstall, and uninstall deletes them when it is done. A copy is put back only when the live file is exactly as setup left it, or differs from its install-day self by nothing but an empty key; a file used since install is never overwritten.
- *Super + M* runs `~/.local/bin/omnemo-window-minimize`: three `hyprctl dispatch` calls on the active window, the same as Omarchy's own minimize.
- *A compiled file ships beside its source.* The flag bar draws its stripes with a small graphics program, `plugins/guy.flag/flag.frag` (readable text). Qt cannot load the text directly, so the compiled form `flag.frag.qsb` ships next to it. A compiled file cannot be read, so it must be checkable instead: on a computer with Qt 6.12 shader tools, `/usr/lib/qt6/bin/qsb --qt6 -o check.qsb flag.frag` produces a file identical, byte for byte, to the shipped `flag.frag.qsb`. A different Qt version may produce different bytes; rebuild from the source rather than trust a mismatch. It runs on the graphics card, inside the shell's own drawing, and can do nothing but colour its own strip.

**Not checked:** an outside review of the installer; Omnemo's own code and what its dependencies do; the Papirus archive's contents beyond its checksum; behaviour on an Omarchy newer than 4.5.0-3.
