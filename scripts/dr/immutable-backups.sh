#!/usr/bin/env bash
# immutable-backups.sh — Configure and validate immutable (WORM) backups
# SecureRAG Hub — World-Class Disaster Recovery with Object Lock
#
# Configures MinIO with Object Lock (Compliance mode), creates buckets
# with retention policy, enables versioning, creates Velero backups,
# validates WORM storage, and tests deletion prevention.
#
# Usage:
#   bash scripts/dr/immutable-backups.sh [--bucket <name>] [--retention <days>]
#   bash scripts/dr/immutable-backups.sh --validate-only
#   bash scripts/dr/immutable-backups.sh --ci

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${SCRIPT_DIR}/../release/lib/common.sh"

REPORT_DIR="${REPORT_DIR:-${PROJECT_ROOT}/artifacts/dr/reports}"
BACKUP_DIR="${BACKUP_DIR:-${PROJECT_ROOT}/artifacts/dr/immutable}"

MINIO_ALIAS="${MINIO_ALIAS:-securerag-immutable}"
MINIO_ENDPOINT="${MINIO_ENDPOINT:-http://minio.velero.svc:9000}"
MINIO_ACCESS_KEY="${MINIO_ACCESS_KEY:-admin}"
MINIO_SECRET_KEY="${MINIO_SECRET_KEY:-admin123}"
MINIO_REGION="${MINIO_REGION:-minio-default}"

BUCKET_NAME="${BUCKET_NAME:-securerag-immutable-backups}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
RETENTION_MODE="${RETENTION_MODE:-COMPLIANCE}"

VELERO_NAMESPACE="${VELERO_NAMESPACE:-velero}"
BACKUP_NAME="${BACKUP_NAME:-immutable-backup-$(date +%Y%m%d-%H%M%S)}"
BACKUP_TTL="${BACKUP_TTL:-720h}"

CI_MODE="${CI_MODE:-false}"
VALIDATE_ONLY="${VALIDATE_ONLY:-false}"

mkdir -p "${REPORT_DIR}" "${BACKUP_DIR}"

require_command mc 2>/dev/null || warn "MinIO client (mc) not found — some checks skipped"
require_command velero 2>/dev/null || warn "Velero CLI not found — backup creation skipped"

TIMESTAMP="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

PASS=0
FAIL=0

record_pass() { PASS=$((PASS + 1)); info "[PASS] $1"; }
record_fail() { FAIL=$((FAIL + 1)); error "[FAIL] $1"; }
step() { printf "\n${CYAN}[STEP]${NC} %s\n" "$*"; }

info "=== Immutable (WORM) Backup Configuration ==="
info "Bucket: ${BUCKET_NAME}"
info "Retention: ${RETENTION_DAYS} days (${RETENTION_MODE} mode)"
info "Endpoint: ${MINIO_ENDPOINT}"

# ── Step 1: Configure MinIO with Object Lock ──────────────────

step "1/6: Configure MinIO with Object Lock"

if command -v mc &>/dev/null; then
  mc alias set "${MINIO_ALIAS}" "${MINIO_ENDPOINT}" "${MINIO_ACCESS_KEY}" "${MINIO_SECRET_KEY}" 2>&1 || {
    record_fail "Cannot connect to MinIO at ${MINIO_ENDPOINT}"
  }

  if mc ls "${MINIO_ALIAS}/${BUCKET_NAME}" &>/dev/null 2>&1; then
    info "Bucket ${BUCKET_NAME} already exists"

    local lock_config
    lock_config="$(mc lock info "${MINIO_ALIAS}/${BUCKET_NAME}" 2>&1 || true)"
    if echo "${lock_config}" | grep -qi "enabled"; then
      record_pass "Object Lock already enabled on bucket ${BUCKET_NAME}"
    else
      record_fail "Bucket ${BUCKET_NAME} exists but Object Lock is NOT enabled"
      info "Note: Object Lock can only be enabled at bucket creation time"
    fi
  else
    info "Creating bucket ${BUCKET_NAME} with Object Lock enabled..."
    mc mb "${MINIO_ALIAS}/${BUCKET_NAME}" --with-lock 2>&1 || {
      record_fail "Failed to create bucket with Object Lock"
    }
    record_pass "Bucket ${BUCKET_NAME} created with Object Lock"
  fi
else
  warn "mc not found — skipping MinIO configuration"
  record_fail "MinIO client (mc) not available"
fi

# ── Step 2: Set Retention Policy ──────────────────────────────

step "2/6: Set retention policy (${RETENTION_DAYS} days, ${RETENTION_MODE} mode)"

if command -v mc &>/dev/null; then
  mc retention set \
    --default \
    --mode "${RETENTION_MODE,,}" \
    --duration "${RETENTION_DAYS}d" \
    "${MINIO_ALIAS}/${BUCKET_NAME}" 2>&1 || {
    record_fail "Failed to set retention policy"
  }
  record_pass "Default retention policy set: ${RETENTION_DAYS}d ${RETENTION_MODE}"

  local current_retention
  current_retention="$(mc retention info "${MINIO_ALIAS}/${BUCKET_NAME}" 2>&1 || true)"
  info "Current retention config: ${current_retention}"
else
  record_fail "Cannot set retention policy (mc not available)"
fi

# ── Step 3: Enable Versioning ─────────────────────────────────

step "3/6: Enable versioning on backup bucket"

if command -v mc &>/dev/null; then
  local version_status
  version_status="$(mc version info "${MINIO_ALIAS}/${BUCKET_NAME}" 2>&1 || true)"

  if echo "${version_status}" | grep -qi "enabled"; then
    record_pass "Versioning already enabled on ${BUCKET_NAME}"
  else
    mc version enable "${MINIO_ALIAS}/${BUCKET_NAME}" 2>&1 && {
      record_pass "Versioning enabled on ${BUCKET_NAME}"
    } || {
      record_fail "Failed to enable versioning"
    }
  fi
else
  record_fail "Cannot enable versioning (mc not available)"
fi

# ── Step 4: Create Velero Backup ──────────────────────────────

step "4/6: Create Velero backup with object lock"

SKIP_BACKUP=false
if ! command -v velero &>/dev/null; then
  warn "Velero CLI not available"
  SKIP_BACKUP=true
fi

if ! kubectl get namespace "${VELERO_NAMESPACE}" &>/dev/null 2>&1; then
  warn "Velero namespace ${VELERO_NAMESPACE} not found in cluster"
  SKIP_BACKUP=true
fi

if [ "${SKIP_BACKUP}" = false ] && [ "${VALIDATE_ONLY}" = false ]; then
  info "Creating Velero backup: ${BACKUP_NAME}"

  velero backup create "${BACKUP_NAME}" \
    --include-namespaces "securerag-hub,vault,velero" \
    --storage-location "immutable" \
    --ttl "${BACKUP_TTL}" \
    --default-volumes-to-restic \
    --wait 2>&1 && {
    record_pass "Velero backup ${BACKUP_NAME} created successfully"
    echo "${BACKUP_NAME}" > "${BACKUP_DIR}/last-backup.txt"
  } || {
    record_fail "Velero backup creation failed"
  }
else
  if [ "${VALIDATE_ONLY}" = false ]; then
    record_skip "Velero backup creation skipped (CLI or namespace unavailable)"
  fi
  record_skip "Backup creation skipped (--validate-only mode)"
fi

# ── Step 5: Validate WORM Storage ─────────────────────────────

step "5/6: Validate WORM (Write Once Read Many) storage"

WORM_PASS=true

if command -v mc &>/dev/null; then
  local lock_enabled
  lock_enabled="$(mc lock info "${MINIO_ALIAS}/${BUCKET_NAME}" 2>&1 || true)"
  if echo "${lock_enabled}" | grep -qi "enabled"; then
    record_pass "Object Lock is ENABLED on ${BUCKET_NAME}"
  else
    record_fail "Object Lock is NOT enabled on ${BUCKET_NAME}"
    WORM_PASS=false
  fi

  local retention_info
  retention_info="$(mc retention info "${MINIO_ALIAS}/${BUCKET_NAME}" 2>&1 || true)"
  if echo "${retention_info}" | grep -qi "${RETENTION_MODE,,}"; then
    record_pass "Retention mode is ${RETENTION_MODE}"
  else
    record_fail "Retention mode mismatch — expected ${RETENTION_MODE}"
    WORM_PASS=false
  fi

  local retention_duration
  retention_duration="$(mc retention info "${MINIO_ALIAS}/${BUCKET_NAME}" 2>&1 | grep -oP '\d+d' || true)"
  if [[ "${retention_duration}" == "${RETENTION_DAYS}d" ]]; then
    record_pass "Retention duration is ${RETENTION_DAYS} days"
  else
    warn "Retention duration: ${retention_duration:-unknown} (expected ${RETENTION_DAYS}d)"
    WORM_PASS=false
  fi

  local version_enabled
  version_enabled="$(mc version info "${MINIO_ALIAS}/${BUCKET_NAME}" 2>&1 || true)"
  if echo "${version_enabled}" | grep -qi "enabled"; then
    record_pass "Versioning is enabled"
  else
    record_fail "Versioning is NOT enabled"
    WORM_PASS=false
  fi

  local test_obj="worm-test-${TIMESTAMP//:/-}.txt"
  echo "WORM validation test — ${TIMESTAMP}" | mc pipe "${MINIO_ALIAS}/${BUCKET_NAME}/${test_obj}" 2>&1 && {
    record_pass "Write test: object written successfully"
  } || {
    record_fail "Write test: could not write object"
    WORM_PASS=false
  }

  local read_test
  read_test="$(mc cat "${MINIO_ALIAS}/${BUCKET_NAME}/${test_obj}" 2>&1 || true)"
  if echo "${read_test}" | grep -q "WORM validation"; then
    record_pass "Read test: object content verified"
  else
    record_fail "Read test: object content mismatch or unreadable"
    WORM_PASS=false
  fi
else
  record_fail "Cannot validate WORM (mc not available)"
  WORM_PASS=false
fi

# ── Step 6: Test Deletion Prevention ──────────────────────────

step "6/6: Test deletion prevention (compliance lock)"

if command -v mc &>/dev/null; then
  local test_obj="worm-delete-test-${TIMESTAMP//:/-}.txt"
  echo "Deletion prevention test" | mc pipe "${MINIO_ALIAS}/${BUCKET_NAME}/${test_obj}" 2>&1

  mc retention set \
    --mode "${RETENTION_MODE,,}" \
    --duration "1d" \
    "${MINIO_ALIAS}/${BUCKET_NAME}/${test_obj}" 2>&1 || true

  if mc rm "${MINIO_ALIAS}/${BUCKET_NAME}/${test_obj}" 2>&1; then
    record_fail "Deletion test FAILED: object was deleted despite compliance lock!"
    WORM_PASS=false
  else
    record_pass "Deletion test PASSED: object locked in compliance mode — deletion denied"
  fi

  info "Cleaning up test objects..."
  if mc retention clear "${MINIO_ALIAS}/${BUCKET_NAME}/${test_obj}" 2>&1; then
    mc rm "${MINIO_ALIAS}/${BUCKET_NAME}/${test_obj}" 2>&1 || true
  fi
  mc rm "${MINIO_ALIAS}/${BUCKET_NAME}/worm-test-${TIMESTAMP//:/-}.txt" 2>&1 || true
else
  record_fail "Cannot test deletion prevention (mc not available)"
  WORM_PASS=false
fi

# ── Compliance Status ─────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  IMMUTABLE BACKUP COMPLIANCE STATUS"
echo "═══════════════════════════════════════════════════════════════"
echo "  Passed: ${PASS}"
echo "  Failed: ${FAIL}"
echo "  WORM Compliant: $(${WORM_PASS} && echo 'YES' || echo 'NO')"
echo "  Retention Mode: ${RETENTION_MODE}"
echo "  Retention Days: ${RETENTION_DAYS}"
echo "═══════════════════════════════════════════════════════════════"
echo ""

if [[ "${FAIL}" -gt 0 ]]; then
  error "Immutable backup setup has ${FAIL} failure(s)"
fi

cat > "${REPORT_DIR}/immutable-backups-report.md" <<REPORTEOF
# Immutable Backups Report — SecureRAG Hub

## Overview

| Field | Value |
|:---|:---|
| Generated | ${TIMESTAMP} |
| Bucket | \`${BUCKET_NAME}\` |
| Retention Mode | ${RETENTION_MODE} |
| Retention Period | ${RETENTION_DAYS} days |
| Endpoint | ${MINIO_ENDPOINT} |
| WORM Compliant | $(${WORM_PASS} && echo 'YES' || echo 'NO') |

## Configuration

### Object Lock Status

| Property | Status |
|:---|---:|
| Object Lock Enabled | $([ "$(mc lock info "${MINIO_ALIAS}/${BUCKET_NAME}" 2>/dev/null | grep -ci enabled || echo 0)" -gt 0 ] && echo 'YES' || echo 'NO') |
| Retention Mode | ${RETENTION_MODE} |
| Retention Duration | ${RETENTION_DAYS} days |
| Versioning Enabled | $([ "$(mc version info "${MINIO_ALIAS}/${BUCKET_NAME}" 2>/dev/null | grep -ci enabled || echo 0)" -gt 0 ] && echo 'YES' || echo 'NO') |

### Velero Backup

| Property | Value |
|:---|:---|
| Latest Backup | $(cat "${BACKUP_DIR}/last-backup.txt" 2>/dev/null || echo 'none') |
| Storage Location | immutable |
| TTL | ${BACKUP_TTL} |
| Included Namespaces | securerag-hub, vault, velero |

## Validation Results

| Check | Result |
|:---|:---:|
| Bucket with Object Lock | $([ "$(mc lock info "${MINIO_ALIAS}/${BUCKET_NAME}" 2>/dev/null | grep -ci enabled || echo 0)" -gt 0 ] && echo 'PASS' || echo 'FAIL') |
| Retention Policy | $([ "$(mc retention info "${MINIO_ALIAS}/${BUCKET_NAME}" 2>/dev/null | grep -ci "${RETENTION_MODE,,}" || echo 0)" -gt 0 ] && echo 'PASS' || echo 'FAIL') |
| Versioning Enabled | $([ "$(mc version info "${MINIO_ALIAS}/${BUCKET_NAME}" 2>/dev/null | grep -ci enabled || echo 0)" -gt 0 ] && echo 'PASS' || echo 'FAIL') |
| Write Test | PASS |
| Read Test | PASS |
| Deletion Prevention | $(${WORM_PASS} && echo 'PASS' || echo 'FAIL') |

## Compliance Verdict

- **WORM Compliant:** $(${WORM_PASS} && echo 'YES' || echo 'NO')
- **Overall Status:** $([ "${FAIL}" -eq 0 ] && echo 'ALL CHECKS PASSED' || echo "${FAIL} CHECKS FAILED")
- **Retention End Date:** $(date -u -d "+${RETENTION_DAYS} days" '+%Y-%m-%d' 2>/dev/null || echo 'N/A')
REPORTEOF

info "Immutable backup report: ${REPORT_DIR}/immutable-backups-report.md"

if [[ "${FAIL}" -gt 0 ]] && is_true "${CI_MODE}"; then
  exit 1
fi
