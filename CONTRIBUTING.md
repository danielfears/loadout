# Contributing to Loadout

Loadout should remain predictable enough to run on a real workstation.

## Development setup

```bash
git clone https://github.com/danielfears/loadout.git
cd loadout
make check
```

Use `loadout plan --skip-windows` while developing. Do not run
`apply` against a workstation containing irreplaceable configuration unless
the proposed delta has been reviewed.

## Adding a tool

Prefer the following order:

1. An official Ubuntu package.
2. An official vendor repository with a scoped signing key.
3. A pinned upstream release for both ARM64 and AMD64.

For release tools:

- add the exact artefact names to `release-tools.tsv`;
- include the upstream checksum manifest where one exists;
- make version detection cheap and non-interactive;
- run `make verify-releases`;
- explain why the tool belongs in the default desired state rather than
  `recommendations.tsv`.

Do not use `curl | sh` installers when a direct package or release artefact is
available.

Version values remain pinned for reproducibility. Renovate updates supported
pins automatically; non-major updates merge only after CI, release URL checks
and clean-machine convergence pass.

## Resource-provider contract

Each resource must:

- inspect without making a managed configuration change;
- report drift through `loadout_change`;
- change only when `LOADOUT_MODE=apply`;
- converge on a second execution;
- surface errors instead of silently falling back;
- work on ARM64 and AMD64 or fail with a clear unsupported message.

## Desired-state files

Manifests and configuration must not contain:

- real credentials or placeholder values that resemble credentials;
- employer-internal URLs, tenant IDs or project names;
- personal email addresses or Git identities;
- private repository coordinates;
- authentication caches, histories or session databases.

## Pull requests

Keep changes focused and use Conventional Commit subjects. Include the commands
used to validate the change and note any release that lacks a published
checksum.
