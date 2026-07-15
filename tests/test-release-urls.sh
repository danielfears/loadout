#!/usr/bin/env bash

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest="$ROOT/manifests/release-tools.tsv"
# shellcheck disable=SC1091
. "$ROOT/manifests/versions.sh"

check_url() {
    local url=$1
    curl --fail --silent --show-error --location --head --retry 2 \
        "$url" --output /dev/null
}

while IFS=$'\t' read -r \
    label _command _version repository tag \
    arm_asset amd_asset _arm_source _amd_source \
    _version_argument checksum; do
    case "$label" in ''|\#*) continue ;; esac
    for asset in "$arm_asset" "$amd_asset"; do
        base="https://github.com/$repository/releases/download/$tag"
        check_url "$base/$asset"
        if [ "$checksum" != - ]; then
            checksum_name=${checksum//\{asset\}/$asset}
            checksum_name=${checksum_name%%::*}
            check_url "$base/$checksum_name"
        fi
    done
    printf '[OK] %s\n' "$label"
done <"$manifest"

for arch in arm64 amd64; do
    check_url "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${arch}.tar.gz"
    check_url "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${arch}.tar.gz.sha256sum"
    check_url "https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_${arch}.zip"
    check_url "https://github.com/FiloSottile/age/releases/download/v${AGE_VERSION}/age-v${AGE_VERSION}-linux-${arch}.tar.gz"
    check_url "https://gitlab.com/gitlab-org/cli/-/releases/v${GLAB_VERSION}/downloads/glab_${GLAB_VERSION}_linux_${arch}.deb"
done
check_url "https://gitlab.com/gitlab-org/cli/-/releases/v${GLAB_VERSION}/downloads/checksums.txt"
check_url "https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_SHA256SUMS"
check_url "https://pypi.org/pypi/pre-commit/${PRE_COMMIT_VERSION}/json"
check_url "https://pypi.org/pypi/yamllint/${YAMLLINT_VERSION}/json"
printf '[OK] special installers\n'
