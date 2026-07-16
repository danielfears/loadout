# shellcheck shell=bash

_loadout_path_prepend() {
    case ":$PATH:" in
        *":$1:"*) ;;
        *) PATH="$1:$PATH" ;;
    esac
}

_loadout_path_prepend "$HOME/.tfenv/bin"
_loadout_path_prepend "$HOME/.local/bin"
export PATH
unset -f _loadout_path_prepend

export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1091
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
# shellcheck disable=SC1091
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

if [ -r "$HOME/.taskrc" ]; then
    export TASKRC="$HOME/.taskrc"
else
    export TASKRC="$HOME/.config/task/taskrc"
fi
