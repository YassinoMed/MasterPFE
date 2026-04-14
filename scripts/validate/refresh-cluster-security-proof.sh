#!/usr/bin/env bash

set -euo pipefail

NS="${NS:-securerag-hub}"
REPORT_DIR="${REPORT_DIR:-artifacts/validation}"
FINAL_DIR="${FINAL_DIR:-artifacts/final}"
STAMP="$(date -u '+%Y%m%dT%H%M%SZ')"
SUMMARY_FILE="${FINAL_DIR}/cluster-security-refresh-${STAMP}.md"

info() { printf '[INFO] %s\n' "$*"; }
error() { printf '[ERROR] %s\n' "$*" >&2; }

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    error "Missing required command: $1"
    exit 2
  fi
}

require_command kubectl
require_command bash

if ! kubectl version --request-timeout=3s >/dev/null 2>&1; then
  error "Kubernetes API is unreachable. Cannot produce fresh runtime security proof."
  exit 1
fi

mkdir -p "${REPORT_DIR}" "${FINAL_DIR}"

info "Installing metrics-server addon"
bash scripts/deploy/install-metrics-server.sh

info "Installing Kyverno addon and applying Audit policies"
KYVERNO_POLICY_MODE="audit" APPLY_POLICIES="true" bash scripts/deploy/install-kyverno.sh

info "Collecting cluster security addon status"
bash scripts/validate/validate-cluster-security-addons.sh

info "Collecting runtime evidence"
NS="${NS}" REPORT_DIR="${REPORT_DIR}" bash scripts/validate/collect-runtime-evidence.sh

{
  printf '# Cluster Security Runtime Refresh\n\n'
  printf -- '- Generated at: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Namespace: `%s`\n' "${NS}"
  printf -- '- Metrics server install: `scripts/deploy/install-metrics-server.sh`\n'
  printf -- '- Kyverno install (Audit): `scripts/deploy/install-kyverno.sh`\n'
  printf -- '- Addon validation: `artifacts/validation/cluster-security-addons.md`\n'
  printf -- '- Runtime evidence: `artifacts/validation/k8s-*.txt`\n'
} > "${SUMMARY_FILE}"

info "Fresh cluster security runtime proof written to ${SUMMARY_FILE}"
