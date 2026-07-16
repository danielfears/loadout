# shellcheck shell=bash

loadout_find_release_source() {
    local extracted=$1
    local source_name=$2
    if [[ "$source_name" == */* ]]; then
        find "$extracted" -type f \
            -path "$extracted/$source_name" -print -quit
    else
        find "$extracted" -type f \
            -name "$source_name" -print -quit
    fi
}

loadout_checksum_for_asset() {
    local repository=$1
    local tag=$2
    local asset=$3
    local checksum_name=$4
    local asset_file=$5
    local checksum_file=$6
    local checksum_field=
    local checksum_text
    local expected

    if [ "$checksum_name" = - ]; then
        loadout_warn "$asset has no upstream checksum; relying on GitHub HTTPS"
        return 0
    fi
    checksum_name=${checksum_name//\{asset\}/$asset}
    if [[ "$checksum_name" == *::* ]]; then
        checksum_field=${checksum_name##*::}
        checksum_name=${checksum_name%%::*}
    fi
    curl --fail --silent --show-error --location --retry 3 \
        "https://github.com/$repository/releases/download/$tag/$checksum_name" \
        --output "$checksum_file"

    if [ "$(od -An -tx1 -N2 "$checksum_file" | tr -d '[:space:]')" = fffe ]; then
        checksum_text=$(iconv -f UTF-16LE -t UTF-8 "$checksum_file")
    else
        checksum_text=$(cat "$checksum_file")
    fi
    if [ -n "$checksum_field" ]; then
        expected=$(tr -d '\r' <<<"$checksum_text" |
            awk -v asset="$asset" -v field="$checksum_field" \
                '$1 == asset { print $field; exit }' || true)
    else
        expected=$(tr -d '\r' <<<"$checksum_text" |
            awk -v asset="$asset" '
                { name=$NF; sub(/^\*/, "", name) }
                name == asset { print $1; exit }
                NR == 1 && NF == 1 { print $1; exit }
            ' || true)
    fi
    [[ "$expected" =~ ^[[:xdigit:]]{64}$ ]] ||
        loadout_die "Checksum manifest does not contain $asset"
    printf '%s  %s\n' "$expected" "$asset_file" |
        sha256sum --check --status ||
        loadout_die "Checksum verification failed for $asset"
}

loadout_install_release_tool() (
    set -Eeuo pipefail
    local label=$1
    local command_name=$2
    local version=$3
    local repository=$4
    local tag=$5
    local asset=$6
    local source_name=$7
    local version_argument=$8
    local checksum_name=$9
    local temporary
    local archive
    local extracted
    local source_file

    temporary=$(mktemp -d)
    trap 'rm -rf "$temporary"' EXIT
    archive="$temporary/$asset"
    extracted="$temporary/extracted"
    mkdir -p "$extracted"

    curl --fail --silent --show-error --location --retry 3 \
        "https://github.com/$repository/releases/download/$tag/$asset" \
        --output "$archive"
    loadout_checksum_for_asset \
        "$repository" "$tag" "$asset" "$checksum_name" \
        "$archive" "$temporary/checksums.txt"

    case "$asset" in
        *.tar.gz|*.tgz) tar -xzf "$archive" -C "$extracted" ;;
        *.zip) unzip -q "$archive" -d "$extracted" ;;
        *) cp "$archive" "$extracted/$source_name" ;;
    esac
    source_file=$(loadout_find_release_source "$extracted" "$source_name")
    [ -n "$source_file" ] ||
        loadout_die "Unable to locate $source_name in the $label release"
    mkdir -p "$HOME/.local/bin"
    install -m 0755 "$source_file" "$HOME/.local/bin/$command_name"
    if ! loadout_version_matches \
        "$command_name" "$version" "$version_argument"; then
        actual_output=$(loadout_version_output \
            "$command_name" "$version_argument" || true)
        loadout_die \
            "$label did not report version $version after installation: ${actual_output:-no output}"
    fi
)

loadout_ensure_release_tools() {
    local label
    local command_name
    local version
    local repository
    local tag_template
    local arm_asset_template
    local amd_asset_template
    local arm_source_template
    local amd_source_template
    local version_argument
    local checksum_template
    local tag
    local asset
    local source_name
    local checksum_name

    loadout_section 'Pinned command-line tools'
    while IFS=$'\t' read -r \
        label command_name version repository tag_template \
        arm_asset_template amd_asset_template \
        arm_source_template amd_source_template \
        version_argument checksum_template; do
        case "$label" in ''|\#*) continue ;; esac
        tag=$(loadout_expand_version "$tag_template" "$version")
        checksum_name=$(loadout_expand_version "$checksum_template" "$version")
        if [ "$LOADOUT_ARCH" = arm64 ]; then
            asset=$(loadout_expand_version "$arm_asset_template" "$version")
            source_name=$(loadout_expand_version "$arm_source_template" "$version")
        else
            asset=$(loadout_expand_version "$amd_asset_template" "$version")
            source_name=$(loadout_expand_version "$amd_source_template" "$version")
        fi

        if loadout_version_matches "$command_name" "$version" "$version_argument"; then
            loadout_ok "$label $version"
            continue
        fi
        loadout_change "install $label $version"
        if loadout_is_apply; then
            loadout_install_release_tool \
                "$label" "$command_name" "$version" "$repository" "$tag" \
                "$asset" "$source_name" "$version_argument" "$checksum_name"
        fi
    done <"$MANIFEST_DIR/release-tools.tsv"
}

loadout_kubectl_matches() {
    local output
    command -v kubectl >/dev/null 2>&1 || return 1
    output=$(kubectl version --client=true 2>&1 || true)
    grep -Fq "v$KUBECTL_VERSION" <<<"$output"
}

loadout_install_kubectl() (
    set -Eeuo pipefail
    local url
    local temporary
    local expected
    temporary=$(mktemp -d)
    trap 'rm -rf "$temporary"' EXIT
    url="https://dl.k8s.io/release/v$KUBECTL_VERSION/bin/linux/$LOADOUT_ARCH/kubectl"
    curl --fail --silent --show-error --location --retry 3 \
        "$url" --output "$temporary/kubectl"
    curl --fail --silent --show-error --location --retry 3 \
        "$url.sha256" --output "$temporary/kubectl.sha256"
    expected=$(tr -d '[:space:]' <"$temporary/kubectl.sha256")
    [[ "$expected" =~ ^[[:xdigit:]]{64}$ ]] ||
        loadout_die 'Invalid kubectl checksum'
    printf '%s  %s\n' "$expected" "$temporary/kubectl" |
        sha256sum --check --status ||
        loadout_die 'kubectl checksum verification failed'
    install -m 0755 "$temporary/kubectl" "$HOME/.local/bin/kubectl"
    loadout_kubectl_matches ||
        loadout_die "kubectl did not report version $KUBECTL_VERSION"
)

loadout_ensure_kubectl() {
    loadout_section 'Kubernetes CLI'

    if loadout_kubectl_matches; then
        loadout_ok "kubectl $KUBECTL_VERSION"
        return
    fi
    loadout_change "install kubectl $KUBECTL_VERSION"
    if loadout_is_apply; then
        loadout_install_kubectl
    fi
}

loadout_install_powershell() (
    set -Eeuo pipefail
    local asset
    local temporary
    local archive
    local extracted
    local destination
    asset="powershell-${POWERSHELL_VERSION}-linux-${LOADOUT_PWSH_ARCH}.tar.gz"
    temporary=$(mktemp -d)
    trap 'rm -rf "$temporary"' EXIT
    archive="$temporary/$asset"
    extracted="$temporary/extracted"
    destination="$HOME/.local/share/powershell/$POWERSHELL_VERSION"

    curl --fail --silent --show-error --location --retry 3 \
        "https://github.com/PowerShell/PowerShell/releases/download/v$POWERSHELL_VERSION/$asset" \
        --output "$archive"
    loadout_checksum_for_asset \
        PowerShell/PowerShell "v$POWERSHELL_VERSION" "$asset" hashes.sha256 \
        "$archive" "$temporary/hashes.sha256"
    mkdir -p "$extracted" "$(dirname "$destination")"
    tar -xzf "$archive" -C "$extracted"
    if [ -e "$destination" ]; then
        loadout_backup_file "$destination"
    fi
    mv "$extracted" "$destination"
    chmod 0755 "$destination/pwsh"
    ln -sfn "$destination/pwsh" "$HOME/.local/bin/pwsh"
    loadout_version_matches pwsh "$POWERSHELL_VERSION" ||
        loadout_die "PowerShell did not report version $POWERSHELL_VERSION"
)

loadout_ensure_powershell() {
    loadout_section 'PowerShell'

    if loadout_version_matches pwsh "$POWERSHELL_VERSION"; then
        loadout_ok "PowerShell $POWERSHELL_VERSION"
        return
    fi
    loadout_change "install PowerShell $POWERSHELL_VERSION"
    if loadout_is_apply; then
        loadout_install_powershell
    fi
}
