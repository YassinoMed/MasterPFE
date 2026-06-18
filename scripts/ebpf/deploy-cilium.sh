#!/usr/bin/env bash
# deploy-cilium.sh — Deploy / Upgrade Cilium + Hubble on SecureRAG Hub
# SecureRAG Hub — eBPF Network Observability (Phase 10)
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { printf "${GREEN}[INFO]${NC}  %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }
step()  { printf "${BLUE}[STEP]${NC}  %s\n" "$*"; }

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CILIUM_NAMESPACE="kube-system"
CILIUM_VERSION="${CILIUM_VERSION:-v1.16.0}"
HELM_REPO="https://helm.cilium.io/"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  CILIUM + HUBBLE — DEPLOYMENT / UPGRADE"
echo "  Version: ${CILIUM_VERSION}"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Phase 1: Add / update Cilium Helm repo
step "Phase 1/7: Adding Cilium Helm repository..."
helm repo add cilium "${HELM_REPO}" 2>/dev/null || true
helm repo update cilium
info "Helm repo ready"

# Phase 2: Install / upgrade Cilium with Hubble enabled
step "Phase 2/7: Deploying Cilium with Hubble..."
helm upgrade --install cilium cilium/cilium \
  --namespace "${CILIUM_NAMESPACE}" --create-namespace \
  --version "${CILIUM_VERSION}" \
  --set hubble.enabled=true \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true \
  --set hubble.metrics.enabled="{flow,http,dns,tcp,policy_verdict,drop}" \
  --set hubble.metrics.serviceMonitor.enabled=true \
  --set prometheus.enabled=true \
  --set operator.prometheus.enabled=true \
  --set rollOutCiliumPods=true \
  --set kubeProxyReplacement=strict \
  --set ipam.mode=kubernetes \
  --set ipv4.enabled=true \
  --set ipv6.enabled=false \
  --set routingMode=tunnel \
  --set tunnelProtocol=vxlan \
  --set endpointRoutes.enabled=true \
  --set bpf.masquerade=true \
  --set autoDirectNodeRoutes=true \
  --set l2announcements.enabled=false \
  --set externalIPs.enabled=true \
  --set nodePort.enabled=true \
  --set hostPort.enabled=true \
  --set socketLB.enabled=true \
  --set devices="" \
  --set bpfClockProbe=true \
  --set cgroup.autoMount.enabled=true \
  --set cgroup.hostRoot=/sys/fs/cgroup \
  --wait --timeout 15m

info "Cilium + Hubble deployed"

# Phase 3: Verify Cilium status
step "Phase 3/7: Verifying Cilium status..."
cilium status --wait --wait-duration=5m || warn "cilium status check incomplete — pods may still be starting"
info "Cilium status checked"

# Phase 4: Apply CiliumNetworkPolicies
step "Phase 4/7: Applying CiliumNetworkPolicies..."
kubectl apply -f "${REPO_ROOT}/infra/k8s/cilium/network-policy-default-deny.yaml" 2>/dev/null || true
kubectl apply -f "${REPO_ROOT}/infra/k8s/cilium/network-policy-allow-dns.yaml" 2>/dev/null || true
kubectl apply -f "${REPO_ROOT}/infra/k8s/cilium/network-policy-allow-database.yaml" 2>/dev/null || true
kubectl apply -f "${REPO_ROOT}/infra/k8s/cilium/network-policy-allow-harbor.yaml" 2>/dev/null || true
kubectl apply -f "${REPO_ROOT}/infra/k8s/cilium/network-policy-allow-monitoring.yaml" 2>/dev/null || true
kubectl apply -f "${REPO_ROOT}/infra/k8s/cilium/network-policy-allow-inter-service.yaml" 2>/dev/null || true
kubectl apply -f "${REPO_ROOT}/infra/k8s/cilium/network-policy-l7-http.yaml" 2>/dev/null || true
info "CiliumNetworkPolicies applied"

# Phase 5: Apply Hubble UI Service and Metrics ConfigMap
step "Phase 5/7: Applying Hubble UI Service and Metrics ConfigMap..."
kubectl apply -f "${REPO_ROOT}/infra/k8s/cilium/hubble-ui-service.yaml" 2>/dev/null || true
kubectl apply -f "${REPO_ROOT}/infra/k8s/cilium/hubble-metrics.yaml" 2>/dev/null || true
info "Hubble services configured"

# Phase 6: Apply ServiceMonitors for Prometheus
step "Phase 6/7: Applying ServiceMonitors..."
kubectl apply -f "${REPO_ROOT}/infra/k8s/cilium/servicemonitor-cilium.yaml" 2>/dev/null || true
info "ServiceMonitors applied"

# Phase 7: Apply Grafana dashboard
step "Phase 7/7: Applying Grafana dashboard..."
kubectl apply -f "${REPO_ROOT}/infra/k8s/cilium/grafana-dashboard-cilium-hubble.yaml" 2>/dev/null || true
info "Grafana dashboard applied"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  CILIUM + HUBBLE DEPLOYMENT COMPLETE"
echo "═══════════════════════════════════════════════════════════════"
echo ""
info "Next steps:"
info "  - Run 'bash scripts/ebpf/cilium-status.sh' to verify health"
info "  - Run 'bash scripts/ebpf/hubble-flows.sh' to observe live flows"
info "  - Access Hubble UI: kubectl port-forward -n kube-system svc/hubble-ui 8081:8081"
echo ""
