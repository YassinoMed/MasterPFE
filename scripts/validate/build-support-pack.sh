#!/usr/bin/env bash

set -euo pipefail

SUPPORT_PACK_ROOT="${SUPPORT_PACK_ROOT:-artifacts/support-pack}"
PACK_ID="${PACK_ID:-$(date -u '+%Y%m%dT%H%M%SZ')}"
PACK_DIR="${SUPPORT_PACK_ROOT%/}/${PACK_ID}"
README_FILE="${PACK_DIR}/README.md"
MANIFEST_FILE="${PACK_DIR}/manifest.txt"
CHECKSUM_FILE="${PACK_DIR}/checksums.txt"

info() { printf '[INFO] %s\n' "$*"; }

mkdir -p "${PACK_DIR}"

copy_tree_if_present() {
  local source_dir="$1"
  local target_name="$2"
  if [[ -d "${source_dir}" ]]; then
    rm -rf "${PACK_DIR:?}/${target_name}"
    cp -R "${source_dir}" "${PACK_DIR}/${target_name}"
  fi
}

copy_file_if_present() {
  local source_file="$1"
  local target_file="$2"
  if [[ -f "${source_file}" ]]; then
    mkdir -p "$(dirname "${PACK_DIR}/${target_file}")"
    cp "${source_file}" "${PACK_DIR}/${target_file}"
  fi
}

copy_tree_if_present "artifacts/release" "release"
copy_tree_if_present "artifacts/sbom" "sbom"
copy_tree_if_present "artifacts/validation" "validation"
copy_tree_if_present "artifacts/final" "final"
copy_tree_if_present "artifacts/jenkins" "jenkins"

copy_file_if_present "README.md" "project/README.md"
copy_file_if_present "docs/runbooks/final-campaign.md" "docs/final-campaign.md"
copy_file_if_present "docs/runbooks/demo-checklist.md" "docs/demo-checklist.md"
copy_file_if_present "docs/runbooks/environment-freeze.md" "docs/environment-freeze.md"
copy_file_if_present "docs/security/policy-matrix.md" "docs/policy-matrix.md"

{
  printf '# SecureRAG Hub Support Pack\n\n'
  printf -- '- Generated at (UTC): `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Pack id: `%s`\n' "${PACK_ID}"
  printf -- '- Git commit: `%s`\n' "$(git rev-parse HEAD 2>/dev/null || printf 'unknown')"
  printf -- '- Cluster context: `%s`\n\n' "$(kubectl config current-context 2>/dev/null || printf 'unavailable')"
  printf '## Included folders\n\n'
  for folder in release sbom validation final jenkins docs project; do
    if [[ -e "${PACK_DIR}/${folder}" ]]; then
      printf -- '- `%s/`\n' "${folder}"
    fi
  done
  printf '\n## Purpose\n\n'
  printf 'This pack is intended for memory and soutenance use. It groups the main release, runtime, Jenkins and documentation artefacts for a single reference campaign.\n'
} > "${README_FILE}"

find "${PACK_DIR}" -type f | sort > "${MANIFEST_FILE}"

if command -v sha256sum >/dev/null 2>&1; then
  (
    cd "${PACK_DIR}"
    find . -type f ! -name "$(basename "${CHECKSUM_FILE}")" | sort | xargs sha256sum
  ) > "${CHECKSUM_FILE}" || true
elif command -v shasum >/dev/null 2>&1; then
  (
    cd "${PACK_DIR}"
    find . -type f ! -name "$(basename "${CHECKSUM_FILE}")" | sort | xargs shasum -a 256
  ) > "${CHECKSUM_FILE}" || true
fi

if command -v tar >/dev/null 2>&1; then
  tar -czf "${SUPPORT_PACK_ROOT%/}/${PACK_ID}.tar.gz" -C "${SUPPORT_PACK_ROOT%/}" "${PACK_ID}"
fi

info "Support pack created in ${PACK_DIR}"
