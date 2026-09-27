#!/bin/bash
# velero-restore-test.sh — Test automatisé de restauration Velero
# Phase 10 : prouve que les sauvegardes sont restaurables.
#
# PRÉREQUIS : le BackupStorageLocation doit être Available (MinIO ou S3).
# Statut actuel : IMPLEMENTED / NOT YET VALIDATED (storage backend indisponible).
#
# Usage : bash scripts/backup/velero-restore-test.sh [backup-name]

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0x32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { printf "${GREEN}[RESTORE]${NC} %s\n" "$*"; }
warn()  { printf "${YELLOW}[RESTORE]${NC} %s\n" "$*"; }
fail()  { printf "${RED}[RESTORE]${NC} %s\n" "$*" >&2; exit 1; }

EVIDENCE_DIR="evidence/$(date +%Y-%m-%d)"
mkdir -p "$EVIDENCE_DIR"
REPORT_FILE="$EVIDENCE_DIR/velero-restore-test-$(date +%H%M%S).md"
TEST_NAMESPACE="securerag-restore-test"

info "=== VELERO RESTORE TEST ==="

# ── 1. Vérifier le BackupStorageLocation ─────────────────────────
info "Étape 1 : Vérification du BackupStorageLocation"
BSL_PHASE=$(kubectl get backupstoragelocation default -n velero -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
if [ "$BSL_PHASE" != "Available" ]; then
  fail "BackupStorageLocation phase=$BSL_PHASE — le stockage doit être Available avant de tester la restauration"
fi
info "✓ BackupStorageLocation: Available"

# ── 2. Sélectionner un backup ─────────────────────────────────────
info "Étape 2 : Sélection du backup"
if [ -n "${1:-}" ]; then
  BACKUP_NAME="$1"
else
  BACKUP_NAME=$(kubectl get backups -n velero --sort-by='.status.completionTimestamp' \
    -o jsonpath='{range .items[?(@.status.phase=="Completed")]}{.metadata.name}{"\n"}{end}' | tail -1)
fi

if [ -z "$BACKUP_NAME" ]; then
  fail "Aucun backup avec phase=Completed trouvé"
fi
info "Backup sélectionné : $BACKUP_NAME"

# ── 3. Créer un namespace de test ────────────────────────────────
info "Étape 3 : Création du namespace de test"
kubectl delete namespace "$TEST_NAMESPACE" --ignore-not-found --wait=false >/dev/null 2>&1
kubectl create namespace "$TEST_NAMESPACE" >/dev/null
info "✓ Namespace $TEST_NAMESPACE créé"

# ── 4. Lancer la restauration ─────────────────────────────────────
info "Étape 4 : Restauration vers $TEST_NAMESPACE"
RESTORE_NAME="restore-test-$(date +%Y%m%d-%H%M%S)"

# Note: Velero restaure dans les namespaces d'origine.
# Pour un vrai test isolé, il faut utiliser --namespace-mappings.
# Pour simplifier : on teste que la restauration démarre et produit des ressources.
velero restore create "$RESTORE_NAME" \
  --from-backup "$BACKUP_NAME" \
  --namespace-mappings "securerag-hub:$TEST_NAMESPACE" \
  --wait 2>/dev/null || kubectl create -f - << EOF
apiVersion: velero.io/v1
kind: Restore
metadata:
  name: "$RESTORE_NAME"
  namespace: velero
spec:
  backupName: "$BACKUP_NAME"
  includedNamespaces:
    - securerag-hub
  namespaceMapping:
    securerag-hub: "$TEST_NAMESPACE"
EOF

info "Restore $RESTORE_NAME créé"

# ── 5. Attendre la restauration ────────────────────────────────────
info "Étape 5 : Attente de la restauration (max 5 min)"
for i in $(seq 1 30); do
  PHASE=$(kubectl get restore "$RESTORE_NAME" -n velero -o jsonpath='{.status.phase}' 2>/dev/null || echo "Pending")
  [ "$PHASE" = "Completed" ] || [ "$PHASE" = "Failed" ] && break
  sleep 10
done
info "Phase de restauration : $PHASE"

# ── 6. Vérifier les ressources restaurées ─────────────────────────
info "Étape 6 : Vérification des ressources restaurées"
if [ "$PHASE" = "Completed" ]; then
  RESOURCES=$(kubectl get all -n "$TEST_NAMESPACE" --no-headers 2>/dev/null | wc -l)
  PVC_COUNT=$(kubectl get pvc -n "$TEST_NAMESPACE" --no-headers 2>/dev/null | wc -l)
  SECRET_COUNT=$(kubectl get secrets -n "$TEST_NAMESPACE" --no-headers 2>/dev/null | grep -v "default-token\|sh.helm" | wc -l)
  info "✓ Ressources: $RESOURCES | PVCs: $PVC_COUNT | Secrets: $SECRET_COUNT"
else
  warn "Restauration phase: $PHASE"
  RESOURCES=0; PVC_COUNT=0; SECRET_COUNT=0
fi

# ── 7. Générer le rapport ─────────────────────────────────────────
info "Étape 7 : Génération du rapport"
cat > "$REPORT_FILE" << EVIDENCE
# Velero Restore Test Report

**Date**: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
**Backup testé**: $BACKUP_NAME
**Restore name**: $RESTORE_NAME
**Namespace de test**: $TEST_NAMESPACE

## Résultats

| Métrique | Valeur |
|---|---|
| Phase de restauration | $PHASE |
| Ressources restaurées | $RESOURCES |
| PVCs restaurés | $PVC_COUNT |
| Secrets restaurés | $SECRET_COUNT |

## Verdict

$([ "$PHASE" = "Completed" ] && echo "✓ RESTAURATION RÉUSSIE — les sauvegardes sont restaurables" || echo "✗ RESTAURATION ÉCHOUÉE — voir les logs Velero")

## Vérifications de non-régression

- [ ] Namespace de production intact
- [ ] Aucune donnée perdue
- [ ] Aucun service interrompu

---
*Généré par scripts/backup/velero-restore-test.sh*
EVIDENCE

info "Rapport : $REPORT_FILE"

# ── 8. Nettoyage ──────────────────────────────────────────────────
info "Étape 8 : Nettoyage du namespace de test"
kubectl delete namespace "$TEST_NAMESPACE" --ignore-not-found >/dev/null 2>&1
info "✓ Namespace $TEST_NAMESPACE supprimé"

# ── 9. Verdict final ──────────────────────────────────────────────
if [ "$PHASE" = "Completed" ]; then
  info "=== RESTORE TEST : RÉUSSI ==="
  exit 0
else
  warn "=== RESTORE TEST : ÉCHOUÉ (phase=$PHASE) ==="
  exit 1
fi
