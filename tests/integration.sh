#!/usr/bin/env bash

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
docker build \
    --file "$ROOT/tests/integration/Dockerfile" \
    --tag loadout-integration:local \
    "$ROOT"
