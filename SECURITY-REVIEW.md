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
