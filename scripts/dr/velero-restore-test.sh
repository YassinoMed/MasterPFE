#!/usr/bin/env bash
# velero-restore-test.sh — Automated Velero Restore Validation
# SecureRAG Hub — World-Class Backup & Disaster Recovery
#
# Exécute un restore test complet:
# 1. Crée un snapshot de test
# 2. Restaure dans un namespace temporaire
# 3. Vérifie que les workloads sont Running
# 4. Nettoie le namespace de test
#
# Usage:
#   bash scripts/dr/velero-restore-test.sh [--backup-name NAME] [--namespace NAMESPACE]
#
# Validation:
#   bash scripts/dr/velero-restore-test.sh --dry-run
#
# Rollback (manual):
#   velero restore delete --all --confirm
#   kubectl delete ns securerag-restore-test --force --grace-period=0

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RESTORE_NAMESPACE="securerag-restore-test"
BACKUP_SCHEDULE="${BACKUP_SCHEDULE:-securerag-daily-full}"
BACKUP_NAME="${BACKUP_NAME:-}"
DRY_RUN="${DRY_RUN:-false}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { printf "${GREEN}[INFO]${NC}  %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }
step()  { printf "${BLUE}[STEP]${NC}  %s\n" "$*"; }

cleanup() {
  info "Cleaning up test namespace..."
  if command -v velero &>/dev/null; then
    velero restore delete --all --confirm 2>/dev/null || true
  fi
  kubectl delete namespace "${RESTORE_NAMESPACE}" --ignore-not-found --grace-period=0 2>/dev/null || true
  info "Cleanup complete"
}

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    --backup-name) BACKUP_NAME="$2"; shift 2 ;;
    --namespace) RESTORE_NAMESPACE="$2"; shift 2 ;;
    --dry-run) DRY_RUN="true"; shift ;;
    *) warn "Unknown argument: $1"; shift ;;
  esac
done

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  VELERO — AUTOMATED RESTORE TEST"
echo "═══════════════════════════════════════════════════════════════"

# Prerequisites
if ! command -v velero &>/dev/null; then
  error "Velero CLI not found. Install with:"
  error "  curl -fsSL https://github.com/vmware-tanzu/velero/releases/latest/download/velero-linux-amd64.tar.gz | tar xz && install velero /usr/local/bin/"
  exit 1
fi

if ! kubectl auth can-i create namespace &>/dev/null; then
  error "Insufficient permissions to create namespaces"
  exit 1
fi

trap cleanup EXIT

# ── Step 1: Determine Backup ───────────────────────────────────────
step "1/5 — Identifying backup to restore"

if [ -z "${BACKUP_NAME}" ]; then
  # Get latest backup from schedule
  latest_backup=$(velero backup get --selector "velero.io/schedule-name=${BACKUP_SCHEDULE}" \
    -o json 2>/dev/null | jq -r '.items | max_by(.metadata.creationTimestamp) | .metadata.name' 2>/dev/null || true)

  if [ -z "${latest_backup}" ] || [ "${latest_backup}" = "null" ]; then
    warn "No existing backup found for schedule '${BACKUP_SCHEDULE}'. Creating one..."
    velero backup create --from-schedule "${BACKUP_SCHEDULE}" --wait 2>&1 | head -5
    latest_backup=$(velero backup get --selector "velero.io/schedule-name=${BACKUP_SCHEDULE}" \
      -o json 2>/dev/null | jq -r '.items | max_by(.metadata.creationTimestamp) | .metadata.name' 2>/dev/null || true)
  fi
  BACKUP_NAME="${latest_backup}"
fi

if [ -z "${BACKUP_NAME}" ] || [ "${BACKUP_NAME}" = "null" ]; then
  error "No backup available. Run: velero backup create --from-schedule ${BACKUP_SCHEDULE} --wait"
  exit 1
fi

info "Using backup: ${BACKUP_NAME}"

# ── Step 2: Validate Backup ────────────────────────────────────────
step "2/5 — Validating backup integrity"

backup_status=$(velero backup get "${BACKUP_NAME}" -o json | jq -r '.status.phase' 2>/dev/null || echo "Unknown")
if [ "${backup_status}" != "Completed" ]; then
  error "Backup '${BACKUP_NAME}' has status '${backup_status}' — expected 'Completed'"
  exit 1
fi

info "Backup '${BACKUP_NAME}' is valid (status: ${backup_status})"

# Count resources in backup
resource_count=$(velero backup describe "${BACKUP_NAME}" \
  -o json 2>/dev/null | jq '.resources | length' 2>/dev/null || echo "unknown")
info "Backup contains approximately ${resource_count} resources"

# ── Step 3: Create Restore ─────────────────────────────────────────
step "3/5 — Creating restore in namespace '${RESTORE_NAMESPACE}'"

if [ "${DRY_RUN}" = "true" ]; then
  info "DRY RUN: Would execute:"
  info "  velero restore create --from-backup '${BACKUP_NAME}' --namespace-mappings *:${RESTORE_NAMESPACE} --wait"
  exit 0
fi

RESTORE_NAME="restore-test-$(date +%Y%m%d-%H%M%S)"
restore_log=$(mktemp)

if ! velero restore create \
  --from-backup "${BACKUP_NAME}" \
  --namespace-mappings '*'="${RESTORE_NAMESPACE}" \
  --restore-volumes=false \
  --preserve-node-ports=false \
  --name "${RESTORE_NAME}" \
  --wait 2>&1 | tee "${restore_log}"; then
  error "Restore creation failed"
  cat "${restore_log}"
  exit 1
fi

restore_status=$(velero restore get "${RESTORE_NAME}" -o json | jq -r '.status.phase' 2>/dev/null || echo "Unknown")
info "Restore '${RESTORE_NAME}' completed with status: ${restore_status}"

if [ "${restore_status}" != "Completed" ]; then
  error "Restore has non-completed status: ${restore_status}"
  velero restore describe "${RESTORE_NAME}"
  exit 1
fi

# ── Step 4: Verify Workloads ───────────────────────────────────────
step "4/5 — Verifying restored workloads"

sleep 5  # Wait for workloads to stabilize

PASS=0
FAIL=0

# Verify deployments
deployments=$(kubectl get deployments -n "${RESTORE_NAMESPACE}" -o name 2>/dev/null || true)
if [ -n "${deployments}" ]; then
  for dep in ${deployments}; do
    ready=$(kubectl get "${dep}" -n "${RESTORE_NAMESPACE}" -o json | jq -r '.status.readyReplicas // 0')
    desired=$(kubectl get "${dep}" -n "${RESTORE_NAMESPACE}" -o json | jq -r '.spec.replicas // 0')
    if [ "${ready}" -ge "${desired}" ] 2>/dev/null; then
      echo "  ✅ ${dep} — ${ready}/${desired} ready"
      PASS=$((PASS + 1))
    else
      echo "  ❌ ${dep} — ${ready}/${desired} ready (expected ${desired})"
      FAIL=$((FAIL + 1))
    fi
  done
else
  info "No deployments found in restored namespace"
fi

# Verify statefulsets
statefulsets=$(kubectl get statefulsets -n "${RESTORE_NAMESPACE}" -o name 2>/dev/null || true)
if [ -n "${statefulsets}" ]; then
  for sts in ${statefulsets}; do
    ready=$(kubectl get "${sts}" -n "${RESTORE_NAMESPACE}" -o json | jq -r '.status.readyReplicas // 0')
    desired=$(kubectl get "${sts}" -n "${RESTORE_NAMESPACE}" -o json | jq -r '.spec.replicas // 0')
    if [ "${ready}" -ge "${desired}" ] 2>/dev/null; then
      echo "  ✅ ${sts} — ${ready}/${desired} ready"
      PASS=$((PASS + 1))
    else
      echo "  ❌ ${sts} — ${ready}/${desired} ready (expected ${desired})"
      FAIL=$((FAIL + 1))
    fi
  done
else
  info "No statefulsets found in restored namespace"
fi

# Verify services exist
services=$(kubectl get services -n "${RESTORE_NAMESPACE}" -o name 2>/dev/null || true)
INFO_COUNT=$(echo "${services}" | wc -l)
info "Restored ${INFO_COUNT} services"

if [ "${FAIL}" -gt 0 ]; then
  warn "${FAIL} workload(s) not ready — restore may be partial"
fi

# Generate report
REPORT_FILE="${REPO_ROOT}/security/reports/restore-test-$(date +%Y%m%d).md"
mkdir -p "$(dirname "${REPORT_FILE}")"
cat > "${REPORT_FILE}" << REPORTEOF
# Velero Restore Test Report
- **Date:** $(date)
- **Backup:** ${BACKUP_NAME}
- **Restore:** ${RESTORE_NAME}
- **Status:** ${restore_status}
- **Deployments Ready:** $(kubectl get deployments -n "${RESTORE_NAMESPACE}" -o json 2>/dev/null | jq '[.items[] | select(.status.readyReplicas >= .spec.replicas)] | length' 2>/dev/null || echo 0) / $(kubectl get deployments -n "${RESTORE_NAMESPACE}" --no-headers 2>/dev/null | wc -l)
- **StatefulSets Ready:** $(kubectl get statefulsets -n "${RESTORE_NAMESPACE}" -o json 2>/dev/null | jq '[.items[] | select(.status.readyReplicas >= .spec.replicas)] | length' 2>/dev/null || echo 0) / $(kubectl get statefulsets -n "${RESTORE_NAMESPACE}" --no-headers 2>/dev/null | wc -l)
- **Services Restored:** $(kubectl get services -n "${RESTORE_NAMESPACE}" --no-headers 2>/dev/null | wc -l)
- **ConfigMaps Restored:** $(kubectl get configmaps -n "${RESTORE_NAMESPACE}" --no-headers 2>/dev/null | wc -l)
- **Secrets Restored:** $(kubectl get secrets -n "${RESTORE_NAMESPACE}" --no-headers 2>/dev/null | wc -l)
REPORTEOF

info "Report saved to: ${REPORT_FILE}"

# ── Step 5: Cleanup ────────────────────────────────────────────────
step "5/5 — Cleaning up test resources"

cleanup
info "Cleanup completed"

echo ""
echo "═══════════════════════════════════════════════════════════════"
if [ "${FAIL}" -eq 0 ]; then
  echo "  RESTORE TEST: ✅ PASS"
else
  echo "  RESTORE TEST: ⚠️  ${FAIL} workload(s) not ready (partial pass)"
fi
echo "═══════════════════════════════════════════════════════════════"
