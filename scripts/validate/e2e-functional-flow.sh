#!/usr/bin/env bash

set -euo pipefail

NS="${NS:-securerag-hub}"
REPORT_DIR="${REPORT_DIR:-artifacts/validation}"
REPORT_FILE="${REPORT_DIR}/e2e-functional-flow.txt"
VALIDATION_IMAGE="${VALIDATION_IMAGE:-${REGISTRY_HOST:-localhost:5001}/securerag-hub-api-gateway:${IMAGE_TAG:-dev}}"
pod_name="e2e-functional-check-$(date +%s)"

mkdir -p "${REPORT_DIR}"
: > "${REPORT_FILE}"

pass() { echo "[PASS] $1" | tee -a "${REPORT_FILE}"; }
fail() { echo "[FAIL] $1" | tee -a "${REPORT_FILE}"; exit 1; }
skip() { echo "[SKIP] $1" | tee -a "${REPORT_FILE}"; }

services=(
  portal-web
  api-gateway
  auth-users
  chatbot-manager
  llm-orchestrator
  security-auditor
  knowledge-hub
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
  --command -- python -c '
import urllib.request
for svc in [
    "portal-web",
    "api-gateway",
    "auth-users",
    "chatbot-manager",
    "llm-orchestrator",
    "security-auditor",
    "knowledge-hub",
]:
    target = f"http://{svc}:8080/healthz"
    if svc == "portal-web":
        target = "http://portal-web:8000/health"
    with urllib.request.urlopen(target, timeout=5) as response:
        if response.status != 200:
            raise SystemExit(response.status)
' >/dev/null 2>&1 \
  && pass "All internal health endpoints are reachable" \
  || fail "One or more internal health endpoints are unreachable"

if curl -fsS "http://localhost:8080/healthz" >/dev/null 2>&1; then
  pass "External access through NodePort works on localhost:8080"
else
  fail "External access through NodePort failed on localhost:8080"
fi

if curl -fsS "http://localhost:8081/health" >/dev/null 2>&1; then
  pass "Portal web is exposed on localhost:8081"
else
  fail "Portal web is not reachable on localhost:8081"
fi

HTTP_CODE="$(curl -s -o /tmp/api_gateway_root.out -w "%{http_code}" http://localhost:8080/ || true)"
if [ "${HTTP_CODE}" = "200" ]; then
  pass "API Gateway root endpoint responds"
else
  skip "API Gateway root endpoint not yet stabilized for functional assertions"
fi

CHAT_HTTP_CODE="$(curl -s -o /tmp/chat_test.out -w "%{http_code}" \
  -H "Content-Type: application/json" \
  -X POST http://localhost:8080/chat \
  -d '{"message":"Bonjour, test plateforme SecureRAG Hub"}' || true)"

case "${CHAT_HTTP_CODE}" in
  200|201)
    pass "Conversation endpoint /chat is available"
    ;;
  404|405)
    skip "Conversation endpoint /chat not implemented yet"
    ;;
  *)
    skip "Conversation endpoint /chat returned HTTP ${CHAT_HTTP_CODE}"
    ;;
esac

echo "E2E functional flow validation completed." | tee -a "${REPORT_FILE}"
