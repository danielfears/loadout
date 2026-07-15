# shellcheck shell=bash

if command -v delta >/dev/null 2>&1; then
    export GIT_PAGER=delta
fi
