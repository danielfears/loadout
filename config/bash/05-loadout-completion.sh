# shellcheck shell=bash

_loadout_complete() {
    local current=${COMP_WORDS[COMP_CWORD]}
    local commands='plan apply check doctor list recommend version'
    local options='--yes --skip-windows --skip-services --verbose --no-colour --help'

    if [ "$COMP_CWORD" -eq 1 ]; then
        mapfile -t COMPREPLY < <(compgen -W "$commands" -- "$current")
    else
        mapfile -t COMPREPLY < <(compgen -W "$options" -- "$current")
    fi
}

complete -F _loadout_complete loadout
