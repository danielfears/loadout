#!/usr/bin/env bash

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

while IFS= read -r file; do
    jq -e . "$file" >/dev/null
done < <(find "$ROOT/config" -type f -name '*.json' | sort)

awk -F '\t' '
    !/^#/ && NF && NF != 11 {
        print FNR ": expected 11 fields, got " NF >"/dev/stderr"
        failed=1
    }
    END { exit failed }
' "$ROOT/manifests/release-tools.tsv"

if rg -i \
    'gitlab\.tooling\.|mod\.gov\.uk|danielfears@microsoft|BEGIN .*PRIVATE KEY|ghp_[A-Za-z0-9]' \
    "$ROOT" \
    --glob '!tests/test-manifests.sh' >/dev/null; then
    printf 'private/internal material detected\n' >&2
    exit 1
fi

printf 'test-manifests: PASS\n'
