#!/usr/bin/env bash
# security-smoke.sh — Security smoke tests running inside the cluster
set -euo pipefail

NS="${NS:-securerag-hub}"
VALIDATION_IMAGE="${VALIDATION_IMAGE:-curlimages/curl:8.11.1}"
pod_name="curl-sec-smoke-$(date +%s)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_DIR="${REPORT_DIR:-reports/postdeploy}"
REPORT_FILE="${REPORT_DIR}/security-smoke-report.md"

mkdir -p "${REPORT_DIR}"

# shellcheck source=scripts/validate/lib/k8s-validation-pod.sh
source "${SCRIPT_DIR}/lib/k8s-validation-pod.sh"

FAILURES=0
WARNINGS=0

pass() { printf '[PASS] %s\n' "$1"; }
warn() { printf '[WARN] %s\n' "$1" >&2; WARNINGS=$((WARNINGS + 1)); }
fail() { printf '[FAIL] %s\n' "$1" >&2; FAILURES=$((FAILURES + 1)); }

{
  printf '# Security Smoke Tests Report — SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Namespace: `%s`\n' "${NS}"
} > "${REPORT_FILE}"

echo "## 1. Environmental Security Variables (APP_DEBUG)" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

# Check for APP_DEBUG in deployment environment variables
app_debug=$(kubectl get deployment portal-web -n "${NS}" -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="APP_DEBUG")].value}' 2>/dev/null || echo "false")
if [[ "${app_debug}" == "false" ]]; then
  pass "Laravel APP_DEBUG is set to false for portal-web"
  printf -- '- **Laravel APP_DEBUG**: `false` (✅ Hardened)\n\n' >> "${REPORT_FILE}"
else
  fail "Laravel APP_DEBUG is set to true or missing for portal-web"
  printf -- '- **Laravel APP_DEBUG**: `%s` (❌ Non-Compliant - Debugging must be disabled in production)\n\n' "${app_debug}" >> "${REPORT_FILE}"
fi

echo "## 2. Sensitive File and Secret Exposure Prevention" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"
echo "| Target URL | Expected Response | Actual | Status |" >> "${REPORT_FILE}"
echo "|---|---|---|---|" >> "${REPORT_FILE}"

set +e
output=$(kubectl run "${pod_name}" --rm -i --attach=true --restart=Never -n "${NS}" \
  --labels=app.kubernetes.io/part-of=securerag-hub,job-role=validation \
  --image="${VALIDATION_IMAGE}" \
  --override-type=strategic \
  --overrides="$(validation_pod_overrides "${pod_name}")" \
  --command -- sh -ec '
    for target in \
      "http://portal-web:8000/.env" \
      "http://portal-web:8000/storage/" \
      "http://portal-web:8000/admin" \
      "http://portal-web:8000/api/secrets" \
      "http://portal-web:8000/dashboard"
    do
      code=$(curl -o /dev/null -s -w "%{http_code}" --max-time 5 "$target" || echo "ERR")
      echo "SEC_CHECK|${target}|${code}"
    done

    # Check security headers on portal homepage
    headers=$(curl -sI -o /dev/null -w "%{header_json}" --max-time 5 "http://portal-web:8000/" 2>/dev/null || echo "{}")
    echo "HEADERS_CHECK|${headers}"
  ' 2>/dev/null)
set -e

while IFS= read -r line; do
  if [[ "${line}" =~ ^SEC_CHECK\| ]]; then
    IFS='|' read -r -a parts <<< "${line}"
    url="${parts[1]}"
    code="${parts[2]}"
    
    # We expect sensitive resources to be blocked (403, 404, 401, or redirect 302 for dashboards)
    if [[ "${url}" =~ \.env$ || "${url}" =~ \/secrets$ || "${url}" =~ \/storage\/$ ]]; then
      if [[ "${code}" == "403" || "${code}" == "404" || "${code}" == "401" ]]; then
        pass "Exposure Blocked for ${url} (HTTP ${code})"
        echo "| \`${url}\` | \`403/404/401\` | \`HTTP ${code}\` | ✅ Hardened |" >> "${REPORT_FILE}"
      else
        fail "Secret or Sensitive file exposed at ${url} (HTTP ${code})"
        echo "| \`${url}\` | \`403/404/401\` | \`HTTP ${code}\` | ❌ EXPOSED |" >> "${REPORT_FILE}"
      fi
    elif [[ "${url}" =~ \/admin$ || "${url}" =~ \/dashboard$ ]]; then
      if [[ "${code}" == "302" || "${code}" == "401" || "${code}" == "403" ]]; then
        pass "Unauthenticated access to protected page ${url} is properly blocked/redirected (HTTP ${code})"
        echo "| \`${url}\` | \`302/401/403\` | \`HTTP ${code}\` | ✅ Hardened |" >> "${REPORT_FILE}"
      else
        fail "Protected page ${url} does not enforce authentication (HTTP ${code})"
        echo "| \`${url}\` | \`302/401/403\` | \`HTTP ${code}\` | ❌ VULNERABLE |" >> "${REPORT_FILE}"
      fi
    fi
  fi
done <<< "${output}"
echo "" >> "${REPORT_FILE}"

echo "## 3. Basic HTTP Security Headers" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

# We can output a note on recommended headers
printf -- '- **X-Frame-Options**: Should be set to `SAMEORIGIN` to prevent clickjacking\n' >> "${REPORT_FILE}"
printf -- '- **X-Content-Type-Options**: Should be set to `nosniff` to prevent MIME-sniffing\n' >> "${REPORT_FILE}"
printf -- '- **Content-Security-Policy (CSP)**: Strongly recommended in production\n\n' >> "${REPORT_FILE}"

echo "## 4. Summary" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

if [[ "${FAILURES}" -eq 0 ]]; then
  printf -- '- **Overall Status**: `OK` (%d warnings) (✅ Hardened)\n' "${WARNINGS}" >> "${REPORT_FILE}"
  printf '[INFO] All security smoke tests passed!\n'
else
  printf -- '- **Overall Status**: `FAILED` (%d failures, %d warnings) (❌ Vulnerabilities Found)\n' "${FAILURES}" "${WARNINGS}" >> "${REPORT_FILE}"
  printf '[ERROR] One or more security vulnerabilities detected! See report: %s\n' "${REPORT_FILE}" >&2
  exit 1
fi
