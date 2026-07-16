# Changelog

All notable changes to Loadout are documented here.

## 0.2.1 - 2026-07-16

### Fixed

- Retain existing Copilot instructions and PowerShell profiles instead of
  replacing personalised user files.
- Recognise an existing login shell that already sources `.bashrc`.
- Continue using an existing `~/.taskrc` rather than hiding its task database.
- Request elevation only when a drifted system resource actually needs it.
- Fetch version-manager tags into explicit local refs before switching an
  existing checkout.

## 0.2.0 - 2026-07-16

### Added

- Renovate management for pinned release tools, runtimes, npm packages and
  PowerShell modules.
- Version templates so dependency updates change one tested value rather than
  repeated release filenames.
- Pull-request clean-machine and release URL gates for dependency updates.

### Fixed

- Select release binaries by an unambiguous archive path when an archive also
  contains a completion file with the same basename.
- Identify BuildKit integration runs explicitly instead of mistaking their WSL
  host kernel for a WSL guest.

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
