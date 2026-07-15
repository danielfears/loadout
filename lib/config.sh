# shellcheck shell=bash

loadout_ensure_file() {
    local label=$1
    local source=$2
    local destination=$3
    local mode=${4:-0644}

    if [ -f "$destination" ] && cmp -s "$source" "$destination"; then
        loadout_ok "$label"
        return
    fi
    loadout_change "configure $label"
    if ! loadout_is_apply; then
        return 0
    fi

    mkdir -p "$(dirname "$destination")"
    loadout_backup_file "$destination"
    install -m "$mode" "$source" "$destination"
}

loadout_ensure_symlink() {
    local label=$1
    local source=$2
    local destination=$3

    if [ -L "$destination" ] &&
        [ "$(readlink -f "$destination")" = "$(readlink -f "$source")" ]; then
        loadout_ok "$label"
        return
    fi
    loadout_change "link $label"
    if ! loadout_is_apply; then
        return 0
    fi

    mkdir -p "$(dirname "$destination")"
    loadout_backup_file "$destination"
    ln -s "$source" "$destination"
}

loadout_ensure_json_overlay() {
    local label=$1
    local overlay=$2
    local destination=$3
    local temporary

    if ! command -v jq >/dev/null 2>&1; then
        loadout_change "merge $label after jq is installed"
        return
    fi

    temporary=$(mktemp -d)
    if [ -s "$destination" ] && jq -e . "$destination" >/dev/null 2>&1; then
        jq --slurpfile overlay "$overlay" \
            '. * $overlay[0]' \
            <"$destination" >"$temporary/merged.json"
    else
        printf '{}\n' |
            jq --slurpfile overlay "$overlay" \
                '. * $overlay[0]' >"$temporary/merged.json"
    fi

    if [ -f "$destination" ] &&
        cmp -s "$temporary/merged.json" "$destination"; then
        loadout_ok "$label"
        rm -rf "$temporary"
        return
    fi
    loadout_change "merge $label"
    if ! loadout_is_apply; then
        rm -rf "$temporary"
        return
    fi

    mkdir -p "$(dirname "$destination")"
    loadout_backup_file "$destination"
    install -m 0644 "$temporary/merged.json" "$destination"
    rm -rf "$temporary"
}

loadout_ensure_marked_block() {
    local label=$1
    local destination=$2
    local block=$3
    local begin='# >>> Loadout >>>'
    local end='# <<< Loadout <<<'
    local current
    local temporary

    current=$(awk -v begin="$begin" -v end="$end" '
        $0 == begin { capture=1 }
        capture { print }
        $0 == end && capture { exit }
    ' "$destination" 2>/dev/null || true)
    if [ "$current" = "$block" ]; then
        loadout_ok "$label"
        return
    fi
    loadout_change "configure $label"
    if ! loadout_is_apply; then
        return 0
    fi

    temporary=$(mktemp)
    if [ -f "$destination" ]; then
        awk -v begin="$begin" -v end="$end" '
            $0 == begin { skip=1; next }
            $0 == end && skip { skip=0; next }
            !skip { print }
        ' "$destination" >"$temporary"
    fi
    {
        printf '\n%s\n' "$block"
    } >>"$temporary"
    loadout_backup_file "$destination"
    install -m 0644 "$temporary" "$destination"
    rm -f "$temporary"
}

loadout_ensure_git_include() {
    local include_file="$HOME/.config/loadout/gitconfig"
    if git config --global --get-all include.path 2>/dev/null |
        grep -Fxq "$include_file"; then
        loadout_ok 'Git include'
        return
    fi
    loadout_change 'add the Loadout Git include'
    if loadout_is_apply; then
        git config --global --add include.path "$include_file"
    fi
}

loadout_linux_vscode_matches() {
    local actual
    command -v code >/dev/null 2>&1 || return 1
    actual=$(code --version 2>/dev/null | sed -n '1p')
    [ "$actual" = "$VSCODE_VERSION" ]
}

loadout_ensure_linux_vscode() {
    local temporary
    local vscode_arch
    if loadout_is_container; then
        loadout_warn 'VS Code convergence skipped inside a container'
        return 0
    fi
    loadout_is_wsl && return 0

    if loadout_linux_vscode_matches; then
        loadout_ok "VS Code $VSCODE_VERSION"
        return
    fi
    loadout_change "install VS Code $VSCODE_VERSION"
    if ! loadout_is_apply; then
        return 0
    fi

    [ "$LOADOUT_ARCH" = arm64 ] && vscode_arch=arm64 || vscode_arch=x64
    temporary=$(mktemp -d)
    curl --fail --silent --show-error --location --retry 3 \
        "https://update.code.visualstudio.com/$VSCODE_VERSION/linux-deb-$vscode_arch/stable" \
        --output "$temporary/code.deb"
    sudo apt-get install -y "$temporary/code.deb"
    rm -rf "$temporary"
}

loadout_ensure_vscode_extensions() {
    local specification
    local extension
    local version
    local current
    local -a install=()
    if loadout_is_container; then
        loadout_warn 'VS Code extensions skipped inside a container'
        return 0
    fi
    if loadout_is_wsl &&
        [ ! -d "$HOME/.vscode-server" ] &&
        ! loadout_is_apply; then
        loadout_change 'initialise the VS Code WSL server and extensions'
        return 0
    fi
    command -v code >/dev/null 2>&1 || {
        loadout_change 'install VS Code before applying WSL extensions'
        return
    }

    current=$(code --list-extensions --show-versions 2>/dev/null || true)
    while IFS= read -r specification; do
        extension=${specification%@*}
        version=${specification##*@}
        if grep -Fxiq "$extension@$version" <<<"$current"; then
            loadout_ok "VS Code extension $extension@$version"
        else
            loadout_change "install VS Code extension $extension@$version"
            install+=("$specification")
        fi
    done < <(loadout_read_lines "$MANIFEST_DIR/vscode-wsl-extensions.txt")

    if loadout_is_apply; then
        for specification in "${install[@]}"; do
            code --install-extension "$specification" --force
        done
    fi
}

loadout_ensure_configuration() {
    local source
    local destination
    local bashrc_block
    local profile_block
    loadout_section 'Configuration'

    while IFS= read -r source; do
        destination="$HOME/.config/loadout/bash/$(basename "$source")"
        loadout_ensure_file \
            "Bash fragment $(basename "$source")" \
            "$source" "$destination"
    done < <(find "$CONFIG_DIR/bash" -maxdepth 1 -type f -name '*.sh' |
        sort)

    bashrc_block=$(cat <<'EOF'
# >>> Loadout >>>
if [ -d "$HOME/.config/loadout/bash" ]; then
    for _loadout_file in "$HOME"/.config/loadout/bash/*.sh; do
        [ -r "$_loadout_file" ] && . "$_loadout_file"
    done
    unset _loadout_file
fi
# <<< Loadout <<<
EOF
)
    profile_block=$(cat <<'EOF'
# >>> Loadout >>>
if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi
# <<< Loadout <<<
EOF
)
    loadout_ensure_marked_block 'Bash startup' "$HOME/.bashrc" "$bashrc_block"
    loadout_ensure_marked_block \
        'Bash login startup' "$HOME/.bash_profile" "$profile_block"

    loadout_ensure_file \
        'Loadout Git configuration' \
        "$CONFIG_DIR/gitconfig" \
        "$HOME/.config/loadout/gitconfig"
    loadout_ensure_git_include
    loadout_ensure_file \
        'Taskwarrior configuration' \
        "$CONFIG_DIR/taskrc" \
        "$HOME/.config/task/taskrc"
    loadout_ensure_file \
        'Copilot instructions' \
        "$CONFIG_DIR/copilot-instructions.md" \
        "$HOME/.copilot/copilot-instructions.md"
    loadout_ensure_json_overlay \
        'Copilot settings' \
        "$CONFIG_DIR/copilot-settings.json" \
        "$HOME/.copilot/settings.json"
    loadout_ensure_file \
        'PowerShell profile' \
        "$CONFIG_DIR/powershell-profile.ps1" \
        "$HOME/.config/powershell/profile.ps1"
    loadout_ensure_file \
        'oh-my-posh theme' \
        "$CONFIG_DIR/oh-my-posh.json" \
        "$HOME/.config/loadout/oh-my-posh.json"
    loadout_ensure_symlink \
        'Loadout CLI' "$LOADOUT_ROOT/bin/loadout" "$HOME/.local/bin/loadout"

    loadout_ensure_linux_vscode
    if ! loadout_is_wsl; then
        loadout_ensure_json_overlay \
            'VS Code settings' \
            "$CONFIG_DIR/vscode-settings.json" \
            "$HOME/.config/Code/User/settings.json"
    fi
    loadout_ensure_vscode_extensions
}
