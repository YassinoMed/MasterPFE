#!/usr/bin/env bash
# generate-support-pack.sh — Collect all security and validation evidence and package them
set -euo pipefail

PACK_DATE=$(date -u '+%Y%m%dT%H%M%SZ')
PACK_NAME="securerag-hub-support-pack-${PACK_DATE}"
PACK_DIR="reports/support-pack/${PACK_NAME}"
ARCHIVE_DIR="support-pack"
ARCHIVE_FILE="${ARCHIVE_DIR}/${PACK_NAME}.tar.gz"

info() { printf '[INFO] %s\n' "$*"; }

mkdir -p "${PACK_DIR}" "${ARCHIVE_DIR}"

copy_dir_if_present() {
  local src="$1"
  local dest="$2"
  if [[ -d "${src}" ]]; then
    mkdir -p "${PACK_DIR}/${dest}"
    cp -R "${src}/" "${PACK_DIR}/${dest}/"
  fi
}

copy_file_if_present() {
  local src="$1"
  local dest="$2"
  if [[ -f "${src}" ]]; then
    mkdir -p "$(dirname "${PACK_DIR}/${dest}")"
    cp "${src}" "${PACK_DIR}/${dest}"
  fi
}

# 1. Collect Post-Deployment and Hardening Reports
info "Collecting post-deployment reports..."
copy_dir_if_present "reports/postdeploy" "postdeploy"

# 2. Collect CI/CD Security Artifacts (Semgrep, Gitleaks, Trivy, SBOM, Cosign, signatures)
info "Collecting CI/CD security reports and configurations..."
copy_dir_if_present "artifacts/security" "security-artifacts"
copy_dir_if_present "artifacts/sbom" "sbom"
copy_dir_if_present "artifacts/release" "release"
copy_dir_if_present "artifacts/validation" "validation"

# Copy configurations to prove custom rules/customizations
copy_file_if_present "security/semgrep/semgrep.yml" "config/semgrep.yml"
copy_file_if_present ".gitleaks.toml" "config/gitleaks.toml"
copy_file_if_present "Makefile" "config/Makefile"
copy_file_if_present "Jenkinsfile" "config/Jenkinsfile"
copy_file_if_present "Jenkinsfile.cd" "config/Jenkinsfile.cd"

# 3. Collect Kubernetes runtime captures
info "Collecting live Kubernetes configurations and details..."
mkdir -p "${PACK_DIR}/k8s-runtime"
kubectl get deploy -n securerag-hub -o yaml > "${PACK_DIR}/k8s-runtime/deployments.yaml" 2>/dev/null || true
kubectl get pods -n securerag-hub -o wide > "${PACK_DIR}/k8s-runtime/pods.txt" 2>/dev/null || true
kubectl get services -n securerag-hub -o wide > "${PACK_DIR}/k8s-runtime/services.txt" 2>/dev/null || true
kubectl get networkpolicies -n securerag-hub -o yaml > "${PACK_DIR}/k8s-runtime/networkpolicies.yaml" 2>/dev/null || true
kubectl get events -n securerag-hub --sort-by=.lastTimestamp > "${PACK_DIR}/k8s-runtime/events.txt" 2>/dev/null || true
kubectl get policyreport -A -o yaml > "${PACK_DIR}/k8s-runtime/kyverno-policyreports.yaml" 2>/dev/null || true

# 4. Generate README for the support pack
info "Generating support pack index..."
{
  printf '# SecureRAG Hub Evidence & Support Pack\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Support Pack ID: `%s`\n' "${PACK_NAME}"
  printf -- '- Git Commit: `%s`\n' "$(git rev-parse HEAD 2>/dev/null || echo "unknown")"
  printf -- '- Cluster Context: `%s`\n\n' "$(kubectl config current-context 2>/dev/null || echo "unavailable")"
  printf '## Contents\n\n'
  printf -- '- `postdeploy/`: Reports from smoke tests, k8s hardening check, and runtime checks.\n'
  printf -- '- `security-artifacts/`: Trivy, Semgrep, and Gitleaks reports if generated.\n'
  printf -- '- `sbom/`: CycloneDX SBOM files.\n'
  printf -- '- `release/`: Release attestations and promoted digest records.\n'
  printf -- '- `config/`: Pipeline files, Makefiles, and security scanning configurations.\n'
  printf -- '- `k8s-runtime/`: Live cluster configurations, pods list, events, and Kyverno policy reports.\n'
} > "${PACK_DIR}/README.md"

# 5. Compress into tar.gz
info "Compressing evidence files into ${ARCHIVE_FILE}..."
if command -v tar >/dev/null 2>&1; then
  tar -czf "${ARCHIVE_FILE}" -C "reports/support-pack" "${PACK_NAME}"
  info "Support pack successfully generated at: ${ARCHIVE_FILE}"
else
  printf '[ERROR] tar command not found, cannot archive evidence!\n' >&2
  exit 1
fi
