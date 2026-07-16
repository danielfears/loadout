# shellcheck shell=bash

LOADOUT_MODE=${LOADOUT_MODE:-plan}
LOADOUT_YES=${LOADOUT_YES:-0}
LOADOUT_SKIP_WINDOWS=${LOADOUT_SKIP_WINDOWS:-0}
LOADOUT_SKIP_SERVICES=${LOADOUT_SKIP_SERVICES:-0}
LOADOUT_VERBOSE=${LOADOUT_VERBOSE:-0}
LOADOUT_NO_COLOUR=${LOADOUT_NO_COLOUR:-0}
LOADOUT_DRIFT=0
C_RESET=
C_BOLD=
C_BLUE=
C_CYAN=
C_GREEN=
C_RED=
C_YELLOW=

export PATH="$HOME/.local/bin:$HOME/.tfenv/bin:$PATH"
export CHECKPOINT_DISABLE=1
export TF_IN_AUTOMATION=1

loadout_init_colours() {
    if [ "$LOADOUT_NO_COLOUR" -eq 1 ] || [ ! -t 1 ]; then
        C_RESET=
        C_BOLD=
        C_BLUE=
        C_CYAN=
        C_GREEN=
        C_RED=
        C_YELLOW=
        return
    fi
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_BLUE=$'\033[34m'
    C_CYAN=$'\033[36m'
    C_GREEN=$'\033[32m'
    C_RED=$'\033[31m'
    C_YELLOW=$'\033[33m'
}

loadout_section() {
    printf '\n%s%s==>%s %s\n' "$C_BOLD" "$C_CYAN" "$C_RESET" "$1"
}

loadout_ok() {
    if [ "$LOADOUT_VERBOSE" -eq 1 ] || [ "$LOADOUT_MODE" = check ]; then
        printf '  %s[OK]%s %s\n' "$C_GREEN" "$C_RESET" "$1"
    fi
}

loadout_change() {
    LOADOUT_DRIFT=$((LOADOUT_DRIFT + 1))
    case "$LOADOUT_MODE" in
        plan) printf '  %s[PLAN]%s %s\n' "$C_YELLOW" "$C_RESET" "$1" ;;
        apply) printf '  %s[APPLY]%s %s\n' "$C_BLUE" "$C_RESET" "$1" ;;
        check) printf '  %s[DRIFT]%s %s\n' "$C_RED" "$C_RESET" "$1" ;;
    esac
}

loadout_warn() {
    printf '  %s[WARN]%s %s\n' "$C_YELLOW" "$C_RESET" "$1" >&2
}

loadout_die() {
    printf '  %s[FAIL]%s %s\n' "$C_RED" "$C_RESET" "$1" >&2
    exit 1
}

loadout_is_apply() {
    [ "$LOADOUT_MODE" = apply ]
}

loadout_is_container() {
    [ "${LOADOUT_CONTAINER:-0}" = 1 ] ||
        [ -e /.dockerenv ] ||
        [ -e /run/.containerenv ] ||
        grep -Eq '/(docker|containerd|kubepods|libpod)(/|$)' \
            /proc/1/cgroup 2>/dev/null
}

loadout_is_wsl() {
    ! loadout_is_container &&
        grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null
}

loadout_read_lines() {
    local file=$1
    awk 'NF && $1 !~ /^#/ { print }' "$file"
}

loadout_expand_version() {
    local template=$1
    local version=$2
    printf '%s\n' "${template//\{version\}/$version}"
}

loadout_version_output() {
    local command_name=$1
    local version_argument=${2:---version}
    local path
    path=$(command -v "$command_name" 2>/dev/null || true)
    [ -n "$path" ] || return 1
    "$path" "$version_argument" 2>&1 || true
}

loadout_version_matches() {
    local command_name=$1
    local expected=$2
    local version_argument=${3:---version}
    local output
    output=$(loadout_version_output "$command_name" "$version_argument" || true)
    [ -n "$output" ] && grep -Fq "$expected" <<<"$output"
}

loadout_backup_file() {
    local destination=$1
    local backup
    [ -e "$destination" ] || [ -L "$destination" ] || return 0
    backup="${destination}.bak.$(date +%Y%m%d%H%M%S)"
    mv "$destination" "$backup"
    loadout_warn "backed up $destination to $backup"
}

loadout_load_desired_state() {
    MANIFEST_DIR="$LOADOUT_ROOT/manifests"
    CONFIG_DIR="$LOADOUT_ROOT/config"
    export MANIFEST_DIR CONFIG_DIR
    [ -r "$MANIFEST_DIR/versions.sh" ] ||
        loadout_die 'Desired-state version manifest is missing'
    # shellcheck disable=SC1090
    # shellcheck disable=SC1091
    . "$MANIFEST_DIR/versions.sh"
}

loadout_detect_platform() {
    [ -r /etc/os-release ] || loadout_die '/etc/os-release is unavailable'
    # shellcheck disable=SC1091
    . /etc/os-release
    [ "${ID:-}" = ubuntu ] ||
        loadout_die "Unsupported Linux distribution: ${ID:-unknown}"
    [ "${VERSION_ID:-}" = "$LOADOUT_UBUNTU_VERSION" ] ||
        loadout_die "Loadout requires Ubuntu $LOADOUT_UBUNTU_VERSION"

    case "$(uname -m)" in
        aarch64|arm64)
            LOADOUT_ARCH=arm64
            LOADOUT_DEB_ARCH=arm64
            LOADOUT_RUST_ARCH=aarch64
            LOADOUT_PWSH_ARCH=arm64
            ;;
        x86_64|amd64)
            LOADOUT_ARCH=amd64
            LOADOUT_DEB_ARCH=amd64
            LOADOUT_RUST_ARCH=x86_64
            LOADOUT_PWSH_ARCH=x64
            ;;
        *) loadout_die "Unsupported architecture: $(uname -m)" ;;
    esac
    export LOADOUT_ARCH LOADOUT_DEB_ARCH LOADOUT_RUST_ARCH LOADOUT_PWSH_ARCH
}

loadout_require_sudo() {
    command -v sudo >/dev/null 2>&1 || loadout_die 'sudo is required'
    sudo -v
}

loadout_reset_drift() {
    LOADOUT_DRIFT=0
}
