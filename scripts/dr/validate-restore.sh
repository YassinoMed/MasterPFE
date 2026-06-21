#!/usr/bin/env bash
# validate-restore.sh — Validate restore integrity
# SecureRAG Hub — Disaster Recovery
set -euo pipefail

BACKUP_NAME="${1:-latest}"
echo "═══ DR Restore Validation ═══"
echo ""

# Get backup info
if [ "${BACKUP_NAME}" = "latest" ]; then
  BACKUP_NAME=$(velero backup get --order-by=creationTimestamp:desc -o json 2>/dev/null | jq -r '.items[0].metadata.name' 2>/dev/null || echo "")
fi

if [ -z "${BACKUP_NAME}" ]; then
  echo "❌ No backups found"
  exit 1
fi

echo "Validating backup: ${BACKUP_NAME}"
echo ""

# Check backup exists
velero backup get "${BACKUP_NAME}" >/dev/null 2>&1 || {
  echo "❌ Backup ${BACKUP_NAME} not found"
  exit 1
}

# Get backup details
STATUS=$(velero backup get "${BACKUP_NAME}" -o json 2>/dev/null | jq -r '.status.phase' 2>/dev/null || echo "unknown")
ERRORS=$(velero backup get "${BACKUP_NAME}" -o json 2>/dev/null | jq -r '.status.errors // 0' 2>/dev/null || echo 0)
WARNINGS=$(velero backup get "${BACKUP_NAME}" -o json 2>/dev/null | jq -r '.status.warnings // 0' 2>/dev/null || echo 0)
ITEMS=$(velero backup get "${BACKUP_NAME}" -o json 2>/dev/null | jq -r '.status.totalItems // 0' 2>/dev/null || echo 0)

echo "Status:   ${STATUS}"
echo "Items:    ${ITEMS}"
echo "Errors:   ${ERRORS}"
echo "Warnings: ${WARNINGS}"
echo ""

PASS=0
FAIL=0

# Validation checks
if [ "${STATUS}" = "Completed" ]; then
  echo "✅ [PASS] Backup completed successfully"
  PASS=$((PASS + 1))
else
  echo "❌ [FAIL] Backup status: ${STATUS}"
  FAIL=$((FAIL + 1))
fi

if [ "${ERRORS}" -eq 0 ]; then
  echo "✅ [PASS] No errors"
  PASS=$((PASS + 1))
else
  echo "❌ [FAIL] ${ERRORS} errors found"
  FAIL=$((FAIL + 1))
fi

if [ "${ITEMS}" -gt 0 ]; then
  echo "✅ [PASS] ${ITEMS} items backed up"
  PASS=$((PASS + 1))
else
  echo "❌ [FAIL] No items in backup"
  FAIL=$((FAIL + 1))
fi

# Check backup age
if command -v jq &>/dev/null; then
  CREATED=$(velero backup get "${BACKUP_NAME}" -o json 2>/dev/null | jq -r '.status.startTimestamp // .metadata.creationTimestamp' 2>/dev/null || echo "")
  if [ -n "${CREATED}" ]; then
    AGE_SECONDS=$(( $(date +%s) - $(date -d "${CREATED}" +%s 2>/dev/null || echo 0) ))
    AGE_HOURS=$(( AGE_SECONDS / 3600 ))
    if [ "${AGE_HOURS}" -lt 48 ]; then
      echo "✅ [PASS] Backup age: ${AGE_HOURS}h (< 48h)"
      PASS=$((PASS + 1))
    else
      echo "⚠️  [WARN] Backup age: ${AGE_HOURS}h (stale)"
    fi
  fi
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  RESULTS: ${PASS} passed, ${FAIL} failed"
echo "═══════════════════════════════════════════════════════════════"

[ "${FAIL}" -eq 0 ] || exit 1
exit 0
