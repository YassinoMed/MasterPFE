#!/usr/bin/env bash
# deploy-istio.sh — SecureRAG Hub
# Deploy Istio Operator + all mesh configs for Phase 6: Service Mesh
#
# Usage:
#   bash scripts/mesh/deploy-istio.sh
#
# Prerequisites:
#   - kubectl configured to the target cluster
#   - istioctl installed (or downloaded by this script)
#   - Prometheus operator stack deployed (for ServiceMonitors)

set -euo pipefail

ISTIO_VERSION="${ISTIO_VERSION:-1.22.0}"
ISTIO_NAMESPACE="${ISTIO_NAMESPACE:-istio-system}"
MESH_NAMESPACE="${MESH_NAMESPACE:-securerag-hub}"
MONITORING_NAMESPACE="${MONITORING_NAMESPACE:-securerag-monitoring}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
LOG_FILE="/tmp/istio-deploy-${TIMESTAMP}.log"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { printf "${GREEN}[INFO]${NC}  %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$*" >&2; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }
step()  { printf "\n${CYAN}═══════════════════════════════════════════════════════════════${NC}\n${CYAN}  %s${NC}\n${CYAN}═══════════════════════════════════════════════════════════════${NC}\n" "$*"; }

cleanup() {
  local exit_code=$?
  if [ $exit_code -ne 0 ]; then
    error "Deployment failed at step ${CURRENT_STEP:-unknown}. Check ${LOG_FILE}"
  fi
  info "Deploy log: ${LOG_FILE}"
}
trap cleanup EXIT

command -v kubectl >/dev/null 2>&1 || { error "kubectl is required"; exit 1; }

# ── 1. Ensure istioctl ─────────────────────────────────────────────
step "1/7 — Ensuring istioctl CLI"
if ! command -v istioctl >/dev/null 2>&1; then
  info "istioctl not found — downloading v${ISTIO_VERSION}..."
  curl -sL "https://istio.io/downloadIstioctl" | ISTIO_VERSION=${ISTIO_VERSION} sh -
  export PATH="${HOME}/.istioctl/bin:${PATH}"
fi
istioctl version --remote=false 2>/dev/null | head -1 || true

# ── 2. Create istio-system namespace ───────────────────────────────
step "2/7 — Creating namespace ${ISTIO_NAMESPACE}"
kubectl create namespace "${ISTIO_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace "${ISTIO_NAMESPACE}" \
  pod-security.kubernetes.io/enforce=privileged \
  pod-security.kubernetes.io/audit=privileged \
  --overwrite 2>/dev/null || true

# ── 3. Install Istio via operator ──────────────────────────────────
step "3/7 — Installing Istio control plane via IstioOperator"
istioctl install -f "${REPO_ROOT}/infra/k8s/istio/operator.yaml" \
  --skip-confirmation \
  --verify \
  2>&1 | tee -a "${LOG_FILE}"

info "Waiting for Istio control plane pods..."
kubectl wait --for=condition=Ready pods -l app=istiod -n "${ISTIO_NAMESPACE}" --timeout=300s 2>&1 | tee -a "${LOG_FILE}"
kubectl wait --for=condition=Ready pods -l app=istio-ingressgateway -n "${ISTIO_NAMESPACE}" --timeout=300s 2>&1 | tee -a "${LOG_FILE}"

# ── 4. Label the mesh namespace for auto-injection ─────────────────
step "4/7 — Labeling ${MESH_NAMESPACE} for sidecar injection"
kubectl label namespace "${MESH_NAMESPACE}" istio-injection=enabled --overwrite 2>&1 | tee -a "${LOG_FILE}"

# ── 5. Apply mesh config resources ─────────────────────────────────
step "5/7 — Applying mesh configuration resources (PeerAuthentication, DestinationRules, etc.)"
CURRENT_STEP="apply-mesh-resources"

kubectl apply -f "${REPO_ROOT}/infra/k8s/istio/peer-authentication.yaml" 2>&1 | tee -a "${LOG_FILE}"
kubectl apply -f "${REPO_ROOT}/infra/k8s/istio/destination-rules.yaml" 2>&1 | tee -a "${LOG_FILE}"
kubectl apply -f "${REPO_ROOT}/infra/k8s/istio/virtual-services.yaml" 2>&1 | tee -a "${LOG_FILE}"
kubectl apply -f "${REPO_ROOT}/infra/k8s/istio/service-entries.yaml" 2>&1 | tee -a "${LOG_FILE}"
kubectl apply -f "${REPO_ROOT}/infra/k8s/istio/authorization-policies.yaml" 2>&1 | tee -a "${LOG_FILE}"
kubectl apply -f "${REPO_ROOT}/infra/k8s/istio/ingress-gateway.yaml" 2>&1 | tee -a "${LOG_FILE}"
kubectl apply -f "${REPO_ROOT}/infra/k8s/istio/telemetry.yaml" 2>&1 | tee -a "${LOG_FILE}"

# ── 6. Deploy Kiali ────────────────────────────────────────────────
step "6/7 — Deploying Kiali visualization"
CURRENT_STEP="deploy-kiali"
kubectl apply -f "${REPO_ROOT}/infra/k8s/istio/kiali.yaml" 2>&1 | tee -a "${LOG_FILE}"
kubectl wait --for=condition=Ready pods -l app=kiali -n "${ISTIO_NAMESPACE}" --timeout=180s 2>&1 | tee -a "${LOG_FILE}"

# ── 7. Apply monitoring resources ──────────────────────────────────
step "7/7 — Applying ServiceMonitors for Istio telemetry"
CURRENT_STEP="apply-monitoring"
if kubectl get namespace "${MONITORING_NAMESPACE}" >/dev/null 2>&1; then
  kubectl apply -k "${REPO_ROOT}/infra/k8s/istio/monitoring" 2>&1 | tee -a "${LOG_FILE}"
else
  warn "Monitoring namespace ${MONITORING_NAMESPACE} not found — skipping ServiceMonitor deployment"
  warn "Deploy the monitoring stack first or apply manually:"
  warn "  kubectl apply -f infra/k8s/istio/monitoring/servicemonitor-istio.yaml"
fi

# ── Verification ───────────────────────────────────────────────────
step "Verification"
CURRENT_STEP="verify"
echo ""
echo "  Istio components:"
kubectl get pods -n "${ISTIO_NAMESPACE}" 2>&1 | tee -a "${LOG_FILE}"
echo ""
echo "  Mesh resources:"
kubectl get peerauthentication,destinationrule,virtualservice,serviceentry,authorizationpolicy,gateway,telemetry -n "${MESH_NAMESPACE}" 2>&1 | tee -a "${LOG_FILE}"
echo ""
echo "  Sidecar injection (namespace label):"
kubectl get namespace "${MESH_NAMESPACE}" -o jsonpath='{.metadata.labels.istio-injection}' 2>&1 | tee -a "${LOG_FILE}"
echo ""

info "Istio service mesh deployment complete!"
info "Kiali: kubectl port-forward -n ${ISTIO_NAMESPACE} svc/kiali 20001:20001"
info "       → http://localhost:20001/kiali"
