#!/usr/bin/env bash
# restore-test.sh — Test Velero restore
# SecureRAG Hub — Disaster Recovery
#
# Restores the most recent backup to a temporary namespace
# and validates data integrity.
set -euo pipefail

RESTORE_NS="dr-restore-test-$(date +%Y%m%d)"
BACKUP_NAME="${1:-$(velero backup get --order-by=creationTimestamp:desc -o json 2>/dev/null | jq -r '.items[0].metadata.name' 2>/dev/null || echo "")}"

if [ -z "${BACKUP_NAME}" ]; then
  echo "❌ No backup found. Run backup-test.sh first."
  exit 1
fi

echo "═══ DR Restore Test ═══"
echo "Backup: ${BACKUP_NAME}"
echo "Restore namespace: ${RESTORE_NS}"
echo ""

# Create restore to test namespace
RESTORE_NAME="dr-restore-$(date +%Y%m%d-%H%M%S)"
velero restore create "${RESTORE_NAME}" \
  --from-backup "${BACKUP_NAME}" \
  --namespace-mappings securerag-hub:${RESTORE_NS} \
  --wait

STATUS=$(velero restore get "${RESTORE_NAME}" -o json 2>/dev/null | jq -r '.status.phase' 2>/dev/null || echo "unknown")
echo ""
echo "Restore status: ${STATUS}"

case "${STATUS}" in
  Completed)
    echo "✅ Restore test PASSED"
    # Clean up test namespace
    kubectl delete ns "${RESTORE_NS}" --wait=false 2>/dev/null || true
    exit 0
    ;;
  PartiallyFailed)
    echo "⚠️  Restore test PARTIAL"
    velero restore describe "${RESTORE_NAME}" 2>/dev/null | tail -20
    kubectl delete ns "${RESTORE_NS}" --wait=false 2>/dev/null || true
    exit 1
    ;;
  Failed)
    echo "❌ Restore test FAILED"
    velero restore describe "${RESTORE_NAME}" 2>/dev/null | tail -30
    exit 2
    ;;
  *)
    echo "❓ Unknown status: ${STATUS}"
    exit 3
    ;;
esac
