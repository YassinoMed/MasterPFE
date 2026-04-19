#!/usr/bin/env bash

set -euo pipefail

NS="${NS:-securerag-hub}"
REPORT_DIR="${REPORT_DIR:-artifacts/validation}"
FINAL_DIR="${FINAL_DIR:-artifacts/final}"
STAMP="$(date -u '+%Y%m%dT%H%M%SZ')"
SUMMARY_FILE="${FINAL_DIR}/hpa-runtime-refresh-${STAMP}.md"

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

if ! kubectl version --request-timeout=5s >/dev/null 2>&1; then
  error "Kubernetes API is unreachable. Cannot install metrics-server or prove HPA runtime."
  exit 1
fi

mkdir -p "${REPORT_DIR}" "${FINAL_DIR}"

info "Installing or repairing metrics-server"
VALIDATE_HPA_NAMESPACE="${NS}" bash scripts/deploy/install-metrics-server.sh

info "Collecting strict HPA runtime proof"
NS="${NS}" OUT_DIR="${REPORT_DIR}" STRICT=true bash scripts/validate/validate-hpa-runtime.sh

info "Collecting production runtime evidence"
NS="${NS}" OUT_DIR="${REPORT_DIR}" bash scripts/validate/collect-production-runtime-evidence.sh

{
  printf '# HPA Runtime Refresh - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Namespace: `%s`\n' "${NS}"
  printf -- '- metrics-server install: `scripts/deploy/install-metrics-server.sh`\n'
  printf -- '- HPA proof: `artifacts/validation/hpa-runtime-report.md`\n'
  printf -- '- Production runtime evidence: `artifacts/validation/production-runtime-evidence.md`\n\n'
  printf 'Status: TERMINÉ only if both referenced reports show metrics-server and HPA checks without PARTIEL or DÉPENDANT_DE_L_ENVIRONNEMENT.\n'
} > "${SUMMARY_FILE}"

info "HPA runtime refresh summary written to ${SUMMARY_FILE}"
