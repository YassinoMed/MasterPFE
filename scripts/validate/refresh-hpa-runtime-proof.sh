#!/usr/bin/env bash

set -euo pipefail

NS="${NS:-securerag-hub}"
REPORT_DIR="${REPORT_DIR:-artifacts/validation}"
FINAL_DIR="${FINAL_DIR:-artifacts/final}"
HPA_WAIT_ATTEMPTS="${HPA_WAIT_ATTEMPTS:-15}"
HPA_WAIT_SLEEP_SECONDS="${HPA_WAIT_SLEEP_SECONDS:-20}"
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

wait_for_hpa_metrics() {
  local attempt

  for attempt in $(seq 1 "${HPA_WAIT_ATTEMPTS}"); do
    info "Waiting for HPA metrics to converge (${attempt}/${HPA_WAIT_ATTEMPTS})"
    kubectl get hpa -n "${NS}" -o wide || true

    if kubectl get hpa -n "${NS}" >/dev/null 2>&1 \
      && ! kubectl get hpa -n "${NS}" | grep -q '<unknown>'; then
      return 0
    fi

    sleep "${HPA_WAIT_SLEEP_SECONDS}"
  done

  return 1
}

if ! kubectl version --request-timeout=5s >/dev/null 2>&1; then
  error "Kubernetes API is unreachable. Cannot install metrics-server or prove HPA runtime."
  exit 1
fi

mkdir -p "${REPORT_DIR}" "${FINAL_DIR}"

info "Installing or repairing metrics-server"
VALIDATE_HPA_NAMESPACE="${NS}" bash scripts/deploy/install-metrics-server.sh

info "Waiting for HPA runtime metrics to become populated"
if ! wait_for_hpa_metrics; then
  error "HPA metrics still contain <unknown> after ${HPA_WAIT_ATTEMPTS} attempts"
  kubectl get hpa -n "${NS}" -o wide || true
  exit 1
fi

info "Collecting strict HPA runtime proof"
NS="${NS}" OUT_DIR="${REPORT_DIR}" STRICT=true bash scripts/validate/validate-hpa-runtime.sh

info "Collecting production runtime evidence"
NS="${NS}" OUT_DIR="${REPORT_DIR}" bash scripts/validate/collect-production-runtime-evidence.sh

{
  printf '# HPA Runtime Refresh - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Namespace: `%s`\n' "${NS}"
  printf -- '- metrics-server install: `scripts/deploy/install-metrics-server.sh`\n'
  printf -- '- HPA wait attempts: `%s`\n' "${HPA_WAIT_ATTEMPTS}"
  printf -- '- HPA wait sleep seconds: `%s`\n' "${HPA_WAIT_SLEEP_SECONDS}"
  printf -- '- HPA proof: `artifacts/validation/hpa-runtime-report.md`\n'
  printf -- '- Production runtime evidence: `artifacts/validation/production-runtime-evidence.md`\n\n'
  printf 'Status: TERMINÉ only if both referenced reports show metrics-server and HPA checks without PARTIEL or DÉPENDANT_DE_L_ENVIRONNEMENT.\n'
} > "${SUMMARY_FILE}"

info "HPA runtime refresh summary written to ${SUMMARY_FILE}"
