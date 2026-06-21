#!/usr/bin/env bash
# backup-test.sh — Test Velero backup creation
# SecureRAG Hub — Disaster Recovery
set -euo pipefail

BACKUP_NAME="dr-test-$(date +%Y%m%d-%H%M%S)"
NAMESPACES="securerag-hub,vault,observability,falco"

echo "═══ DR Backup Test ═══"
echo "Backup: ${BACKUP_NAME}"
echo "Namespaces: ${NAMESPACES}"
echo ""

# Create backup
velero backup create "${BACKUP_NAME}" \
  --include-namespaces "${NAMESPACES}" \
  --wait \
  --ttl 24h

# Check status
STATUS=$(velero backup get "${BACKUP_NAME}" -o json 2>/dev/null | jq -r '.status.phase' 2>/dev/null || echo "unknown")
echo ""
echo "Status: ${STATUS}"

case "${STATUS}" in
  Completed)
    echo "✅ Backup test PASSED"
    exit 0
    ;;
  PartiallyFailed)
    echo "⚠️  Backup test PARTIAL — check velero logs"
    exit 1
    ;;
  Failed)
    echo "❌ Backup test FAILED"
    velero backup describe "${BACKUP_NAME}" 2>/dev/null | tail -20
    exit 2
    ;;
  *)
    echo "❓ Unknown status: ${STATUS}"
    exit 3
    ;;
esac
