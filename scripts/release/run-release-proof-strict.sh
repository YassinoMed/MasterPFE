#!/usr/bin/env bash

set -euo pipefail

REPORT_DIR="${REPORT_DIR:-artifacts/release}"
SUMMARY_FILE="${SUMMARY_FILE:-${REPORT_DIR}/release-proof-strict.md}"

mkdir -p "${REPORT_DIR}"

{
  printf '# Strict Release Proof - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
} > "${SUMMARY_FILE}"

bash scripts/release/run-supply-chain-execute.sh
STRICT_SBOM_VALIDATION=true bash scripts/release/validate-sbom-cyclonedx.sh
STRICT_RELEASE_ATTESTATION=true bash scripts/release/generate-release-attestation.sh
STRICT_PROVENANCE=true bash scripts/release/generate-provenance-statement.sh
bash scripts/release/assert-supply-chain-evidence.sh

{
  printf '| Gate | Status |\n'
  printf '|---|---:|\n'
  printf '| Supply chain execute | TERMINÉ |\n'
  printf '| SBOM CycloneDX validation | TERMINÉ |\n'
  printf '| Release attestation | TERMINÉ |\n'
  printf '| SLSA-style provenance | TERMINÉ |\n'
  printf '| Mandatory evidence gate | TERMINÉ |\n'
} >> "${SUMMARY_FILE}"

printf '[INFO] Strict release proof written to %s\n' "${SUMMARY_FILE}"
