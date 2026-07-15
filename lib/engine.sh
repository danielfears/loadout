# shellcheck shell=bash

loadout_run_engine() {
    loadout_detect_platform
    loadout_ensure_wsl_systemd
    loadout_ensure_apt_packages
    loadout_ensure_azure_cli
    loadout_ensure_release_tools
    loadout_ensure_platform_tools
    loadout_ensure_kubectl
    loadout_ensure_powershell
    loadout_ensure_checkouts
    loadout_ensure_node
    loadout_ensure_terraform
    loadout_ensure_azure_extensions
    loadout_ensure_powershell_modules
    loadout_ensure_windows
    loadout_ensure_configuration
}

loadout_doctor() {
    loadout_section 'Platform'
    if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        printf '  Distribution: %s %s\n' "${NAME:-unknown}" "${VERSION_ID:-unknown}"
    else
        loadout_warn '/etc/os-release is unavailable'
    fi
    printf '  Architecture: %s\n' "$(uname -m)"
    if loadout_is_container; then
        printf '  Runtime:      container\n'
    elif loadout_is_wsl; then
        printf '  Runtime:      WSL\n'
    else
        printf '  Runtime:      native Linux\n'
    fi

    loadout_section 'Prerequisites'
    for command_name in bash curl git sudo tar; do
        if command -v "$command_name" >/dev/null 2>&1; then
            loadout_ok "$command_name"
        else
            loadout_warn "$command_name is missing"
        fi
    done
    if [ -n "$(git config --global user.name 2>/dev/null || true)" ] &&
        [ -n "$(git config --global user.email 2>/dev/null || true)" ]; then
        loadout_ok 'Git identity configured'
    else
        loadout_warn 'Git identity is unset; configure user.name and user.email'
    fi

    loadout_section 'Authentication'
    if gh auth status >/dev/null 2>&1; then
        loadout_ok 'GitHub CLI authenticated'
    else
        loadout_warn 'GitHub CLI not authenticated (run gh auth login)'
    fi
    if az account show >/dev/null 2>&1; then
        loadout_ok 'Azure CLI authenticated'
    else
        loadout_warn 'Azure CLI not authenticated (run azlogin after apply)'
    fi
    if glab auth status >/dev/null 2>&1; then
        loadout_ok 'GitLab CLI authenticated'
    else
        loadout_warn 'GitLab CLI not authenticated (run glab auth login)'
    fi

    loadout_section 'Platform services'
    if docker info >/dev/null 2>&1; then
        loadout_ok 'Docker daemon reachable'
    else
        loadout_warn 'Docker daemon is not reachable'
    fi
    if kubectl config current-context >/dev/null 2>&1; then
        loadout_ok 'Kubernetes context configured'
    else
        loadout_warn 'No Kubernetes context is configured'
    fi
}

loadout_list_state() {
    printf '%s%s%s\n' "$C_BOLD" "$LOADOUT_NAME" "$C_RESET"
    printf '%s\n\n' "$LOADOUT_DESCRIPTION"
    printf 'Ubuntu: %s\n' "$LOADOUT_UBUNTU_VERSION"
    printf 'APT packages: %s\n' "$(loadout_read_lines "$MANIFEST_DIR/apt-packages.txt" | wc -l)"
    printf 'Release tools: %s\n' "$(loadout_read_lines "$MANIFEST_DIR/release-tools.tsv" | wc -l)"
    printf 'Special installers: 6\n'
    printf 'Azure extensions: %s\n' \
        "$(loadout_read_lines "$MANIFEST_DIR/azure-extensions.tsv" | wc -l)"
    printf 'PowerShell modules: %s\n' \
        "$(loadout_read_lines "$MANIFEST_DIR/powershell-modules.tsv" | wc -l)"
    printf 'Windows packages: %s\n' \
        "$(loadout_read_lines "$MANIFEST_DIR/windows-packages.tsv" | wc -l)"
    printf 'Optional recommendations: %s\n' \
        "$(loadout_read_lines "$MANIFEST_DIR/recommendations.tsv" | wc -l)"
}

loadout_list_recommendations() {
    local tool
    local category
    local reason
    printf '%sOptional additions for %s%s\n\n' \
        "$C_BOLD" "$LOADOUT_NAME" "$C_RESET"
    while IFS=$'\t' read -r tool category reason; do
        case "$tool" in ''|\#*) continue ;; esac
        printf '%-22s %-14s %s\n' "$tool" "$category" "$reason"
    done <"$MANIFEST_DIR/recommendations.tsv"
}
