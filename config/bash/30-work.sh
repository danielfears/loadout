# shellcheck shell=bash

work() {
    local root="$HOME/git"
    if [ "$#" -eq 0 ]; then
        printf 'Projects in %s:\n' "$root"
        command find "$root" -maxdepth 1 -mindepth 1 -type d \
            -printf '  %f\n' 2>/dev/null | sort
        return
    fi

    local dir="$root/$1"
    [ -d "$dir" ] || {
        printf 'No such project: %s\n' "$dir" >&2
        return 1
    }
    cd "$dir" || return 1
    git rev-parse --git-dir >/dev/null 2>&1 || return 0

    local branch
    local upstream
    local behind
    local ahead
    branch=$(git symbolic-ref --short -q HEAD)
    [ -n "$branch" ] || {
        printf 'Detached HEAD; skipping update.\n'
        return 0
    }
    git fetch --quiet || {
        printf 'Fetch failed; entered project without updating.\n' >&2
        return 0
    }
    upstream=$(git rev-parse --abbrev-ref --symbolic-full-name \
        '@{upstream}' 2>/dev/null || true)
    [ -n "$upstream" ] || return 0
    behind=$(git rev-list --count "HEAD..$upstream")
    ahead=$(git rev-list --count "$upstream..HEAD")

    if [ "$behind" -gt 0 ] &&
        [ "$ahead" -eq 0 ] &&
        [ -z "$(git status --porcelain)" ]; then
        git pull --ff-only --quiet
        printf 'Updated %s.\n' "$branch"
    fi
}

_loadout_work_complete() {
    local current=${COMP_WORDS[COMP_CWORD]}
    local projects
    projects=$(command find "$HOME/git" -maxdepth 1 -mindepth 1 \
        -type d -printf '%f\n' 2>/dev/null)
    mapfile -t COMPREPLY < <(compgen -W "$projects" -- "$current")
}
complete -F _loadout_work_complete work
