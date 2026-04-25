#!/usr/bin/env bash

set -euo pipefail

REPORT_DIR="${REPORT_DIR:-artifacts/release}"
SBOM_DIR="${SBOM_DIR:-artifacts/sbom}"
IMAGE_PREFIX="${IMAGE_PREFIX:-securerag-hub}"
SOURCE_IMAGE_TAG="${SOURCE_IMAGE_TAG:-${IMAGE_TAG:-dev}}"
TARGET_IMAGE_TAG="${TARGET_IMAGE_TAG:-release-local}"
DIGEST_RECORD_FILE="${DIGEST_RECORD_FILE:-${REPORT_DIR}/promotion-digests.txt}"
SUMMARY_FILE="${SUMMARY_FILE:-${REPORT_DIR}/release-proof-strict.md}"

mkdir -p "${REPORT_DIR}"

infer_source_tag_from_promotion_evidence() {
  local manifest="${REPORT_DIR}/promotion-digests.json"

  python3 - "${manifest}" "${DIGEST_RECORD_FILE}" "${TARGET_IMAGE_TAG}" <<'PY'
import json
import os
import sys

manifest, digest_record, expected_target = sys.argv[1:]

if os.path.exists(manifest):
    with open(manifest, encoding="utf-8") as handle:
        payload = json.load(handle)

    source_tag = payload.get("source_tag")
    target_tag = payload.get("target_tag")
    if source_tag and target_tag == expected_target:
        print(source_tag)
        raise SystemExit(0)

source_tags = set()
if os.path.exists(digest_record):
    with open(digest_record, encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split("|")
            if len(parts) != 4:
                continue
            _, source_ref, target_ref, _ = parts
            source_tag = source_ref.rsplit(":", 1)[-1]
            target_tag = target_ref.rsplit(":", 1)[-1]
            if target_tag == expected_target and source_tag:
                source_tags.add(source_tag)

if len(source_tags) == 1:
    print(next(iter(source_tags)))
    raise SystemExit(0)

raise SystemExit(1)
PY
}

if [[ "${SOURCE_IMAGE_TAG}" == "dev" && "${TARGET_IMAGE_TAG}" != "release-local" ]]; then
  inferred_source_tag="$(infer_source_tag_from_promotion_evidence || true)"
  if [[ -n "${inferred_source_tag}" ]]; then
    printf '[INFO] Inferred SOURCE_IMAGE_TAG=%s from existing promotion evidence\n' "${inferred_source_tag}"
    SOURCE_IMAGE_TAG="${inferred_source_tag}"
  fi
fi

export REPORT_DIR SBOM_DIR IMAGE_PREFIX SOURCE_IMAGE_TAG TARGET_IMAGE_TAG DIGEST_RECORD_FILE

{
  printf '# Strict Release Proof - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Source tag: `%s`\n' "${SOURCE_IMAGE_TAG}"
  printf -- '- Target tag: `%s`\n\n' "${TARGET_IMAGE_TAG}"
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
