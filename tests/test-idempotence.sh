#!/usr/bin/env bash

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
temporary=$(mktemp -d "$ROOT/loadout-test.XXXXXX")
trap 'rm -rf "$temporary"' EXIT
export HOME="$temporary/home"
mkdir -p "$HOME"

LOADOUT_ROOT="$ROOT"
LOADOUT_MODE=apply
LOADOUT_NO_COLOUR=1
# shellcheck disable=SC1091
. "$ROOT/lib/common.sh"
# shellcheck disable=SC1091
. "$ROOT/lib/config.sh"
loadout_init_colours

printf 'desired\n' >"$temporary/source"
loadout_ensure_file test-file "$temporary/source" "$HOME/config/file" >/dev/null
[ "$(cat "$HOME/config/file")" = desired ]
loadout_reset_drift
loadout_ensure_file test-file "$temporary/source" "$HOME/config/file" >/dev/null
[ "$LOADOUT_DRIFT" -eq 0 ]

block=$'# >>> Loadout >>>\nvalue\n# <<< Loadout <<<'
loadout_reset_drift
loadout_ensure_marked_block test-block "$HOME/.bashrc" "$block" >/dev/null
loadout_reset_drift
loadout_ensure_marked_block test-block "$HOME/.bashrc" "$block" >/dev/null
[ "$LOADOUT_DRIFT" -eq 0 ]

printf '{"existing":true}\n' >"$HOME/settings.json"
printf '{"loadout":"enabled"}\n' >"$temporary/overlay.json"
loadout_reset_drift
loadout_ensure_json_overlay \
    test-json "$temporary/overlay.json" "$HOME/settings.json" >/dev/null
loadout_reset_drift
loadout_ensure_json_overlay \
    test-json "$temporary/overlay.json" "$HOME/settings.json" >/dev/null
[ "$LOADOUT_DRIFT" -eq 0 ]
jq -e '.existing and .loadout == "enabled"' "$HOME/settings.json" >/dev/null

printf 'test-idempotence: PASS\n'
