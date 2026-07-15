## Summary

## Resource-provider behaviour

- [ ] `plan` detects drift without changing managed configuration
- [ ] `apply` changes only drifted resources
- [ ] `check` passes after apply
- [ ] A second apply performs no managed changes

## Validation

- [ ] `make check`
- [ ] `make verify-releases` when release manifests changed
- [ ] Clean-machine integration when installers changed

## Security

- [ ] No credentials, private URLs, identities or personal data
- [ ] Official source and checksum documented
- [ ] ARM64 and AMD64 covered
