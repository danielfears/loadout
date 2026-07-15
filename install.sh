#!/usr/bin/env bash

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
destination="$HOME/.local/bin/loadout"
mkdir -p "$(dirname "$destination")"

if [ -L "$destination" ] &&
    [ "$(readlink -f "$destination")" = "$ROOT/bin/loadout" ]; then
    printf 'Loadout is already installed at %s\n' "$destination"
    exit 0
fi

if [ -e "$destination" ] || [ -L "$destination" ]; then
    backup="${destination}.bak.$(date +%Y%m%d%H%M%S)"
    mv "$destination" "$backup"
    printf 'Backed up existing %s to %s\n' "$destination" "$backup"
fi

ln -s "$ROOT/bin/loadout" "$destination"
printf 'Installed Loadout at %s\n' "$destination"
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) printf 'Use %s directly until a new shell adds ~/.local/bin to PATH.\n' \
        "$destination" ;;
esac
