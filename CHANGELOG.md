# Changelog

All notable changes to Loadout are documented here.

## 0.1.1 - 2026-07-16

### Fixed

- Adopt an existing valid Azure CLI APT source in either Deb822 or legacy
  one-line format.
- Retire the conflicting legacy source created by Loadout 0.1.0 when a valid
  modern source already exists.
- Install new Azure CLI sources with the modern `/etc/apt/keyrings` and
  Deb822 conventions.

## 0.1.0 - 2026-07-15

### Added

- Idempotent `plan`, `apply`, `check`, `doctor`, `list` and `recommend`
  commands.
- Ubuntu 24.04 support on ARM64 and AMD64.
- Windows 11 to WSL2 bootstrap and optional Windows host adapter.
- Opinionated Azure DevOps and platform-engineering desired state.
- Pinned Azure, Terraform, Kubernetes, GitOps, policy and supply-chain tools.
- Full Az PowerShell module parity across Windows and Linux.
- Safe shell, Git, VS Code, Copilot and terminal configuration.
- Linux/Windows CI, release URL validation and clean-machine integration.
