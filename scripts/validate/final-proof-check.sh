#!/usr/bin/env bash

set -euo pipefail

NS="${NS:-securerag-hub}"
JENKINS_URL="${JENKINS_URL:-http://localhost:8085/login}"
API_GATEWAY_HEALTH_URL="${API_GATEWAY_HEALTH_URL:-http://localhost:8080/healthz}"
PORTAL_HEALTH_URL="${PORTAL_HEALTH_URL:-http://localhost:8081/health}"

FINAL_DIR="${FINAL_DIR:-artifacts/final}"
RELEASE_DIR="${RELEASE_DIR:-artifacts/release}"
SUPPORT_DIR="${SUPPORT_DIR:-artifacts/support-pack}"
REPORT_FILE="${FINAL_PROOF_REPORT:-${FINAL_DIR}/final-proof-check.txt}"

mkdir -p "${FINAL_DIR}"

pass_count=0
warn_count=0
fail_count=0

log() {
  printf '%s\n' "$*" | tee -a "${REPORT_FILE}"
}

pass() {
  pass_count=$((pass_count + 1))
  log "[PASS] $1"
}

warn() {
  warn_count=$((warn_count + 1))
  log "[WARN] $1"
}

fail() {
  fail_count=$((fail_count + 1))
  log "[FAIL] $1"
}

require_command() {
  if command -v "$1" >/dev/null 2>&1; then
    pass "Command available: $1"
  else
    fail "Command missing: $1"
  fi
}

: > "${REPORT_FILE}"

log "=== SecureRAG Hub - Final Proof Check ==="
log "timestamp_utc=$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
log "namespace=${NS}"
log ""

require_command docker
require_command kubectl
require_command curl

if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then
    pass "Docker is accessible"
  else
    fail "Docker is installed but not accessible"
  fi
fi

if command -v kubectl >/dev/null 2>&1; then
  current_context="$(kubectl config current-context 2>/dev/null || true)"
  if [[ "${current_context}" == "kind-securerag-dev" ]]; then
    pass "kubectl context is ${current_context}"
  elif [[ -n "${current_context}" ]]; then
    warn "kubectl context is ${current_context}, expected kind-securerag-dev"
  else
    fail "kubectl current-context is empty"
  fi

  if kubectl get ns "${NS}" >/dev/null 2>&1; then
    pass "Namespace ${NS} exists"
  else
    fail "Namespace ${NS} is not reachable"
  fi

  if kubectl get pods -n "${NS}" >/dev/null 2>&1; then
    pass "Kubernetes API responds for namespace ${NS}"
  else
    fail "Kubernetes API does not respond for namespace ${NS}"
  fi
fi

if command -v curl >/dev/null 2>&1; then
  if curl -fsS "${API_GATEWAY_HEALTH_URL}" >/dev/null 2>&1; then
    pass "API Gateway health is reachable"
  else
    warn "API Gateway health is not reachable at ${API_GATEWAY_HEALTH_URL}"
  fi

  if curl -fsS "${PORTAL_HEALTH_URL}" >/dev/null 2>&1; then
    pass "Portal Web health is reachable"
  else
    warn "Portal Web health is not reachable at ${PORTAL_HEALTH_URL}"
  fi

  if curl -fsS "${JENKINS_URL}" >/dev/null 2>&1; then
    pass "Jenkins is reachable"
  else
    warn "Jenkins is not reachable at ${JENKINS_URL}"
  fi
fi

if [[ -f "${FINAL_DIR}/reference-campaign-summary.md" ]]; then
  pass "Reference campaign summary is present"
else
  warn "Reference campaign summary is missing"
fi

if [[ -f "${FINAL_DIR}/final-validation-summary.md" ]]; then
  pass "Final validation summary is present"
else
  warn "Final validation summary is missing"
fi

if [[ -f "${RELEASE_DIR}/release-evidence.md" ]]; then
  pass "Release evidence is present"
else
  warn "Release evidence is missing"
fi

latest_support_pack="$(find "${SUPPORT_DIR}" -maxdepth 1 -type f -name '*.tar.gz' 2>/dev/null | sort | tail -n 1 || true)"
if [[ -n "${latest_support_pack}" ]]; then
  pass "Support pack found: ${latest_support_pack}"
else
  warn "No archived support pack found"
fi

log ""
log "=== Kubernetes quick view ==="
if command -v kubectl >/dev/null 2>&1; then
  kubectl get pods,svc,hpa,pdb,networkpolicy -n "${NS}" 2>&1 | tee -a "${REPORT_FILE}" || warn "Unable to print Kubernetes quick view"
else
  warn "kubectl unavailable, Kubernetes quick view skipped"
fi

log ""
log "=== Final proof check summary ==="
log "pass=${pass_count}"
log "warn=${warn_count}"
log "fail=${fail_count}"
log "report=${REPORT_FILE}"

if (( fail_count > 0 )); then
  exit 1
fi

exit 0
