#!/usr/bin/env bash
# Logic walk of check_version with stubbed pacman/vercmp. NOT a box test.
src="$1"
die()  { printf "DIE: %s\n" "$*"; exit 1; }
say()  { printf 'OK:  %s\n' "$*"; }
need() { command -v "$1" >/dev/null 2>&1 || die "missing $1"; }
eval "$(sed -n '/^MIN_PKGVER=/p; /^omarchy_pkgver()/p' "$src")"
eval "$(awk '/^check_version\(\) \{/,/^\}/' "$src")"
# vercmp stub: strip pkgrel; letters after the numeric base = pre-release of that base
vercmp() {
  local a=${1%-*} b=${2%-*} ab bb; ab=${a%%[a-z]*}; bb=${b%%[a-z]*}
  if [[ $ab == "$bb" ]]; then
    [[ $a == "$ab" && $b != "$bb" ]] && { echo 1; return; }
    [[ $a != "$ab" && $b == "$bb" ]] && { echo -1; return; }
    echo 0; return
  fi
  [[ $(printf '%s\n%s\n' "$ab" "$bb" | sort -V | head -1) == "$ab" ]] && echo -1 || echo 1
}
for PKG in 4.4.9-1 4.5.0rc2-1 4.5.0beta1-1 4.5.0-1 4.6.1-2; do
  for rc in 0 1; do
    pacman() { echo "omarchy $PKG"; }
    printf "%-13s allow_rc=%s -> " "$PKG" "$rc"; ( check_version "$rc" ) || true
  done
done
