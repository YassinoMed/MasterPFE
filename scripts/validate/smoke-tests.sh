#!/usr/bin/env bash
# smoke-tests.sh — Application smoke tests running inside the cluster
set -euo pipefail

NS="${NS:-securerag-hub}"
VALIDATION_IMAGE="${VALIDATION_IMAGE:-curlimages/curl:8.11.1}"
pod_name="curl-smoke-$(date +%s)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_DIR="${REPORT_DIR:-reports/postdeploy}"
REPORT_FILE="${REPORT_DIR}/smoke-tests-report.md"

mkdir -p "${REPORT_DIR}"

# shellcheck source=scripts/validate/lib/k8s-validation-pod.sh
source "${SCRIPT_DIR}/lib/k8s-validation-pod.sh"

FAILURES=0

pass() { printf '[PASS] %s\n' "$1"; }
fail() { printf '[FAIL] %s\n' "$1" >&2; FAILURES=$((FAILURES + 1)); }

{
  printf '# Application Smoke Tests Report — SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Namespace: `%s`\n' "${NS}"
} > "${REPORT_FILE}"

echo "## 1. Workload Rollout Status Check" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

services=(
  portal-web
  auth-users
  chatbot-manager
  conversation-service
  audit-security-service
)

for service in "${services[@]}"; do
  if kubectl rollout status "deployment/${service}" -n "${NS}" --timeout=60s >/dev/null 2>&1; then
    pass "Deployment ${service} is fully rolled out"
    printf -- '- **%s**: `Active` (✅ Rollout OK)\n' "${service}" >> "${REPORT_FILE}"
  else
    fail "Deployment ${service} failed rollout status check"
    printf -- '- **%s**: `Unavailable` (❌ Rollout FAILED)\n' "${service}" >> "${REPORT_FILE}"
  fi
done
echo "" >> "${REPORT_FILE}"

echo "## 2. HTTP Connectivity and Route Verification" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"
echo "| Route URL | Expected | Result | Status |" >> "${REPORT_FILE}"
echo "|---|---|---|---|" >> "${REPORT_FILE}"

# Run curl commands from inside the validation pod to check connectivity
set +e
output=$(kubectl run "${pod_name}" --rm -i --attach=true --restart=Never -n "${NS}" \
  --labels=app.kubernetes.io/part-of=securerag-hub,job-role=validation \
  --image="${VALIDATION_IMAGE}" \
  --override-type=strategic \
  --overrides="$(validation_pod_overrides "${pod_name}")" \
  --command -- sh -ec '
    for route in \
      "http://portal-web:8000/health" \
      "http://portal-web:8000/" \
      "http://auth-users:8000/health" \
      "http://chatbot-manager:8000/health" \
      "http://conversation-service:8000/health" \
      "http://audit-security-service:8000/health"
    do
      code=$(curl -o /dev/null -s -w "%{http_code}" --max-time 5 "$route" || echo "ERR")
      echo "ROUTE_CHECK|${route}|${code}"
    done
  ' 2>/dev/null)
set -e

# Parse curl results and print them in the report
while IFS= read -r line; do
  if [[ "${line}" =~ ^ROUTE_CHECK\| ]]; then
    IFS='|' read -r -a parts <<< "${line}"
    route="${parts[1]}"
    code="${parts[2]}"
    
    if [[ "${code}" =~ ^2[0-9][0-9]$ || "${code}" == "302" ]]; then
      pass "Route ${route} returned HTTP ${code}"
      echo "| \`${route}\` | \`200/302\` | \`HTTP ${code}\` | ✅ OK |" >> "${REPORT_FILE}"
    else
      fail "Route ${route} returned error or invalid HTTP code: ${code}"
      echo "| \`${route}\` | \`200/302\` | \`HTTP ${code}\` | ❌ FAILED |" >> "${REPORT_FILE}"
    fi
  fi
done <<< "${output}"
echo "" >> "${REPORT_FILE}"

echo "## 3. Summary" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"
if [[ "${FAILURES}" -eq 0 ]]; then
  printf -- '- **Overall Status**: `OK` (✅ Compliant)\n' >> "${REPORT_FILE}"
  printf '[INFO] All application smoke tests passed!\n'
else
  printf -- '- **Overall Status**: `FAILED` (%d errors) (❌ Non-Compliant)\n' "${FAILURES}" >> "${REPORT_FILE}"
  printf '[ERROR] One or more smoke tests failed. See report: %s\n' "${REPORT_FILE}" >&2
  exit 1
fi
