# shellcheck shell=bash

loadout_wsl_systemd_configured() {
    [ -r /etc/wsl.conf ] &&
        awk '
            /^\[boot\][[:space:]]*$/ { in_boot=1; next }
            /^\[/ { in_boot=0 }
            in_boot && /^[[:space:]]*systemd[[:space:]]*=[[:space:]]*true[[:space:]]*$/ {
                found=1
            }
            END { exit !found }
        ' /etc/wsl.conf
}

loadout_write_wsl_systemd_config() {
    local temporary
    temporary=$(mktemp)
    if [ -r /etc/wsl.conf ]; then
        awk '
        BEGIN { in_boot=0; saw_boot=0; wrote=0 }
        /^\[boot\][[:space:]]*$/ {
            in_boot=1
            saw_boot=1
            print
            next
        }
        /^\[/ {
            if (in_boot && !wrote) {
                print "systemd=true"
                wrote=1
            }
            in_boot=0
        }
        in_boot && /^[[:space:]]*systemd[[:space:]]*=/ {
            if (!wrote) {
                print "systemd=true"
                wrote=1
            }
            next
        }
        { print }
        END {
            if (in_boot && !wrote) {
                print "systemd=true"
            } else if (!saw_boot) {
                print ""
                print "[boot]"
                print "systemd=true"
            }
        }
        ' /etc/wsl.conf >"$temporary"
    fi
    if [ ! -s "$temporary" ]; then
        printf '[boot]\nsystemd=true\n' >"$temporary"
    fi
    if [ -e /etc/wsl.conf ]; then
        sudo cp -a /etc/wsl.conf \
            "/etc/wsl.conf.bak.$(date +%Y%m%d%H%M%S)"
    fi
    sudo install -m 0644 "$temporary" /etc/wsl.conf
    rm -f "$temporary"
}

loadout_ensure_wsl_systemd() {
    loadout_is_wsl || return 0
    loadout_section 'WSL systemd'

    if loadout_wsl_systemd_configured; then
        loadout_ok 'systemd enabled in /etc/wsl.conf'
        return
    fi
    loadout_change 'enable systemd in /etc/wsl.conf'
    if loadout_is_apply; then
        loadout_write_wsl_systemd_config
        loadout_die \
            "WSL systemd was enabled. Run 'wsl --shutdown' in Windows, then rerun Loadout."
    fi
}

loadout_apt_installed() {
    local package=$1
    dpkg-query -W -f='${Status}' "$package" 2>/dev/null |
        grep -q '^install ok installed$'
}

loadout_ensure_apt_packages() {
    local package
    local -a missing=()
    loadout_section 'Ubuntu packages'

    while IFS= read -r package; do
        if loadout_apt_installed "$package"; then
            loadout_ok "$package"
        else
            missing+=("$package")
            loadout_change "install apt package $package"
        fi
    done < <(loadout_read_lines "$MANIFEST_DIR/apt-packages.txt")

    if loadout_is_apply && [ "${#missing[@]}" -gt 0 ]; then
        sudo apt-get update
        sudo env DEBIAN_FRONTEND=noninteractive \
            apt-get install -y "${missing[@]}"
    fi

    loadout_ensure_git_lfs
    loadout_ensure_docker
}

loadout_ensure_git_lfs() {
    if git config --global --get filter.lfs.process 2>/dev/null |
        grep -Fq 'git-lfs filter-process'; then
        loadout_ok 'Git LFS global filters'
        return
    fi
    loadout_change 'initialise Git LFS global filters'
    if loadout_is_apply; then
        git lfs install --skip-repo
    fi
}

loadout_ensure_docker() {
    local current_user
    current_user=$(id -un)

    if [ "$LOADOUT_SKIP_SERVICES" -eq 1 ]; then
        loadout_warn 'Docker group and service convergence skipped'
        return 0
    fi

    if getent group docker 2>/dev/null |
        awk -F: -v user="$current_user" '
            {
                count=split($4, members, ",")
                for (i=1; i<=count; i++) if (members[i] == user) found=1
            }
            END { exit !found }
        '; then
        loadout_ok 'Docker group membership'
    else
        loadout_change "add $current_user to the Docker group"
        if loadout_is_apply; then
            sudo usermod --append --groups docker "$current_user"
            loadout_warn 'Docker group access starts in the next login shell'
        fi
    fi

    if systemctl is-active --quiet docker 2>/dev/null &&
        systemctl is-enabled --quiet docker 2>/dev/null; then
        loadout_ok 'Docker service'
    else
        loadout_change 'enable and start Docker'
        if loadout_is_apply; then
            systemctl is-system-running >/dev/null 2>&1 ||
                loadout_die 'systemd is not running; restart WSL and apply again'
            sudo systemctl enable --now docker
        fi
    fi
}

loadout_azure_repo_matches() {
    local source=/etc/apt/sources.list.d/azure-cli.list
    [ -r /usr/share/keyrings/microsoft.gpg ] &&
        [ -r "$source" ] &&
        grep -Fq 'https://packages.microsoft.com/repos/azure-cli/ noble main' "$source"
}

loadout_install_azure_repo() (
    set -Eeuo pipefail
    local temporary
    local key
    temporary=$(mktemp -d)
    key="$temporary/microsoft.asc"
    trap 'rm -rf "$temporary"' EXIT

    curl --fail --silent --show-error --location --retry 3 \
        https://packages.microsoft.com/keys/microsoft.asc \
        --output "$key"
    gpg --dearmor --batch --yes \
        --output "$temporary/microsoft.gpg" "$key"
    sudo install -m 0644 "$temporary/microsoft.gpg" \
        /usr/share/keyrings/microsoft.gpg
    printf 'deb [arch=%s signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ noble main\n' \
        "$LOADOUT_DEB_ARCH" >"$temporary/azure-cli.list"
    sudo install -m 0644 "$temporary/azure-cli.list" \
        /etc/apt/sources.list.d/azure-cli.list
)

loadout_ensure_azure_cli() {
    local repo_drift=0
    local package_drift=0
    loadout_section 'Azure CLI'

    if loadout_azure_repo_matches; then
        loadout_ok 'Microsoft Azure CLI repository'
    else
        repo_drift=1
        loadout_change 'configure the Microsoft Azure CLI repository'
    fi

    if loadout_apt_installed azure-cli && command -v az >/dev/null 2>&1; then
        loadout_ok 'azure-cli'
    else
        package_drift=1
        loadout_change 'install azure-cli'
    fi

    if loadout_is_apply && [ "$repo_drift" -eq 1 ]; then
        loadout_install_azure_repo
    fi
    if loadout_is_apply && { [ "$repo_drift" -eq 1 ] || [ "$package_drift" -eq 1 ]; }; then
        sudo apt-get update
        sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y azure-cli
    fi
}
