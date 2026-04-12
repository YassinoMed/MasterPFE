#!/usr/bin/env bash

set -euo pipefail

OUT_DIR="${OUT_DIR:-artifacts/release}"
SBOM_DIR="${SBOM_DIR:-artifacts/sbom}"
OUT_FILE="${OUT_FILE:-${OUT_DIR}/supply-chain-evidence.md}"

mkdir -p "${OUT_DIR}"

status_file() {
  local file="$1"
  if [[ -f "${file}" ]]; then
    printf 'OK: `%s`' "${file}"
  else
    printf 'ABSENT: `%s`' "${file}"
  fi
}

count_files() {
  local pattern="$1"
  find . -path "./${pattern}" -type f 2>/dev/null | wc -l | tr -d ' '
}

sbom_count=0
if [[ -d "${SBOM_DIR}" ]]; then
  sbom_count="$(find "${SBOM_DIR}" -type f -name '*sbom*.json' 2>/dev/null | wc -l | tr -d ' ')"
fi

signature_log_count="$(count_files "${OUT_DIR}/*-sign.log")"
verify_log_count="$(count_files "${OUT_DIR}/*verify*")"

cat > "${OUT_FILE}" <<EOF
# Supply Chain Evidence - SecureRAG Hub

## 1. Release evidence

- $(status_file "${OUT_DIR}/release-evidence.md")
- $(status_file "${OUT_DIR}/release-manifest.env")
- $(status_file "${OUT_DIR}/release-attestation.md")
- $(status_file "${OUT_DIR}/release-attestation.json")

## 2. Verification and signature evidence

- $(status_file "${OUT_DIR}/verify-summary.txt")
- $(status_file "${OUT_DIR}/sign-summary.txt")
- Signature logs detected: ${signature_log_count}
- Verification artefacts detected: ${verify_log_count}

## 3. Promotion evidence

- $(status_file "${OUT_DIR}/promotion-summary.txt")
- $(status_file "${OUT_DIR}/promotion-by-digest-summary.txt")
- $(status_file "${OUT_DIR}/promotion-digests.txt")

## 4. SBOM evidence

- SBOM directory: \`${SBOM_DIR}\`
- SBOM files detected: ${sbom_count}
- $(status_file "${OUT_DIR}/sbom-summary.txt")

EOF

if [[ -d "${SBOM_DIR}" ]]; then
  {
    printf '### SBOM files\n\n'
    find "${SBOM_DIR}" -type f | sort | while IFS= read -r sbom; do
      printf -- '- `%s`\n' "${sbom}"
    done
    printf '\n'
  } >> "${OUT_FILE}"
fi

cat >> "${OUT_FILE}" <<EOF
## 5. Status interpretation

- Ready: scripts and expected paths exist.
- Partial: evidence files are missing because the environment has not executed that step.
- Complete: digest promotion, SBOM, signature and verification artefacts are present for the release candidate.

## 6. Soutenance note

The official demo may use \`dry-run\` as preparatory evidence. Full supply-chain enforcement in \`execute\` mode depends on local availability of Cosign keys, Syft, Docker registry and reachable signed images.
EOF

printf 'Supply chain evidence written to %s\n' "${OUT_FILE}"
