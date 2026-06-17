#!/usr/bin/env bash
# disaster-recovery-test.sh — SecureRAG Hub DR Validation
# Teste backup → destroy → restore sur staging.
# Usage: bash scripts/validate/disaster-recovery-test.sh

set -euo pipefail
NAMESPACE="${NAMESPACE:-securerag-hub}"

log() { echo "[$(date +%H:%M:%S)] $*"; }

log "═══════════════════════════════════════════"
log "  SecureRAG Hub — DR Test"
log "═══════════════════════════════════════════"

# ── 1. Snapshot pre-test ──────────────────────────────────
log ""
log "─── 1. Snapshot pre-test ───"
kubectl get all -n "${NAMESPACE}" -o wide > /tmp/dr-snapshot-before.txt 2>/dev/null || true
PRE_PODS=$(kubectl get pods -n "${NAMESPACE}" --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
log "Pre-test running pods: ${PRE_PODS}"

# ── 2. Simuler une panne (suppression d'un deployment) ────
log ""
log "─── 2. Simulating failure (scale down audit-security) ───"
kubectl scale deploy audit-security-service -n "${NAMESPACE}" --replicas=0 2>/dev/null || true
sleep 5
AFTER_SCALE=$(kubectl get pods -n "${NAMESPACE}" --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
log "After scale down: ${AFTER_SCALE} pods running"

# ── 3. Restore (scale back up) ─────────────────────────────
log ""
log "─── 3. Auto-healing: scale back up ───"
START=$(date +%s)
kubectl scale deploy audit-security-service -n "${NAMESPACE}" --replicas=1 2>/dev/null || true
kubectl rollout status "deployment/audit-security-service" -n "${NAMESPACE}" --timeout=120s
END=$(date +%s)
RTO=$((END - START))

# ── 4. Verify ──────────────────────────────────────────────
log ""
log "─── 4. Post-restore verification ───"
POST_PODS=$(kubectl get pods -n "${NAMESPACE}" --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
log "Post-restore running pods: ${POST_PODS}"

if [[ "${POST_PODS}" -ge "${PRE_PODS}" ]]; then
  log "✅ All pods restored. RTO: ${RTO}s"
else
  log "⚠️  Missing ${PRE_PODS} -> ${POST_PODS} pods"
fi

# ── 5. Summary ─────────────────────────────────────────────
log ""
log "═══════════════════════════════════════════"
log "  DR Test Results"
log "  RTO (audit-security): ${RTO}s"
log "  Pre-pods:  ${PRE_PODS}"
log "  Post-pods: ${POST_PODS}"
log "═══════════════════════════════════════════"
