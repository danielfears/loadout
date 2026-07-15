# Customising Loadout

Loadout has one desired state rather than selectable runtime profiles.

## Layout

```text
manifests/
├── versions.sh
├── apt-packages.txt
├── release-tools.tsv
├── azure-extensions.tsv
├── powershell-modules.tsv
├── windows-packages.tsv
├── vscode-windows-extensions.txt
├── vscode-wsl-extensions.txt
└── recommendations.tsv

config/
├── bash/
├── copilot-instructions.md
├── copilot-settings.json
├── gitconfig
├── oh-my-posh.json
├── powershell-profile.ps1
├── taskrc
├── vscode-settings.json
└── windows-terminal.fragment.json
```

Edit these files or maintain them in a downstream fork, then run:

```bash
loadout plan
loadout apply
```

## Release manifest

`release-tools.tsv` has eleven tab-separated fields:

1. Display label
2. Installed command
3. Expected version substring
4. GitHub `owner/repository`
5. Release tag
6. ARM64 asset
7. AMD64 asset
8. ARM64 binary filename inside the asset
9. AMD64 binary filename inside the asset
10. Version argument
11. Checksum asset, `{asset}.suffix`, or `-`

The generic provider handles tarballs, ZIP archives and raw binaries.

## Configuration overlays

Loadout owns files under `~/.config/loadout`. It inserts a marked source block
into Bash startup files and adds a Git include rather than replacing the
global Git configuration.

JSON settings are merged at the top level. Existing files are preserved as
timestamped backups before changed output is written.

## Why there are no profiles

A workstation bootstrap should have one obvious target state. Multiple
runtime profiles make `plan` and `check` ambiguous and encourage untested
combinations. Teams that want a different loadout should fork or vendor the
repository and change the desired-state files explicitly.
