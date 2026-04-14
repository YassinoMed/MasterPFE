#!/usr/bin/env bash

set -euo pipefail

REPORT_DIR="${REPORT_DIR:-artifacts/release}"
SBOM_DIR="${SBOM_DIR:-artifacts/sbom}"
DIGEST_RECORD_FILE="${DIGEST_RECORD_FILE:-${REPORT_DIR}/promotion-digests.txt}"
ASSERT_REPORT_FILE="${ASSERT_REPORT_FILE:-${REPORT_DIR}/supply-chain-gate-report.md}"
REQUIRE_SUPPLY_CHAIN_EVIDENCE="${REQUIRE_SUPPLY_CHAIN_EVIDENCE:-true}"

info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
error() { printf '[ERROR] %s\n' "$*" >&2; }

is_true() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|y|Y|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

assert_non_empty_file() {
  local file="$1"
  local label="$2"

  if [[ -s "${file}" ]]; then
    printf '| %s | OK | `%s` |\n' "${label}" "${file}" >> "${ASSERT_REPORT_FILE}"
    return 0
  fi

  printf '| %s | FAIL | `%s` missing or empty |\n' "${label}" "${file}" >> "${ASSERT_REPORT_FILE}"
  return 1
}

mkdir -p "${REPORT_DIR}" "${SBOM_DIR}"

{
  printf '# Supply Chain Mandatory Evidence Gate\n\n'
  printf -- '- Generated at: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- REQUIRE_SUPPLY_CHAIN_EVIDENCE: `%s`\n\n' "${REQUIRE_SUPPLY_CHAIN_EVIDENCE}"
  printf '| Required evidence | Status | Detail |\n'
  printf '|---|---:|---|\n'
} > "${ASSERT_REPORT_FILE}"

if ! is_true "${REQUIRE_SUPPLY_CHAIN_EVIDENCE}"; then
  printf '| Gate mode | BYPASS | Requirement disabled by environment |\n' >> "${ASSERT_REPORT_FILE}"
  warn "Supply-chain mandatory evidence gate is bypassed by REQUIRE_SUPPLY_CHAIN_EVIDENCE=${REQUIRE_SUPPLY_CHAIN_EVIDENCE}"
  exit 0
fi

failure=0

assert_non_empty_file "${REPORT_DIR}/sign-summary.txt" "Cosign sign summary" || failure=1
assert_non_empty_file "${REPORT_DIR}/verify-summary.txt" "Cosign verify summary" || failure=1
assert_non_empty_file "${DIGEST_RECORD_FILE}" "Digest promotion record" || failure=1
assert_non_empty_file "${SBOM_DIR}/sbom-index.txt" "SBOM index" || failure=1

if (( failure > 0 )); then
  error "Mandatory supply-chain evidence is incomplete. See ${ASSERT_REPORT_FILE}"
  exit 1
fi

info "Mandatory supply-chain evidence gate passed. Report: ${ASSERT_REPORT_FILE}"
