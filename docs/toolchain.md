# Toolchain rationale

The default toolchain is intentionally broad enough for Azure DevOps and platform
engineering, but each default has a distinct job.

| Pillar | Defaults | Purpose |
|---|---|---|
| Azure | az, azd, Bicep, AzCopy, kubelogin, Az PowerShell | Native delivery, identity and service operations |
| Infrastructure | Terraform, Packer, TFLint, terraform-docs, Infracost | Provisioning, images, quality and cost |
| Kubernetes | kubectl, Helm, Kustomize, k9s, kind, stern, kubeconform | Cluster development, packaging and diagnosis |
| GitOps and policy | Flux, OPA, Conftest | Reconciliation and policy-as-code |
| Supply chain | SOPS, age, cosign, Syft, ORAS, Trivy | Secrets, signing, SBOMs and OCI artefacts |
| CI quality | actionlint, hadolint, ShellCheck, yamllint, pre-commit | Fast local pipeline feedback |
| Collaboration | gh, glab, VS Code, Copilot | GitHub, GitLab and assisted development |

## Deliberate omissions

- **Argo CD CLI:** useful when Argo CD is selected; Flux is the Azure-aligned
  default.
- **Terragrunt:** valuable in estates designed around it, but not a universal
  Terraform requirement.
- **Grype:** Trivy already provides vulnerability scanning; Syft supplies the
  complementary SBOM capability.
- **OpenTofu:** avoid placing two Terraform-compatible CLIs in the default
  path without a deliberate estate decision.
- **Vault:** SOPS and Azure Key Vault cover the default workflow.

Run `loadout recommend` for the optional list.
