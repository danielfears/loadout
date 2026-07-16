# Security policy

## Reporting a vulnerability

Do not open a public issue for a suspected vulnerability.

Use GitHub's **Report a vulnerability** workflow on the Security tab. Include:

- the affected command and manifest;
- the operating system and architecture;
- the expected and observed behaviour;
- a minimal reproduction;
- whether credentials, file contents or command execution are exposed.

## Security boundaries

Loadout manages executable downloads and workstation configuration, so changes
to installers receive the same scrutiny as production deployment code.

- Versions and release URLs are explicit manifest data.
- Published SHA-256 manifests are verified when upstream provides them.
- Sources without detached checksums produce a visible warning.
- Renovate waits three days after a release and requires the test gates before
  non-major version updates can merge.
- Managed files are backed up before replacement.
- Secrets, authentication caches and private keys are never configuration content.
- Cloud authentication remains interactive.
- Loadout does not deploy infrastructure or run Terraform plans/applies.

## Supported versions

Until the first stable release, security fixes are applied to the latest
`main` branch and newest `0.x` release only.

## Maintainer checklist

Before publishing a release:

1. Run `make check`.
2. Run `make verify-releases`.
3. Run the clean-machine integration workflow.
4. Scan the complete Git history for credentials and private references.
5. Review all new download origins, checksums and executable permissions.
