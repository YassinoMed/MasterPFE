#!/usr/bin/env bash

set -euo pipefail

REPORT_DIR="${REPORT_DIR:-artifacts/release}"
SBOM_DIR="${SBOM_DIR:-artifacts/sbom}"
DIGEST_RECORD_FILE="${DIGEST_RECORD_FILE:-${REPORT_DIR}/promotion-digests.txt}"
ASSERT_REPORT_FILE="${ASSERT_REPORT_FILE:-${REPORT_DIR}/supply-chain-gate-report.md}"
REQUIRE_SUPPLY_CHAIN_EVIDENCE="${REQUIRE_SUPPLY_CHAIN_EVIDENCE:-true}"
REQUIRE_RELEASE_ATTESTATION="${REQUIRE_RELEASE_ATTESTATION:-true}"

DEFAULT_SERVICES=(
  api-gateway
  auth-users
  chatbot-manager
  llm-orchestrator
  security-auditor
  knowledge-hub
  portal-web
)

if [[ -n "${SERVICES:-}" ]]; then
  # shellcheck disable=SC2206
  SERVICES_ARRAY=(${SERVICES//,/ })
else
  SERVICES_ARRAY=("${DEFAULT_SERVICES[@]}")
fi

EXPECTED_COUNT="${EXPECTED_SERVICE_COUNT:-${#SERVICES_ARRAY[@]}}"

info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
error() { printf '[ERROR] %s\n' "$*" >&2; }

is_true() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|y|Y|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    error "Missing required command: $1"
    exit 2
  fi
}

file_sha256() {
  local target_file="$1"

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${target_file}" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "${target_file}" | awk '{print $1}'
  else
    printf 'unavailable'
  fi
}

status_count() {
  local file="$1"
  local status="$2"
  local count

  count="$(grep -Ec "^[[:space:]]*${status}[[:space:]]*[|]" "${file}" 2>/dev/null || true)"
  printf '%s' "${count:-0}"
}

record() {
  local control="$1"
  local status="$2"
  local detail="$3"

  printf '| %s | %s | %s |\n' "${control}" "${status}" "${detail}" >> "${ASSERT_REPORT_FILE}"
}

assert_summary_all_pass() {
  local file="$1"
  local label="$2"

  if [[ ! -s "${file}" ]]; then
    record "${label}" "FAIL" "\`${file}\` missing or empty"
    return 1
  fi

  local pass_count fail_count skip_count
  pass_count="$(status_count "${file}" "PASS")"
  fail_count="$(status_count "${file}" "FAIL")"
  skip_count="$(status_count "${file}" "SKIP")"

  if [[ "${pass_count}" == "${EXPECTED_COUNT}" && "${fail_count}" == "0" && "${skip_count}" == "0" ]]; then
    record "${label}" "OK" "PASS=${pass_count}/${EXPECTED_COUNT}, sha256=$(file_sha256 "${file}")"
    return 0
  fi

  record "${label}" "FAIL" "\`${file}\`: PASS=${pass_count}/${EXPECTED_COUNT}, FAIL=${fail_count}, SKIP=${skip_count}"
  return 1
}

assert_digest_records() {
  if [[ ! -s "${DIGEST_RECORD_FILE}" ]]; then
    record "Digest promotion record" "FAIL" "\`${DIGEST_RECORD_FILE}\` missing or empty"
    return 1
  fi

  local record_count invalid_count
  record_count="$(grep -Ev '^[[:space:]]*(#|$)' "${DIGEST_RECORD_FILE}" | wc -l | tr -d ' ')"
  invalid_count="$(grep -Ev '^[[:space:]]*(#|$)' "${DIGEST_RECORD_FILE}" | awk -F'|' '$4 !~ /^sha256:[0-9a-f]{64}$/ {bad++} END {print bad+0}')"

  if [[ "${record_count}" == "${EXPECTED_COUNT}" && "${invalid_count}" == "0" ]]; then
    record "Digest promotion record" "OK" "records=${record_count}/${EXPECTED_COUNT}, sha256=$(file_sha256 "${DIGEST_RECORD_FILE}")"
    return 0
  fi

  record "Digest promotion record" "FAIL" "\`${DIGEST_RECORD_FILE}\`: records=${record_count}/${EXPECTED_COUNT}, invalid_digests=${invalid_count}"
  return 1
}

assert_sbom_index() {
  require_command python3

  local index_file="${SBOM_DIR}/sbom-index.txt"
  if [[ ! -s "${index_file}" ]]; then
    record "SBOM index" "FAIL" "\`${index_file}\` missing or empty"
    return 1
  fi

  if python3 - "${index_file}" "${EXPECTED_COUNT}" <<'PY'
import json
import pathlib
import sys

index_path = pathlib.Path(sys.argv[1])
expected = int(sys.argv[2])
records = []

for raw_line in index_path.read_text(encoding="utf-8").splitlines():
    line = raw_line.strip()
    if not line or line.startswith("#"):
        continue
    parts = line.split("|")
    if len(parts) != 5:
        raise SystemExit(f"invalid index row: {line}")
    service, image, source, sbom_file, checksum = parts
    sbom_path = pathlib.Path(sbom_file)
    if not sbom_path.is_file() or sbom_path.stat().st_size == 0:
        raise SystemExit(f"missing SBOM file for {service}: {sbom_file}")
    with sbom_path.open(encoding="utf-8") as handle:
        payload = json.load(handle)
    if payload.get("bomFormat") != "CycloneDX":
        raise SystemExit(f"SBOM is not CycloneDX for {service}: {sbom_file}")
    records.append((service, image, source, sbom_file, checksum))

if len(records) != expected:
    raise SystemExit(f"expected {expected} SBOM records, got {len(records)}")
PY
  then
    record "SBOM index" "OK" "records=${EXPECTED_COUNT}/${EXPECTED_COUNT}, sha256=$(file_sha256 "${index_file}")"
    return 0
  fi

  record "SBOM index" "FAIL" "\`${index_file}\` does not describe ${EXPECTED_COUNT} valid CycloneDX SBOM files"
  return 1
}

assert_release_attestation() {
  if ! is_true "${REQUIRE_RELEASE_ATTESTATION}"; then
    record "Release attestation" "BYPASS" "Disabled by REQUIRE_RELEASE_ATTESTATION=${REQUIRE_RELEASE_ATTESTATION}"
    return 0
  fi

  require_command python3

  local attestation="${REPORT_DIR}/release-attestation.json"
  if [[ ! -s "${attestation}" ]]; then
    record "Release attestation" "FAIL" "\`${attestation}\` missing or empty"
    return 1
  fi

  if python3 - "${attestation}" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)

if payload.get("status") != "COMPLETE_PROVEN":
    raise SystemExit(f"attestation status is {payload.get('status')!r}, expected COMPLETE_PROVEN")

claims = payload.get("claims", {})
required_claims = [
    "sbom_generated",
    "cosign_signed",
    "cosign_verified",
    "digest_promoted",
    "no_rebuild_deploy_ready",
]
missing = [claim for claim in required_claims if claims.get(claim) is not True]
if missing:
    raise SystemExit(f"attestation claims are not all true: {', '.join(missing)}")
PY
  then
    record "Release attestation" "OK" "status=COMPLETE_PROVEN, sha256=$(file_sha256 "${attestation}")"
    return 0
  fi

  record "Release attestation" "FAIL" "\`${attestation}\` is present but not COMPLETE_PROVEN"
  return 1
}

mkdir -p "${REPORT_DIR}" "${SBOM_DIR}"

{
  printf '# Supply Chain Mandatory Evidence Gate\n\n'
  printf -- '- Generated at: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- REQUIRE_SUPPLY_CHAIN_EVIDENCE: `%s`\n' "${REQUIRE_SUPPLY_CHAIN_EVIDENCE}"
  printf -- '- Expected services: `%s`\n' "${EXPECTED_COUNT}"
  printf -- '- Services: `%s`\n\n' "${SERVICES_ARRAY[*]}"
  printf '| Required evidence | Status | Detail |\n'
  printf '|---|---:|---|\n'
} > "${ASSERT_REPORT_FILE}"

if ! is_true "${REQUIRE_SUPPLY_CHAIN_EVIDENCE}"; then
  record "Gate mode" "BYPASS" "Requirement disabled by environment"
  warn "Supply-chain mandatory evidence gate is bypassed by REQUIRE_SUPPLY_CHAIN_EVIDENCE=${REQUIRE_SUPPLY_CHAIN_EVIDENCE}"
  exit 0
fi

failure=0

assert_summary_all_pass "${REPORT_DIR}/sign-summary.txt" "Cosign sign summary" || failure=1
assert_summary_all_pass "${REPORT_DIR}/verify-summary.txt" "Cosign verify summary" || failure=1
assert_summary_all_pass "${REPORT_DIR}/promotion-by-digest-summary.txt" "Digest promotion summary" || failure=1
assert_digest_records || failure=1
assert_summary_all_pass "${REPORT_DIR}/sbom-summary.txt" "SBOM generation summary" || failure=1
assert_sbom_index || failure=1
assert_release_attestation || failure=1

if (( failure > 0 )); then
  error "Mandatory supply-chain evidence is incomplete or unproven. See ${ASSERT_REPORT_FILE}"
  exit 1
fi

info "Mandatory supply-chain evidence gate passed. Report: ${ASSERT_REPORT_FILE}"
