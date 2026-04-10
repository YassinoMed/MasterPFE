#!/usr/bin/env bash

set -euo pipefail

REGISTRY_HOST="${REGISTRY_HOST:-localhost:5001}"
IMAGE_PREFIX="${IMAGE_PREFIX:-securerag-hub}"
SOURCE_IMAGE_TAG="${SOURCE_IMAGE_TAG:-${IMAGE_TAG:-dev}}"
TARGET_IMAGE_TAG="${TARGET_IMAGE_TAG:-release-local}"
REPORT_DIR="${REPORT_DIR:-artifacts/release}"
SBOM_DIR="${SBOM_DIR:-artifacts/sbom}"
FINAL_DIR="${FINAL_DIR:-artifacts/final}"
DIGEST_RECORD_FILE="${DIGEST_RECORD_FILE:-${REPORT_DIR}/promotion-digests.txt}"
EVIDENCE_FILE="${EVIDENCE_FILE:-${REPORT_DIR}/release-evidence.md}"
MANIFEST_FILE="${MANIFEST_FILE:-${REPORT_DIR}/release-manifest.env}"

mkdir -p "${REPORT_DIR}" "${FINAL_DIR}"

info() { printf '[INFO] %s\n' "$*"; }

artifact_status() {
  local path="$1"
  if [[ -f "${path}" ]]; then
    printf 'present'
  else
    printf 'missing'
  fi
}

{
  printf 'REGISTRY_HOST=%s\n' "${REGISTRY_HOST}"
  printf 'IMAGE_PREFIX=%s\n' "${IMAGE_PREFIX}"
  printf 'SOURCE_IMAGE_TAG=%s\n' "${SOURCE_IMAGE_TAG}"
  printf 'TARGET_IMAGE_TAG=%s\n' "${TARGET_IMAGE_TAG}"
  printf 'DIGEST_RECORD_FILE=%s\n' "${DIGEST_RECORD_FILE}"
  printf 'SBOM_DIR=%s\n' "${SBOM_DIR}"
  printf 'REPORT_DIR=%s\n' "${REPORT_DIR}"
} > "${MANIFEST_FILE}"

{
  printf '# SecureRAG Hub Release Evidence\n\n'
  printf -- '- Generated at (UTC): `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Registry: `%s`\n' "${REGISTRY_HOST}"
  printf -- '- Image prefix: `%s`\n' "${IMAGE_PREFIX}"
  printf -- '- Source tag: `%s`\n' "${SOURCE_IMAGE_TAG}"
  printf -- '- Target tag: `%s`\n\n' "${TARGET_IMAGE_TAG}"

  printf '## Release artefacts\n\n'
  printf '| Artefact | Statut |\n'
  printf '|---|---|\n'
  printf '| `verify-summary.txt` | %s |\n' "$(artifact_status "${REPORT_DIR}/verify-summary.txt")"
  printf '| `promotion-summary.txt` | %s |\n' "$(artifact_status "${REPORT_DIR}/promotion-summary.txt")"
  printf '| `promotion-by-digest-summary.txt` | %s |\n' "$(artifact_status "${REPORT_DIR}/promotion-by-digest-summary.txt")"
  printf '| `promotion-digests.txt` | %s |\n' "$(artifact_status "${DIGEST_RECORD_FILE}")"
  printf '| `sign-summary.txt` | %s |\n' "$(artifact_status "${REPORT_DIR}/sign-summary.txt")"
  printf '| `sbom-summary.txt` | %s |\n' "$(artifact_status "${REPORT_DIR}/sbom-summary.txt")"
  printf '| `release-manifest.env` | %s |\n' "$(artifact_status "${MANIFEST_FILE}")"

  printf '\n## Digests promoted\n\n'
  if [[ -f "${DIGEST_RECORD_FILE}" ]]; then
    printf '| Service | Source | Target | Digest |\n'
    printf '|---|---|---|---|\n'
    while IFS='|' read -r service source_ref target_ref digest; do
      [[ "${service}" == '# service' ]] && continue
      printf '| `%s` | `%s` | `%s` | `%s` |\n' "${service}" "${source_ref}" "${target_ref}" "${digest}"
    done < "${DIGEST_RECORD_FILE}"
  else
    printf 'Digest record file not present. This generally means digest promotion has not been executed yet.\n'
  fi

  printf '\n## SBOM inventory\n\n'
  if compgen -G "${SBOM_DIR}/*-sbom.cdx.json" > /dev/null; then
    for sbom_file in "${SBOM_DIR}"/*-sbom.cdx.json; do
      printf -- '- `%s`\n' "$(basename "${sbom_file}")"
    done
  else
    printf 'No SBOM files detected in `%s`.\n' "${SBOM_DIR}"
  fi

  printf '\n## Notes\n\n'
  printf -- '- This document records release evidence only; runtime validation evidence is stored under `artifacts/validation/`.\n'
  printf -- '- If promotion by digest has not run yet, tag-level evidence may exist without digest-level evidence.\n'
} > "${EVIDENCE_FILE}"

info "Release evidence written to ${EVIDENCE_FILE}"
