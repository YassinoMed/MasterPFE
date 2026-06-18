#!/usr/bin/env bash
# cilium-status.sh — Check Cilium + Hubble Status (Connectivity, Policies, Service Map)
# SecureRAG Hub — eBPF Network Observability (Phase 10)
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { printf "${GREEN}[INFO]${NC}  %s\n" "$*"; }
warn()    { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
error()   { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }
step()    { printf "${BLUE}[STEP]${NC}  %s\n" "$*"; }
success() { printf "${GREEN}[PASS]${NC}  %s\n" "$*"; }
fail()    { printf "${RED}[FAIL]${NC}  %s\n" "$*"; }

CILIUM_NAMESPACE="kube-system"
CILIUM_POD=""

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  CILIUM + HUBBLE — STATUS CHECK"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Section 1: Cilium Pod Status
step "Section 1/7: Cilium DaemonSet Status..."
DAEMONSET_READY=$(kubectl get daemonset cilium -n "${CILIUM_NAMESPACE}" -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
DAEMONSET_DESIRED=$(kubectl get daemonset cilium -n "${CILIUM_NAMESPACE}" -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo "0")
info "Cilium agent pods: ${DAEMONSET_READY}/${DAEMONSET_DESIRED} ready"

if [ "${DAEMONSET_READY}" -gt 0 ] && [ "${DAEMONSET_READY}" -eq "${DAEMONSET_DESIRED}" ] 2>/dev/null; then
  success "All Cilium agent pods are running"
  CILIUM_POD=$(kubectl get pods -n "${CILIUM_NAMESPACE}" -l app.kubernetes.io/name=cilium -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
else
  fail "Cilium DaemonSet not fully ready"
  warn "Expected ${DAEMONSET_DESIRED}, got ${DAEMONSET_READY} ready"
fi

# Section 2: Hubble Components
echo ""
step "Section 2/7: Hubble Components Status..."
for component in "hubble-relay" "hubble-ui"; do
  DEPLOY_READY=$(kubectl get deployment "${component}" -n "${CILIUM_NAMESPACE}" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  if [ "${DEPLOY_READY}" -gt 0 ] 2>/dev/null; then
    success "${component}: ready (${DEPLOY_READY} replicas)"
  else
    fail "${component}: not ready"
  fi
done

# Section 3: Cilium Network Policies
echo ""
step "Section 3/7: CiliumNetworkPolicy Status..."
POLICIES=$(kubectl get ciliumnetworkpolicies -n securerag-hub -o name 2>/dev/null || true)
if [ -n "${POLICIES}" ]; then
  success "CiliumNetworkPolicies found in securerag-hub:"
  for p in ${POLICIES}; do
    POL_NAME=$(echo "${p}" | cut -d/ -f2)
    POL_STATUS=$(kubectl get "${p}" -o jsonpath='{.metadata.name}' 2>/dev/null || "unknown")
    info "  ✓ ${POL_NAME}"
  done
else
  warn "No CiliumNetworkPolicies found in securerag-hub namespace"
fi

# Section 4: Cilium Status (via cilium CLI)
echo ""
step "Section 4/7: Cilium Agent Status..."
if command -v cilium &>/dev/null; then
  if [ -n "${CILIUM_POD}" ]; then
    kubectl exec -n "${CILIUM_NAMESPACE}" "${CILIUM_POD}" -- cilium status --brief 2>/dev/null || warn "cilium status command failed"
  else
    warn "No Cilium pod available to exec into"
  fi
else
  warn "cilium CLI not found — install from https://github.com/cilium/cilium-cli"
fi

# Section 5: Hubble Connectivity Test
echo ""
step "Section 5/7: Hubble Connectivity..."
if command -v hubble &>/dev/null; then
  HUBBLE_RELAY_POD=$(kubectl get pods -n "${CILIUM_NAMESPACE}" -l app.kubernetes.io/name=hubble-relay -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  if [ -n "${HUBBLE_RELAY_POD}" ]; then
    info "Port-forwarding Hubble Relay for status check..."
    kubectl port-forward -n "${CILIUM_NAMESPACE}" "pod/${HUBBLE_RELAY_POD}" 4245:4245 &
    PF_PID=$!
    sleep 2
    hubble status --server localhost:4245 2>/dev/null && success "Hubble Relay reachable" || fail "Hubble Relay not reachable"
    kill "${PF_PID}" 2>/dev/null || true
  else
    warn "Hubble Relay pod not found"
  fi
else
  warn "hubble CLI not found — install from https://github.com/cilium/hubble"
fi

# Section 6: Service Map (flows observation)
echo ""
step "Section 6/7: Hubble Service Map (recent flows)..."
if [ -n "${CILIUM_POD}" ]; then
  kubectl exec -n "${CILIUM_NAMESPACE}" "${CILIUM_POD}" -- hubble observe --last 5 --output jsonpb 2>/dev/null | \
    head -20 || warn "No flows observed (hubble may still be starting)"
  info "Use 'bash scripts/ebpf/hubble-flows.sh' for real-time flow observation"
else
  warn "Cannot observe flows — no Cilium pod available"
fi

# Section 7: Prometheus ServiceMonitors
echo ""
step "Section 7/7: Prometheus ServiceMonitors..."
for sm in "servicemonitor-cilium-agent" "servicemonitor-cilium-hubble" "servicemonitor-cilium-operator"; do
  if kubectl get servicemonitor "${sm}" -n securerag-monitoring &>/dev/null 2>&1; then
    success "ServiceMonitor ${sm}: found"
  else
    warn "ServiceMonitor ${sm}: not found (may not be deployed yet)"
  fi
done

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  STATUS CHECK COMPLETE"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Summary
if [ "${DAEMONSET_READY:-0}" -eq "${DAEMONSET_DESIRED:-0}" ] 2>/dev/null && [ "${DAEMONSET_DESIRED:-0}" -gt 0 ]; then
  success "Cilium + Hubble is healthy"
  info "Access Hubble UI: kubectl port-forward -n kube-system svc/hubble-ui 8081:8081"
  info "View Grafana dashboard: Cilium & Hubble — eBPF Network Observability"
else
  warn "Cilium + Hubble is not fully ready — check pod logs for details"
fi
echo ""
