#!/bin/bash
# ---------------------------------------------------------------------------
# setup.sh - the one tool vmath needs: get the LightStrings dependency right.
#
# Usage:
#   ./setup.sh                        check fpc and the dependency (default)
#   ./setup.sh --install              build LightStrings into the FPC tree
#   ./setup.sh --fu                   print the -Fu flag for your own builds
#   ./setup.sh --prefix DIR           FPC prefix for --install
#                                     (default: derived from fpc.cfg)
#   ./setup.sh --lightstrings DIR     the LightStrings checkout to use
#
# vmath needs Free Pascal 3.2.2 or newer and the LightStrings package:
# BaseMathPersistence and Matrix use its stack-based TStrList instead of the
# heap-based TStringList, so nothing in this tree builds without it.
# LightStrings is looked for in
#     $LIGHTSTRINGS_DIR, ../LightStrings, vendor/lightstrings
# and, when none of those exists, on the compiler's own unit path (i.e. it is
# already installed).
#
# --install runs, in the LightStrings checkout:
#     fpc fpmake.pp && ./fpmake compile install --prefix=<fpc prefix>
# which puts the units in <prefix>/lib/fpc/<ver>/units/<target>/lightstrings/
# and the package description in .../fpmkinst/<target>/lightstrings.fpm, so
# fpmake (vmath's manifest) and Lazarus (RequiredPkgs) resolve it themselves.
#
# A plain `fpc` call still needs the package on its unit path. If that does not
# work after the install, fpc.cfg lacks the usual
#     -Fu<prefix>/lib/fpc/$fpcversion/units/$fpctarget/*
# line and the script prints it; @vmath.cfg does not need it, because it passes
# the path itself.
# ---------------------------------------------------------------------------
set -u

root=$(cd "$(dirname "$0")" && pwd)
minfpc=3.2.2
action=check
prefix=''
lt=''

while [ $# -gt 0 ]; do
  case "$1" in
    --install) action=install ;;
    --check) action=check ;;
    --fu) action=fu ;;
    --prefix) shift; prefix=${1:-} ;;
    --lightstrings) shift; lt=${1:-} ;;
    -h|--help) sed -n '3,33p' "$0"; exit 0 ;;
    *) echo "setup.sh: unknown option '$1'" >&2; exit 2 ;;
  esac
  shift
done

fail() { echo "setup.sh: $*" >&2; exit 1; }

[ -n "$lt" ] && export LIGHTSTRINGS_DIR=$lt

# the LightStrings source directory, or failure
lightstrings_dir() {
  local cand
  for cand in "${LIGHTSTRINGS_DIR:-}" "$root/../LightStrings" "$root/vendor/lightstrings"; do
    [ -n "$cand" ] || continue
    if [ -f "$cand/src/LightStrings.pas" ]; then
      (cd "$cand/src" && pwd)
      return 0
    fi
  done
  return 1
}

# <prefix>/bin/<target>/fpc.cfg -> <prefix>
fpc_prefix() {
  local cfg
  cfg=$(fpc -va 2>&1 | sed -n 's/^\[[^]]*\] Hint: Start of reading config file \(.*\)$/\1/p' | head -1)
  [ -n "$cfg" ] || return 1
  (cd "$(dirname "$cfg")/../.." && pwd)
}

# compile a two-line program that uses LightStrings; $1 = extra flags
probe() {
  local flags=$1 work rc
  work=$(mktemp -d) || return 1
  printf '%s\n' \
    'program dep_probe;' \
    '{$mode objfpc}{$H+}' \
    'uses LightStrings;' \
    'var L: TStrList;' \
    'begin' \
    "  L.AddPair('a', 'b');" \
    'end.' > "$work/dep_probe.pas"
  # shellcheck disable=SC2086
  fpc $flags -FU"$work" -FE"$work" "$work/dep_probe.pas" > "$work/log" 2>&1
  rc=$?
  if [ $rc -ne 0 ]; then
    grep -E 'Error|Fatal' "$work/log" >&2 || cat "$work/log" >&2
  fi
  rm -rf "$work"
  return $rc
}

command -v fpc > /dev/null 2>&1 || fail "fpc is not on PATH"
ver=$(fpc -iV)
newest=$(printf '%s\n%s\n' "$minfpc" "$ver" | sort -V | tail -1)
[ "$newest" = "$ver" ] || fail "fpc $ver is too old, $minfpc or newer is required"

# --fu: print the flag for a source checkout, nothing to install
if [ "$action" = fu ]; then
  dir=$(lightstrings_dir) || fail "LightStrings checkout not found; pass --lightstrings DIR"
  echo "-Fu$dir"
  exit 0
fi

if [ "$action" = install ]; then
  src=$(lightstrings_dir) || fail "LightStrings checkout not found; pass --lightstrings DIR"
  if [ -z "$prefix" ]; then
    prefix=$(fpc_prefix) || fail "cannot locate fpc.cfg; pass --prefix DIR"
    echo "setup.sh: FPC prefix is $prefix"
  fi
  [ -d "$prefix/lib/fpc" ] || fail "'$prefix' does not look like an FPC prefix (no lib/fpc)"
  echo "setup.sh: installing LightStrings from $src"
  ( cd "$src/.." || exit 1
    [ -f fpmake ] || fpc fpmake.pp > /dev/null || exit 1
    ./fpmake compile install --prefix="$prefix" ) || fail "LightStrings install failed"
fi

# check: a source checkout is enough, otherwise the package has to be installed
ready() {
  echo "setup.sh: $1"
  echo "setup.sh: build and run the suite with"
  echo "  fpc @vmath.cfg tests/run_tests.pas -FUtests/units -FEbin && ./bin/run_tests --all"
}

if dir=$(lightstrings_dir); then
  probe "-Fu$dir" || fail "the LightStrings checkout at $dir does not compile"
  ready "ready - LightStrings comes from the checkout $dir"
  exit 0
fi

if probe ""; then
  ready "ready - LightStrings is installed for $(fpc -iTP)-$(fpc -iTO)"
  exit 0
fi

fail "LightStrings is not usable.
  Install it:                       ./setup.sh --install
  Or point at a checkout:           --lightstrings DIR   (or LIGHTSTRINGS_DIR)
  If it is installed but a bare fpc cannot find it, add this line to fpc.cfg:
      -Fu$(fpc_prefix 2>/dev/null)/lib/fpc/$(fpc -iV)/units/$(fpc -iTP)-$(fpc -iTO)/*"
