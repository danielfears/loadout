# shellcheck shell=bash

loadout_windows_code_path() {
    local win_path
    local win_home
    local program_files_path
    local program_files
    win_path=$(cmd.exe /d /c echo %USERPROFILE% </dev/null 2>/dev/null |
        tr -d '\r')
    [ -n "$win_path" ] || return 1
    win_home=$(wslpath -u "$win_path")
    if [ -x "$win_home/AppData/Local/Programs/Microsoft VS Code/bin/code" ]; then
        printf '%s/AppData/Local/Programs/Microsoft VS Code/bin/code\n' "$win_home"
        return
    fi
    program_files_path=$(cmd.exe /d /c echo %ProgramFiles% </dev/null 2>/dev/null |
        tr -d '\r')
    [ -n "$program_files_path" ] || return 1
    program_files=$(wslpath -u "$program_files_path")
    [ -x "$program_files/Microsoft VS Code/bin/code" ] || return 1
    printf '%s/Microsoft VS Code/bin/code\n' "$program_files"
}

loadout_ensure_windows() {
    local ps_mode
    local status
    local code_path

    loadout_is_wsl || {
        loadout_ok 'Windows resources not applicable on native Linux'
        return
    }
    [ "$LOADOUT_SKIP_WINDOWS" -eq 0 ] || {
        loadout_warn 'Windows resources skipped'
        return
    }

    loadout_section 'Windows host'
    command -v powershell.exe >/dev/null 2>&1 ||
        loadout_die 'powershell.exe is unavailable through WSL interop'
    command -v wslpath >/dev/null 2>&1 ||
        loadout_die 'wslpath is unavailable'

    case "$LOADOUT_MODE" in
        plan) ps_mode=Plan ;;
        apply) ps_mode=Apply ;;
        check) ps_mode=Check ;;
    esac

    set +e
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File \
        "$(wslpath -w "$LOADOUT_ROOT/windows/apply.ps1")" \
        -Mode "$ps_mode" \
        -LoadoutRoot "$(wslpath -w "$LOADOUT_ROOT")" \
        -CascadiaVersion "$CASCADIA_CODE_VERSION"
    status=$?
    set -e
    case "$status" in
        0) ;;
        2) LOADOUT_DRIFT=$((LOADOUT_DRIFT + 1)) ;;
        *) loadout_die "Windows resource adapter failed with exit code $status" ;;
    esac

    code_path=$(loadout_windows_code_path || true)
    if [ -n "$code_path" ] && [ -x "$code_path" ]; then
        loadout_ensure_symlink \
            'VS Code WSL command' "$code_path" "$HOME/.local/bin/code"
    else
        loadout_change 'expose the Windows VS Code command inside WSL'
        if loadout_is_apply; then
            loadout_die 'VS Code was not available after Windows package convergence'
        fi
    fi
}
