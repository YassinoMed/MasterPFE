#!/usr/bin/env bash

set -euo pipefail

# Generate a factual release attestation from already produced evidence.
#
# This script is intentionally non-destructive. It never claims that signing,
# verification, SBOM generation, digest promotion or no-rebuild deployment were
# performed unless the corresponding evidence files exist and contain PASS data.
# Set STRICT_RELEASE_ATTESTATION=true to fail when the chain of custody is not
# complete.

REPORT_DIR="${REPORT_DIR:-artifacts/release}"
SBOM_DIR="${SBOM_DIR:-artifacts/sbom}"
OUT_JSON="${OUT_JSON:-${REPORT_DIR}/release-attestation.json}"
OUT_MD="${OUT_MD:-${REPORT_DIR}/release-attestation.md}"
STRICT_RELEASE_ATTESTATION="${STRICT_RELEASE_ATTESTATION:-false}"

DEFAULT_SERVICES=(
  auth-users
  chatbot-manager
  conversation-service
  audit-security-service
  portal-web
)

if [[ -n "${SERVICES:-}" ]]; then
  # shellcheck disable=SC2206
  SERVICES_ARRAY=(${SERVICES//,/ })
else
  SERVICES_ARRAY=("${DEFAULT_SERVICES[@]}")
fi

EXPECTED_COUNT="${EXPECTED_SERVICE_COUNT:-${#SERVICES_ARRAY[@]}}"

mkdir -p "${REPORT_DIR}"

info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
fail() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

is_true() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|y|Y|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

file_sha256() {
  local target_file="$1"

  if [[ ! -f "${target_file}" ]]; then
    printf 'missing'
    return 0
  fi

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${target_file}" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "${target_file}" | awk '{print $1}'
  else
    printf 'unavailable'
  fi
}

artifact_present() {
  [[ -s "$1" ]]
}

artifact_has_pass() {
  local target_file="$1"
  [[ -s "${target_file}" ]] && grep -Eq '(^|[[:space:]])PASS([[:space:]]|[|]|$)' "${target_file}"
}

artifact_has_fail() {
  local target_file="$1"
  [[ -s "${target_file}" ]] && grep -Eq '(^|[[:space:]])FAIL([[:space:]]|[|]|$)' "${target_file}"
}

status_count() {
  local target_file="$1"
  local status="$2"
  local count

  count="$(grep -Ec "^[[:space:]]*${status}[[:space:]]*[|]" "${target_file}" 2>/dev/null || true)"
  printf '%s' "${count:-0}"
}

json_bool() {
  if [[ "$1" == "true" ]]; then
    printf 'true'
  else
    printf 'false'
  fi
}

status_for() {
  local target_file="$1"
  local require_pass="${2:-true}"

  if ! artifact_present "${target_file}"; then
    printf 'MISSING'
    return 0
  fi

  if artifact_has_fail "${target_file}"; then
    printf 'FAILED'
    return 0
  fi

  if [[ "${require_pass}" == "true" ]] && artifact_has_pass "${target_file}"; then
    printf 'PROVEN'
    return 0
  fi

  if [[ "${require_pass}" != "true" ]]; then
    printf 'PRESENT'
    return 0
  fi

  printf 'PRESENT_UNPROVEN'
}

summary_status_for() {
  local target_file="$1"
  local allow_warn="${2:-false}"

  if ! artifact_present "${target_file}"; then
    printf 'MISSING'
    return 0
  fi

  local pass_count fail_count skip_count warn_count
  pass_count="$(status_count "${target_file}" "PASS")"
  fail_count="$(status_count "${target_file}" "FAIL")"
  skip_count="$(status_count "${target_file}" "SKIP")"
  warn_count="$(status_count "${target_file}" "WARN")"

  if [[ "${fail_count}" != "0" ]]; then
    printf 'FAILED'
    return 0
  fi

  if [[ "${skip_count}" != "0" ]]; then
    printf 'SKIPPED'
    return 0
  fi

  if [[ "${allow_warn}" == "true" && "$((pass_count + warn_count))" == "${EXPECTED_COUNT}" ]]; then
    printf 'PROVEN'
    return 0
  fi

  if [[ "${pass_count}" == "${EXPECTED_COUNT}" ]]; then
    printf 'PROVEN'
    return 0
  fi

  if [[ "${pass_count}" != "0" ]]; then
    printf 'PARTIAL'
    return 0
  fi

  printf 'PRESENT_UNPROVEN'
}

digest_status_for() {
  local target_file="$1"

  if ! artifact_present "${target_file}"; then
    printf 'MISSING'
    return 0
  fi

  local record_count invalid_count
  record_count="$(grep -Ev '^[[:space:]]*(#|$)' "${target_file}" | wc -l | tr -d ' ')"
  invalid_count="$(grep -Ev '^[[:space:]]*(#|$)' "${target_file}" | awk -F'|' '$4 !~ /^sha256:[0-9a-f]{64}$/ {bad++} END {print bad+0}')"

  if [[ "${record_count}" == "${EXPECTED_COUNT}" && "${invalid_count}" == "0" ]]; then
    printf 'PROVEN'
    return 0
  fi

  printf 'PRESENT_UNPROVEN'
}

IMAGE_SCAN_STATUS="$(summary_status_for "${REPORT_DIR}/image-scan-summary.txt" true)"
SIGN_STATUS="$(summary_status_for "${REPORT_DIR}/sign-summary.txt")"
VERIFY_STATUS="$(summary_status_for "${REPORT_DIR}/verify-summary.txt")"
PROMOTION_STATUS="$(summary_status_for "${REPORT_DIR}/promotion-by-digest-summary.txt")"
SBOM_STATUS="$(summary_status_for "${REPORT_DIR}/sbom-summary.txt")"
ATTEST_STATUS="$(summary_status_for "${REPORT_DIR}/attest-summary.txt")"
DIGEST_STATUS="$(digest_status_for "${REPORT_DIR}/promotion-digests.txt")"
RELEASE_EVIDENCE_STATUS="$(status_for "${REPORT_DIR}/release-evidence.md" false)"
SUPPLY_EVIDENCE_STATUS="$(status_for "${REPORT_DIR}/supply-chain-evidence.md" false)"

SBOM_COUNT=0
if [[ -d "${SBOM_DIR}" ]]; then
  SBOM_COUNT="$(find "${SBOM_DIR}" -type f -name '*-sbom.cdx.json' 2>/dev/null | wc -l | tr -d ' ')"
fi

COMPLETE=true
for status in "${IMAGE_SCAN_STATUS}" "${SIGN_STATUS}" "${VERIFY_STATUS}" "${PROMOTION_STATUS}" "${SBOM_STATUS}" "${ATTEST_STATUS}"; do
  if [[ "${status}" != "PROVEN" ]]; then
    COMPLETE=false
  fi
done

if [[ "${DIGEST_STATUS}" != "PROVEN" || "${SBOM_COUNT}" != "${EXPECTED_COUNT}" ]]; then
  COMPLETE=false
fi

ATTESTATION_STATUS="PARTIAL_READY_TO_PROVE"
if [[ "${COMPLETE}" == "true" ]]; then
  ATTESTATION_STATUS="COMPLETE_PROVEN"
fi

TIMESTAMP="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
GIT_COMMIT="$(git rev-parse HEAD 2>/dev/null || printf 'unknown')"

cat > "${OUT_JSON}" <<EOF
{
  "generated_at": "${TIMESTAMP}",
  "git_commit": "${GIT_COMMIT}",
  "attestation_type": "SecureRAG Hub release evidence attestation",
  "status": "${ATTESTATION_STATUS}",
  "expected_service_count": ${EXPECTED_COUNT},
  "strict_mode": $(json_bool "${STRICT_RELEASE_ATTESTATION}"),
  "claims": {
    "image_scan_passed": $(json_bool "$([[ "${IMAGE_SCAN_STATUS}" == "PROVEN" ]] && echo true || echo false)"),
    "sbom_generated": $(json_bool "$([[ "${SBOM_STATUS}" == "PROVEN" ]] && echo true || echo false)"),
    "sbom_attested": $(json_bool "$([[ "${ATTEST_STATUS}" == "PROVEN" ]] && echo true || echo false)"),
    "cosign_signed": $(json_bool "$([[ "${SIGN_STATUS}" == "PROVEN" ]] && echo true || echo false)"),
    "cosign_verified": $(json_bool "$([[ "${VERIFY_STATUS}" == "PROVEN" ]] && echo true || echo false)"),
    "digest_promoted": $(json_bool "$([[ "${PROMOTION_STATUS}" == "PROVEN" && "${DIGEST_STATUS}" == "PROVEN" ]] && echo true || echo false)"),
    "no_rebuild_deploy_ready": $(json_bool "$([[ "${PROMOTION_STATUS}" == "PROVEN" && "${DIGEST_STATUS}" == "PROVEN" ]] && echo true || echo false)")
  },
  "evidence": {
    "image_scan_summary": {
      "path": "${REPORT_DIR}/image-scan-summary.txt",
      "status": "${IMAGE_SCAN_STATUS}",
      "pass": $(status_count "${REPORT_DIR}/image-scan-summary.txt" "PASS"),
      "fail": $(status_count "${REPORT_DIR}/image-scan-summary.txt" "FAIL"),
      "skip": $(status_count "${REPORT_DIR}/image-scan-summary.txt" "SKIP"),
      "sha256": "$(file_sha256 "${REPORT_DIR}/image-scan-summary.txt")"
    },
    "sign_summary": {
      "path": "${REPORT_DIR}/sign-summary.txt",
      "status": "${SIGN_STATUS}",
      "pass": $(status_count "${REPORT_DIR}/sign-summary.txt" "PASS"),
      "fail": $(status_count "${REPORT_DIR}/sign-summary.txt" "FAIL"),
      "skip": $(status_count "${REPORT_DIR}/sign-summary.txt" "SKIP"),
      "sha256": "$(file_sha256 "${REPORT_DIR}/sign-summary.txt")"
    },
    "verify_summary": {
      "path": "${REPORT_DIR}/verify-summary.txt",
      "status": "${VERIFY_STATUS}",
      "pass": $(status_count "${REPORT_DIR}/verify-summary.txt" "PASS"),
      "fail": $(status_count "${REPORT_DIR}/verify-summary.txt" "FAIL"),
      "skip": $(status_count "${REPORT_DIR}/verify-summary.txt" "SKIP"),
      "sha256": "$(file_sha256 "${REPORT_DIR}/verify-summary.txt")"
    },
    "promotion_summary": {
      "path": "${REPORT_DIR}/promotion-by-digest-summary.txt",
      "status": "${PROMOTION_STATUS}",
      "pass": $(status_count "${REPORT_DIR}/promotion-by-digest-summary.txt" "PASS"),
      "fail": $(status_count "${REPORT_DIR}/promotion-by-digest-summary.txt" "FAIL"),
      "skip": $(status_count "${REPORT_DIR}/promotion-by-digest-summary.txt" "SKIP"),
      "sha256": "$(file_sha256 "${REPORT_DIR}/promotion-by-digest-summary.txt")"
    },
    "promotion_digests": {
      "path": "${REPORT_DIR}/promotion-digests.txt",
      "status": "${DIGEST_STATUS}",
      "sha256": "$(file_sha256 "${REPORT_DIR}/promotion-digests.txt")"
    },
    "sbom_summary": {
      "path": "${REPORT_DIR}/sbom-summary.txt",
      "status": "${SBOM_STATUS}",
      "pass": $(status_count "${REPORT_DIR}/sbom-summary.txt" "PASS"),
      "fail": $(status_count "${REPORT_DIR}/sbom-summary.txt" "FAIL"),
      "skip": $(status_count "${REPORT_DIR}/sbom-summary.txt" "SKIP"),
      "sha256": "$(file_sha256 "${REPORT_DIR}/sbom-summary.txt")"
    },
    "attest_summary": {
      "path": "${REPORT_DIR}/attest-summary.txt",
      "status": "${ATTEST_STATUS}",
      "pass": $(status_count "${REPORT_DIR}/attest-summary.txt" "PASS"),
      "fail": $(status_count "${REPORT_DIR}/attest-summary.txt" "FAIL"),
      "skip": $(status_count "${REPORT_DIR}/attest-summary.txt" "SKIP"),
      "sha256": "$(file_sha256 "${REPORT_DIR}/attest-summary.txt")"
    },
    "sbom_count": ${SBOM_COUNT},
    "release_evidence": {
      "path": "${REPORT_DIR}/release-evidence.md",
      "status": "${RELEASE_EVIDENCE_STATUS}",
      "sha256": "$(file_sha256 "${REPORT_DIR}/release-evidence.md")"
    },
    "supply_chain_evidence": {
      "path": "${REPORT_DIR}/supply-chain-evidence.md",
      "status": "${SUPPLY_EVIDENCE_STATUS}",
      "sha256": "$(file_sha256 "${REPORT_DIR}/supply-chain-evidence.md")"
    }
  }
}
EOF

{
  printf '# Release Attestation — SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "${TIMESTAMP}"
  printf -- '- Git commit: `%s`\n' "${GIT_COMMIT}"
  printf -- '- Expected services: `%s`\n' "${EXPECTED_COUNT}"
  printf -- '- Expected service names: `%s`\n' "${SERVICES_ARRAY[*]}"
  printf -- '- Status: `%s`\n' "${ATTESTATION_STATUS}"
  printf -- '- Strict mode: `%s`\n\n' "${STRICT_RELEASE_ATTESTATION}"

  printf '## Evidence status\n\n'
  printf '| Control | Status | Evidence |\n'
  printf '|---|---|---|\n'
  printf '| Trivy image scan | `%s` | `%s` |\n' "${IMAGE_SCAN_STATUS}" "${REPORT_DIR}/image-scan-summary.txt"
  printf '| Cosign sign | `%s` | `%s` |\n' "${SIGN_STATUS}" "${REPORT_DIR}/sign-summary.txt"
  printf '| Cosign verify | `%s` | `%s` |\n' "${VERIFY_STATUS}" "${REPORT_DIR}/verify-summary.txt"
  printf '| Digest promotion | `%s` | `%s` |\n' "${PROMOTION_STATUS}" "${REPORT_DIR}/promotion-by-digest-summary.txt"
  printf '| Digest record | `%s` | `%s` |\n' "${DIGEST_STATUS}" "${REPORT_DIR}/promotion-digests.txt"
  printf '| SBOM generation | `%s` | `%s` |\n' "${SBOM_STATUS}" "${REPORT_DIR}/sbom-summary.txt"
  printf '| SBOM attestation | `%s` | `%s` |\n' "${ATTEST_STATUS}" "${REPORT_DIR}/attest-summary.txt"
  printf '| SBOM files | `%s` | `%s` |\n' "${SBOM_COUNT}" "${SBOM_DIR}"
  printf '| Release evidence | `%s` | `%s` |\n' "${RELEASE_EVIDENCE_STATUS}" "${REPORT_DIR}/release-evidence.md"
  printf '| Supply chain evidence | `%s` | `%s` |\n\n' "${SUPPLY_EVIDENCE_STATUS}" "${REPORT_DIR}/supply-chain-evidence.md"

  printf '## Honest reading\n\n'
  if [[ "${COMPLETE}" == "true" ]]; then
    printf 'The release chain is complete for the expected service set: image scan, SBOM, SBOM attestation, signing, verification, digest promotion and no-rebuild promotion evidence are all proven without FAIL or SKIP rows.\n'
  else
    printf 'The release chain is not fully proven yet. Missing, partial, failed or skipped evidence must be regenerated by `make supply-chain-execute` on an environment with Docker, registry access, Trivy, Syft, Cosign and valid Cosign keys.\n'
  fi
} > "${OUT_MD}"

info "Release attestation written to ${OUT_JSON} and ${OUT_MD}"

if [[ "${COMPLETE}" != "true" ]]; then
  warn "Release attestation is partial; supply-chain execute evidence is incomplete."
  if is_true "${STRICT_RELEASE_ATTESTATION}"; then
    fail "Strict attestation refused because the release chain is incomplete."
  fi
fi
