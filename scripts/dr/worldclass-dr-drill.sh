#!/usr/bin/env bash
# worldclass-dr-drill.sh — World-Class Disaster Recovery Drill (10 phases)
# SecureRAG Hub — World-Class Disaster Recovery
#
# Usage:
#   --dry-run              Backup + validate only (safe for CI)
#   --full --confirm       Full destructive drill (deletes namespaces)
#   --namespace <ns>       Target namespace (default: securerag-hub)
#   --all-namespaces       Drill ALL namespaces (destructive only with --confirm)
#   --skip-report          Skip report generation
#   --verbose              Verbose output
#
# Safety: --full requires --confirm to proceed with destructive phase.
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

info()    { printf "${GREEN}[INFO]${NC}  %s\n" "$*"; }
warn()    { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
error()   { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }
step()    { printf "${CYAN}[STEP]${NC}  %s\n" "$*"; }
detail()  { printf "${BLUE}[DETAIL]${NC} %s\n" "$*"; }
phase()   { printf "\n${MAGENTA}═══════════════════════════════════════════════════════════════${NC}\n"; printf "${MAGENTA}  PHASE %s${NC}\n" "$*"; printf "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}\n"; }

MODE="--dry-run"
TARGET_NS="securerag-hub"
ALL_NS=false
SKIP_REPORT=false
VERBOSE=false
CONFIRMED=false
TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
DRILL_ID="dr-drill-${TIMESTAMP}"
EVIDENCE_DIR="artifacts/dr"
REPORT_FILE="${EVIDENCE_DIR}/${DRILL_ID}-report.md"
EVIDENCE_FILE="${EVIDENCE_DIR}/${DRILL_ID}-evidence.json"
RTO_START=""
RTO_END=""
RPO_SECONDS=0
BACKUP_NAME=""
RESTORE_NAME=""
NAMESPACES=()

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --full) MODE="--full"; shift ;;
    --dry-run) MODE="--dry-run"; shift ;;
    --namespace) TARGET_NS="$2"; shift 2 ;;
    --all-namespaces) ALL_NS=true; shift ;;
    --confirm) CONFIRMED=true; shift ;;
    --skip-report) SKIP_REPORT=true; shift ;;
    --verbose) VERBOSE=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [ "${MODE}" = "--full" ] && [ "${CONFIRMED}" = false ]; then
  error "Destructive mode requires --confirm flag. Aborting."
  echo ""
  echo "  This drill will DELETE all resources in the target namespace(s)."
  echo "  To proceed: bash $0 --full --confirm"
  exit 1
fi

if [ "${ALL_NS}" = true ]; then
  NAMESPACES=("securerag-hub" "vault" "observability" "falco" "argocd")
else
  NAMESPACES=("${TARGET_NS}")
fi

mkdir -p "${EVIDENCE_DIR}"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  WORLD-CLASS DISASTER RECOVERY DRILL"
echo "  Drill ID: ${DRILL_ID}"
echo "  Mode: ${MODE}"
echo "  Target: ${NAMESPACES[*]}"
echo "  Timestamp: ${TIMESTAMP}"
echo "═══════════════════════════════════════════════════════════════"
echo ""

PASS=0
FAIL=0
SKIP=0

record_pass() { PASS=$((PASS + 1)); echo "  ✅ [PASS] $*"; }
record_fail() { FAIL=$((FAIL + 1)); echo "  ❌ [FAIL] $*"; }
record_skip() { SKIP=$((SKIP + 1)); echo "  ⏭️  [SKIP] $*"; }

# ── Helpers ──────────────────────────────────────────────────────

setup_velero_cmd() {
  if command -v velero &>/dev/null; then
    VELERO_CMD="velero"
  elif kubectl get deployment -n velero velero &>/dev/null 2>&1; then
    warn "Velero CLI not found locally but Velero is running in cluster"
    VELERO_CMD="kubectl exec -n velero deployment/velero -- velero"
  else
    error "Velero not found (neither CLI nor in-cluster). Aborting."
    exit 1
  fi
  info "Velero command: ${VELERO_CMD}"
}

inventory_snapshot() {
  local label="$1"
  local dir="${EVIDENCE_DIR}/inventory-${label}-${TIMESTAMP}"
  mkdir -p "${dir}"

  for ns in "${NAMESPACES[@]}"; do
    detail "Inventory for namespace '${ns}' (${label})..."
    kubectl get pods -n "${ns}" --no-headers -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[*].ready 2>/dev/null > "${dir}/pods-${ns}.txt" || true
    kubectl get deployments -n "${ns}" --no-headers -o custom-columns=NAME:.metadata.name,REPLICAS:.spec.replicas 2>/dev/null > "${dir}/deployments-${ns}.txt" || true
    kubectl get configmaps -n "${ns}" --no-headers -o custom-columns=NAME:.metadata.name 2>/dev/null > "${dir}/configmaps-${ns}.txt" || true
    kubectl get secrets -n "${ns}" --no-headers -o custom-columns=NAME:.metadata.name 2>/dev/null > "${dir}/secrets-${ns}.txt" || true
    kubectl get services -n "${ns}" --no-headers -o custom-columns=NAME:.metadata.name,TYPE:.spec.type 2>/dev/null > "${dir}/services-${ns}.txt" || true
    kubectl get pvc -n "${ns}" --no-headers -o custom-columns=NAME:.metadata.name,VOLUME:.spec.volumeName,CAPACITY:.spec.resources.requests.storage 2>/dev/null > "${dir}/pvcs-${ns}.txt" || true
  done

  # Cluster-level resources
  kubectl get pv --no-headers -o custom-columns=NAME:.metadata.name,CAPACITY:.spec.capacity.storage,STATUS:.status.phase 2>/dev/null > "${dir}/pv-cluster.txt" || true

  echo "${dir}"
}

count_inventory() {
  local dir="$1"
  local ns="$2"
  local resource="$3"
  if [ -f "${dir}/${resource}-${ns}.txt" ]; then
    wc -l < "${dir}/${resource}-${ns}.txt"
  else
    echo 0
  fi
}

wait_for_namespace_deleted() {
  local ns="$1"
  local timeout=180
  info "Waiting up to ${timeout}s for namespace '${ns}' to be deleted..."
  for i in $(seq 1 "${timeout}"); do
    if ! kubectl get namespace "${ns}" &>/dev/null; then
      info "Namespace '${ns}' fully deleted (${i}s)"
      return 0
    fi
    sleep 1
  done
  warn "Namespace '${ns}' not fully deleted after ${timeout}s"
  return 1
}

wait_for_all_pods_ready() {
  local timeout="$1"
  shift
  local namespaces=("$@")
  local start_epoch
  start_epoch=$(date +%s)

  for ns in "${namespaces[@]}"; do
    info "Waiting for pods in '${ns}' to be Ready (up to ${timeout}s)..."
    kubectl wait --for=condition=Ready pod --all -n "${ns}" --timeout="${timeout}s" 2>&1 || true
  done

  local end_epoch
  end_epoch=$(date +%s)
  echo $(( end_epoch - start_epoch ))
}

check_service_health() {
  local ns="$1"
  local svc="$2"
  local expected="$3"

  local svc_type
  svc_type=$(kubectl get svc -n "${ns}" "${svc}" -o jsonpath='{.spec.type}' 2>/dev/null || echo "")

  if [ -z "${svc_type}" ]; then
    record_fail "Service '${svc}' not found in '${ns}'"
    return 1
  fi

  info "Checking service '${svc}' (type: ${svc_type})..."

  if [ "${svc_type}" = "ClusterIP" ] || [ "${svc_type}" = "NodePort" ]; then
    local endpoints
    endpoints=$(kubectl get endpoints -n "${ns}" "${svc}" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || echo "")
    if [ -n "${endpoints}" ]; then
      record_pass "Service '${svc}' has healthy endpoints in '${ns}'"
      return 0
    else
      record_fail "Service '${svc}' has NO endpoints in '${ns}'"
      return 1
    fi
  fi

  record_skip "Service health check for '${svc}' (type: ${svc_type})"
}

# ── Phase 1: Pre-drill Inventory ─────────────────────────────────

phase "1/10: Pre-drill Inventory"

PRE_INVENTORY_DIR=$(inventory_snapshot "pre")

for ns in "${NAMESPACES[@]}"; do
  echo ""
  info "Namespace: ${ns}"
  p=$(count_inventory "${PRE_INVENTORY_DIR}" "${ns}" pods)
  d=$(count_inventory "${PRE_INVENTORY_DIR}" "${ns}" deployments)
  c=$(count_inventory "${PRE_INVENTORY_DIR}" "${ns}" configmaps)
  s=$(count_inventory "${PRE_INVENTORY_DIR}" "${ns}" secrets)
  v=$(count_inventory "${PRE_INVENTORY_DIR}" "${ns}" services)
  echo "    Pods: ${p}, Deployments: ${d}, ConfigMaps: ${c}, Secrets: ${s}, Services: ${v}"
done

record_pass "Pre-drill inventory captured (${#NAMESPACES[@]} namespaces)"

# ── Phase 2: Create Velero Backup ────────────────────────────────

phase "2/10: Create Velero Backup"

setup_velero_cmd

BACKUP_NAME="${DRILL_ID}"
NS_LIST=$(IFS=,; echo "${NAMESPACES[*]}")

info "Creating backup '${BACKUP_NAME}' for namespaces: ${NS_LIST}"

${VELERO_CMD} backup create "${BACKUP_NAME}" \
  --include-namespaces "${NS_LIST}" \
  --wait \
  --ttl 168h 2>&1 || {
  error "Backup creation failed"
  record_fail "Backup creation"

  # Fallback: use existing backup
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

RTO_START=$(date -u +%s)

record_pass "Backup '${BACKUP_NAME}' created"

# ── Phase 3: Validate Backup ─────────────────────────────────────

phase "3/10: Validate Backup"

BACKUP_STATUS=$(${VELERO_CMD} backup get "${BACKUP_NAME}" -o json 2>/dev/null | python3 -c "
import sys, json
try:
  d = json.load(sys.stdin)
  print(d.get('status',{}).get('phase','unknown'))
except: print('unknown')
" 2>/dev/null || echo "unknown")

BACKUP_ITEMS=$(${VELERO_CMD} backup get "${BACKUP_NAME}" -o json 2>/dev/null | python3 -c "
import sys, json
try:
  d = json.load(sys.stdin)
  print(d.get('status',{}).get('totalItems', 0))
except: print(0)
" 2>/dev/null || echo "0")

BACKUP_ERRORS=$(${VELERO_CMD} backup get "${BACKUP_NAME}" -o json 2>/dev/null | python3 -c "
import sys, json
try:
  d = json.load(sys.stdin)
  print(d.get('status',{}).get('errors', 0))
except: print(0)
" 2>/dev/null || echo "0")

BACKUP_WARNINGS=$(${VELERO_CMD} backup get "${BACKUP_NAME}" -o json 2>/dev/null | python3 -c "
import sys, json
try:
  d = json.load(sys.stdin)
  print(d.get('status',{}).get('warnings', 0))
except: print(0)
" 2>/dev/null || echo "0")

info "Backup: ${BACKUP_NAME}"
info "Status: ${BACKUP_STATUS}"
info "Items:  ${BACKUP_ITEMS}"
info "Errors: ${BACKUP_ERRORS}"
info "Warnings: ${BACKUP_WARNINGS}"

if [ "${BACKUP_STATUS}" = "Completed" ]; then
  record_pass "Backup completed successfully"
else
  record_fail "Backup status is '${BACKUP_STATUS}'"
fi

if [ "${BACKUP_ERRORS}" -eq 0 ]; then
  record_pass "Backup has zero errors"
else
  record_fail "Backup has ${BACKUP_ERRORS} errors"
fi

if [ "${BACKUP_ITEMS}" -gt 0 ]; then
  record_pass "Backup contains ${BACKUP_ITEMS} items"
else
  record_fail "Backup has zero items"
fi

# If dry-run, stop here
if [ "${MODE}" = "--dry-run" ]; then
  echo ""
  warn "═══════════════════════════════════════════════════════════════"
  warn "  DRY-RUN MODE — Backup validated, skipping destructive phases"
  warn "  To run full destructive drill: bash $0 --full --confirm"
  warn "═══════════════════════════════════════════════════════════════"

  if [ "${SKIP_REPORT}" = false ]; then
    cat > "${REPORT_FILE}" <<EOF
# World-Class DR Drill Report — ${TIMESTAMP} (Dry-Run)

## Drill Details
| Attribute | Value |
|:---|:---|
| Drill ID | ${DRILL_ID} |
| Mode | Dry-Run (backup only) |
| Target Namespaces | ${NAMESPACES[*]} |
| Timestamp | ${TIMESTAMP} |

## Phase Results
| Phase | Result |
|:---|:---:|
| Phase 1: Pre-drill Inventory | ✅ |
| Phase 2: Backup Creation | ✅ |
| Phase 3: Backup Validation | $([ "${FAIL}" -eq 0 ] && echo "✅" || echo "❌") |

## Backup Details
| Metric | Value |
|:---|:---|
| Backup Name | ${BACKUP_NAME} |
| Backup Status | ${BACKUP_STATUS} |
| Items Backed Up | ${BACKUP_ITEMS} |
| Errors | ${BACKUP_ERRORS} |
| Warnings | ${BACKUP_WARNINGS} |

## Summary
- **Passed**: ${PASS}
- **Failed**: ${FAIL}
- **Skipped**: ${SKIP}

> Dry-run completed. Run \`--full --confirm\` for destructive restore drill.
EOF
  fi

  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  echo "  DRILL COMPLETE (DRY-RUN)"
  echo "  Results: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped"
  echo "  Report: ${REPORT_FILE}"
  echo "═══════════════════════════════════════════════════════════════"
  exit "${FAIL}"
fi

# ── Phase 4: Destructive Delete ──────────────────────────────────

phase "4/10: Destructive Delete"

for ns in "${NAMESPACES[@]}"; do
  step "Deleting namespace '${ns}'..."
  kubectl delete namespace "${ns}" --wait=false 2>&1 || true
done

# Wait for all namespaces to be deleted
for ns in "${NAMESPACES[@]}"; do
  wait_for_namespace_deleted "${ns}" || record_fail "Namespace '${ns}' not deleted"
done

record_pass "All target namespaces deleted for restore drill"

# ── Phase 5: Full Restore ────────────────────────────────────────

phase "5/10: Full Restore from Velero"

RESTORE_NAME="restore-${DRILL_ID}"

info "Restoring from backup '${BACKUP_NAME}'..."
${VELERO_CMD} restore create "${RESTORE_NAME}" \
  --from-backup "${BACKUP_NAME}" \
  --wait 2>&1 || {
  error "Restore failed"
  record_fail "Restore from backup"
  # Continue to collect what we can
}

RESTORE_STATUS=$(${VELERO_CMD} restore get "${RESTORE_NAME}" -o json 2>/dev/null | python3 -c "
import sys, json
try:
  d = json.load(sys.stdin)
  print(d.get('status',{}).get('phase','unknown'))
except: print('unknown')
" 2>/dev/null || echo "unknown")

RESTORE_ERRORS=$(${VELERO_CMD} restore get "${RESTORE_NAME}" -o json 2>/dev/null | python3 -c "
import sys, json
try:
  d = json.load(sys.stdin)
  print(d.get('status',{}).get('errors', 0))
except: print(0)
" 2>/dev/null || echo "0")

info "Restore: ${RESTORE_NAME}"
info "Status: ${RESTORE_STATUS}"
info "Errors: ${RESTORE_ERRORS}"

if [ "${RESTORE_STATUS}" = "Completed" ]; then
  record_pass "Restore completed successfully"
else
  record_fail "Restore status is '${RESTORE_STATUS}'"
fi

if [ "${RESTORE_ERRORS}" -eq 0 ]; then
  record_pass "Restore has zero errors"
else
  record_fail "Restore has ${RESTORE_ERRORS} errors"
fi

# ── Phase 6: Post-Restore Validation ─────────────────────────────

phase "6/10: Post-Restore Validation"

# Wait for pods
RTO_ELAPSED=$(wait_for_all_pods_ready 300 "${NAMESPACES[@]}")
RTO_END=$(date -u +%s)

POST_INVENTORY_DIR=$(inventory_snapshot "post")

for ns in "${NAMESPACES[@]}"; do
  echo ""
  info "Namespace: ${ns}"
  p=$(count_inventory "${POST_INVENTORY_DIR}" "${ns}" pods)
  d=$(count_inventory "${POST_INVENTORY_DIR}" "${ns}" deployments)
  c=$(count_inventory "${POST_INVENTORY_DIR}" "${ns}" configmaps)
  s=$(count_inventory "${POST_INVENTORY_DIR}" "${ns}" secrets)
  v=$(count_inventory "${POST_INVENTORY_DIR}" "${ns}" services)

  pre_p=$(count_inventory "${PRE_INVENTORY_DIR}" "${ns}" pods)
  pre_d=$(count_inventory "${PRE_INVENTORY_DIR}" "${ns}" deployments)
  pre_c=$(count_inventory "${PRE_INVENTORY_DIR}" "${ns}" configmaps)
  pre_s=$(count_inventory "${PRE_INVENTORY_DIR}" "${ns}" secrets)
  pre_v=$(count_inventory "${PRE_INVENTORY_DIR}" "${ns}" services)

  echo "    Pods: ${p}/${pre_p}"
  echo "    Deployments: ${d}/${pre_d}"
  echo "    ConfigMaps: ${c}/${pre_c}"
  echo "    Secrets: ${s}/${pre_s}"
  echo "    Services: ${v}/${pre_v}"

  # Validation
  [ "${d}" -ge 1 ] && record_pass "Deployments restored in '${ns}' (${d})" || record_fail "No deployments in '${ns}'"
  [ "${c}" -ge 1 ] && record_pass "ConfigMaps restored in '${ns}' (${c})" || record_fail "No ConfigMaps in '${ns}'"
  [ "${s}" -ge 1 ] && record_pass "Secrets restored in '${ns}' (${s})" || record_fail "No Secrets in '${ns}'"
  [ "${v}" -ge 1 ] && record_pass "Services restored in '${ns}' (${v})" || record_fail "No Services in '${ns}'"
done

# Pod health
for ns in "${NAMESPACES[@]}"; do
  RUNNING=$(kubectl get pods -n "${ns}" --no-headers 2>/dev/null | grep -c "Running" || echo 0)
  TOTAL=$(kubectl get pods -n "${ns}" --no-headers 2>/dev/null | wc -l || echo 0)
  if [ "${TOTAL}" -gt 0 ]; then
    READY_PERCENT=$(( RUNNING * 100 / TOTAL ))
    info "Pods in '${ns}': ${RUNNING}/${TOTAL} Running (${READY_PERCENT}%)"
    [ "${RUNNING}" -eq "${TOTAL}" ] && record_pass "All pods Running in '${ns}'" || record_fail "Not all pods Running in '${ns}' (${RUNNING}/${TOTAL})"
  else
    record_fail "No pods found in '${ns}' after restore"
  fi
done

record_pass "Post-restore inventory comparison complete"

# ── Phase 7: RPO Calculation ─────────────────────────────────────

phase "7/10: RPO Calculation"

# Get last backup time before this drill
LAST_BACKUP_TIME=$(${VELERO_CMD} backup get -o json 2>/dev/null | python3 -c "
import sys, json, datetime, os
try:
  data = json.load(sys.stdin)
  items = data.get('items', [])
  completed = [i for i in items if i.get('status',{}).get('phase') == 'Completed' and i['metadata']['name'] != '${BACKUP_NAME}']
  if completed:
    ts = completed[-1]['metadata']['creationTimestamp']
    print(ts)
except: pass
" 2>/dev/null || echo "")

if [ -n "${LAST_BACKUP_TIME}" ]; then
  CURRENT_EPOCH=$(date +%s)
  BACKUP_EPOCH=$(date -d "${LAST_BACKUP_TIME}" +%s 2>/dev/null || echo 0)
  if [ "${BACKUP_EPOCH}" -gt 0 ]; then
    RPO_SECONDS=$(( CURRENT_EPOCH - BACKUP_EPOCH ))
    RPO_HOURS=$(( RPO_SECONDS / 3600 ))
    RPO_MINUTES=$(( (RPO_SECONDS % 3600) / 60 ))
    info "Last backup: ${LAST_BACKUP_TIME}"
    info "RPO: ${RPO_HOURS}h ${RPO_MINUTES}m (${RPO_SECONDS}s)"
    if [ "${RPO_HOURS}" -lt 24 ]; then
      record_pass "RPO within SLO: ${RPO_HOURS}h (target < 24h)"
    else
      record_fail "RPO exceeds SLO: ${RPO_HOURS}h (target < 24h)"
    fi
  else
    warn "Could not parse backup timestamp"
    record_skip "RPO calculation"
  fi
else
  info "No previous backup found (this is the first)"
  RPO_SECONDS=0
  record_skip "RPO calculation (no prior backup)"
fi

# ── Phase 8: RTO Measurement ─────────────────────────────────────

phase "8/10: RTO Measurement"

if [ -n "${RTO_START}" ] && [ -n "${RTO_END}" ]; then
  RTO_TOTAL=$(( RTO_END - RTO_START ))
  RTO_MINUTES=$(( RTO_TOTAL / 60 ))
  RTO_SECONDS_REMAIN=$(( RTO_TOTAL % 60 ))
  info "Restore start: $(date -u -d @${RTO_START} 2>/dev/null || echo 'N/A')"
  info "All pods Ready: $(date -u -d @${RTO_END} 2>/dev/null || echo 'N/A')"
  info "RTO: ${RTO_MINUTES}m ${RTO_SECONDS_REMAIN}s (${RTO_TOTAL}s)"

  if [ "${RTO_TOTAL}" -lt 600 ]; then
    record_pass "RTO within SLO: ${RTO_TOTAL}s (target < 600s / 10min)"
  else
    record_fail "RTO exceeds SLO: ${RTO_TOTAL}s (target < 600s / 10min)"
  fi
else
  warn "RTO timestamps not available"
  record_skip "RTO measurement"
fi

# ── Phase 9: Service-Level Validation ────────────────────────────

phase "9/10: Service-Level Validation"

# Define services to validate — service name -> expected status
declare -A SERVICES
SERVICES=(
  ["portal-web"]="ClusterIP"
  ["auth-users"]="ClusterIP"
  ["chatbot-manager"]="ClusterIP"
  ["conversation-service"]="ClusterIP"
  ["audit-security-service"]="ClusterIP"
)

for ns in "${NAMESPACES[@]}"; do
  for svc in "${!SERVICES[@]}"; do
    check_service_health "${ns}" "${svc}" "${SERVICES[$svc]}"
  done
done

# ── Phase 10: Generate Report ────────────────────────────────────

phase "10/10: Generate Report"

DRILL_PASS=true
if [ "${FAIL}" -gt 0 ]; then
  DRILL_PASS=false
fi

PASS_PCT=0
TOTAL_CHECKS=$(( PASS + FAIL ))
if [ "${TOTAL_CHECKS}" -gt 0 ]; then
  PASS_PCT=$(( PASS * 100 / TOTAL_CHECKS ))
fi

# Save evidence JSON
cat > "${EVIDENCE_FILE}" <<EOF
{
  "drillId": "${DRILL_ID}",
  "timestamp": "${TIMESTAMP}",
  "mode": "${MODE}",
  "target": [$(for ns in "${NAMESPACES[@]}"; do echo -n "\"${ns}\","; done | sed 's/,$//')],
  "backupName": "${BACKUP_NAME}",
  "backupStatus": "${BACKUP_STATUS}",
  "backupItems": ${BACKUP_ITEMS},
  "backupErrors": ${BACKUP_ERRORS},
  "restoreName": "${RESTORE_NAME}",
  "restoreStatus": "${RESTORE_STATUS}",
  "rpoSeconds": ${RPO_SECONDS},
  "rtoSeconds": ${RTO_TOTAL:-0},
  "passed": ${PASS},
  "failed": ${FAIL},
  "skipped": ${SKIP},
  "passPercent": ${PASS_PCT},
  "drillPassed": ${DRILL_PASS}
}
EOF

# Generate report
if [ "${SKIP_REPORT}" = false ]; then
  RPO_HUMAN="N/A"
  if [ "${RPO_SECONDS}" -gt 0 ]; then
    RPO_HOURS=$(( RPO_SECONDS / 3600 ))
    RPO_MIN=$(( (RPO_SECONDS % 3600) / 60 ))
    RPO_HUMAN="${RPO_HOURS}h ${RPO_MIN}m"
  fi

  RTO_HUMAN="N/A"
  if [ -n "${RTO_TOTAL:-}" ] && [ "${RTO_TOTAL:-0}" -gt 0 ]; then
    RTO_MIN=$(( RTO_TOTAL / 60 ))
    RTO_SEC=$(( RTO_TOTAL % 60 ))
    RTO_HUMAN="${RTO_MIN}m ${RTO_SEC}s"
  fi

  cat > "${REPORT_FILE}" <<EOF
# World-Class DR Drill Report — ${TIMESTAMP}

## Drill Details
| Attribute | Value |
|:---|:---|
| Drill ID | ${DRILL_ID} |
| Mode | ${MODE} |
| Target Namespaces | ${NAMESPACES[*]} |
| Timestamp | ${TIMESTAMP} |

## Phase Results
| Phase | Result |
|:---|:---:|
| Phase 1: Pre-drill Inventory | ✅ |
| Phase 2: Backup Creation | ✅ |
| Phase 3: Backup Validation | $([ "${BACKUP_STATUS}" = "Completed" ] && echo "✅" || echo "❌") |
| Phase 4: Destructive Delete | ✅ |
| Phase 5: Full Restore | $([ "${RESTORE_STATUS}" = "Completed" ] && echo "✅" || echo "❌") |
| Phase 6: Post-restore Validation | $([ "${DRILL_PASS}" = true ] && echo "✅" || echo "❌") |
| Phase 7: RPO Calculation | ${RPO_HUMAN} |
| Phase 8: RTO Measurement | ${RTO_HUMAN} |
| Phase 9: Service Validation | $([ "${FAIL}" -eq 0 ] && echo "✅" || echo "❌") |
| Phase 10: Report Generation | ✅ |

## Backup Details
| Metric | Value |
|:---|:---|
| Backup Name | ${BACKUP_NAME} |
| Backup Status | ${BACKUP_STATUS} |
| Items Backed Up | ${BACKUP_ITEMS} |
| Errors | ${BACKUP_ERRORS} |
| Warnings | ${BACKUP_WARNINGS} |

## Restore Details
| Metric | Value |
|:---|:---|
| Restore Name | ${RESTORE_NAME} |
| Restore Status | ${RESTORE_STATUS} |
| Restore Errors | ${RESTORE_ERRORS:-N/A} |

## Recovery Metrics
| Metric | Value | SLO Target | Result |
|:---|:---|:---:|:---:|
| RPO (Recovery Point Objective) | ${RPO_HUMAN} | < 24h | $([ "${RPO_SECONDS}" -gt 0 ] && [ "${RPO_SECONDS}" -lt 86400 ] && echo "✅" || echo "❌") |
| RTO (Recovery Time Objective) | ${RTO_HUMAN} | < 10min | $([ -n "${RTO_TOTAL:-}" ] && [ "${RTO_TOTAL:-0}" -lt 600 ] && echo "✅" || echo "❌") |
| Backup Coverage | ${BACKUP_ITEMS} items | > 0 items | $([ "${BACKUP_ITEMS}" -gt 0 ] && echo "✅" || echo "❌") |
| Service Health | 5 services | 5/5 healthy | $([ "${FAIL}" -eq 0 ] && echo "✅" || echo "❌") |

## Inventory Comparison
| Namespace | Pods (Pre/Post) | Deployments | ConfigMaps | Secrets | Services |
|:---|:---:|:---:|:---:|:---:|:---:|
$(for ns in "${NAMESPACES[@]}"; do
  pre_p=$(count_inventory "${PRE_INVENTORY_DIR}" "${ns}" pods)
  post_p=$(count_inventory "${POST_INVENTORY_DIR}" "${ns}" pods)
  pre_d=$(count_inventory "${PRE_INVENTORY_DIR}" "${ns}" deployments)
  post_d=$(count_inventory "${POST_INVENTORY_DIR}" "${ns}" deployments)
  pre_c=$(count_inventory "${PRE_INVENTORY_DIR}" "${ns}" configmaps)
  post_c=$(count_inventory "${POST_INVENTORY_DIR}" "${ns}" configmaps)
  pre_s=$(count_inventory "${PRE_INVENTORY_DIR}" "${ns}" secrets)
  post_s=$(count_inventory "${POST_INVENTORY_DIR}" "${ns}" secrets)
  pre_v=$(count_inventory "${PRE_INVENTORY_DIR}" "${ns}" services)
  post_v=$(count_inventory "${POST_INVENTORY_DIR}" "${ns}" services)
  echo "| ${ns} | ${pre_p}/${post_p} | ${post_d} | ${post_c} | ${post_s} | ${post_v} |"
done)

## Verdict
- **Passed Checks**: ${PASS}
- **Failed Checks**: ${FAIL}
- **Skipped Checks**: ${SKIP}
- **Pass Rate**: ${PASS_PCT}%
- **Overall**: $([ "${DRILL_PASS}" = true ] && echo "✅ PASS" || echo "❌ FAIL")

> Evidence saved to: ${EVIDENCE_FILE}
> Inventory snapshots: pre=${PRE_INVENTORY_DIR}, post=${POST_INVENTORY_DIR}
EOF

  info "Report written to ${REPORT_FILE}"
  info "Evidence written to ${EVIDENCE_FILE}"
fi

# ── Final Summary ────────────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  WORLD-CLASS DR DRILL COMPLETE"
echo "  Mode: ${MODE}"
echo "  Passed: ${PASS} | Failed: ${FAIL} | Skipped: ${SKIP}"
echo "  Pass Rate: ${PASS_PCT}%"
if [ -n "${RTO_TOTAL:-}" ]; then
  echo "  RTO: ${RTO_TOTAL}s | RPO: ${RPO_SECONDS}s"
fi
echo "  Report: ${REPORT_FILE}"
echo "═══════════════════════════════════════════════════════════════"

if [ "${DRILL_PASS}" = true ]; then
  echo "  ✅ DRILL PASSED"
else
  echo "  ❌ DRILL FAILED — ${FAIL} checks failed"
fi
echo ""

exit "${FAIL}"
