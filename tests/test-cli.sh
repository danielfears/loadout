#!/usr/bin/env bash

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT
TEST_PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$ROOT/bin"

version=$("$ROOT/bin/loadout" version)
[ "$version" = "$(cat "$ROOT/VERSION")" ]

output=$("$ROOT/bin/loadout" --help)
grep -Fq 'workstation as code' <<<"$output"
output=$("$ROOT/bin/loadout" list --no-colour)
grep -Fq 'Loadout: Azure DevOps and platform engineering' <<<"$output"
output=$("$ROOT/bin/loadout" recommend --no-colour)
grep -Fq 'Argo CD CLI' <<<"$output"

HOME="$temporary/home" PATH="$TEST_PATH" "$ROOT/bin/loadout" plan \
    --skip-windows \
    --skip-services \
    --no-colour >"$temporary/plan.log"
grep -Fq 'change(s) planned' "$temporary/plan.log"
for path in .bashrc .bash_profile .config/loadout .copilot .gitconfig; do
    [ ! -e "$temporary/home/$path" ]
done

if HOME="$temporary/home" PATH="$TEST_PATH" "$ROOT/bin/loadout" check \
    --skip-windows \
    --skip-services \
    --no-colour >/dev/null 2>&1; then
    printf 'check unexpectedly passed for an empty home\n' >&2
    exit 1
fi

if "$ROOT/bin/loadout" plan --unknown-option >/dev/null 2>&1; then
    printf 'unknown option was accepted\n' >&2
    exit 1
fi

printf 'test-cli: PASS\n'
