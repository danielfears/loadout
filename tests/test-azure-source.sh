#!/usr/bin/env bash

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

LOADOUT_ROOT="$ROOT"
LOADOUT_DEB_ARCH=arm64
# shellcheck disable=SC1091
. "$ROOT/lib/common.sh"
# shellcheck disable=SC1091
. "$ROOT/lib/system.sh"

key="$test_root/microsoft.gpg"
touch "$key"

cat >"$test_root/azure-cli.sources" <<EOF
Types: deb
URIs: https://packages.microsoft.com/repos/azure-cli/
Suites: noble
Components: main
Architectures: arm64
Signed-By: $key
EOF
loadout_azure_source_is_valid "$test_root/azure-cli.sources"

cat >"$test_root/azure-cli.list" <<EOF
deb [arch=arm64 signed-by=$key] https://packages.microsoft.com/repos/azure-cli/ noble main
EOF
loadout_azure_source_is_valid "$test_root/azure-cli.list"

sed 's/Architectures: arm64/Architectures: amd64/' \
    "$test_root/azure-cli.sources" >"$test_root/wrong-architecture.sources"
if loadout_azure_source_is_valid "$test_root/wrong-architecture.sources"; then
    printf 'wrong Deb822 architecture was accepted\n' >&2
    exit 1
fi

sed "s|Signed-By: $key|Signed-By: $test_root/missing.gpg|" \
    "$test_root/azure-cli.sources" >"$test_root/missing-key.sources"
if loadout_azure_source_is_valid "$test_root/missing-key.sources"; then
    printf 'Deb822 source with a missing key was accepted\n' >&2
    exit 1
fi

printf 'test-azure-source: PASS\n'
