#!/usr/bin/env bash
# disaster-recovery.sh — SecureRAG Hub
# Restauration complète à partir des sauvegardes Velero.
#
# Usage :
#   bash scripts/gitops/disaster-recovery.sh [BACKUP_NAME]
#
# Si BACKUP_NAME n'est pas spécifié, utilise la dernière sauvegarde.

set -euo pipefail

NAMESPACE="${NAMESPACE:-securerag-hub}"
BACKUP_NAME="${1:-}"

log()  { echo "[$(date -u +%H:%M:%S)] $*"; }
fail() { echo "[FATAL] $*" >&2; exit 1; }

log "═══════════════════════════════════════════════════════"
log "  SecureRAG Hub — Disaster Recovery"
log "═══════════════════════════════════════════════════════"

# ── 1. Vérifier Velero ──────────────────────────────────────────
command -v velero >/dev/null 2>&1 || fail "velero CLI is required."
velero version --client-only 2>/dev/null | head -1 || true

# ── 2. Lister les sauvegardes disponibles ───────────────────────
log ""
log "Available backups:"
velero backup get 2>/dev/null || fail "Cannot list backups. Is Velero running?"

if [[ -z "${BACKUP_NAME}" ]]; then
  BACKUP_NAME=$(velero backup get -o json 2>/dev/null | python3 -c "import json,sys;data=json.load(sys.stdin);print(data['items'][0]['metadata']['name'] if data.get('items') else '')" 2>/dev/null || echo "")
  if [[ -z "${BACKUP_NAME}" ]]; then
    fail "No backups found. Create one first: velero backup create manual-backup --include-namespaces securerag-hub,securerag-monitoring,falco"
  fi
  log "Using latest backup: ${BACKUP_NAME}"
fi

# ── 3. Vérifier l'état du backup ───────────────────────────────
status=$(velero backup get "${BACKUP_NAME}" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
log "Backup status: ${status}"

if [[ "${status}" != "Completed" ]]; then
  fail "Backup ${BACKUP_NAME} is not in Completed state (status: ${status})."
fi

# ── 4. Restaurer ────────────────────────────────────────────────
log ""
log "Restoring from backup: ${BACKUP_NAME}..."
log ""

DR_NAME="dr-restore-$(date -u +%Y%m%dT%H%M%SZ)"

if velero restore create "${DR_NAME}" --from-backup "${BACKUP_NAME}" --wait 2>/dev/null; then
  log "Restore ${DR_NAME} completed."
else
  fail "Restore failed. Check: velero restore describe ${DR_NAME}"
fi

# ── 5. Vérifier la restauration ────────────────────────────────
log ""
log "Waiting for all pods to be ready..."
sleep 10

for ns in securerag-hub securerag-monitoring falco securerag-backup; do
  if kubectl get ns "${ns}" >/dev/null 2>&1; then
    log "  Waiting for pods in ${ns}..."
    kubectl wait --for=condition=Ready pods --all -n "${ns}" --timeout=300s 2>/dev/null || \
      log "  [WARN] Not all pods in ${ns} are ready yet."
  fi
done

# ── 6. Forcer la synchronisation ArgoCD ─────────────────────────
log ""
log "Triggering ArgoCD self-heal..."
for app in securerag-demo securerag-production securerag-observability securerag-runtime-detection securerag-kyverno securerag-kyverno-policies; do
  kubectl annotate application "${app}" -n argocd argocd.argoproj.io/refresh=normal --overwrite 2>/dev/null || true
done

log ""
log "═══════════════════════════════════════════════════════"
log "  Disaster Recovery Complete"
log "  Backup used : ${BACKUP_NAME}"
log "  Restore ID  : ${DR_NAME}"
log "  ArgoCD will self-heal any remaining drift."
log "═══════════════════════════════════════════════════════"

# ── 7. Vérifier les restore ─────────────────────────────────────
log ""
log "Restore history:"
velero restore get 2>/dev/null | head -5 || true
