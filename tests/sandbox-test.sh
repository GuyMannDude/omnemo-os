#!/usr/bin/env bash
# Sandbox walk of install / update / repair / uninstall. NOT a box test: it runs
# the real omnemo-os script inside a throwaway home folder, with stand-ins for
# everything that would touch a real desktop (omarchy, hyprctl, systemctl,
# pacman, python3/pip, the AI helpers). It proves the script's own logic: what
# it writes, what it puts back, and that it never starts a helper that is not
# on the computer yet. A cold run on a real Omarchy is still the release gate.
#
#   tests/sandbox-test.sh [path-to-an-older-checkout-for-the-update-walk]
set -uo pipefail

REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
OLD="${1:-}"
SB="$(mktemp -d "${TMPDIR:-/tmp}/omnemo-os-sandbox.XXXXXX")"
STUBS="$SB/stubs"; mkdir -p "$STUBS"
pass=0; failed=0
ok()  { printf 'ok    %s\n' "$*"; pass=$((pass + 1)); }
bad() { printf 'FAIL  %s\n' "$*"; failed=$((failed + 1)); }
check() { local what="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$what"; else bad "$what"; fi; }
nope()  { local what="$1"; shift; if "$@" >/dev/null 2>&1; then bad "$what"; else ok "$what"; fi; }

# ---------------------------------------------------------------- stand-ins
stub() { cat >"$STUBS/$1"; chmod 755 "$STUBS/$1"; }

stub omarchy <<'EOF'
#!/bin/bash
echo "omarchy $*" >>"$SB_LOG"
case "$*" in
  version) echo 4.5.0 ;;
  "hyprland workspace layout default floating")
    d="$HOME/.local/state/omarchy"; mkdir -p "$d/workspace-layouts"
    echo floating >"$d/workspace-layouts/default.lua"; echo 7 >"$d/workspace-layout-notification" ;;
  "plugin disable omarchy.dock")
    f="$HOME/.config/omarchy/shell.json"; t="$(mktemp)"
    jq '.disabledPlugins = ((.disabledPlugins // []) + ["omarchy.dock"] | unique)' "$f" >"$t" && cat "$t" >"$f"; rm -f "$t" ;;
esac
exit 0
EOF
for s in omarchy-shell omarchy-menu systemctl xdg-mime update-desktop-database logger; do
  stub "$s" <<'EOF'
#!/bin/bash
echo "$(basename "$0") $*" >>"$SB_LOG"; exit 0
EOF
done
stub hyprctl <<'EOF'
#!/bin/bash
echo "hyprctl $*" >>"$SB_LOG"
case "$*" in
  "monitors -j") echo '[{"focused":true,"width":1366,"height":768,"scale":1,"reserved":[0,0,0,32]}]' ;;
  "getoption general:gaps_out -j") echo '{"custom":"10 10 10 10"}' ;;
  "getoption general:border_size -j") echo '{"int":2}' ;;
esac
exit 0
EOF
stub pacman <<'EOF'
#!/bin/bash
case "$*" in
  "-Q omarchy") echo "omarchy 4.5.0-3" ;;
  "-Qqd omarchy") [[ -e "$SB/omarchy-is-a-dependency" ]] && echo omarchy || exit 1 ;;
  *) exit 1 ;;
esac
EOF
stub curl <<'EOF'
#!/bin/bash
echo "curl (refused: the sandbox has no internet)" >>"$SB_LOG"; exit 7
EOF
# The lazy stand-in: any helper command that is only a link to this "mise"
# pretends to download the helper when run. The walk must never see that.
stub mise <<'EOF'
#!/bin/bash
n="$(basename "$0")"
if [[ ! -d "$HOME/.local/share/mise/installs/$n/1.0" ]]; then
  echo "DOWNLOADED $n ($*)" >>"$SB/downloads.log"
  mkdir -p "$HOME/.local/share/mise/installs/$n/1.0"
fi
case "$n" in
  claude) f="$HOME/.claude.json"; [[ -e $f ]] || echo '{"firstStartTime":"x","userID":"y"}' >"$f" ;;
  codex)  mkdir -p "$HOME/.codex/tmp/arg0-linux"; [[ -e "$HOME/.codex/config.toml" ]] || : >"$HOME/.codex/config.toml" ;;
esac
exit 0
EOF
# A helper that really is on the computer (used by the "claude is here" walk).
cat >"$SB/real-claude" <<'EOF'
#!/bin/bash
echo "claude $*" >>"$SB_LOG"
f="$HOME/.claude.json"
[[ -e $f ]] || { echo '{"firstStartTime":"x","userID":"y"}' >"$f"; chmod 600 "$f"; }
t="$(mktemp)"
case "$*" in
  "mcp list") jq -r '.mcpServers // {} | keys[]' "$f" ;;
  "mcp get omnemo") jq -e '.mcpServers.omnemo' "$f" >/dev/null && printf 'command: omnemo\nargs: serve\n' ;;
  "mcp add --scope user omnemo -- omnemo serve") jq '.mcpServers.omnemo = {command:"omnemo",args:["serve"]}' "$f" >"$t" && cat "$t" >"$f" ;;
  "mcp remove --scope user omnemo") jq '.mcpServers |= del(.omnemo)' "$f" >"$t" && cat "$t" >"$f" ;;
esac
rm -f "$t"; exit 0
EOF
chmod 755 "$SB/real-claude"
# python3 -m venv DIR: a pretend Omnemo (pip + omnemo) that registers with
# every helper it can find on PATH, the way the real setup does.
stub python3 <<'EOF'
#!/bin/bash
[[ "$1 $2" == "-m venv" ]] || exit 1
v="$3"; mkdir -p "$v/bin"
cat >"$v/bin/pip" <<'P'
#!/bin/bash
v="$(cd "$(dirname "$0")/.." && pwd)"
echo "pip $*" >>"$SB_LOG"
case "$1" in
  install) for a in "$@"; do [[ $a == git+* ]] && echo "${a##*@}" >"$v/ref"; done ;;
  freeze)  echo "omnemo @ git+https://github.com/GuyMannDude/omnemo@$(cat "$v/ref" 2>/dev/null)" ;;
esac
exit 0
P
cat >"$v/bin/omnemo" <<'O'
#!/bin/bash
echo "omnemo $*" >>"$SB_LOG"
merge() { local f="$1" k="$2" t; mkdir -p "$(dirname "$f")"; [[ -e $f ]] || echo '{}' >"$f"; t="$(mktemp)"; jq --arg k "$k" '.[$k].omnemo = {command:"omnemo"}' "$f" >"$t" && cat "$t" >"$f"; rm -f "$t"; }
unmerge() { local f="$1" k="$2" t; [[ -e $f ]] || return 0; t="$(mktemp)"; jq --arg k "$k" 'if .[$k] then .[$k] |= del(.omnemo) else . end' "$f" >"$t" && cat "$t" >"$f"; rm -f "$t"; }
has() { command -v "$1" >/dev/null 2>&1; }
case "$1" in
  --version) echo "omnemo 0.2.1" ;;
  stats) echo '{"memory_count":0,"superseded":0}' ;;
  setup)
    has claude && { claude mcp list >/dev/null; claude mcp add --scope user omnemo -- omnemo serve; }
    has codex && { codex mcp list >/dev/null; }
    has opencode && merge "$HOME/.config/opencode/opencode.json" mcp
    has crush && merge "$HOME/.config/crush/crush.json" mcp
    has gemini && merge "$HOME/.gemini/settings.json" mcpServers ;;
  disconnect)
    has claude && { claude mcp list >/dev/null; claude mcp remove --scope user omnemo; }
    has codex && { codex mcp list >/dev/null; }
    has opencode && unmerge "$HOME/.config/opencode/opencode.json" mcp
    has crush && unmerge "$HOME/.config/crush/crush.json" mcp
    has gemini && unmerge "$HOME/.gemini/settings.json" mcpServers ;;
esac
exit 0
O
chmod 755 "$v/bin/pip" "$v/bin/omnemo"
EOF

# ------------------------------------------------------------ a fresh "home"
# Stock Omarchy as the installer meets it: claude and codex are lazy stand-ins,
# opencode and crush are really installed, opencode has its stock settings.
new_home() {
  H="$SB/home-$1"; SHIMS="$SB/shims-$1"; REAL="$SB/real-$1"
  mkdir -p "$H/.config/omarchy/extensions" "$H/.config/hypr" "$H/.config/opencode" "$SHIMS" "$REAL"
  # Folders every Omarchy home already has.
  mkdir -p "$H/.config/omarchy/plugins" "$H/.config/systemd/user" "$H/.local/bin" "$H/.local/share/applications" "$H/.local/state/omarchy"
  echo '{"version":1,"bar":{"position":"top","layout":{"left":["omarchy.workspaces"],"right":["omarchy.clock"]}},"dock":{"pinned":[]}}' | jq . >"$H/.config/omarchy/shell.json"
  printf -- '-- stock user file\n' >"$H/.config/hypr/hyprland.lua"
  printf -- '-- stock bindings\n' >"$H/.config/hypr/bindings.lua"
  printf -- '-- stock looknfeel\n' >"$H/.config/hypr/looknfeel.lua"
  printf '{\n  // stock menu\n}\n' >"$H/.config/omarchy/extensions/omarchy-menu.jsonc"
  printf '{\n  "$schema": "https://opencode.ai/config.json",\n  "theme": "system"\n}\n' >"$H/.config/opencode/opencode.json"
  for n in claude codex gemini; do ln -s "$STUBS/mise" "$SHIMS/$n"; done
  for n in opencode crush; do printf '#!/bin/bash\nexit 0\n' >"$REAL/$n"; chmod 755 "$REAL/$n"; done
  : >"$SB/downloads.log"; : >"$SB/log-$1"
}
# Run a command as the person at home "$1" would, with nothing from the real session.
as() {
  local name="$1"; shift
  env -i HOME="$SB/home-$name" SB="$SB" SB_LOG="$SB/log-$name" TMPDIR="$SB" LANG=C \
      PATH="$SB/shims-$name:$SB/real-$name:$STUBS:/usr/bin" "$@"
}
# Everything under home, with checksums, minus our own state folder (the
# backup and the uninstall record stay by design) and the lazy tools' own data.
snapshot() {
  ( cd "$SB/home-$1" && find . \( -path ./.local/state/omnemo-os -o -path ./.local/share/mise \) -prune -o \
      \( -type f -printf '%p %m ' -exec sha256sum {} \; -o -type l -printf '%p -> %l\n' -o -type d -printf '%p/\n' \) | sed 's/  \.\/.*$//' | sort )
}

# ================================================================ walk A
echo "== A. fresh computer: install, then uninstall"
new_home A
snapshot A >"$SB/A.before"
as A "$REPO/bin/omnemo-os" install >"$SB/A.install.out" 2>&1; rcA=$?
check "install exits 0" test "$rcA" = 0
check "says what it downloads before starting" grep -q "this will download the memory program (about 330 MB once installed) and the colored icons (33 MB)" "$SB/A.install.out"
check "says which helpers it will NOT download" grep -q "(claude codex gemini) are NOT downloaded" "$SB/A.install.out"
nope  "no AI helper was downloaded by install (#5)" test -s "$SB/downloads.log"
check "memory registered with opencode (really installed)" jq -e '.mcp.omnemo' "$SB/home-A/.config/opencode/opencode.json"
check "memory registered with crush (really installed)" jq -e '.mcp.omnemo' "$SB/home-A/.config/crush/crush.json"
nope  "claude's settings file was not created" test -e "$SB/home-A/.claude.json"
nope  "codex's folder was not created" test -e "$SB/home-A/.codex"
check "Super+M line is in bindings.lua" grep -q 'o.rebind("SUPER + M", "Minimize window to the taskbar", "omnemo-window-minimize")' "$SB/home-A/.config/hypr/bindings.lua"
check "the minimize program is installed" test -x "$SB/home-A/.local/bin/omnemo-window-minimize"
check "record says 0.9.3" test "$(jq -r .edition_version "$SB/home-A/.local/state/omnemo-os/installed.json")" = 0.9.3
check "the omnemo-os command link works" test -x "$SB/home-A/.local/bin/omnemo-os"
as A "$SB/home-A/.local/bin/omnemo-os" status >"$SB/A.status.out" 2>&1
check "status names the helpers that have the memory" grep -q "AI helpers on this computer: opencode crush" "$SB/A.status.out"
nope  "status did not download a helper" test -s "$SB/downloads.log"
as A "$SB/home-A/.local/bin/omnemo-os" repair >"$SB/A.repair.out" 2>&1
check "repair exits 0" test $? = 0
nope  "repair did not download a helper" test -s "$SB/downloads.log"
as A "$SB/home-A/.local/bin/omnemo-os" uninstall >"$SB/A.uninstall.out" 2>&1 </dev/null
check "uninstall exits 0" test $? = 0
nope  "uninstall did not download a helper" test -s "$SB/downloads.log"
nope  "no copy of a helper's settings stays in the backup" bash -c "ls -d '$SB/home-A/.local/state/omnemo-os/backup'/*/helpers"
snapshot A >"$SB/A.after"
if diff "$SB/A.before" "$SB/A.after" >"$SB/A.diff"; then ok "home is exactly as before install (#4: nothing left behind)"
else bad "home differs after uninstall:"; sed 's/^/        /' "$SB/A.diff"; fi

# ================================================================ walk B
echo "== B. Claude is really installed; the person uses it after install"
new_home B
rm -f "$SB/shims-B/claude"; cp "$SB/real-claude" "$SB/real-B/claude"
snapshot B >"$SB/B.before"
as B "$REPO/bin/omnemo-os" install >"$SB/B.install.out" 2>&1
check "install exits 0" test $? = 0
check "memory registered with claude" jq -e '.mcpServers.omnemo' "$SB/home-B/.claude.json"
nope  "codex (not installed) was not downloaded" test -s "$SB/downloads.log"
cp -a "$SB/home-B" "$SB/home-B2"; cp -a "$SB/shims-B" "$SB/shims-B2"; cp -a "$SB/real-B" "$SB/real-B2"; : >"$SB/log-B2"
# B: nobody touches Claude's file -> it must be gone again (it was not there before).
as B "$SB/home-B/.local/bin/omnemo-os" uninstall >"$SB/B.uninstall.out" 2>&1 </dev/null
snapshot B >"$SB/B.after"
if diff "$SB/B.before" "$SB/B.after" >"$SB/B.diff"; then ok "untouched since install: home is exactly as before"
else bad "home differs after uninstall:"; sed 's/^/        /' "$SB/B.diff"; fi
# B2: the person signs in and works with Claude -> the file is theirs and stays.
# (a copied home keeps paths of home-B inside its record; re-point them)
sed -i "s#$SB/home-B/#$SB/home-B2/#g" "$SB/home-B2/.local/state/omnemo-os/installed.json"
sed -i "s#$SB/home-B/#$SB/home-B2/#g" "$SB/home-B2/.local/state/omnemo-os/backup"/*/helpers/*.list "$SB/home-B2/.local/state/omnemo-os/backup"/*/helpers/after-setup.tsv "$SB/home-B2/.local/state/omnemo-os/backup"/*/absent.list
ln -sfn "$SB/home-B2/.local/share/omnemo-os/app/bin/omnemo-os" "$SB/home-B2/.local/bin/omnemo-os"
t="$(mktemp)"; jq '.oauthAccount = {"emailAddress":"someone"} | .projects = {"/home/x":{}}' "$SB/home-B2/.claude.json" >"$t" && cat "$t" >"$SB/home-B2/.claude.json"; rm -f "$t"
as B2 "$SB/home-B2/.local/bin/omnemo-os" uninstall >"$SB/B2.uninstall.out" 2>&1 </dev/null
check "used after install: Claude's file is kept" jq -e '.oauthAccount.emailAddress == "someone"' "$SB/home-B2/.claude.json"
check "  ...with the memory line taken out" jq -e '(.mcpServers // {}) | has("omnemo") | not' "$SB/home-B2/.claude.json"
check "  ...and uninstall says so" grep -q "left in place, because it was used after install" "$SB/B2.uninstall.out"

# ================================================================ walk C
if [[ -n $OLD && -x "$OLD/bin/omnemo-os" ]]; then
  oldv="$(sed -n 's/^VERSION="\(.*\)"/\1/p' "$OLD/bin/omnemo-os")"
  echo "== C. update: $oldv installed, then this version's update, then uninstall"
  new_home C
  snapshot C >"$SB/C.before"
  as C "$OLD/bin/omnemo-os" install >"$SB/C.install-old.out" 2>&1
  check "old version installs" test $? = 0
  cp "$SB/downloads.log" "$SB/C.old-downloads.log"; : >"$SB/downloads.log"
  echo "// the person's own edit" >>"$SB/home-C/.config/omarchy/plugins/guy.clock/BarWidget.qml"
  sed -i 's/#435ECE/#123456/' "$SB/home-C/.config/omarchy/shell.toml"
  mkdir -p "$SB/home-C/.local/share/omnemo"; echo "a memory" >"$SB/home-C/.local/share/omnemo/store.db"
  as C "$REPO/bin/omnemo-os" update >"$SB/C.update.out" 2>&1 </dev/null
  check "update exits 0" test $? = 0
  R="$SB/home-C/.local/state/omnemo-os/installed.json"
  check "record says 0.9.3, updated from $oldv" test "$(jq -r '.edition_version + " " + .updated_from' "$R")" = "0.9.3 $oldv"
  check "same install-day backup is kept" test -f "$(jq -r .backup_dir "$R")/shell.json"
  check "Super+M line arrived, once" test "$(grep -c 'SUPER + M' "$SB/home-C/.config/hypr/bindings.lua")" = 1
  check "one managed block in bindings.lua" test "$(grep -c 'omnemo-os:begin' "$SB/home-C/.config/hypr/bindings.lua")" = 1
  check "one managed block in hyprland.lua" test "$(grep -c 'omnemo-os:begin' "$SB/home-C/.config/hypr/hyprland.lua")" = 1
  check "one Apps entry in the menu" test "$(grep -c '"apps"' "$SB/home-C/.config/omarchy/extensions/omarchy-menu.jsonc")" = 1
  check "the minimize program is installed" test -x "$SB/home-C/.local/bin/omnemo-window-minimize"
  check "the edited plugin was saved to one side" bash -c "grep -rq \"the person's own edit\" '$SB/home-C/.local/state/omnemo-os/replaced'/*/plugins/guy.clock/BarWidget.qml"
  check "  ...and update says so" grep -q "you had changed these parts of the bar: guy.clock" "$SB/C.update.out"
  check "the new help row is in place" grep -q "Windows won't move or resize" "$SB/home-C/.config/omarchy/plugins/guy.help/BarWidget.qml"
  check "the person's bar colour was kept" grep -q '#123456' "$SB/home-C/.config/omarchy/shell.toml"
  check "the memory program moved to the new pin" grep -q "$(sed -n 's/^OMNEMO_REF="\(.*\)"/\1/p' "$REPO/bin/omnemo-os")" "$SB/home-C/.local/share/omnemo-venv/ref"
  check "the memories were not touched" grep -q "a memory" "$SB/home-C/.local/share/omnemo/store.db"
  nope  "update downloaded no AI helper" test -s "$SB/downloads.log"
  # A second home where the person changed nothing: our colour block is swapped for the new one.
  new_home D
  as D "$OLD/bin/omnemo-os" install >/dev/null 2>&1; : >"$SB/downloads.log"
  as D "$REPO/bin/omnemo-os" update >"$SB/D.update.out" 2>&1 </dev/null
  check "untouched bar colours are replaced by this version's" bash -c "diff <(sed -n '/^# omnemo-os:begin/,/^# omnemo-os:end/p' '$SB/home-D/.config/omarchy/shell.toml') '$REPO/system/omnemo-look-flag.toml'"
  check "  ...still one colour block" test "$(grep -c 'omnemo-os:begin' "$SB/home-D/.config/omarchy/shell.toml")" = 1
  check "the flag's shader files are installed" test -s "$SB/home-D/.config/omarchy/plugins/guy.flag/flag.frag.qsb" -a -s "$SB/home-D/.config/omarchy/plugins/guy.flag/flag.frag"
  nope  "an untouched home is told nothing was 'changed'" grep -q "you had changed\|you have changed" "$SB/D.update.out"
  cp "$SB/home-C/.config/hypr/bindings.lua" "$SB/C.bindings.1"
  as C "$REPO/bin/omnemo-os" update >"$SB/C.update2.out" 2>&1 </dev/null
  check "a second update changes nothing in bindings.lua" cmp "$SB/C.bindings.1" "$SB/home-C/.config/hypr/bindings.lua"
  check "the installed command can update itself (from a local copy of this branch)" \
    as C env OMNEMO_OS_URL="$REPO" OMNEMO_OS_REF="$(git -C "$REPO" rev-parse --abbrev-ref HEAD)" "$SB/home-C/.local/bin/omnemo-os" update
  rm -rf "$SB/home-C/.local/share/omnemo"
  as C "$SB/home-C/.local/bin/omnemo-os" uninstall >"$SB/C.uninstall.out" 2>&1 </dev/null
  check "uninstall after update exits 0" test $? = 0
  snapshot C >"$SB/C.after"
  if diff "$SB/C.before" "$SB/C.after" >"$SB/C.diff"; then ok "home is exactly as before the old install"
  else echo "note  home differs after uninstall (what the OLD version's install left is expected here):"; sed 's/^/        /' "$SB/C.diff"; fi
else
  echo "== C. update walk skipped (give the path of an older checkout to run it)"
fi

echo
echo "$pass passed, $failed failed.  Sandbox kept for reading: $SB"
exit $(( failed > 0 ))
