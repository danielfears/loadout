# Architecture

Loadout is a dependency-light Bash control plane with a small PowerShell
adapter for Windows hosts.

## Execution model

`bin/loadout` parses the command, loads the desired-state manifests, detects the platform and
executes each resource provider in a fixed order.

| Mode | Behaviour |
|---|---|
| `plan` | Inspects resources and prints drift. |
| `apply` | Plans, asks for confirmation, applies drift, then checks again. |
| `check` | Inspects and exits non-zero when drift remains. |

The second check is part of `apply`; an installer that returns success without
converging fails the command.

## Resource order

1. Platform and WSL systemd
2. Ubuntu packages and Docker
3. Azure CLI repository
4. Pinned release tools
5. Platform-specialised installers
6. kubectl and PowerShell
7. Git-backed version managers
8. Node, Terraform, Azure extensions and PowerShell modules
9. Optional Windows host adapter
10. Managed shell, Git, editor and Copilot configuration

Later providers may rely on earlier providers during the same apply.

## Desired-state boundary

Versions, packages, extensions and modules live under `manifests/`.
Configuration overlays live under `config/`. These files describe one
opinionated target state; they do not contain credentials or authentication
state.

## Windows boundary

`bootstrap.ps1` is an orchestrator for a fresh Windows host. It prepares WSL,
then invokes the Linux engine.

When Loadout runs under WSL, `lib/windows.sh` invokes
`windows/apply.ps1`. The adapter manages only:

- winget packages;
- Cascadia Nerd Fonts;
- a Windows Terminal fragment;
- merged VS Code and Copilot settings;
- VS Code extensions;
- PowerShell modules.

Native Linux never calls the adapter.

## Idempotence

Resource providers do not rely on a mutable Loadout state database. Desired
state is compared directly with package databases, command versions, Git
commits, module inventories, extension inventories, file content and service
status.

This makes drift explainable and allows `check` to run independently from
previous Loadout executions.

## Version lifecycle

Desired versions stay pinned so a clean-machine run is reproducible. Renovate
updates the single version field for each dependency and opens a pull request.
Version-bearing release tags and filenames use `{version}` templates, avoiding
multi-file manual edits. Non-major updates can merge only after the repository
test workflows pass.
