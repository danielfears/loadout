# shellcheck shell=bash

loadout_checkout_matches() {
    local path=$1
    local commit=$2
    [ -d "$path/.git" ] &&
        [ "$(git -C "$path" rev-parse HEAD 2>/dev/null || true)" = "$commit" ]
}

loadout_ensure_checkout() {
    local label=$1
    local path=$2
    local remote=$3
    local commit=$4

    if loadout_checkout_matches "$path" "$commit"; then
        loadout_ok "$label checkout"
        return
    fi
    loadout_change "pin $label checkout to $commit"
    if ! loadout_is_apply; then
        return 0
    fi

    if [ -d "$path/.git" ]; then
        [ -z "$(git -C "$path" status --porcelain)" ] ||
            loadout_die "$path has local changes; refusing to change its revision"
        git -C "$path" fetch --quiet origin "$commit"
    elif [ -e "$path" ]; then
        loadout_die "$path exists but is not a Git checkout"
    else
        git clone --quiet "$remote" "$path"
        git -C "$path" fetch --quiet origin "$commit"
    fi
    git -C "$path" checkout --quiet --detach "$commit"
}

loadout_ensure_checkouts() {
    loadout_section 'Version-manager checkouts'
    loadout_ensure_checkout \
        fzf "$HOME/.fzf" https://github.com/junegunn/fzf.git "$FZF_COMMIT"
    loadout_ensure_checkout \
        nvm "$HOME/.nvm" https://github.com/nvm-sh/nvm.git "$NVM_COMMIT"
    loadout_ensure_checkout \
        tfenv "$HOME/.tfenv" https://github.com/tfutils/tfenv.git "$TFENV_COMMIT"
}

loadout_source_nvm() {
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] || return 1
    set +u
    # shellcheck disable=SC1091
    . "$NVM_DIR/nvm.sh"
    set -u
}

loadout_global_npm_version() {
    local package=$1
    local npm_root
    npm_root=$(npm root --global 2>/dev/null || true)
    [ -n "$npm_root" ] || return 1
    node -p "require('$npm_root/$package/package.json').version" 2>/dev/null
}

loadout_ensure_node() {
    local -a packages=()
    local actual
    loadout_section 'Node.js and Copilot CLI'

    if [ -s "$HOME/.nvm/nvm.sh" ]; then
        loadout_source_nvm || true
    fi

    if loadout_version_matches node "v$NODE_VERSION"; then
        loadout_ok "Node.js $NODE_VERSION"
    else
        loadout_change "install Node.js $NODE_VERSION"
        if loadout_is_apply; then
            loadout_source_nvm ||
                loadout_die 'nvm is unavailable after checkout convergence'
            nvm install "$NODE_VERSION"
            nvm alias default "$NODE_VERSION"
            nvm use "$NODE_VERSION"
        fi
    fi

    if loadout_version_matches npm "$NPM_VERSION"; then
        loadout_ok "npm $NPM_VERSION"
    else
        loadout_change "install npm $NPM_VERSION"
        packages+=("npm@$NPM_VERSION")
    fi

    actual=$(loadout_global_npm_version corepack || true)
    if [ "$actual" = "$COREPACK_VERSION" ]; then
        loadout_ok "corepack $COREPACK_VERSION"
    else
        loadout_change "install corepack $COREPACK_VERSION"
        packages+=("corepack@$COREPACK_VERSION")
    fi

    actual=$(loadout_global_npm_version @github/copilot || true)
    if [ "$actual" = "$COPILOT_NPM_VERSION" ]; then
        loadout_ok "GitHub Copilot CLI package $COPILOT_NPM_VERSION"
    else
        loadout_change "install GitHub Copilot CLI package $COPILOT_NPM_VERSION"
        packages+=("@github/copilot@$COPILOT_NPM_VERSION")
    fi

    if loadout_is_apply && [ "${#packages[@]}" -gt 0 ]; then
        loadout_source_nvm ||
            loadout_die 'nvm is unavailable while installing npm packages'
        npm install --global "${packages[@]}"
        corepack enable
    fi
}

loadout_ensure_terraform() {
    loadout_section 'Terraform'
    export PATH="$HOME/.tfenv/bin:$PATH"

    if loadout_version_matches terraform "$TERRAFORM_VERSION"; then
        loadout_ok "Terraform $TERRAFORM_VERSION"
        return
    fi
    loadout_change "install Terraform $TERRAFORM_VERSION with tfenv"
    if ! loadout_is_apply; then
        return 0
    fi

    [ -x "$HOME/.tfenv/bin/tfenv" ] ||
        loadout_die 'tfenv is unavailable after checkout convergence'
    if [ ! -d "$HOME/.tfenv/versions/$TERRAFORM_VERSION" ]; then
        tfenv install "$TERRAFORM_VERSION"
    fi
    tfenv use "$TERRAFORM_VERSION"
}

loadout_ensure_azure_extensions() {
    local extension
    local expected
    local actual
    loadout_section 'Azure CLI extensions'

    while IFS=$'\t' read -r extension expected; do
        case "$extension" in ''|\#*) continue ;; esac
        actual=
        if command -v az >/dev/null 2>&1; then
            actual=$(az extension show --name "$extension" --query version \
                --output tsv 2>/dev/null || true)
        fi
        if [ "$actual" = "$expected" ]; then
            loadout_ok "$extension $expected"
            continue
        fi
        loadout_change "install Azure extension $extension $expected"
        if loadout_is_apply; then
            az extension add \
                --name "$extension" \
                --version "$expected" \
                --upgrade
        fi
    done <"$MANIFEST_DIR/azure-extensions.tsv"
}

loadout_powershell_module_version() {
    local module=$1
    local expected=$2
    command -v pwsh >/dev/null 2>&1 || return 1
    pwsh -NoProfile -NonInteractive -Command \
        "\$m=Get-Module -ListAvailable '$module' | Where-Object Version -eq '$expected' | Select-Object -First 1; if(\$m){\$m.Version.ToString()}" \
        2>/dev/null |
        tr -d '\r'
}

loadout_ensure_powershell_modules() {
    local module
    local expected
    local actual
    local module_drift=0
    loadout_section 'PowerShell modules'

    while IFS=$'\t' read -r module expected; do
        case "$module" in ''|\#*) continue ;; esac
        actual=$(loadout_powershell_module_version "$module" "$expected" || true)
        if [ "$actual" = "$expected" ]; then
            loadout_ok "$module $expected"
        else
            module_drift=1
            loadout_change "install PowerShell module $module $expected"
        fi
    done <"$MANIFEST_DIR/powershell-modules.tsv"

    if loadout_is_apply && [ "$module_drift" -eq 1 ]; then
        pwsh -NoProfile -NonInteractive -File \
            "$LOADOUT_ROOT/scripts/install-powershell-modules.ps1" \
            -Manifest "$MANIFEST_DIR/powershell-modules.tsv"
    fi
}
