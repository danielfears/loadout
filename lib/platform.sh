# shellcheck shell=bash

loadout_helm_matches() {
    local output
    command -v helm >/dev/null 2>&1 || return 1
    output=$(helm version --short 2>&1 || true)
    grep -Fq "v$HELM_VERSION" <<<"$output"
}

loadout_install_helm() (
    set -Eeuo pipefail
    local asset="helm-v${HELM_VERSION}-linux-${LOADOUT_ARCH}.tar.gz"
    local temporary
    local expected
    temporary=$(mktemp -d)
    trap 'rm -rf "$temporary"' EXIT

    curl --fail --silent --show-error --location --retry 3 \
        "https://get.helm.sh/$asset" --output "$temporary/$asset"
    curl --fail --silent --show-error --location --retry 3 \
        "https://get.helm.sh/$asset.sha256sum" \
        --output "$temporary/$asset.sha256sum"
    expected=$(awk '{print $1; exit}' "$temporary/$asset.sha256sum")
    [[ "$expected" =~ ^[[:xdigit:]]{64}$ ]] ||
        loadout_die 'Invalid Helm checksum'
    printf '%s  %s\n' "$expected" "$temporary/$asset" |
        sha256sum --check --status ||
        loadout_die 'Helm checksum verification failed'
    tar -xzf "$temporary/$asset" -C "$temporary"
    install -m 0755 "$temporary/linux-${LOADOUT_ARCH}/helm" \
        "$HOME/.local/bin/helm"
)

loadout_packer_matches() {
    loadout_version_matches packer "$PACKER_VERSION" version
}

loadout_install_packer() (
    set -Eeuo pipefail
    local asset="packer_${PACKER_VERSION}_linux_${LOADOUT_ARCH}.zip"
    local checksum="packer_${PACKER_VERSION}_SHA256SUMS"
    local base="https://releases.hashicorp.com/packer/$PACKER_VERSION"
    local temporary
    local expected
    temporary=$(mktemp -d)
    trap 'rm -rf "$temporary"' EXIT

    curl --fail --silent --show-error --location --retry 3 \
        "$base/$asset" --output "$temporary/$asset"
    curl --fail --silent --show-error --location --retry 3 \
        "$base/$checksum" --output "$temporary/$checksum"
    expected=$(awk -v asset="$asset" '$NF == asset {print $1; exit}' \
        "$temporary/$checksum")
    [[ "$expected" =~ ^[[:xdigit:]]{64}$ ]] ||
        loadout_die 'Invalid Packer checksum'
    printf '%s  %s\n' "$expected" "$temporary/$asset" |
        sha256sum --check --status ||
        loadout_die 'Packer checksum verification failed'
    unzip -q "$temporary/$asset" -d "$temporary/extracted"
    install -m 0755 "$temporary/extracted/packer" "$HOME/.local/bin/packer"
)

loadout_age_matches() {
    loadout_version_matches age "$AGE_VERSION" &&
        loadout_version_matches age-keygen "$AGE_VERSION"
}

loadout_install_age() (
    set -Eeuo pipefail
    local asset="age-v${AGE_VERSION}-linux-${LOADOUT_ARCH}.tar.gz"
    local temporary
    temporary=$(mktemp -d)
    trap 'rm -rf "$temporary"' EXIT

    loadout_warn "$asset is signed upstream but has no SHA256 manifest; relying on GitHub HTTPS"
    curl --fail --silent --show-error --location --retry 3 \
        "https://github.com/FiloSottile/age/releases/download/v$AGE_VERSION/$asset" \
        --output "$temporary/$asset"
    tar -xzf "$temporary/$asset" -C "$temporary"
    install -m 0755 "$temporary/age/age" "$HOME/.local/bin/age"
    install -m 0755 "$temporary/age/age-keygen" "$HOME/.local/bin/age-keygen"
)

loadout_glab_matches() {
    loadout_version_matches glab "$GLAB_VERSION"
}

loadout_install_glab() (
    set -Eeuo pipefail
    local asset="glab_${GLAB_VERSION}_linux_${LOADOUT_ARCH}.deb"
    local temporary
    local expected
    temporary=$(mktemp -d)
    trap 'rm -rf "$temporary"' EXIT

    curl --fail --silent --show-error --location --retry 3 \
        "https://gitlab.com/gitlab-org/cli/-/releases/v$GLAB_VERSION/downloads/$asset" \
        --output "$temporary/$asset"
    curl --fail --silent --show-error --location --retry 3 \
        "https://gitlab.com/gitlab-org/cli/-/releases/v$GLAB_VERSION/downloads/checksums.txt" \
        --output "$temporary/checksums.txt"
    expected=$(awk -v asset="$asset" '$NF == asset {print $1; exit}' \
        "$temporary/checksums.txt")
    [[ "$expected" =~ ^[[:xdigit:]]{64}$ ]] ||
        loadout_die 'Invalid GitLab CLI checksum'
    printf '%s  %s\n' "$expected" "$temporary/$asset" |
        sha256sum --check --status ||
        loadout_die 'GitLab CLI checksum verification failed'
    sudo apt-get install -y "$temporary/$asset"
)

loadout_pipx_package_matches() {
    local command_name=$1
    local expected=$2
    loadout_version_matches "$command_name" "$expected"
}

loadout_ensure_pipx_package() {
    local package=$1
    local command_name=$2
    local version=$3

    if loadout_pipx_package_matches "$command_name" "$version"; then
        loadout_ok "$package $version"
        return
    fi
    loadout_change "install $package $version with pipx"
    if loadout_is_apply; then
        pipx install --force "$package==$version"
    fi
}

loadout_ensure_platform_tools() {
    loadout_section 'Platform engineering essentials'

    if loadout_helm_matches; then
        loadout_ok "Helm $HELM_VERSION"
    else
        loadout_change "install Helm $HELM_VERSION"
        loadout_is_apply && loadout_install_helm
    fi

    if loadout_packer_matches; then
        loadout_ok "Packer $PACKER_VERSION"
    else
        loadout_change "install Packer $PACKER_VERSION"
        loadout_is_apply && loadout_install_packer
    fi

    if loadout_age_matches; then
        loadout_ok "age $AGE_VERSION"
    else
        loadout_change "install age and age-keygen $AGE_VERSION"
        loadout_is_apply && loadout_install_age
    fi

    if loadout_glab_matches; then
        loadout_ok "GitLab CLI $GLAB_VERSION"
    else
        loadout_change "install GitLab CLI $GLAB_VERSION"
        loadout_is_apply && loadout_install_glab
    fi

    loadout_ensure_pipx_package \
        pre-commit pre-commit "$PRE_COMMIT_VERSION"
    loadout_ensure_pipx_package \
        yamllint yamllint "$YAMLLINT_VERSION"
}
