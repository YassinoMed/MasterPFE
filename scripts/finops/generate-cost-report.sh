#!/usr/bin/env bash
# generate-cost-report.sh — Query OpenCost API and generate cost report
# ============================================================================
# Generates a markdown cost report by querying the OpenCost API for
# namespace-level costs, cluster totals, and idle resource costs.
# ============================================================================

set -euo pipefail

NAMESPACE="${NAMESPACE:-securerag-finops}"
OPENCOST_SVC="${OPENCOST_SVC:-opencost.${NAMESPACE}.svc}"
OPENCOST_PORT="${OPENCOST_PORT:-9003}"
REPORT_DIR="${REPORT_DIR:-artifacts/finops}"
REPORT_FILE="${REPORT_DIR}/cost-report-$(date -u +%Y%m%d-%H%M%S).md"

CURL_OPTS="-s --max-time 10"

PASS=0
WARN=0
FAIL=0

pass() { printf '[PASS] %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '[FAIL] %s\n' "$1"; FAIL=$((FAIL + 1)); }
warn() { printf '[WARN] %s\n' "$1"; WARN=$((WARN + 1)); }

mkdir -p "${REPORT_DIR}"

# ── Check prerequisites ──────────────────────────────────────────────────
if ! command -v kubectl &>/dev/null; then
  echo "[FATAL] kubectl is required"
  exit 1
fi

if ! kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
  echo "[SKIP] Namespace ${NAMESPACE} not found — OpenCost not deployed"
  {
    printf "# Cost Report — SecureRAG Hub\n\n"
    printf "**Status**: OpenCost not deployed\n\n"
    printf "Deploy with: \`bash scripts/finops/deploy-opencost.sh\`\n"
    printf "\n---\n_Generated at UTC: %s_\n" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  } > "${REPORT_FILE}"
  echo "[INFO] Report written to ${REPORT_FILE}"
  exit 0
fi

# ── Helper: query OpenCost API ───────────────────────────────────────────
query_opencost() {
  local endpoint="$1"
  kubectl run curl-finops --image=curlimages/curl:latest --restart=Never \
    -n "${NAMESPACE}" --rm -- \
    ${CURL_OPTS} "http://${OPENCOST_SVC}:${OPENCOST_PORT}${endpoint}" 2>/dev/null || echo '{}'
}

# ── Build report ─────────────────────────────────────────────────────────
{
  printf '# Cost Report — SecureRAG Hub\n\n'
  printf -- '- **Generated at UTC**: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')'
  printf -- '- **Namespace**: `%s`\n\n' "${NAMESPACE}"
} > "${REPORT_FILE}"

# ── 1. Cluster Total Cost ────────────────────────────────────────────────
log() { echo "[INFO] $*"; }
log "Fetching cluster total cost..."
CLUSTER_COST=$(query_opencost "/allCost/model?window=1d")
printf '## 1. Cluster Overview\n\n' >> "${REPORT_FILE}"
printf '| Metric | Value |\n' >> "${REPORT_FILE}"
printf '|---|---|\n' >> "${REPORT_FILE}"
printf '| Total Cluster Cost (24h) | `%s` |\n' "$(echo "${CLUSTER_COST}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('totalCost','N/A'))" 2>/dev/null || echo 'N/A')" >> "${REPORT_FILE}"
printf '| CPU Cost (24h) | `%s` |\n' "$(echo "${CLUSTER_COST}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('cpuCost','N/A'))" 2>/dev/null || echo 'N/A')" >> "${REPORT_FILE}"
printf '| Memory Cost (24h) | `%s` |\n' "$(echo "${CLUSTER_COST}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('memoryCost','N/A'))" 2>/dev/null || echo 'N/A')" >> "${REPORT_FILE}"
printf '| GPU Cost (24h) | `%s` |\n' "$(echo "${CLUSTER_COST}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('gpuCost','N/A'))" 2>/dev/null || echo 'N/A')" >> "${REPORT_FILE}"
printf '| Network Cost (24h) | `%s` |\n' "$(echo "${CLUSTER_COST}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('networkCost','N/A'))" 2>/dev/null || echo 'N/A')" >> "${REPORT_FILE}"
printf '| Idle Cost (24h) | `%s` |\n' "$(echo "${CLUSTER_COST}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('idleCost','N/A'))" 2>/dev/null || echo 'N/A')" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

if [ "$(echo "${CLUSTER_COST}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('totalCost',0))" 2>/dev/null || echo '0')" != "0" ]; then
  pass "Cluster total cost data retrieved"
else
  warn "Cluster total cost is zero or unavailable"
fi

# ── 2. Cost by Namespace ─────────────────────────────────────────────────
log "Fetching cost by namespace..."
NAMESPACE_COST=$(query_opencost "/allCost/model?window=30d&aggregate=namespace")
printf '## 2. Cost by Namespace (30d)\n\n' >> "${REPORT_FILE}"
printf '| Namespace | Cost |\n' >> "${REPORT_FILE}"
printf '|---|---|\n' >> "${REPORT_FILE}"

echo "${NAMESPACE_COST}" | python3 -c "
import sys, json
d = json.load(sys.stdin)
costs = d.get('data', [])
costs.sort(key=lambda x: x.get('totalCost', 0), reverse=True)
for c in costs:
    ns = c.get('name', 'unknown')
    cost = c.get('totalCost', 0)
    print(f'| {ns} | \${cost:.2f} |')
" 2>/dev/null >> "${REPORT_FILE}" || warn "Failed to parse namespace cost data"
echo "" >> "${REPORT_FILE}"

# ── 3. Budget vs Actual ──────────────────────────────────────────────────
printf '## 3. Budget vs Actual\n\n' >> "${REPORT_FILE}"
printf '| Namespace | Budget | Actual | Remaining | Status |\n' >> "${REPORT_FILE}"
printf '|---|---|---|---|---|\n' >> "${REPORT_FILE}"

# Read budgets from ConfigMap
BUDGETS=$(kubectl get configmap cost-budgets -n "${NAMESPACE}" \
  -o jsonpath='{.data.budgets\.yaml}' 2>/dev/null || echo "")

if [ -n "${BUDGETS}" ]; then
  echo "${BUDGETS}" | python3 -c "
import sys, yaml, json
budgets = yaml.safe_load(sys.stdin)
ns_data = {}
echo_output = ''
for ns, info in budgets.get('namespaces', {}).items():
    ns_data[ns] = info.get('budget', 0)
actual_data = json.loads('''$(echo "${NAMESPACE_COST}" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin).get('data',[])))" 2>/dev/null || echo '[]')''')
actual_map = {c.get('name'): c.get('totalCost', 0) for c in actual_data}
for ns, budget in sorted(ns_data.items()):
    actual = actual_map.get(ns, 0)
    remaining = budget - actual
    pct = (actual / budget * 100) if budget > 0 else 0
    status = 'OVER BUDGET' if remaining < 0 else ('WARNING' if pct > 80 else 'OK')
    print(f'| {ns} | \${budget:.2f} | \${actual:.2f} | \${remaining:.2f} | {status} |')
" 2>/dev/null >> "${REPORT_FILE}" || warn "Failed to compute budget vs actual"
else
  printf '| — | — | — | — | Budget ConfigMap not found |\n' >> "${REPORT_FILE}"
  warn "cost-budgets ConfigMap not found in namespace ${NAMESPACE}"
fi
echo "" >> "${REPORT_FILE}"

# ── 4. Summary ────────────────────────────────────────────────────────────
{
  printf '## Summary\n\n'
  printf -- '- **Total cost (24h)**: %s\n' "$(echo "${CLUSTER_COST}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'\${d.get(\"totalCost\",0):.2f}')" 2>/dev/null || echo 'N/A')"
  printf -- '- **Namespaces tracked**: %d\n' "$(echo "${NAMESPACE_COST}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('data',[])))" 2>/dev/null || echo '0')"
  printf -- '- **Report generated**: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf '\n---\n_Generated by generate-cost-report.sh_\n'
} >> "${REPORT_FILE}"

# ── Results ──────────────────────────────────────────────────────────────
printf '\n[RESULTS] PASS=%d  WARN=%d  FAIL=%d\n' "${PASS}" "${WARN}" "${FAIL}"
printf '[INFO] Cost report: %s\n' "${REPORT_FILE}"
exit $((FAIL > 0 ? 1 : 0))
