#!/usr/bin/env bash
# deploy-opencost.sh — Deploy OpenCost with FinOps stack
# ============================================================================
# Deploys OpenCost, cost dashboards, budgets, and alerting rules
# to the securerag-finops namespace.
# ============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
KUSTOMIZE_DIR="${REPO_ROOT}/infra/k8s/finops"
NAMESPACE="securerag-finops"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()   { echo -e "${CYAN}[$(date -u +%H:%M:%S)]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail()  { echo -e "${RED}[FATAL]${NC} $*" >&2; exit 1; }

# ── Prerequisites ────────────────────────────────────────────────────────
log "══════════════════════════════════════════════════════════════"
log "  SecureRAG Hub — OpenCost FinOps Stack Deployment"
log "══════════════════════════════════════════════════════════════"
log ""

for cmd in kubectl kustomize; do
  command -v "${cmd}" >/dev/null 2>&1 || fail "${cmd} is required. Install it first."
done

if ! kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
  kubectl create namespace "${NAMESPACE}"
  ok "Created namespace ${NAMESPACE}"
fi

# ── Deploy with Kustomize ────────────────────────────────────────────────
log "─── Deploying OpenCost FinOps resources..."
kustomize build "${KUSTOMIZE_DIR}" | kubectl apply -f -
ok "OpenCost FinOps resources applied"

# ── Wait for deployment ──────────────────────────────────────────────────
log "─── Waiting for OpenCost deployment to become ready..."
kubectl wait --for=condition=Available deployment/opencost \
  -n "${NAMESPACE}" --timeout=120s
ok "OpenCost deployment is ready"

# ── Verify OpenCost API ─────────────────────────────────────────────────
log "─── Verifying OpenCost API..."
if kubectl run curl-test --image=curlimages/curl --restart=Never \
  -n "${NAMESPACE}" --rm -- \
  -s -o /dev/null -w "%{http_code}" \
  --max-time 5 http://opencost.${NAMESPACE}.svc:9003/healthz 2>/dev/null; then
  ok "OpenCost API is healthy"
else
  warn "OpenCost health check did not return 200"
fi

# ── Summary ──────────────────────────────────────────────────────────────
log ""
log "══════════════════════════════════════════════════════════════"
ok "OpenCost FinOps stack deployed successfully"
log ""
log "Access:"
log "  OpenCost API:  kubectl -n ${NAMESPACE} port-forward svc/opencost 9003:9003"
log "  OpenCost UI:   kubectl -n ${NAMESPACE} port-forward svc/opencost 9004:9004"
log ""
log "Grafana dashboard: SecureRAG — Cost & FinOps (uid: securerag-cost)"
log "Alerting rules installed in Prometheus (securerag-monitoring)"
log "══════════════════════════════════════════════════════════════"
