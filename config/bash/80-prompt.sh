# shellcheck shell=bash

theme="$HOME/.config/loadout/oh-my-posh.json"
if command -v oh-my-posh >/dev/null 2>&1 && [ -r "$theme" ]; then
    eval "$(oh-my-posh init bash --config "$theme")"
fi
unset theme
