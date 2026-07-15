# shellcheck shell=bash

command -v eza >/dev/null 2>&1 && {
    alias ls='eza --icons --group-directories-first'
    alias ll='eza -l --icons --git --group-directories-first'
    alias la='eza -la --icons --git --group-directories-first'
    alias lt='eza --tree --level=2 --icons --git-ignore'
}
command -v bat >/dev/null 2>&1 && {
    alias cat='bat --paging=never'
    alias less='bat'
}
command -v rg >/dev/null 2>&1 && alias grep='rg'
command -v fd >/dev/null 2>&1 && alias find='fd'
command -v lazygit >/dev/null 2>&1 && alias lg='lazygit'

alias tf='terraform'
alias tfi='terraform init'
alias tfp='terraform plan'
alias tfa='terraform apply'
alias tfd='terraform destroy'
alias tff='terraform fmt -recursive'
alias tfv='terraform validate'

alias td='task'
alias tda='task add'
alias tdl='task list'
alias tdn='task next'
alias tdd='task done'
alias tdr='task delete'

alias gs='git status -sb'
alias gd='git diff'
alias gl='git log --oneline --graph --decorate -20'
alias gco='git checkout'
alias gcm='git commit -m'
alias gp='git push'
alias gpl='git pull'
