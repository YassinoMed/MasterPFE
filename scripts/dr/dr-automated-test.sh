#!/usr/bin/env bash
# dr-automated-test.sh — Automated DR test for Jenkins/GitLab pipeline
# SecureRAG Hub — World-Class Disaster Recovery
#
# Non-destructive: creates backup, validates, measures RTO, cleans up.
# Outputs JUnit-compatible XML for CI pipeline gating.
#
# Usage:
#   bash scripts/dr/dr-automated-test.sh
#   bash scripts/dr/dr-automated-test.sh --namespace securerag-hub
#   bash scripts/dr/dr-automated-test.sh --junit-output results/dr-test.xml
#   bash scripts/dr/dr-automated-test.sh --slack-webhook https://hooks.slack.com/...
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { printf "${GREEN}[INFO]${NC}  %s\n" "$*"; }
warn()    { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
error()   { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }
step()    { printf "${CYAN}[STEP]${NC}  %s\n" "$*"; }

NAMESPACE="securerag-hub"
JUNIT_OUTPUT=""
SLACK_WEBHOOK=""
TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
BACKUP_NAME="dr-auto-${TIMESTAMP}"
RESTORE_NS="dr-auto-test-$(date +%Y%m%d-%H%M%S)"
EVIDENCE_DIR="artifacts/dr"
RTO_SLO=300
PIPELINE_PASS=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --junit-output) JUNIT_OUTPUT="$2"; shift 2 ;;
    --slack-webhook) SLACK_WEBHOOK="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

mkdir -p "${EVIDENCE_DIR}"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  AUTOMATED DR TEST — Pipeline Integration"
echo "  Timestamp: ${TIMESTAMP}"
echo "  Namespace: ${NAMESPACE}"
echo "  RTO SLO: ${RTO_SLO}s"
echo "═══════════════════════════════════════════════════════════════"
echo ""

START_TIME=$(date +%s)
PASS=0
FAIL=0
RTO_ACTUAL=0

record_pass() { PASS=$((PASS + 1)); echo "  ✅ [PASS] $*"; }
record_fail() { FAIL=$((FAIL + 1)); PIPELINE_PASS=false; echo "  ❌ [FAIL] $*"; }

# ── 1. Check prerequisites ─────────────────────────────────────

step "1/7: Checking prerequisites"

for cmd in kubectl velero jq; do
  if command -v "${cmd}" &>/dev/null; then
    record_pass "Prerequisite '${cmd}' available"
  else
    record_fail "Prerequisite '${cmd}' not found"
  fi
done

if ! kubectl get namespace "${NAMESPACE}" &>/dev/null; then
  record_fail "Namespace '${NAMESPACE}' does not exist"
fi

if ! kubectl get deployment -n velero velero &>/dev/null; then
  record_fail "Velero not deployed in cluster"
fi

# ── 2. Create backup ───────────────────────────────────────────

step "2/7: Creating backup '${BACKUP_NAME}'"

velero backup create "${BACKUP_NAME}" \
  --include-namespaces "${NAMESPACE}" \
  --wait \
  --ttl 4h 2>&1 || {
  record_fail "Backup creation failed"
}

BACKUP_STATUS=$(velero backup get "${BACKUP_NAME}" -o json 2>/dev/null | jq -r '.status.phase' 2>/dev/null || echo "unknown")
BACKUP_ITEMS=$(velero backup get "${BACKUP_NAME}" -o json 2>/dev/null | jq -r '.status.totalItems // 0' 2>/dev/null || echo "0")
BACKUP_ERRORS=$(velero backup get "${BACKUP_NAME}" -o json 2>/dev/null | jq -r '.status.errors // 0' 2>/dev/null || echo "0")

if [ "${BACKUP_STATUS}" = "Completed" ] && [ "${BACKUP_ITEMS}" -gt 0 ] && [ "${BACKUP_ERRORS}" -eq 0 ]; then
  record_pass "Backup '${BACKUP_NAME}' completed (${BACKUP_ITEMS} items, 0 errors)"
else
  record_fail "Backup issues: status=${BACKUP_STATUS}, items=${BACKUP_ITEMS}, errors=${BACKUP_ERRORS}"
fi

# ── 3. Validate backup ─────────────────────────────────────────

step "3/7: Validating backup integrity"

BACKUP_WARNINGS=$(velero backup get "${BACKUP_NAME}" -o json 2>/dev/null | jq -r '.status.warnings // 0' 2>/dev/null || echo "0")

info "Backup: ${BACKUP_NAME} | Status: ${BACKUP_STATUS} | Items: ${BACKUP_ITEMS} | Errors: ${BACKUP_ERRORS} | Warnings: ${BACKUP_WARNINGS}"

if [ "${BACKUP_WARNINGS}" -gt 0 ]; then
  warn "Backup has ${BACKUP_WARNINGS} warnings — investigate"
fi

if [ "${BACKUP_ITEMS}" -gt 0 ]; then
  record_pass "Backup contains ${BACKUP_ITEMS} items"
else
  record_fail "Backup has zero items"
fi

# ── 4. Restore to test namespace ───────────────────────────────

step "4/7: Restoring to test namespace '${RESTORE_NS}'"

RESTORE_NAME="dr-auto-restore-${TIMESTAMP}"
RESTORE_START=$(date +%s)

velero restore create "${RESTORE_NAME}" \
  --from-backup "${BACKUP_NAME}" \
  --namespace-mappings "${NAMESPACE}:${RESTORE_NS}" \
  --wait 2>&1 || {
  record_fail "Restore to test namespace failed"
}

RESTORE_STATUS=$(velero restore get "${RESTORE_NAME}" -o json 2>/dev/null | jq -r '.status.phase' 2>/dev/null || echo "unknown")
RESTORE_ERRORS=$(velero restore get "${RESTORE_NAME}" -o json 2>/dev/null | jq -r '.status.errors // 0' 2>/dev/null || echo "0")

if [ "${RESTORE_STATUS}" = "Completed" ] && [ "${RESTORE_ERRORS}" -eq 0 ]; then
  record_pass "Restore '${RESTORE_NAME}' completed with 0 errors"
else
  record_fail "Restore issues: status=${RESTORE_STATUS}, errors=${RESTORE_ERRORS}"
fi

# ── 5. Measure RTO for pod recovery ────────────────────────────

step "5/7: Measuring RTO for pod recovery in '${RESTORE_NS}'"

info "Waiting for pods to be Ready (up to ${RTO_SLO}s)..."
kubectl wait --for=condition=Ready pod --all -n "${RESTORE_NS}" --timeout="${RTO_SLO}s" 2>&1 || {
  warn "Some pods not ready within RTO SLO"
}

RESTORE_END=$(date +%s)
RTO_ACTUAL=$(( RESTORE_END - RESTORE_START ))

RUNNING=$(kubectl get pods -n "${RESTORE_NS}" --no-headers 2>/dev/null | grep -c "Running" || echo 0)
TOTAL=$(kubectl get pods -n "${RESTORE_NS}" --no-headers 2>/dev/null | wc -l || echo 0)

info "RTO actual: ${RTO_ACTUAL}s | Pods: ${RUNNING}/${TOTAL} Running"

if [ "${RTO_ACTUAL}" -le "${RTO_SLO}" ]; then
  record_pass "RTO ${RTO_ACTUAL}s within SLO ${RTO_SLO}s"
else
  record_fail "RTO ${RTO_ACTUAL}s exceeds SLO ${RTO_SLO}s"
fi

if [ "${RUNNING}" -eq "${TOTAL}" ] && [ "${TOTAL}" -gt 0 ]; then
  record_pass "All ${TOTAL} pods Running in test namespace"
else
  record_fail "Pod health: ${RUNNING}/${TOTAL} Running"
fi

# ── 6. Validate SLO compliance ─────────────────────────────────

step "6/7: Validating SLO compliance"

SLO_PASS=true

# RTO SLO
if [ "${RTO_ACTUAL}" -le "${RTO_SLO}" ]; then
  record_pass "RTO SLO: ${RTO_ACTUAL}s <= ${RTO_SLO}s"
else
  record_fail "RTO SLO: ${RTO_ACTUAL}s > ${RTO_SLO}s"
  SLO_PASS=false
fi

# Backup integrity SLO
if [ "${BACKUP_ERRORS}" -eq 0 ] && [ "${BACKUP_ITEMS}" -gt 0 ]; then
  record_pass "Backup integrity SLO: 0 errors, ${BACKUP_ITEMS} items"
else
  record_fail "Backup integrity SLO violated"
  SLO_PASS=false
fi

# Restore integrity SLO
if [ "${RESTORE_ERRORS}" -eq 0 ] && [ "${RESTORE_STATUS}" = "Completed" ]; then
  record_pass "Restore integrity SLO: 0 errors, completed"
else
  record_fail "Restore integrity SLO violated"
  SLO_PASS=false
fi

if [ "${SLO_PASS}" = true ]; then
  record_pass "All SLOs met"
else
  record_fail "One or more SLOs violated"
fi

# ── 6b. Cleanup test namespace ─────────────────────────────────

step "Cleaning up test namespace '${RESTORE_NS}'..."
kubectl delete namespace "${RESTORE_NS}" --wait=false 2>/dev/null || true
info "Cleanup initiated (async)"

# ── 7. Output results — JUnit + Slack notification ─────────────

step "7/7: Outputting results"

END_TIME=$(date +%s)
TOTAL_TIME=$(( END_TIME - START_TIME ))

# JUnit XML output
if [ -n "${JUNIT_OUTPUT}" ]; then
  JUNIT_DIR=$(dirname "${JUNIT_OUTPUT}")
  mkdir -p "${JUNIT_DIR}"

  TOTAL_TESTS=$(( PASS + FAIL ))

  cat > "${JUNIT_OUTPUT}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="dr-automated-test" tests="${TOTAL_TESTS}" failures="${FAIL}" time="${TOTAL_TIME}">
  <testcase classname="DR.1" name="Prerequisites" time="1">
EOF
  if command -v kubectl &>/dev/null && command -v velero &>/dev/null; then
    echo '    <system-out>All prerequisites available</system-out>' >> "${JUNIT_OUTPUT}"
  else
    echo '    <failure message="Prerequisites not met"/>' >> "${JUNIT_OUTPUT}"
  fi
  cat >> "${JUNIT_OUTPUT}" <<EOF
  </testcase>
  <testcase classname="DR.2" name="Backup Creation" time="${TOTAL_TIME}">
EOF
  if [ "${BACKUP_STATUS}" = "Completed" ]; then
    echo "    <system-out>Backup ${BACKUP_NAME}: ${BACKUP_ITEMS} items</system-out>" >> "${JUNIT_OUTPUT}"
  else
    echo '    <failure message="Backup failed"/>' >> "${JUNIT_OUTPUT}"
  fi
  cat >> "${JUNIT_OUTPUT}" <<EOF
  </testcase>
  <testcase classname="DR.3" name="Restore" time="${RTO_ACTUAL}">
EOF
  if [ "${RESTORE_STATUS}" = "Completed" ]; then
    echo "    <system-out>Restore ${RESTORE_NAME}: RTO=${RTO_ACTUAL}s</system-out>" >> "${JUNIT_OUTPUT}"
  else
    echo '    <failure message="Restore failed"/>' >> "${JUNIT_OUTPUT}"
  fi
  cat >> "${JUNIT_OUTPUT}" <<EOF
  </testcase>
  <testcase classname="DR.4" name="RTO SLO (${RTO_SLO}s)" time="${RTO_ACTUAL}">
EOF
  if [ "${RTO_ACTUAL}" -le "${RTO_SLO}" ]; then
    echo "    <system-out>RTO ${RTO_ACTUAL}s <= ${RTO_SLO}s SLO</system-out>" >> "${JUNIT_OUTPUT}"
  else
    echo "    <failure message=\"RTO ${RTO_ACTUAL}s exceeds SLO ${RTO_SLO}s\"/>" >> "${JUNIT_OUTPUT}"
  fi
  cat >> "${JUNIT_OUTPUT}" <<EOF
  </testcase>
  <testcase classname="DR.5" name="Backup Integrity (0 errors)" time="1">
EOF
  if [ "${BACKUP_ERRORS}" -eq 0 ]; then
    echo '    <system-out>0 errors</system-out>' >> "${JUNIT_OUTPUT}"
  else
    echo "    <failure message=\"${BACKUP_ERRORS} errors\"/>" >> "${JUNIT_OUTPUT}"
  fi
  echo '  </testcase>' >> "${JUNIT_OUTPUT}"
  echo '</testsuite>' >> "${JUNIT_OUTPUT}"

  info "JUnit report: ${JUNIT_OUTPUT}"
fi

# Slack notification (on failure)
if [ -n "${SLACK_WEBHOOK}" ] && [ "${PIPELINE_PASS}" = false ]; then
  info "Sending Slack notification..."
  curl -s -X POST "${SLACK_WEBHOOK}" \
    -H "Content-Type: application/json" \
    -d "{
      \"text\": \"❌ *DR Automated Test Failed*\nBackup: ${BACKUP_NAME}\nRTO: ${RTO_ACTUAL}s\nNamespace: ${NAMESPACE}\nPassed: ${PASS} | Failed: ${FAIL}\nPipeline: <${BUILD_URL:-N/A}|View Build>\"
    }" 2>/dev/null || warn "Slack notification failed"
fi

# Summary report
cat > "${EVIDENCE_DIR}/dr-auto-test-${TIMESTAMP}.md" <<EOF
# Automated DR Test — ${TIMESTAMP}

## Summary
| Metric | Value |
|:---|:---|
| Namespace | ${NAMESPACE} |
| Backup | ${BACKUP_NAME} (${BACKUP_STATUS}) |
| Restore | ${RESTORE_NAME} (${RESTORE_STATUS}) |
| Backup Items | ${BACKUP_ITEMS} |
| Backup Errors | ${BACKUP_ERRORS} |
| RTO Actual | ${RTO_ACTUAL}s |
| RTO SLO | ${RTO_SLO}s |
| Passed | ${PASS} |
| Failed | ${FAIL} |
| Overall | $([ "${PIPELINE_PASS}" = true ] && echo "✅ PASS" || echo "❌ FAIL") |
EOF

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  AUTOMATED DR TEST COMPLETE"
echo "  Passed: ${PASS} | Failed: ${FAIL}"
echo "  RTO: ${RTO_ACTUAL}s | SLO: ${RTO_SLO}s"
echo "  Overall: $([ "${PIPELINE_PASS}" = true ] && echo "✅ PASS" || echo "❌ FAIL")"
echo "  Duration: ${TOTAL_TIME}s"
echo "═══════════════════════════════════════════════════════════════"
echo ""

if [ "${PIPELINE_PASS}" = false ]; then
  exit 1
fi
exit 0
