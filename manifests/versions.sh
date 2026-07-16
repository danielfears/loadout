# shellcheck shell=bash
# shellcheck disable=SC2034

LOADOUT_NAME="Loadout: Azure DevOps and platform engineering"
LOADOUT_DESCRIPTION="An opinionated zero-to-hero Azure platform workstation"
LOADOUT_UBUNTU_VERSION=24.04

# renovate: datasource=github-releases depName=nvm-sh/nvm
NVM_VERSION=0.39.7
# renovate: datasource=node-version depName=node versioning=node
NODE_VERSION=24.16.0
# renovate: datasource=npm depName=npm
NPM_VERSION=11.13.0
# renovate: datasource=npm depName=corepack
COREPACK_VERSION=0.35.0
# renovate: datasource=npm depName=@github/copilot
COPILOT_NPM_VERSION=1.0.59

# renovate: datasource=github-releases depName=tfutils/tfenv
TFENV_VERSION=3.2.2
# renovate: datasource=github-releases depName=hashicorp/terraform
TERRAFORM_VERSION=1.14.4

# renovate: datasource=github-releases depName=kubernetes/kubernetes
KUBECTL_VERSION=1.35.4
# renovate: datasource=github-releases depName=PowerShell/PowerShell
POWERSHELL_VERSION=7.6.3
# renovate: datasource=github-releases depName=microsoft/cascadia-code
CASCADIA_CODE_VERSION=2407.24
# renovate: datasource=github-releases depName=microsoft/vscode
VSCODE_VERSION=1.129.0
# renovate: datasource=github-releases depName=helm/helm
HELM_VERSION=4.2.3
# renovate: datasource=github-releases depName=hashicorp/packer
PACKER_VERSION=1.15.4
# renovate: datasource=github-releases depName=FiloSottile/age
AGE_VERSION=1.3.1
# renovate: datasource=gitlab-releases depName=gitlab-org/cli registryUrl=https://gitlab.com
GLAB_VERSION=1.108.0
# renovate: datasource=pypi depName=pre-commit
PRE_COMMIT_VERSION=4.6.0
# renovate: datasource=pypi depName=yamllint
YAMLLINT_VERSION=1.38.0

LOADOUT_COPILOT_AUTOPILOT=1
LOADOUT_COPILOT_ALLOW_ALL=1
LOADOUT_STARTUP_SPLASH=1
