#!/usr/bin/env bash
# validate-observability.sh — Check observability stack readiness
set -euo pipefail

NS_MONITORING="${NS_MONITORING:-securerag-monitoring}"
REPORT_DIR="${REPORT_DIR:-artifacts/validation}"
REPORT_FILE="${REPORT_DIR}/observability-validation.md"

mkdir -p "${REPORT_DIR}"

pass() { printf '[PASS] %s\n' "$1" | tee -a "${REPORT_FILE}"; }
warn() { printf '[WARN] %s\n' "$1" | tee -a "${REPORT_FILE}"; WARNINGS=$((WARNINGS + 1)); }
skip() { printf '[SKIP] %s\n' "$1" | tee -a "${REPORT_FILE}"; SKIPPED=$((SKIPPED + 1)); }

WARNINGS=0
SKIPPED=0

{
  printf '# Observability Validation — SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Monitoring namespace: `%s`\n\n' "${NS_MONITORING}"
} > "${REPORT_FILE}"

# Check if monitoring namespace exists
if ! kubectl get namespace "${NS_MONITORING}" > /dev/null 2>&1; then
  {
    printf '## Status: SKIPPED_OPTIONAL\n\n'
    printf 'The observability stack is **prepared but not deployed**.\n\n'
    printf '### How to deploy\n\n'
    printf '```bash\nmake observability-up\n```\n\n'
    printf 'This deploys:\n'
    printf '- Prometheus (scraping, alerting rules)\n'
    printf '- Grafana (dashboards, datasources)\n'
    printf '- Loki (log aggregation)\n'
    printf '- Alertmanager (alert routing)\n\n'
    printf '### Manifests location\n\n'
    printf '`infra/k8s/observability/`\n'
  } >> "${REPORT_FILE}"
  skip "Observability namespace ${NS_MONITORING} does not exist — stack is prepared but not deployed"
  printf '[INFO] Report: %s\n' "${REPORT_FILE}"
  exit 0
fi

echo "## Components" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"
echo "| Component | Deployment | Status | Pods Ready |" >> "${REPORT_FILE}"
echo "|---|---|---|---|" >> "${REPORT_FILE}"

components=(prometheus grafana loki alertmanager)

for component in "${components[@]}"; do
  if kubectl get deployment "${component}" -n "${NS_MONITORING}" > /dev/null 2>&1; then
    ready=$(kubectl get deployment "${component}" -n "${NS_MONITORING}" \
      -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    ready="${ready:-0}"
    desired=$(kubectl get deployment "${component}" -n "${NS_MONITORING}" \
      -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")
    if [[ "${ready}" -ge "${desired}" ]]; then
      printf '| %s | ✅ Exists | Running | %s/%s |\n' "${component}" "${ready}" "${desired}" >> "${REPORT_FILE}"
      pass "${component} is running (${ready}/${desired})"
    else
      printf '| %s | ✅ Exists | Not Ready | %s/%s |\n' "${component}" "${ready}" "${desired}" >> "${REPORT_FILE}"
      warn "${component} exists but not fully ready (${ready}/${desired})"
    fi
  else
    printf '| %s | ❌ Missing | — | — |\n' "${component}" >> "${REPORT_FILE}"
    skip "${component} deployment not found"
  fi
done

echo "" >> "${REPORT_FILE}"

# Check services
echo "## Services" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

for component in "${components[@]}"; do
  if kubectl get svc "${component}" -n "${NS_MONITORING}" > /dev/null 2>&1; then
    port=$(kubectl get svc "${component}" -n "${NS_MONITORING}" \
      -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || echo "?")
    pass "Service ${component} exposed on port ${port}"
  fi
done

echo "" >> "${REPORT_FILE}"

# Summary
{
  printf '## Summary\n\n'
  if [[ "${WARNINGS}" -eq 0 && "${SKIPPED}" -eq 0 ]]; then
    printf -- '- **Status**: `OK` — all components running\n'
  elif [[ "${SKIPPED}" -gt 0 ]]; then
    printf -- '- **Status**: `PARTIAL` — %d component(s) missing\n' "${SKIPPED}"
  else
    printf -- '- **Status**: `WARNING` — %d warning(s)\n' "${WARNINGS}"
  fi
  printf '\n## Access\n\n'
  printf '```bash\n'
  printf '# Grafana (admin / see grafana-admin Secret)\n'
  printf 'kubectl -n %s port-forward svc/grafana 3000:3000\n\n' "${NS_MONITORING}"
  printf '# Prometheus\n'
  printf 'kubectl -n %s port-forward svc/prometheus 9090:9090\n\n' "${NS_MONITORING}"
  printf '# Alertmanager\n'
  printf 'kubectl -n %s port-forward svc/alertmanager 9093:9093\n' "${NS_MONITORING}"
  printf '```\n'
} >> "${REPORT_FILE}"

printf '[INFO] Observability validation report: %s\n' "${REPORT_FILE}"
