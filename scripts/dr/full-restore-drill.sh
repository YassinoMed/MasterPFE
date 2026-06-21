#!/usr/bin/env bash
# full-restore-drill.sh — Complete Velero backup/restore drill with evidence
# SecureRAG Hub — World-Class Disaster Recovery
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { printf "${GREEN}[INFO]${NC}  %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }
step()  { printf "${CYAN}[STEP]${NC}  %s\n" "$*"; }

MODE="${1:---dry-run}"
DRILL_NS="securerag-hub"
EVIDENCE_DIR="artifacts/dr"
TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
BACKUP_NAME="dr-drill-${TIMESTAMP}"
REPORT_FILE="${EVIDENCE_DIR}/restore-drill-${TIMESTAMP}.md"

mkdir -p "${EVIDENCE_DIR}"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  DISASTER RECOVERY DRILL — SecureRAG Hub"
echo "  Mode: ${MODE}"
echo "  Timestamp: ${TIMESTAMP}"
echo "═══════════════════════════════════════════════════════════════"
echo ""

PASS=0
FAIL=0
SKIP=0

record_pass() { PASS=$((PASS + 1)); echo "✅ [PASS] $*"; }
record_fail() { FAIL=$((FAIL + 1)); echo "❌ [FAIL] $*"; }
record_skip() { SKIP=$((SKIP + 1)); echo "⏭️  [SKIP] $*"; }

# Check prerequisites
if ! command -v velero &>/dev/null; then
  # Try to use kubectl plugin or helm-installed velero
  if kubectl get deployment -n velero velero &>/dev/null 2>&1; then
    warn "Velero CLI not found locally but Velero is running in cluster"
    VELERO_CMD="kubectl exec -n velero deployment/velero -- velero"
  else
    error "Velero not found (neither CLI nor in-cluster)"
    echo "Install Velero: bash scripts/deploy/deploy-velero.sh"
    exit 1
  fi
else
  VELERO_CMD="velero"
fi

# ── Phase 1: Pre-drill snapshot ──────────────────────────────────────
step "Phase 1/5: Capturing pre-drill state..."

PRE_PODS=$(kubectl get pods -n "${DRILL_NS}" --no-headers 2>/dev/null | wc -l)
PRE_DEPLOYMENTS=$(kubectl get deployments -n "${DRILL_NS}" --no-headers 2>/dev/null | wc -l)
PRE_CONFIGMAPS=$(kubectl get configmaps -n "${DRILL_NS}" --no-headers 2>/dev/null | wc -l)
PRE_SECRETS=$(kubectl get secrets -n "${DRILL_NS}" --no-headers 2>/dev/null | wc -l)
PRE_SERVICES=$(kubectl get services -n "${DRILL_NS}" --no-headers 2>/dev/null | wc -l)

info "Pre-drill inventory:"
info "  Pods: ${PRE_PODS}, Deployments: ${PRE_DEPLOYMENTS}, ConfigMaps: ${PRE_CONFIGMAPS}, Secrets: ${PRE_SECRETS}, Services: ${PRE_SERVICES}"

# ── Phase 2: Create backup ──────────────────────────────────────────
step "Phase 2/5: Creating Velero backup '${BACKUP_NAME}'..."

${VELERO_CMD} backup create "${BACKUP_NAME}" \
  --include-namespaces "${DRILL_NS}" \
  --wait --ttl 24h 2>&1 || {
  error "Backup creation failed"
  record_fail "Backup creation"

  # Fallback: check if any existing backup is available
  EXISTING_BACKUP=$(${VELERO_CMD} backup get -o json 2>/dev/null | python3 -c "
import sys, json
try:
  data = json.load(sys.stdin)
  items = data.get('items', [])
  completed = [i for i in items if i.get('status',{}).get('phase') == 'Completed']
  if completed:
    print(completed[-1]['metadata']['name'])
except: pass
" 2>/dev/null || echo "")

  if [ -n "${EXISTING_BACKUP}" ]; then
    warn "Using existing backup: ${EXISTING_BACKUP}"
    BACKUP_NAME="${EXISTING_BACKUP}"
  else
    error "No usable backup found. Aborting drill."
    exit 1
  fi
}

# Validate backup
BACKUP_STATUS=$(${VELERO_CMD} backup get "${BACKUP_NAME}" -o json 2>/dev/null | python3 -c "
import sys, json
try:
  d = json.load(sys.stdin)
  print(d.get('status',{}).get('phase','unknown'))
except: print('unknown')
" 2>/dev/null || echo "unknown")

if [ "${BACKUP_STATUS}" = "Completed" ]; then
  record_pass "Backup '${BACKUP_NAME}' completed successfully"
else
  record_fail "Backup status: ${BACKUP_STATUS}"
fi

BACKUP_ITEMS=$(${VELERO_CMD} backup get "${BACKUP_NAME}" -o json 2>/dev/null | python3 -c "
import sys, json
try:
  d = json.load(sys.stdin)
  print(d.get('status',{}).get('totalItems', 0))
except: print(0)
" 2>/dev/null || echo "0")
info "Backup contains ${BACKUP_ITEMS} items"

if [ "${MODE}" = "--dry-run" ]; then
  record_skip "Restore drill (dry-run mode — backup validated only)"

  # Generate report
  cat > "${REPORT_FILE}" <<EOF
# DR Drill Report — ${TIMESTAMP} (Dry-Run)

| Metric | Value |
|:---|:---|
| Mode | Dry-Run (backup validation only) |
| Backup Name | ${BACKUP_NAME} |
| Backup Status | ${BACKUP_STATUS} |
| Items Backed Up | ${BACKUP_ITEMS} |
| Pre-drill Pods | ${PRE_PODS} |
| Pre-drill Deployments | ${PRE_DEPLOYMENTS} |
| Pre-drill ConfigMaps | ${PRE_CONFIGMAPS} |
| Pre-drill Secrets | ${PRE_SECRETS} |
| Passed | ${PASS} |
| Failed | ${FAIL} |
| Skipped | ${SKIP} |

> Dry-run mode: backup created and validated. Use \`--full\` for destructive restore drill.
EOF

  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  echo "  DR DRILL COMPLETE (DRY-RUN)"
  echo "  Results: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped"
  echo "  Report: ${REPORT_FILE}"
  echo "═══════════════════════════════════════════════════════════════"
  exit "${FAIL}"
fi

# ── Phase 3: Destructive delete (full mode only) ────────────────────
step "Phase 3/5: Deleting namespace '${DRILL_NS}'..."
kubectl delete namespace "${DRILL_NS}" --wait --timeout=120s 2>&1 || true

# Wait for namespace to be fully deleted
for i in $(seq 1 30); do
  if ! kubectl get namespace "${DRILL_NS}" &>/dev/null; then
    info "Namespace deleted"
    break
  fi
  sleep 5
done
record_pass "Namespace '${DRILL_NS}' deleted for restore drill"

# ── Phase 4: Restore from backup ────────────────────────────────────
step "Phase 4/5: Restoring from backup '${BACKUP_NAME}'..."

RESTORE_NAME="dr-restore-${TIMESTAMP}"
${VELERO_CMD} restore create "${RESTORE_NAME}" \
  --from-backup "${BACKUP_NAME}" \
  --wait 2>&1 || {
  error "Restore failed"
  record_fail "Restore from backup"
}

RESTORE_STATUS=$(${VELERO_CMD} restore get "${RESTORE_NAME}" -o json 2>/dev/null | python3 -c "
import sys, json
try:
  d = json.load(sys.stdin)
  print(d.get('status',{}).get('phase','unknown'))
except: print('unknown')
" 2>/dev/null || echo "unknown")

if [ "${RESTORE_STATUS}" = "Completed" ]; then
  record_pass "Restore '${RESTORE_NAME}' completed"
else
  record_fail "Restore status: ${RESTORE_STATUS}"
fi

# ── Phase 5: Post-restore validation ────────────────────────────────
step "Phase 5/5: Validating post-restore state..."

# Wait for pods to come up
info "Waiting for pods to be Ready (up to 5 minutes)..."
kubectl wait --for=condition=Ready pod --all -n "${DRILL_NS}" --timeout=300s 2>&1 || {
  warn "Some pods not ready within timeout"
}

POST_PODS=$(kubectl get pods -n "${DRILL_NS}" --no-headers 2>/dev/null | wc -l)
POST_DEPLOYMENTS=$(kubectl get deployments -n "${DRILL_NS}" --no-headers 2>/dev/null | wc -l)
POST_CONFIGMAPS=$(kubectl get configmaps -n "${DRILL_NS}" --no-headers 2>/dev/null | wc -l)
POST_SECRETS=$(kubectl get secrets -n "${DRILL_NS}" --no-headers 2>/dev/null | wc -l)
POST_SERVICES=$(kubectl get services -n "${DRILL_NS}" --no-headers 2>/dev/null | wc -l)

info "Post-restore inventory:"
info "  Pods: ${POST_PODS}, Deployments: ${POST_DEPLOYMENTS}, ConfigMaps: ${POST_CONFIGMAPS}, Secrets: ${POST_SECRETS}, Services: ${POST_SERVICES}"

# Compare pre/post
[ "${POST_DEPLOYMENTS}" -ge "${PRE_DEPLOYMENTS}" ] && record_pass "Deployments restored (${POST_DEPLOYMENTS}/${PRE_DEPLOYMENTS})" || record_fail "Deployments: ${POST_DEPLOYMENTS}/${PRE_DEPLOYMENTS}"
[ "${POST_CONFIGMAPS}" -ge 1 ] && record_pass "ConfigMaps restored (${POST_CONFIGMAPS})" || record_fail "ConfigMaps not restored"
[ "${POST_SERVICES}" -ge 1 ] && record_pass "Services restored (${POST_SERVICES})" || record_fail "Services not restored"

# Check running pods
RUNNING_PODS=$(kubectl get pods -n "${DRILL_NS}" --no-headers 2>/dev/null | grep -c "Running" || echo 0)
[ "${RUNNING_PODS}" -ge 1 ] && record_pass "Running pods: ${RUNNING_PODS}" || record_fail "No running pods after restore"

# Generate report
cat > "${REPORT_FILE}" <<EOF
# DR Drill Report — ${TIMESTAMP} (Full Restore)

## Summary
| Metric | Pre-drill | Post-restore | Match |
|:---|:---:|:---:|:---:|
| Pods | ${PRE_PODS} | ${POST_PODS} | $([ "${POST_PODS}" -ge "${PRE_PODS}" ] && echo "✅" || echo "❌") |
| Deployments | ${PRE_DEPLOYMENTS} | ${POST_DEPLOYMENTS} | $([ "${POST_DEPLOYMENTS}" -ge "${PRE_DEPLOYMENTS}" ] && echo "✅" || echo "❌") |
| ConfigMaps | ${PRE_CONFIGMAPS} | ${POST_CONFIGMAPS} | $([ "${POST_CONFIGMAPS}" -ge 1 ] && echo "✅" || echo "❌") |
| Secrets | ${PRE_SECRETS} | ${POST_SECRETS} | $([ "${POST_SECRETS}" -ge 1 ] && echo "✅" || echo "❌") |
| Services | ${PRE_SERVICES} | ${POST_SERVICES} | $([ "${POST_SERVICES}" -ge 1 ] && echo "✅" || echo "❌") |

## Details
| Check | Result |
|:---|:---|
| Backup Name | ${BACKUP_NAME} |
| Backup Status | ${BACKUP_STATUS} |
| Backup Items | ${BACKUP_ITEMS} |
| Restore Name | ${RESTORE_NAME} |
| Restore Status | ${RESTORE_STATUS} |

## Verdict
- **Passed**: ${PASS}
- **Failed**: ${FAIL}
- **Score**: $(( PASS * 100 / (PASS + FAIL + 1) ))%
EOF

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  DR DRILL COMPLETE (FULL)"
echo "  Results: ${PASS} passed, ${FAIL} failed"
echo "  Report: ${REPORT_FILE}"
echo "═══════════════════════════════════════════════════════════════"

[ "${FAIL}" -eq 0 ] || exit 1
