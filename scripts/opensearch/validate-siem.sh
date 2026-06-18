#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="opensearch"
OPENSEARCH_URL="https://opensearch.${NAMESPACE}.svc:9200"
DASHBOARDS_URL="http://opensearch-dashboards.${NAMESPACE}.svc:5601"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

errors=0

echo "=== SecureRAG SIEM Validation ==="
echo ""

echo "--- OpenSearch Cluster Health ---"
health=$(kubectl exec -n "${NAMESPACE}" deploy/opensearch -- \
  curl -s -k -u admin:admin "${OPENSEARCH_URL}/_cluster/health" 2>/dev/null || echo '{"status":"UNREACHABLE"}')
status=$(echo "${health}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','UNKNOWN'))" 2>/dev/null || echo "UNKNOWN")

case "${status}" in
  green)  pass "Cluster health: ${status}" ;;
  yellow) warn "Cluster health: ${status}" ;;
  red)    fail "Cluster health: ${status}"; ((errors++)) ;;
  *)      fail "Cluster health: ${status} (unreachable)"; ((errors++)) ;;
esac

echo ""
echo "--- Indices ---"
indices=$(kubectl exec -n "${NAMESPACE}" deploy/opensearch -- \
  curl -s -k -u admin:admin "${OPENSEARCH_URL}/_cat/indices?v" 2>/dev/null || echo "UNREACHABLE")
echo "${indices}"

expected_indices=("falco-events" "tetragon-events" "trivy-reports" "k8s-audit" "kyverno-admissions" "runtime-events")
for index in "${expected_indices[@]}"; do
  if echo "${indices}" | grep -q "${index}"; then
    pass "Index ${index} exists"
  else
    warn "Index ${index} not found (may not be created yet)"
  fi
done

echo ""
echo "--- Security Events Count ---"
for index in "${expected_indices[@]}"; do
  count=$(kubectl exec -n "${NAMESPACE}" deploy/opensearch -- \
    curl -s -k -u admin:admin "${OPENSEARCH_URL}/${index}-*/_count" 2>/dev/null | \
    python3 -c "import sys,json; print(json.load(sys.stdin).get('count',0))" 2>/dev/null || echo "0")
  echo "  ${index}: ${count} documents"
done

echo ""
echo "--- ISM Policies ---"
for policy in security_events_30d runtime_events_7d; do
  if kubectl exec -n "${NAMESPACE}" deploy/opensearch -- \
    curl -s -k -u admin:admin "${OPENSEARCH_URL}/_plugins/_ism/policies/${policy}" \
    -o /dev/null -w "%{http_code}" 2>/dev/null | grep -q "200"; then
    pass "ISM policy ${policy} exists"
  else
    warn "ISM policy ${policy} not found"
  fi
done

echo ""
echo "--- Dashboards Health ---"
dash_status=$(kubectl exec -n "${NAMESPACE}" deploy/opensearch-dashboards -- \
  curl -s -o /dev/null -w "%{http_code}" "${DASHBOARDS_URL}/api/status" 2>/dev/null || echo "000")
if [ "${dash_status}" = "200" ]; then
  pass "OpenSearch Dashboards reachable (HTTP ${dash_status})"
else
  fail "OpenSearch Dashboards unreachable (HTTP ${dash_status})"
  ((errors++))
fi

echo ""
echo "--- Index Templates ---"
for template in falco-events tetragon-events trivy-reports k8s-audit kyverno-admissions runtime-events; do
  tpl_status=$(kubectl exec -n "${NAMESPACE}" deploy/opensearch -- \
    curl -s -k -u admin:admin -o /dev/null -w "%{http_code}" \
    "${OPENSEARCH_URL}/_index_template/${template}" 2>/dev/null || echo "000")
  if [ "${tpl_status}" = "200" ]; then
    pass "Index template ${template} exists"
  else
    warn "Index template ${template} not found"
  fi
done

echo ""
echo "--- ServiceMonitor ---"
if kubectl get servicemonitor -n securerag-monitoring opensearch -o name &>/dev/null; then
  pass "ServiceMonitor opensearch exists"
else
  fail "ServiceMonitor opensearch not found"
  ((errors++))
fi

echo ""
echo "========== SIEM Health Summary =========="
if [ "${errors}" -eq 0 ]; then
  echo -e "${GREEN}All checks passed. SIEM is healthy.${NC}"
  exit 0
else
  echo -e "${RED}${errors} check(s) failed. Review warnings above.${NC}"
  exit 1
fi
