#!/usr/bin/env bash

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

LOADOUT_ROOT="$ROOT"
# shellcheck disable=SC1091
. "$ROOT/lib/common.sh"
# shellcheck disable=SC1091
. "$ROOT/lib/releases.sh"

mkdir -p \
    "$test_root/package/usr/bin" \
    "$test_root/package/usr/share/bash-completion/completions"
printf 'binary\n' >"$test_root/package/usr/bin/example"
printf 'completion\n' \
    >"$test_root/package/usr/share/bash-completion/completions/example"

source_file=$(loadout_find_release_source \
    "$test_root" '*/usr/bin/example')
[ "$source_file" = "$test_root/package/usr/bin/example" ]

printf 'test-release-source: PASS\n'
