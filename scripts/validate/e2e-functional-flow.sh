#!/usr/bin/env bash

set -euo pipefail

NS="${NS:-securerag-hub}"
REPORT_DIR="${REPORT_DIR:-artifacts/validation}"
REPORT_FILE="${REPORT_DIR}/e2e-functional-flow.txt"
VALIDATION_IMAGE="${VALIDATION_IMAGE:-curlimages/curl:8.11.1}"
pod_name="e2e-functional-check-$(date +%s)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/validate/lib/k8s-validation-pod.sh
source "${SCRIPT_DIR}/lib/k8s-validation-pod.sh"

mkdir -p "${REPORT_DIR}"
: > "${REPORT_FILE}"

pass() { echo "[PASS] $1" | tee -a "${REPORT_FILE}"; }
fail() { echo "[FAIL] $1" | tee -a "${REPORT_FILE}"; exit 1; }
skip() { echo "[SKIP] $1" | tee -a "${REPORT_FILE}"; }

services=(
  portal-web
  auth-users
  chatbot-manager
  conversation-service
  audit-security-service
)

echo "=== E2E functional flow validation ===" | tee -a "${REPORT_FILE}"

for svc in "${services[@]}"; do
  if kubectl get svc "${svc}" -n "${NS}" >/dev/null 2>&1; then
    pass "Service ${svc} exists"
  else
    fail "Service ${svc} missing"
  fi
done

kubectl run "${pod_name}" \
  --rm -i --attach=true --restart=Never -n "${NS}" \
  --labels=app.kubernetes.io/part-of=securerag-hub,job-role=validation \
  --image="${VALIDATION_IMAGE}" \
  --override-type=strategic \
  --overrides="$(validation_pod_overrides "${pod_name}")" \
  --command -- sh -ec '
for target in \
  http://portal-web:8000/health \
  http://auth-users:8000/health \
  http://chatbot-manager:8000/health \
  http://conversation-service:8000/health \
  http://audit-security-service:8000/health
do
  curl -fsS --max-time 5 "$target" >/dev/null
done
' >/dev/null 2>&1 \
  && pass "All internal health endpoints are reachable" \
  || fail "One or more internal health endpoints are unreachable"

if curl -fsS "http://localhost:8081/health" >/dev/null 2>&1; then
  pass "Portal web NodePort works on localhost:8081"
else
  fail "Portal web is not reachable on localhost:8081"
fi

skip "Legacy api-gateway /chat flow is excluded from the official Laravel runtime validation"

echo "E2E functional flow validation completed." | tee -a "${REPORT_FILE}"
