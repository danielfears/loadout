# shellcheck shell=bash

# shellcheck disable=SC1091
[ -f "$HOME/.fzf/shell/key-bindings.bash" ] &&
    . "$HOME/.fzf/shell/key-bindings.bash"
# shellcheck disable=SC1091
[ -f "$HOME/.fzf/shell/completion.bash" ] &&
    . "$HOME/.fzf/shell/completion.bash"

export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --preview-window=right:60%'
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
