#!/usr/bin/env bash
# validate-immutable.sh — Validate immutable (WORM) backup compliance
# SecureRAG Hub — World-Class Disaster Recovery
#
# Checks MinIO bucket Object Lock status, retention mode, verifies
# that objects cannot be deleted before retention expires, and reports
# WORM compliance status.
#
# Usage:
#   bash scripts/dr/validate-immutable.sh [--bucket <name>] [--ci]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${SCRIPT_DIR}/../release/lib/common.sh"

REPORT_DIR="${REPORT_DIR:-${PROJECT_ROOT}/artifacts/dr/reports}"
VALIDATION_DIR="${VALIDATION_DIR:-${REPORT_DIR}/immutable-validation}"

MINIO_ALIAS="${MINIO_ALIAS:-securerag-immutable}"
MINIO_ENDPOINT="${MINIO_ENDPOINT:-http://minio.velero.svc:9000}"
MINIO_ACCESS_KEY="${MINIO_ACCESS_KEY:-admin}"
MINIO_SECRET_KEY="${MINIO_SECRET_KEY:-admin123}"

BUCKET_NAME="${BUCKET_NAME:-securerag-immutable-backups}"
EXPECTED_RETENTION_MODE="${EXPECTED_RETENTION_MODE:-COMPLIANCE}"
EXPECTED_RETENTION_DAYS="${EXPECTED_RETENTION_DAYS:-30}"
CI_MODE="${CI_MODE:-false}"

mkdir -p "${VALIDATION_DIR}"

require_command mc 2>/dev/null || error "MinIO client (mc) is required"

TIMESTAMP="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

PASS=0
FAIL=0
WARN=0

record_pass() { PASS=$((PASS + 1)); info "[PASS] $1"; }
record_fail() { FAIL=$((FAIL + 1)); error "[FAIL] $1"; }
record_warn() { WARN=$((WARN + 1)); warn "[WARN] $1"; }

VALIDATION_RESULTS=()

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  IMMUTABLE BACKUP VALIDATION"
echo "═══════════════════════════════════════════════════════════════"
echo ""

info "Connecting to MinIO: ${MINIO_ENDPOINT}"
mc alias set "${MINIO_ALIAS}" "${MINIO_ENDPOINT}" "${MINIO_ACCESS_KEY}" "${MINIO_SECRET_KEY}" 2>&1 || {
  error "Cannot connect to MinIO"
  exit 1
}

# ── Check 1: Object Lock Enabled ──────────────────────────────

echo ""
echo "--- Check 1: Object Lock Enabled ---"

LOCK_INFO="$(mc lock info "${MINIO_ALIAS}/${BUCKET_NAME}" 2>&1 || true)"

if echo "${LOCK_INFO}" | grep -qiE '(enabled|true)'; then
  record_pass "Object Lock is enabled on bucket ${BUCKET_NAME}"
  VALIDATION_RESULTS+=("Object Lock Enabled|PASS|Lock is active on bucket")
else
  record_fail "Object Lock is NOT enabled on bucket ${BUCKET_NAME}"
  VALIDATION_RESULTS+=("Object Lock Enabled|FAIL|Lock not found on bucket")
fi

# ── Check 2: Retention Mode is COMPLIANCE ─────────────────────

echo ""
echo "--- Check 2: Retention Mode Check ---"

RETENTION_INFO="$(mc retention info "${MINIO_ALIAS}/${BUCKET_NAME}" 2>&1 || true)"
RETENTION_MODE="$(echo "${RETENTION_INFO}" | grep -oiP '(compliance|governance)' || true)"
RETENTION_DAYS="$(echo "${RETENTION_INFO}" | grep -oP '\d+' || true)"

if [[ "${RETENTION_MODE,,}" == "${EXPECTED_RETENTION_MODE,,}" ]]; then
  record_pass "Retention mode is ${RETENTION_MODE} (expected ${EXPECTED_RETENTION_MODE})"
  VALIDATION_RESULTS+=("Retention Mode|PASS|${RETENTION_MODE}")
else
  record_fail "Retention mode mismatch: got ${RETENTION_MODE:-none}, expected ${EXPECTED_RETENTION_MODE}"
  VALIDATION_RESULTS+=("Retention Mode|FAIL|Got: ${RETENTION_MODE:-none}, Expected: ${EXPECTED_RETENTION_MODE}")
fi

if [[ -n "${RETENTION_DAYS}" ]]; then
  if [[ "${RETENTION_DAYS}" -ge "${EXPECTED_RETENTION_DAYS}" ]]; then
    record_pass "Retention period: ${RETENTION_DAYS} days (>= ${EXPECTED_RETENTION_DAYS} minimum)"
    VALIDATION_RESULTS+=("Retention Period|PASS|${RETENTION_DAYS} days")
  else
    record_warn "Retention period: ${RETENTION_DAYS} days (< ${EXPECTED_RETENTION_DAYS} recommended)"
    VALIDATION_RESULTS+=("Retention Period|WARN|${RETENTION_DAYS} days (below ${EXPECTED_RETENTION_DAYS})")
  fi
else
  record_fail "Retention period not detected"
  VALIDATION_RESULTS+=("Retention Period|FAIL|Not detected")
fi

# ── Check 3: Versioning Enabled ───────────────────────────────

echo ""
echo "--- Check 3: Versioning Status ---"

VERSION_INFO="$(mc version info "${MINIO_ALIAS}/${BUCKET_NAME}" 2>&1 || true)"

if echo "${VERSION_INFO}" | grep -qiE '(enabled|true)'; then
  record_pass "Versioning is enabled on bucket ${BUCKET_NAME}"
  VALIDATION_RESULTS+=("Versioning Enabled|PASS|Versioning active")
else
  record_fail "Versioning is NOT enabled on bucket ${BUCKET_NAME}"
  VALIDATION_RESULTS+=("Versioning Enabled|FAIL|Versioning not enabled")
fi

# ── Check 4: Write Test ───────────────────────────────────────

echo ""
echo "--- Check 4: Write Object Test ---"

WRITE_TEST="worm-write-test-${TIMESTAMP//:/-}.txt"
echo "Immutable backup validation test — ${TIMESTAMP}" | mc pipe "${MINIO_ALIAS}/${BUCKET_NAME}/${WRITE_TEST}" 2>&1 && {
  record_pass "Write test: object created successfully"
  VALIDATION_RESULTS+=("Write Test|PASS|Object written")
} || {
  record_fail "Write test: could not create object"
  VALIDATION_RESULTS+=("Write Test|FAIL|Could not write")
}

# ── Check 5: Read Test ────────────────────────────────────────

echo ""
echo "--- Check 5: Read Object Test ---"

READ_CONTENT="$(mc cat "${MINIO_ALIAS}/${BUCKET_NAME}/${WRITE_TEST}" 2>&1 || true)"
if echo "${READ_CONTENT}" | grep -q "Immutable backup validation test"; then
  record_pass "Read test: object content verified"
  VALIDATION_RESULTS+=("Read Test|PASS|Content verified")
else
  record_fail "Read test: object content mismatch or unreadable"
  VALIDATION_RESULTS+=("Read Test|FAIL|Content mismatch")
fi

# ── Check 6: Deletion Prevention ──────────────────────────────

echo ""
echo "--- Check 6: Deletion Prevention Test ---"

DELETE_TEST="worm-delete-test-${TIMESTAMP//:/-}.txt"
echo "Deletion prevention validation" | mc pipe "${MINIO_ALIAS}/${BUCKET_NAME}/${DELETE_TEST}" 2>&1

mc retention set \
  --mode "compliance" \
  --duration "1d" \
  "${MINIO_ALIAS}/${BUCKET_NAME}/${DELETE_TEST}" 2>&1 || true

sleep 2

DELETE_ATTEMPT="$(mc rm "${MINIO_ALIAS}/${BUCKET_NAME}/${DELETE_TEST}" 2>&1 || true)"

if [[ -z "${DELETE_ATTEMPT}" ]] || echo "${DELETE_ATTEMPT}" | grep -qiE '(error|denied|lock|forbidden|immutable)'; then
  record_pass "Deletion prevention: object locked in compliance mode — deletion denied"
  VALIDATION_RESULTS+=("Deletion Prevention|PASS|Delete denied by compliance lock")
else
  record_fail "Deletion prevention: object was deleted despite compliance lock!"
  VALIDATION_RESULTS+=("Deletion Prevention|FAIL|Object was deletable")
fi

# ── Cleanup test objects ──────────────────────────────────────

info "Cleaning up test objects..."
for obj in "${WRITE_TEST}" "${DELETE_TEST}"; do
  mc retention clear "${MINIO_ALIAS}/${BUCKET_NAME}/${obj}" 2>/dev/null || true
  mc rm "${MINIO_ALIAS}/${BUCKET_NAME}/${obj}" 2>/dev/null || true
done

# ── Generate Report ───────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  VALIDATION SUMMARY"
echo "═══════════════════════════════════════════════════════════════"
echo "  Passed: ${PASS}"
echo "  Failed: ${FAIL}"
echo "  Warnings: ${WARN}"
echo ""

WORM_COMPLIANT=false
if [[ "${FAIL}" -eq 0 ]]; then
  WORM_COMPLIANT=true
  echo "  WORM Compliance: ✅ COMPLIANT"
else
  echo "  WORM Compliance: ❌ NON-COMPLIANT"
fi

cat > "${VALIDATION_DIR}/immutable-validation-report.md" <<REPORTEOF
# Immutable Backup Validation Report — SecureRAG Hub

## Overview

| Field | Value |
|:---|:---|
| Generated | ${TIMESTAMP} |
| Bucket | \`${BUCKET_NAME}\` |
| MinIO Endpoint | ${MINIO_ENDPOINT} |
| Passed | ${PASS} |
| Failed | ${FAIL} |
| Warnings | ${WARN} |
| WORM Compliant | $(${WORM_COMPLIANT} && echo 'YES' || echo 'NO') |

## Validation Checks

| Check | Status | Details |
|:---|:---:|:---|
REPORTEOF

for result in "${VALIDATION_RESULTS[@]}"; do
  IFS='|' read -r check status details <<< "${result}"
  ICON=""
  case "${status}" in
    PASS) ICON="✅" ;;
    FAIL) ICON="❌" ;;
    WARN) ICON="⚠️" ;;
  esac
  printf '| %s | %s %s | %s |\n' "${check}" "${ICON}" "${status}" "${details}" >> "${VALIDATION_DIR}/immutable-validation-report.md"
done

cat >> "${VALIDATION_DIR}/immutable-validation-report.md" <<REPORTEOF

## Detailed Results

### 1. Object Lock Enabled
Verifies that the MinIO bucket has Object Lock feature enabled. Object Lock must be enabled at bucket creation time and cannot be added later.

### 2. Retention Mode
Ensures retention mode is set to \`${EXPECTED_RETENTION_MODE}\`. Compliance mode means that no one (including the root user) can delete or overwrite protected objects until the retention period expires.

### 3. Versioning
Versioning is required for WORM compliance to maintain multiple versions of objects and prevent overwrite-based data loss.

### 4. Write Test
Verifies that objects can be written to the bucket.

### 5. Read Test
Verifies that written objects can be read back with correct content.

### 6. Deletion Prevention
The critical WORM test — attempts to delete an object under compliance lock. The deletion MUST be denied for WORM compliance.

## Compliance Verdict

- **WORM Compliant:** $(${WORM_COMPLIANT} && echo 'YES' || echo 'NO')
- **Storage Class:** Immutable (Write Once Read Many)
- **Compliance Standard:** SEC Rule 17a-4, FINRA, CFTC (via MinIO Object Lock Compliance mode)
- **Retention Period:** \`${EXPECTED_RETENTION_DAYS}\` days minimum

**Note:** Objects under Compliance mode cannot be deleted, overwritten, or modified by any user (including root) until the retention period expires. Verify retention periods align with organizational data governance policies.
REPORTEOF

info "Validation report: ${VALIDATION_DIR}/immutable-validation-report.md"

if [[ "${FAIL}" -gt 0 ]] && is_true "${CI_MODE}"; then
  exit 1
fi

[[ "${FAIL}" -eq 0 ]] || exit 1
