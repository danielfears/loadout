#!/usr/bin/env bash

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

git init -q --bare "$test_root/origin.git"
git init -q -b main "$test_root/source"
git -C "$test_root/source" config user.name Test
git -C "$test_root/source" config user.email test@example.invalid
printf 'version one\n' >"$test_root/source/version.txt"
git -C "$test_root/source" add version.txt
git -C "$test_root/source" commit -q -m initial
git -C "$test_root/source" tag v1.0.0
git -C "$test_root/source" remote add origin "$test_root/origin.git"
git -C "$test_root/source" push -q origin main v1.0.0

git clone -q --branch main "$test_root/origin.git" "$test_root/checkout"
git -C "$test_root/checkout" tag -d v1.0.0 >/dev/null

LOADOUT_ROOT="$ROOT"
LOADOUT_MODE=apply
LOADOUT_NO_COLOUR=1
# shellcheck disable=SC1091
. "$ROOT/lib/common.sh"
# shellcheck disable=SC1091
. "$ROOT/lib/runtimes.sh"
loadout_init_colours

loadout_ensure_checkout \
    test \
    "$test_root/checkout" \
    "$test_root/origin.git" \
    v1.0.0 >/dev/null
git -C "$test_root/checkout" describe --tags --exact-match |
    grep -Fxq v1.0.0

loadout_reset_drift
loadout_ensure_checkout \
    test \
    "$test_root/checkout" \
    "$test_root/origin.git" \
    v1.0.0 >/dev/null
[ "$LOADOUT_DRIFT" -eq 0 ]

printf 'test-checkout: PASS\n'
