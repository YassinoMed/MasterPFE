#!/usr/bin/env bash

set -euo pipefail

REPORT_DIR="${REPORT_DIR:-artifacts/release}"
SBOM_DIR="${SBOM_DIR:-artifacts/sbom}"
OUT_FILE="${OUT_FILE:-${REPORT_DIR}/supply-chain-evidence.md}"
PACK_ROOT="${PACK_ROOT:-artifacts}"
PACK_NAME="${PACK_NAME:-${PACK_ROOT}/secure-supply-chain-pack-$(date -u '+%Y%m%dT%H%M%SZ').tar.gz}"
GENERATE_PACK="${GENERATE_PACK:-true}"

mkdir -p "${REPORT_DIR}" "${PACK_ROOT}"

info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }

status_file() {
  local path="$1"
  if [[ -s "${path}" ]]; then
    printf 'present'
  else
    printf 'missing'
  fi
}

pass_fail_summary() {
  local path="$1"
  if [[ ! -s "${path}" ]]; then
    printf 'missing'
    return 0
  fi

  local pass_count fail_count skip_count
  pass_count="$(grep -Ec '(^|[[:space:]])PASS([[:space:]]|[|]|$)' "${path}" || true)"
  fail_count="$(grep -Ec '(^|[[:space:]])FAIL([[:space:]]|[|]|$)' "${path}" || true)"
  skip_count="$(grep -Ec '(^|[[:space:]])SKIP([[:space:]]|[|]|$)' "${path}" || true)"
  printf 'present: PASS=%s FAIL=%s SKIP=%s' "${pass_count}" "${fail_count}" "${skip_count}"
}

sbom_count=0
if [[ -d "${SBOM_DIR}" ]]; then
  sbom_count="$(find "${SBOM_DIR}" -type f -name '*-sbom.cdx.json' 2>/dev/null | wc -l | tr -d ' ')"
fi

# Keep attestation factual and non-blocking unless STRICT_RELEASE_ATTESTATION is set by the caller.
REPORT_DIR="${REPORT_DIR}" SBOM_DIR="${SBOM_DIR}" SERVICES="${SERVICES:-}" EXPECTED_SERVICE_COUNT="${EXPECTED_SERVICE_COUNT:-}" \
  bash scripts/release/generate-release-attestation.sh

{
  printf '# Supply Chain Evidence — SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Git commit: `%s`\n\n' "$(git rev-parse HEAD 2>/dev/null || printf 'unknown')"

  printf '## Evidence inventory\n\n'
  printf '| Evidence | Status |\n'
  printf '|---|---|\n'
  printf '| `sign-summary.txt` | %s |\n' "$(pass_fail_summary "${REPORT_DIR}/sign-summary.txt")"
  printf '| `verify-summary.txt` | %s |\n' "$(pass_fail_summary "${REPORT_DIR}/verify-summary.txt")"
  printf '| `promotion-by-digest-summary.txt` | %s |\n' "$(pass_fail_summary "${REPORT_DIR}/promotion-by-digest-summary.txt")"
  printf '| `promotion-digests.txt` | %s |\n' "$(status_file "${REPORT_DIR}/promotion-digests.txt")"
  printf '| `sbom-summary.txt` | %s |\n' "$(pass_fail_summary "${REPORT_DIR}/sbom-summary.txt")"
  printf '| `release-evidence.md` | %s |\n' "$(status_file "${REPORT_DIR}/release-evidence.md")"
  printf '| `release-attestation.json` | %s |\n' "$(status_file "${REPORT_DIR}/release-attestation.json")"
  printf '| SBOM files | %s |\n\n' "${sbom_count}"

  printf '## SBOM files\n\n'
  if [[ "${sbom_count}" != "0" ]]; then
    find "${SBOM_DIR}" -type f -name '*-sbom.cdx.json' | sort | while IFS= read -r sbom; do
      printf -- '- `%s`\n' "${sbom}"
    done
  else
    printf 'No SBOM file detected yet.\n'
  fi

  printf '\n## Honest reading\n\n'
  printf -- '- `present` means the artefact exists locally.\n'
  printf -- '- `PASS` means a script recorded a successful control for at least one image.\n'
  printf -- '- A full release proof requires SBOM, Cosign sign, Cosign verify, digest promotion and attestation generated from the same execution context.\n'
} > "${OUT_FILE}"

if [[ "${GENERATE_PACK}" == "true" ]]; then
  if command -v tar >/dev/null 2>&1 && [[ -d "${REPORT_DIR}" ]]; then
    tar -czf "${PACK_NAME}" -C "$(dirname "${REPORT_DIR}")" "$(basename "${REPORT_DIR}")"
    info "Supply-chain evidence pack written to ${PACK_NAME}"
  else
    warn "tar unavailable or ${REPORT_DIR} missing; evidence pack not generated"
  fi
fi

info "Supply-chain evidence written to ${OUT_FILE}"
