#!/usr/bin/env bash
# opencost-status.sh — Check OpenCost health and data
# ============================================================================
# Reports on OpenCost deployment health, API availability, Prometheus
# connectivity, and cost data freshness.
# ============================================================================

set -euo pipefail

NAMESPACE="${NAMESPACE:-securerag-finops}"
OPENCOST_SVC="${OPENCOST_SVC:-opencost.${NAMESPACE}.svc}"
OPENCOST_PORT="${OPENCOST_PORT:-9003}"
REPORT_DIR="${REPORT_DIR:-artifacts/finops}"
REPORT_FILE="${REPORT_DIR}/opencost-status.md"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PASS=0
WARN=0
FAIL=0
SKIP=0

pass() { printf '  %s[PASS]%s %s\n' "${GREEN}" "${NC}" "$1"; PASS=$((PASS + 1)); }
warn() { printf '  %s[WARN]%s %s\n' "${YELLOW}" "${NC}" "$1"; WARN=$((WARN + 1)); }
fail() { printf '  %s[FAIL]%s %s\n' "${RED}" "${NC}" "$1"; FAIL=$((FAIL + 1)); }
skip() { printf '  %s[SKIP]%s %s\n' "${CYAN}" "${NC}" "$1"; SKIP=$((SKIP + 1)); }

mkdir -p "${REPORT_DIR}"

# ── Header ────────────────────────────────────────────────────────────────
{
  printf '# OpenCost Status — SecureRAG Hub\n\n'
  printf -- '- **Generated at UTC**: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- **Namespace**: `%s`\n\n' "${NAMESPACE}"
  printf '## Health Checks\n\n'
  printf '| Check | Status |\n' 
  printf '|---|---|\n'
} > "${REPORT_FILE}"

# ── 1. Namespace exists ──────────────────────────────────────────────────
if kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
  printf '| Namespace %s | ✅ Exists |\n' "${NAMESPACE}" >> "${REPORT_FILE}"
  pass "Namespace ${NAMESPACE} exists"
else
  printf '| Namespace %s | ❌ Not found |\n' "${NAMESPACE}" >> "${REPORT_FILE}"
  fail "Namespace ${NAMESPACE} not found"
  skip "Remaining checks skipped — namespace missing"
  echo "" >> "${REPORT_FILE}"
  printf '## Summary\n\n' >> "${REPORT_FILE}"
  printf -- '- PASS: %d | WARN: %d | FAIL: %d | SKIP: %d\n' "${PASS}" "${WARN}" "${FAIL}" "${SKIP}" >> "${REPORT_FILE}"
  exit 1
fi

# ── 2. OpenCost deployment ────────────────────────────────────────────────
if kubectl get deployment opencost -n "${NAMESPACE}" >/dev/null 2>&1; then
  READY=$(kubectl get deployment opencost -n "${NAMESPACE}" \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  DESIRED=$(kubectl get deployment opencost -n "${NAMESPACE}" \
    -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")
  if [[ "${READY:-0}" -ge "${DESIRED:-1}" ]]; then
    printf '| OpenCost deployment | ✅ Ready (%s/%s) |\n' "${READY}" "${DESIRED}" >> "${REPORT_FILE}"
    pass "OpenCost deployment ready (${READY}/${DESIRED})"
  else
    printf '| OpenCost deployment | ⚠️ Not ready (%s/%s) |\n' "${READY:-0}" "${DESIRED:-1}" >> "${REPORT_FILE}"
    warn "OpenCost deployment not fully ready (${READY:-0}/${DESIRED:-1})"
  fi
else
  printf '| OpenCost deployment | ❌ Missing |\n' >> "${REPORT_FILE}"
  fail "OpenCost deployment not found"
fi

# ── 3. Service exists ────────────────────────────────────────────────────
if kubectl get service opencost -n "${NAMESPACE}" >/dev/null 2>&1; then
  API_PORT=$(kubectl get service opencost -n "${NAMESPACE}" \
    -o jsonpath='{.spec.ports[?(@.name=="api")].port}' 2>/dev/null || echo "?")
  UI_PORT=$(kubectl get service opencost -n "${NAMESPACE}" \
    -o jsonpath='{.spec.ports[?(@.name=="ui")].port}' 2>/dev/null || echo "?")
  printf '| OpenCost service | ✅ API:%s UI:%s |\n' "${API_PORT}" "${UI_PORT}" >> "${REPORT_FILE}"
  pass "OpenCost service exposed (API:${API_PORT}, UI:${UI_PORT})"
else
  printf '| OpenCost service | ❌ Missing |\n' >> "${REPORT_FILE}"
  fail "OpenCost service not found"
fi

# ── 4. ServiceMonitor exists ─────────────────────────────────────────────
if kubectl get servicemonitor servicemonitor-opencost -n securerag-monitoring >/dev/null 2>&1; then
  printf '| ServiceMonitor | ✅ Present |\n' >> "${REPORT_FILE}"
  pass "ServiceMonitor configured for OpenCost"
else
  printf '| ServiceMonitor | ⚠️ Not found |\n' >> "${REPORT_FILE}"
  warn "ServiceMonitor not found in securerag-monitoring"
fi

# ── 5. PrometheusRule exists ─────────────────────────────────────────────
if kubectl get prometheusrule finops-alerts -n securerag-monitoring >/dev/null 2>&1; then
  printf '| PrometheusRule | ✅ Present |\n' >> "${REPORT_FILE}"
  pass "PrometheusRule finops-alerts installed"
else
  printf '| PrometheusRule | ⚠️ Not found |\n' >> "${REPORT_FILE}"
  warn "PrometheusRule finops-alerts not found"
fi

# ── 6. Cost budgets ConfigMap ────────────────────────────────────────────
if kubectl get configmap cost-budgets -n "${NAMESPACE}" >/dev/null 2>&1; then
  BUDGET_COUNT=$(kubectl get configmap cost-budgets -n "${NAMESPACE}" \
    -o jsonpath='{.data.budgets\.yaml}' 2>/dev/null | grep -c "budget:" || echo "0")
  printf '| Cost budgets | ✅ %d budgets defined |\n' "${BUDGET_COUNT}" >> "${REPORT_FILE}"
  pass "Cost budgets ConfigMap with ${BUDGET_COUNT} budgets"
else
  printf '| Cost budgets | ❌ Missing |\n' >> "${REPORT_FILE}"
  fail "Cost budgets ConfigMap not found"
fi

# ── 7. Grafana dashboard ConfigMap ───────────────────────────────────────
if kubectl get configmap grafana-dashboard-cost -n securerag-monitoring >/dev/null 2>&1; then
  printf '| Grafana dashboard | ✅ Present |\n' >> "${REPORT_FILE}"
  pass "Cost dashboard ConfigMap installed in securerag-monitoring"
else
  printf '| Grafana dashboard | ⚠️ Not found |\n' >> "${REPORT_FILE}"
  warn "Cost dashboard ConfigMap not found in securerag-monitoring"
fi

# ── 8. API health check ──────────────────────────────────────────────────
echo "" >> "${REPORT_FILE}"
printf '## API & Data\n\n' >> "${REPORT_FILE}"
printf '| Check | Result |\n' >> "${REPORT_FILE}"
printf '|---|---|\n' >> "${REPORT_FILE}"

API_HEALTH=$(kubectl run curl-finops --image=curlimages/curl:latest \
  --restart=Never -n "${NAMESPACE}" --rm -- \
  -s -o /dev/null -w "%{http_code}" \
  --max-time 5 "http://${OPENCOST_SVC}:${OPENCOST_PORT}/healthz" 2>/dev/null || echo "000")

if [[ "${API_HEALTH}" == "200" ]]; then
  printf '| API /healthz | ✅ %s |\n' "${API_HEALTH}" >> "${REPORT_FILE}"
  pass "OpenCost API health check returned 200"
else
  printf '| API /healthz | ❌ %s |\n' "${API_HEALTH}" >> "${REPORT_FILE}"
  fail "OpenCost API health check returned ${API_HEALTH}"
fi

PROMS_CHECK=$(kubectl run curl-finops --image=curlimages/curl:latest \
  --restart=Never -n "${NAMESPACE}" --rm -- \
  -s -o /dev/null -w "%{http_code}" \
  --max-time 5 "http://${OPENCOST_SVC}:${OPENCOST_PORT}/prometheusStatus" 2>/dev/null || echo "000")

if [[ "${PROMS_CHECK}" == "200" ]]; then
  printf '| Prometheus connection | ✅ Connected |\n' >> "${REPORT_FILE}"
  pass "OpenCost connected to Prometheus"
else
  printf '| Prometheus connection | ⚠️ HTTP %s |\n' "${PROMS_CHECK}" >> "${REPORT_FILE}"
  warn "OpenCost Prometheus connection check returned ${PROMS_CHECK}"
fi

# ── 9. Cost data availability ─────────────────────────────────────────────
TOTAL_COST_RAW=$(kubectl run curl-finops --image=curlimages/curl:latest \
  --restart=Never -n "${NAMESPACE}" --rm -- \
  -s --max-time 10 "http://${OPENCOST_SVC}:${OPENCOST_PORT}/allCost/model?window=1h" 2>/dev/null || echo "{}")

TOTAL_COST=$(echo "${TOTAL_COST_RAW}" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('totalCost', 0))
except:
    print('error')
" 2>/dev/null || echo "error")

if [[ "${TOTAL_COST}" != "error" ]] && [[ "${TOTAL_COST}" != "0" ]]; then
  printf '| Cost data (1h) | ✅ $%.2f |\n' "${TOTAL_COST}" >> "${REPORT_FILE}"
  pass "Cost data available (1h total: \$${TOTAL_COST})"
else
  printf '| Cost data (1h) | ⚠️ Unavailable or zero |\n' >> "${REPORT_FILE}"
  warn "No cost data in last hour"
fi

# ── Summary ──────────────────────────────────────────────────────────────
{
  echo ""
  printf '## Summary\n\n'
  printf -- '- **PASS**: %d\n' "${PASS}"
  printf -- '- **WARN**: %d\n' "${WARN}"
  printf -- '- **FAIL**: %d\n' "${FAIL}"
  printf -- '- **SKIP**: %d\n' "${SKIP}"
  echo ""
  if [[ "${FAIL}" -eq 0 && "${WARN}" -eq 0 ]]; then
    printf '**Overall**: ✅ All checks passed\n'
  elif [[ "${FAIL}" -gt 0 ]]; then
    printf '**Overall**: ❌ %d failure(s) detected\n' "${FAIL}"
  else
    printf '**Overall**: ⚠️ %d warning(s) — review recommended\n' "${WARN}"
  fi
  printf '\n---\n_Generated by opencost-status.sh_\n'
} >> "${REPORT_FILE}"

# ── Output ───────────────────────────────────────────────────────────────
printf '\n%s[RESULTS] PASS=%d  WARN=%d  FAIL=%d  SKIP=%d%s\n' \
  "${GREEN}" "${PASS}" "${WARN}" "${FAIL}" "${SKIP}" "${NC}"
printf '%s[INFO] Status report: %s%s\n' "${CYAN}" "${REPORT_FILE}" "${NC}"

exit $((FAIL > 0 ? 1 : 0))
