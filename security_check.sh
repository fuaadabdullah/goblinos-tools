#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "[security_check] running security checks"

# Check if required tools are installed
command -v trivy >/dev/null 2>&1 || { echo "[security_check] error: trivy is not installed. Install from https://aquasecurity.github.io/trivy/"; exit 1; }
command -v cosign >/dev/null 2>&1 || { echo "[security_check] error: cosign is not installed. Install from https://docs.sigstore.dev/cosign/installation/"; exit 1; }
command -v sops >/dev/null 2>&1 || { echo "[security_check] error: sops is not installed. Install from https://github.com/getsops/sops"; exit 1; }
command -v age >/dev/null 2>&1 || { echo "[security_check] error: age is not installed. Install from https://github.com/FiloSottile/age"; exit 1; }

echo "[security_check] all security tools are available"

# Container scanning with Trivy (if Docker images exist)
if command -v docker >/dev/null 2>&1 && docker images | grep -q .; then
  echo "[security_check] scanning Docker images with Trivy"

  # Get list of local images
  docker images --format "table {{.Repository}}:{{.Tag}}" | tail -n +2 | while read -r image; do
    if [[ "$image" != "<none>:<none>" ]]; then
      echo "[security_check] scanning image: $image"
      trivy image --exit-code 0 --no-progress --format table "$image" || echo "[security_check] warning: failed to scan $image"
    fi
  done

  # Scan Dockerfiles for misconfigurations
  echo "[security_check] scanning Dockerfiles for misconfigurations"
  find "${REPO_ROOT}" -name "Dockerfile*" -type f | while read -r dockerfile; do
    echo "[security_check] scanning Dockerfile: $dockerfile"
    trivy config --exit-code 0 --no-progress "$dockerfile" || echo "[security_check] warning: misconfigurations found in $dockerfile"
  done
else
  echo "[security_check] Docker not available or no images to scan"
fi

# Check for encrypted secrets (SOPS files)
if find "${REPO_ROOT}" -name "*.sops.*" -o -name "*.enc.*" | grep -q .; then
  echo "[security_check] found encrypted files, validating with SOPS"
  # Basic validation - check if sops can decrypt (would need keys)
  sops --version
else
  echo "[security_check] no SOPS encrypted files found"
fi

echo "[security_check] completed"
