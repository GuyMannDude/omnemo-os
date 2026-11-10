#!/usr/bin/env bash
# Bar check: run on a computer with the edition installed, right after an
# `omarchy update` (and after any install or `omnemo-os update`). It only
# looks; it changes nothing. Part of the release test gate.
#
# What it catches: a bar that came back doubled, a stock widget repeated across
# the bar, the shell failing to load a type after an update (omarchy#17952),
# one of our widgets missing from the bar, or the flag strip not running.
#
#   tests/bar-check.sh        exit 0 = every line says ok
set -uo pipefail

CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
SHELL_JSON="$CFG/omarchy/shell.json"
PLUGINS="$CFG/omarchy/plugins"
bad=0
ok()   { printf 'ok    %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*"; bad=1; }

# 1. Exactly one bar process.
n="$(pgrep -cx quickshell 2>/dev/null || true)"; n="${n:-0}"
if [[ $n == 1 ]]; then ok "one bar is running"; else fail "$n bar processes are running (want 1)"; fi

# 2. Nothing on the bar twice. One widget listed twice, or drawn many times, is
#    the visible half of omarchy#17952.
if [[ -r $SHELL_JSON ]]; then
  dup="$(jq -r '[.bar.layout[]?[]? | if type == "object" then .id else . end] | group_by(.) | map(select(length > 1) | .[0]) | join(" ")' "$SHELL_JSON" 2>/dev/null)"
  if [[ -z $dup ]]; then ok "no widget is on the bar twice"; else fail "on the bar more than once: $dup"; fi
else
  fail "cannot read $SHELL_JSON"
fi

# 3. Every widget of ours that the bar layout names is installed.
miss=""
while IFS= read -r id; do
  [[ -d "$PLUGINS/$id" ]] || miss+="$id "
done < <(jq -r '[.bar.layout[]?[]? | if type == "object" then .id else . end] | map(select(startswith("guy."))) | .[]' "$SHELL_JSON" 2>/dev/null)
if [[ -z $miss ]]; then ok "every edition widget on the bar is installed"; else fail "on the bar but not installed: $miss"; fi

# 4. The shell's own log since this start-up: no type that failed to load.
if command -v journalctl >/dev/null 2>&1; then
  bad_types="$(journalctl --user -b -t omarchy-shell --no-pager -o cat 2>/dev/null | grep -c -E 'is not a type|is not installed|Type .* unavailable' || true)"
  if [[ ${bad_types:-0} == 0 ]]; then ok "the shell log has no failed-to-load lines"
  else fail "$bad_types failed-to-load lines in the shell log: journalctl --user -b | grep -E 'is not a type|unavailable'"; fi
fi

# 5. The flag strip is up, when the flag is part of this bar.
if jq -e '[.bar.layout[]?[]? | if type == "object" then .id else . end] | index("guy.flag")' "$SHELL_JSON" >/dev/null 2>&1; then
  if hyprctl layers 2>/dev/null | grep -q 'guy-flag'; then ok "the flag strip is running under the bar"
  else fail "the flag strip is not running (try: omarchy restart shell)"; fi
fi

# 6. What a person must still look at; a script cannot see these.
cat <<'EOF'

Now look, for one minute:
  - the bar is at the bottom, with the flag showing through it
  - the AI meter shows once, next to the taskbar
  - Tools, the "?" guide and Favorites each open and close
  - Super+M minimizes a window to the taskbar; clicking its dimmed icon brings it back
EOF
exit "$bad"
