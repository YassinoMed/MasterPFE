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

SIGN_STATUS="$(status_for "${REPORT_DIR}/sign-summary.txt" true)"
VERIFY_STATUS="$(status_for "${REPORT_DIR}/verify-summary.txt" true)"
PROMOTION_STATUS="$(status_for "${REPORT_DIR}/promotion-by-digest-summary.txt" true)"
SBOM_STATUS="$(status_for "${REPORT_DIR}/sbom-summary.txt" true)"
DIGEST_STATUS="$(status_for "${REPORT_DIR}/promotion-digests.txt" false)"
RELEASE_EVIDENCE_STATUS="$(status_for "${REPORT_DIR}/release-evidence.md" false)"
SUPPLY_EVIDENCE_STATUS="$(status_for "${REPORT_DIR}/supply-chain-evidence.md" false)"

SBOM_COUNT=0
if [[ -d "${SBOM_DIR}" ]]; then
  SBOM_COUNT="$(find "${SBOM_DIR}" -type f -name '*-sbom.cdx.json' 2>/dev/null | wc -l | tr -d ' ')"
fi

COMPLETE=true
for status in "${SIGN_STATUS}" "${VERIFY_STATUS}" "${PROMOTION_STATUS}" "${SBOM_STATUS}"; do
  if [[ "${status}" != "PROVEN" ]]; then
    COMPLETE=false
  fi
done

if [[ "${DIGEST_STATUS}" == "MISSING" || "${SBOM_COUNT}" == "0" ]]; then
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
  "strict_mode": $(json_bool "${STRICT_RELEASE_ATTESTATION}"),
  "claims": {
    "sbom_generated": $(json_bool "$([[ "${SBOM_STATUS}" == "PROVEN" ]] && echo true || echo false)"),
    "cosign_signed": $(json_bool "$([[ "${SIGN_STATUS}" == "PROVEN" ]] && echo true || echo false)"),
    "cosign_verified": $(json_bool "$([[ "${VERIFY_STATUS}" == "PROVEN" ]] && echo true || echo false)"),
    "digest_promoted": $(json_bool "$([[ "${PROMOTION_STATUS}" == "PROVEN" && "${DIGEST_STATUS}" != "MISSING" ]] && echo true || echo false)"),
    "no_rebuild_deploy_ready": $(json_bool "$([[ "${PROMOTION_STATUS}" == "PROVEN" && "${DIGEST_STATUS}" != "MISSING" ]] && echo true || echo false)")
  },
  "evidence": {
    "sign_summary": {
      "path": "${REPORT_DIR}/sign-summary.txt",
      "status": "${SIGN_STATUS}",
      "sha256": "$(file_sha256 "${REPORT_DIR}/sign-summary.txt")"
    },
    "verify_summary": {
      "path": "${REPORT_DIR}/verify-summary.txt",
      "status": "${VERIFY_STATUS}",
      "sha256": "$(file_sha256 "${REPORT_DIR}/verify-summary.txt")"
    },
    "promotion_summary": {
      "path": "${REPORT_DIR}/promotion-by-digest-summary.txt",
      "status": "${PROMOTION_STATUS}",
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
      "sha256": "$(file_sha256 "${REPORT_DIR}/sbom-summary.txt")"
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
  printf -- '- Status: `%s`\n' "${ATTESTATION_STATUS}"
  printf -- '- Strict mode: `%s`\n\n' "${STRICT_RELEASE_ATTESTATION}"

  printf '## Evidence status\n\n'
  printf '| Control | Status | Evidence |\n'
  printf '|---|---|---|\n'
  printf '| Cosign sign | `%s` | `%s` |\n' "${SIGN_STATUS}" "${REPORT_DIR}/sign-summary.txt"
  printf '| Cosign verify | `%s` | `%s` |\n' "${VERIFY_STATUS}" "${REPORT_DIR}/verify-summary.txt"
  printf '| Digest promotion | `%s` | `%s` |\n' "${PROMOTION_STATUS}" "${REPORT_DIR}/promotion-by-digest-summary.txt"
  printf '| Digest record | `%s` | `%s` |\n' "${DIGEST_STATUS}" "${REPORT_DIR}/promotion-digests.txt"
  printf '| SBOM generation | `%s` | `%s` |\n' "${SBOM_STATUS}" "${REPORT_DIR}/sbom-summary.txt"
  printf '| SBOM files | `%s` | `%s` |\n' "${SBOM_COUNT}" "${SBOM_DIR}"
  printf '| Release evidence | `%s` | `%s` |\n' "${RELEASE_EVIDENCE_STATUS}" "${REPORT_DIR}/release-evidence.md"
  printf '| Supply chain evidence | `%s` | `%s` |\n\n' "${SUPPLY_EVIDENCE_STATUS}" "${REPORT_DIR}/supply-chain-evidence.md"

  printf '## Honest reading\n\n'
  if [[ "${COMPLETE}" == "true" ]]; then
    printf 'The release chain is complete for the available evidence: SBOM, signing, verification, digest promotion and no-rebuild promotion evidence are present.\n'
  else
    printf 'The release chain is not fully proven yet. Missing or unproven evidence must be produced by `make supply-chain-execute` on an environment with Docker, registry access, Syft, Cosign and valid Cosign keys.\n'
  fi
} > "${OUT_MD}"

info "Release attestation written to ${OUT_JSON} and ${OUT_MD}"

if [[ "${COMPLETE}" != "true" ]]; then
  warn "Release attestation is partial; supply-chain execute evidence is incomplete."
  if is_true "${STRICT_RELEASE_ATTESTATION}"; then
    fail "Strict attestation refused because the release chain is incomplete."
  fi
fi
