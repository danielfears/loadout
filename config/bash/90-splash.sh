# shellcheck shell=bash

if [[ $- == *i* ]] &&
    [ -z "${COPILOT_AGENT_RUNTIME_VERSION:-}" ] &&
    [ -z "${VSCODE_INJECTION:-}" ]; then
    command -v fastfetch >/dev/null 2>&1 && fastfetch 2>/dev/null
    printf '\n  %s\n' "$(date '+%A, %d %B %Y - %H:%M')"
    printf '  Projects: %d in ~/git\n\n' \
        "$(command find "$HOME/git" -maxdepth 1 -mindepth 1 \
            -type d 2>/dev/null | wc -l)"

    if command -v task >/dev/null 2>&1; then
        count=$(task +PENDING count 2>/dev/null || printf 0)
        if [ "$count" -gt 0 ]; then
            printf '  Next tasks (%s pending):\n\n' "$count"
            task rc.verbose=nothing rc.defaultwidth=0 next limit:8 2>/dev/null |
                sed 's/^/    /'
            printf '\n'
        fi
        unset count
    fi
fi
