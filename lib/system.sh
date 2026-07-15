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

loadout_azure_source_files() {
    local source
    for source in \
        /etc/apt/sources.list \
        /etc/apt/sources.list.d/*.list \
        /etc/apt/sources.list.d/*.sources; do
        [ -r "$source" ] || continue
        grep -Fqi 'https://packages.microsoft.com/repos/azure-cli' "$source" ||
            continue
        printf '%s\n' "$source"
    done
}

loadout_deb822_field_has_word() {
    local source=$1
    local field=$2
    local expected=$3
    awk -F: -v field="$field" -v expected="$expected" '
        tolower($1) == field {
            value=$0
            sub(/^[^:]*:[[:space:]]*/, "", value)
            count=split(value, words, /[[:space:]]+/)
            for (i=1; i<=count; i++) {
                if (words[i] == expected) {
                    found=1
                }
            }
        }
        END { exit !found }
    ' "$source"
}

loadout_azure_source_is_valid() {
    local source=$1
    local signed_by
    case "$source" in
        *.sources)
            loadout_deb822_field_has_word "$source" types deb &&
                grep -Eqi '^URIs:[[:space:]]*https://packages\.microsoft\.com/repos/azure-cli/?[[:space:]]*$' "$source" &&
                loadout_deb822_field_has_word "$source" suites noble &&
                loadout_deb822_field_has_word "$source" components main ||
                return 1
            if grep -Eqi '^Architectures:' "$source"; then
                loadout_deb822_field_has_word \
                    "$source" architectures "$LOADOUT_DEB_ARCH" ||
                    return 1
            fi
            signed_by=$(awk -F: '
                tolower($1) == "signed-by" {
                    sub(/^[[:space:]]+/, "", $2)
                    print $2
                    exit
                }
            ' "$source")
            ;;
        *)
            local line
            line=$(grep -Ei \
                '^[[:space:]]*deb .*https://packages\.microsoft\.com/repos/azure-cli/?[[:space:]]+noble[[:space:]]+main([[:space:]]|$)' \
                "$source" | sed -n '1p')
            [ -n "$line" ] || return 1
            signed_by=$(sed -n \
                's/.*signed-by=\([^] ,]*\).*/\1/p' <<<"$line")
            ;;
    esac
    [ -n "$signed_by" ] && [ -r "$signed_by" ]
}

loadout_find_valid_azure_source() {
    local excluded=${1:-}
    local source
    while IFS= read -r source; do
        [ "$source" = "$excluded" ] && continue
        if loadout_azure_source_is_valid "$source"; then
            printf '%s\n' "$source"
            return 0
        fi
    done < <(loadout_azure_source_files)
    return 1
}

loadout_azure_repo_matches() {
    loadout_find_valid_azure_source >/dev/null
}

loadout_legacy_azure_source_conflicts() {
    local legacy=/etc/apt/sources.list.d/azure-cli.list
    [ -r "$legacy" ] &&
        grep -Fq 'signed-by=/usr/share/keyrings/microsoft.gpg' "$legacy" &&
        grep -Fq 'https://packages.microsoft.com/repos/azure-cli/ noble main' \
            "$legacy" &&
        loadout_find_valid_azure_source "$legacy" >/dev/null
}

loadout_reconcile_legacy_azure_source() {
    local legacy=/etc/apt/sources.list.d/azure-cli.list
    local backup
    loadout_legacy_azure_source_conflicts || return 0

    loadout_section 'APT source compatibility'
    loadout_change 'retire Loadout legacy Azure CLI source'
    if loadout_is_apply; then
        backup="${legacy}.bak.$(date +%Y%m%d%H%M%S)"
        sudo mv "$legacy" "$backup"
        loadout_warn "retired conflicting source to $backup"
    fi
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
    sudo install -d -m 0755 /etc/apt/keyrings
    sudo install -m 0644 "$temporary/microsoft.gpg" \
        /etc/apt/keyrings/microsoft.gpg
    cat >"$temporary/azure-cli.sources" <<EOF
Types: deb
URIs: https://packages.microsoft.com/repos/azure-cli/
Suites: noble
Components: main
Architectures: $LOADOUT_DEB_ARCH
Signed-By: /etc/apt/keyrings/microsoft.gpg
EOF
    sudo install -m 0644 "$temporary/azure-cli.sources" \
        /etc/apt/sources.list.d/azure-cli.sources
)

loadout_ensure_azure_cli() {
    local repo_drift=0
    local package_drift=0
    loadout_section 'Azure CLI'

    if loadout_azure_repo_matches; then
        loadout_ok 'Microsoft Azure CLI repository'
    else
        if [ -n "$(loadout_azure_source_files)" ]; then
            loadout_die \
                'An Azure CLI APT source exists but its signing key or Noble configuration is invalid'
        fi
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
