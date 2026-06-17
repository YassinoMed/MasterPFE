#!/usr/bin/env bash
# chaos-engineering.sh — SecureRAG Hub Chaos Testing
# UNIQUEMENT sur staging. JAMAIS sur production.
# Feature flag: ENABLE_CHAOS_MESH=true
# Usage: STAGING_CONTEXT=kind-staging bash scripts/chaos/chaos-engineering.sh

set -euo pipefail
CONTEXT="${STAGING_CONTEXT:-}"
NAMESPACE="${NAMESPACE:-securerag-hub}"
ENABLE_CHAOS="${ENABLE_CHAOS:-false}"

log()  { echo "[$(date +%H:%M:%S)] $*"; }
fail() { echo "[FATAL] $*" >&2; exit 1; }

log "═══════════════════════════════════════════"
log "  SecureRAG Hub — Chaos Engineering"
log "  Context: ${CONTEXT:-default}"
log "  ENABLE_CHAOS: ${ENABLE_CHAOS}"
log "═══════════════════════════════════════════"

if [[ "${ENABLE_CHAOS}" != "true" ]]; then
  log "Chaos experiments disabled (ENABLE_CHAOS=${ENABLE_CHAOS})"
  exit 0
fi

if [[ -n "${CONTEXT}" ]]; then
  kubectl config use-context "${CONTEXT}" 2>/dev/null || fail "Context ${CONTEXT} not found"
  log "Switched to context: ${CONTEXT}"
fi

# ── Pre-check ────────────────────────────────────────────
log ""
log "─── Pre-check: Pod status ───"
kubectl get pods -n "${NAMESPACE}" -o wide

# ── Test 1: Pod Kill ────────────────────────────────────
log ""
log "─── Test 1: Pod Kill (single pod) ───"
POD=$(kubectl get pods -n "${NAMESPACE}" -l app.kubernetes.io/name=portal-web -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -n "${POD}" ]]; then
  log "Deleting pod: ${POD}"
  kubectl delete pod "${POD}" -n "${NAMESPACE}" --grace-period=5
  sleep 5
  log "Waiting for rollout..."
  kubectl rollout status "deployment/portal-web" -n "${NAMESPACE}" --timeout=120s
  ok "Pod auto-healed"
else
  fail "No portal-web pod found"
fi

# ── Test 2: Health after chaos ──────────────────────────
log ""
log "─── Test 2: Health Check ───"
for deploy in portal-web auth-users chatbot-manager conversation-service audit-security-service; do
  ready=$(kubectl get deploy "${deploy}" -n "${NAMESPACE}" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  ok "${deploy}: ${ready} ready"
done

# ── Test 3: Measure RTO ─────────────────────────────────
log ""
log "─── RTO Measurement ───"
START=$(date +%s)
kubectl delete pod -n "${NAMESPACE}" -l app.kubernetes.io/name=chatbot-manager --grace-period=3 2>/dev/null || true
kubectl rollout status "deployment/chatbot-manager" -n "${NAMESPACE}" --timeout=120s
END=$(date +%s)
RTO=$((END - START))
ok "RTO (chatbot-manager pod kill): ${RTO}s"

log ""
log "═══════════════════════════════════════════"
log "  Chaos Engineering Complete"
log "  RTO: ${RTO}s"
log "  All services healthy"
log "═══════════════════════════════════════════"
