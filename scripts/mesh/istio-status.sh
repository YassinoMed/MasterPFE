#!/usr/bin/env bash
# istio-status.sh — SecureRAG Hub
# Check Istio service mesh status: sidecars, mTLS, policies, health
#
# Usage:
#   bash scripts/mesh/istio-status.sh [namespace]
#
# Default namespace: securerag-hub

set -euo pipefail

NAMESPACE="${1:-securerag-hub}"
ISTIO_NAMESPACE="${ISTIO_NAMESPACE:-istio-system}"
MONITORING_NAMESPACE="${MONITORING_NAMESPACE:-securerag-monitoring}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; MAG='\033[0;35m'; NC='\033[0m'
info()  { printf "${GREEN}[INFO]${NC}  %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$*" >&2; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }
pass()  { printf "  ${GREEN}✓${NC} %s\n" "$*"; }
fail()  { printf "  ${RED}✗${NC} %s\n" "$*"; }
header(){ printf "\n${CYAN}═══════════════════════════════════════════════════════════════${NC}\n${CYAN}  %s${NC}\n${CYAN}═══════════════════════════════════════════════════════════════${NC}\n" "$*"; }

command -v kubectl >/dev/null 2>&1 || { error "kubectl is required"; exit 1; }

PASS=0; FAIL=0; WARN=0

check() {
  local status=$1; shift
  case "$status" in
    pass) pass "$*"; PASS=$((PASS + 1));;
    fail) fail "$*"; FAIL=$((FAIL + 1));;
    warn) warn "  ⚠ $*"; WARN=$((WARN + 1));;
  esac
}

# ── 1. Istio Control Plane ─────────────────────────────────────────
header "1. Istio Control Plane"

if kubectl get namespace "${ISTIO_NAMESPACE}" >/dev/null 2>&1; then
  check pass "Namespace ${ISTIO_NAMESPACE} exists"
else
  check fail "Namespace ${ISTIO_NAMESPACE} does not exist — Istio not installed"
  echo ""
  info "Summary: ${PASS} passed, ${FAIL} failed, ${WARN} warnings"
  exit 1
fi

for pod in istiod istio-ingressgateway istio-egressgateway; do
  if kubectl get pods -n "${ISTIO_NAMESPACE}" -l "app=${pod}" 2>/dev/null | grep -q Running; then
    check pass "${pod} is Running"
  else
    check fail "${pod} is not Running"
  fi
done

# ── 2. Sidecar Injection ───────────────────────────────────────────
header "2. Sidecar Injection (${NAMESPACE})"

INJECTION_LABEL=$(kubectl get namespace "${NAMESPACE}" -o jsonpath='{.metadata.labels.istio-injection}' 2>/dev/null || echo "missing")
if [ "${INJECTION_LABEL}" = "enabled" ]; then
  check pass "istio-injection=enabled on namespace ${NAMESPACE}"
else
  check fail "istio-injection label is '${INJECTION_LABEL}' (expected 'enabled')"
fi

TOTAL_PODS=0; INJECTED_PODS=0; NON_INJECTED=""
for pod in $(kubectl get pods -n "${NAMESPACE}" -o jsonpath='{range .items[*]}{.metadata.name}{" "}{end}' 2>/dev/null); do
  TOTAL_PODS=$((TOTAL_PODS + 1))
  CONTAINERS=$(kubectl get pod "${pod}" -n "${NAMESPACE}" -o jsonpath='{.spec.containers[*].name}' 2>/dev/null)
  if echo "${CONTAINERS}" | grep -q "istio-proxy"; then
    INJECTED_PODS=$((INJECTED_PODS + 1))
  else
    NON_INJECTED="${NON_INJECTED} ${pod}"
  fi
done

if [ "${TOTAL_PODS}" -gt 0 ]; then
  check pass "${INJECTED_PODS}/${TOTAL_PODS} pods have sidecar injected"
  if [ -n "${NON_INJECTED}" ]; then
    for p in ${NON_INJECTED}; do
      check warn "Pod '${p}' has NO istio-proxy sidecar"
    done
  fi
else
  check warn "No pods found in namespace ${NAMESPACE}"
fi

# ── 3. mTLS Status ─────────────────────────────────────────────────
header "3. mTLS Status"

PA_COUNT=$(kubectl get peerauthentication -n "${NAMESPACE}" -o name 2>/dev/null | wc -l)
if [ "${PA_COUNT}" -gt 0 ]; then
  check pass "${PA_COUNT} PeerAuthentication(s) configured"
  while IFS= read -r pa; do
    MODE=$(kubectl get "${pa}" -n "${NAMESPACE}" -o jsonpath='{.spec.mtls.mode}' 2>/dev/null)
    if [ "${MODE}" = "STRICT" ]; then
      check pass "${pa}: mTLS STRICT"
    elif [ "${MODE}" = "PERMISSIVE" ]; then
      check warn "${pa}: mTLS PERMISSIVE (not fully secure)"
    else
      check fail "${pa}: mTLS mode '${MODE}'"
    fi
  done < <(kubectl get peerauthentication -n "${NAMESPACE}" -o name 2>/dev/null)
else
  check fail "No PeerAuthentication resources found in ${NAMESPACE}"
fi

# ── 4. DestinationRules ────────────────────────────────────────────
header "4. DestinationRules & Connection Pools"

DR_COUNT=$(kubectl get destinationrule -n "${NAMESPACE}" -o name 2>/dev/null | wc -l)
if [ "${DR_COUNT}" -gt 0 ]; then
  check pass "${DR_COUNT} DestinationRule(s) configured"
  while IFS= read -r dr; do
    HOST=$(kubectl get "${dr}" -n "${NAMESPACE}" -o jsonpath='{.spec.host}' 2>/dev/null)
    LB=$(kubectl get "${dr}" -n "${NAMESPACE}" -o jsonpath='{.spec.trafficPolicy.loadBalancer.simple}' 2>/dev/null)
    check pass "${dr}: host=${HOST}, lb=${LB:-default}"
  done < <(kubectl get destinationrule -n "${NAMESPACE}" -o name 2>/dev/null)
else
  check fail "No DestinationRule resources found in ${NAMESPACE}"
fi

# ── 5. VirtualServices ─────────────────────────────────────────────
header "5. VirtualServices & Timeouts"

VS_COUNT=$(kubectl get virtualservice -n "${NAMESPACE}" -o name 2>/dev/null | wc -l)
if [ "${VS_COUNT}" -gt 0 ]; then
  check pass "${VS_COUNT} VirtualService(s) configured"
  while IFS= read -r vs; do
    HOSTS=$(kubectl get "${vs}" -n "${NAMESPACE}" -o jsonpath='{.spec.hosts}' 2>/dev/null)
    TIMEOUT=$(kubectl get "${vs}" -n "${NAMESPACE}" -o jsonpath='{.spec.http[0].timeout}' 2>/dev/null)
    RETRIES=$(kubectl get "${vs}" -n "${NAMESPACE}" -o jsonpath='{.spec.http[0].retries.attempts}' 2>/dev/null)
    check pass "${vs}: hosts=${HOSTS}, timeout=${TIMEOUT:-none}, retries=${RETRIES:-0}"
  done < <(kubectl get virtualservice -n "${NAMESPACE}" -o name 2>/dev/null)
else
  check fail "No VirtualService resources found in ${NAMESPACE}"
fi

# ── 6. Authorization Policies ──────────────────────────────────────
header "6. Authorization Policies"

AP_COUNT=$(kubectl get authorizationpolicy -n "${NAMESPACE}" -o name 2>/dev/null | wc -l)
if [ "${AP_COUNT}" -gt 0 ]; then
  check pass "${AP_COUNT} AuthorizationPolicy(ies) configured"
  while IFS= read -r ap; do
    ACTION=$(kubectl get "${ap}" -n "${NAMESPACE}" -o jsonpath='{.spec.action}' 2>/dev/null)
    check pass "${ap}: action=${ACTION}"
  done < <(kubectl get authorizationpolicy -n "${NAMESPACE}" -o name 2>/dev/null)
else
  check fail "No AuthorizationPolicy resources found in ${NAMESPACE}"
fi

# ── 7. Service Entries ─────────────────────────────────────────────
header "7. Service Entries (External Services)"

SE_COUNT=$(kubectl get serviceentry -n "${NAMESPACE}" -o name 2>/dev/null | wc -l)
check pass "${SE_COUNT} ServiceEntry(ies) configured"

# ── 8. Telemetry ───────────────────────────────────────────────────
header "8. Telemetry Configuration"

TL_COUNT=$(kubectl get telemetry -n "${NAMESPACE}" -o name 2>/dev/null | wc -l)
if [ "${TL_COUNT}" -gt 0 ]; then
  check pass "${TL_COUNT} Telemetry resource(s) configured"
  while IFS= read -r tl; do
    SAMPLING=$(kubectl get "${tl}" -n "${NAMESPACE}" -o jsonpath='{.spec.tracing[0].randomSamplingPercentage}' 2>/dev/null)
    check pass "${tl}: sampling=${SAMPLING:-default}%"
  done < <(kubectl get telemetry -n "${NAMESPACE}" -o name 2>/dev/null)
else
  check warn "No Telemetry resources found in ${NAMESPACE}"
fi

# ── 9. Gateway ─────────────────────────────────────────────────────
header "9. Gateway & Ingress"

GW_COUNT=$(kubectl get gateway -n "${NAMESPACE}" -o name 2>/dev/null | wc -l)
if [ "${GW_COUNT}" -gt 0 ]; then
  check pass "${GW_COUNT} Gateway resource(s) configured"
else
  check warn "No Gateway resources found in ${NAMESPACE}"
fi

# ── 10. Kiali ──────────────────────────────────────────────────────
header "10. Kiali Visualization"

if kubectl get deployment kiali -n "${ISTIO_NAMESPACE}" >/dev/null 2>&1; then
  KIALI_READY=$(kubectl get deployment kiali -n "${ISTIO_NAMESPACE}" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [ "${KIALI_READY:-0}" -ge 1 ]; then
    check pass "Kiali is Running (${KIALI_READY} replica(s))"
  else
    check fail "Kiali deployment exists but not ready"
  fi
else
  check warn "Kiali not deployed"
fi

# ── 11. Monitoring ─────────────────────────────────────────────────
header "11. Monitoring (ServiceMonitors)"

if kubectl get namespace "${MONITORING_NAMESPACE}" >/dev/null 2>&1; then
  SM_COUNT=$(kubectl get servicemonitor -n "${MONITORING_NAMESPACE}" -l app.kubernetes.io/component=service-mesh -o name 2>/dev/null | wc -l)
  check pass "${SM_COUNT} Istio ServiceMonitor(s) in ${MONITORING_NAMESPACE}"
else
  check warn "Monitoring namespace ${MONITORING_NAMESPACE} not found"
fi

# ── 12. Envoy Metrics ──────────────────────────────────────────────
header "12. Envoy Metrics Connectivity"

for svc in portal-web auth-users chatbot-manager conversation-service audit-security-service; do
  if kubectl get service "${svc}" -n "${NAMESPACE}" -o jsonpath='{.metadata.name}' >/dev/null 2>&1; then
    PORTS=$(kubectl get service "${svc}" -n "${NAMESPACE}" -o jsonpath='{.spec.ports[*].name}' 2>/dev/null)
    if echo "${PORTS}" | grep -q "http-envoy-prom"; then
      check pass "${svc} has http-envoy-prom port"
    else
      check warn "${svc} missing http-envoy-prom port (Envoy metrics not exposed)"
    fi
  fi
done

# ── Summary ────────────────────────────────────────────────────────
header "Summary"
echo ""
echo "  ${GREEN}Passed:${NC} ${PASS}"
echo "  ${RED}Failed:${NC} ${FAIL}"
echo "  ${YELLOW}Warnings:${NC} ${WARN}"
echo ""
echo "  Total checks: $((PASS + FAIL + WARN))"
echo ""

if [ "${FAIL}" -eq 0 ]; then
  info "All Istio mesh checks passed!"
else
  error "${FAIL} check(s) failed — review output above"
fi

exit ${FAIL}
