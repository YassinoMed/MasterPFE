#!/usr/bin/env bash

set -euo pipefail

SBOM_DIR="${SBOM_DIR:-artifacts/sbom}"
REPORT_DIR="${REPORT_DIR:-artifacts/release}"
REPORT_FILE="${REPORT_FILE:-${REPORT_DIR}/sbom-cyclonedx-validation.md}"
EXPECTED_SERVICE_COUNT="${EXPECTED_SERVICE_COUNT:-5}"
STRICT_SBOM_VALIDATION="${STRICT_SBOM_VALIDATION:-false}"

mkdir -p "${REPORT_DIR}"

status="PRÊT_NON_EXÉCUTÉ"
detail="SBOM index is missing; generate SBOMs with scripts/release/generate-sbom.sh."

if [[ -s "${SBOM_DIR}/sbom-index.txt" ]]; then
  if python3 - "${SBOM_DIR}/sbom-index.txt" "${EXPECTED_SERVICE_COUNT}" <<'PY'
import json
import pathlib
import sys

index = pathlib.Path(sys.argv[1])
expected = int(sys.argv[2])
records = []
for raw in index.read_text(encoding="utf-8").splitlines():
    line = raw.strip()
    if not line or line.startswith("#"):
        continue
    parts = line.split("|")
    if len(parts) != 5:
        raise SystemExit(f"invalid index row: {line}")
    service, _image, _source, sbom_file, _checksum = parts
    path = pathlib.Path(sbom_file)
    if not path.is_file():
        raise SystemExit(f"missing SBOM for {service}: {path}")
    payload = json.loads(path.read_text(encoding="utf-8"))
    if payload.get("bomFormat") != "CycloneDX":
        raise SystemExit(f"not CycloneDX: {path}")
    if "components" not in payload:
        raise SystemExit(f"missing components key: {path}")
    records.append(service)
if len(records) != expected:
    raise SystemExit(f"expected {expected} SBOMs, got {len(records)}")
PY
  then
    status="TERMINÉ"
    detail="All indexed SBOMs are valid CycloneDX JSON files."
  else
    status="PARTIEL"
    detail="SBOM index exists but validation failed."
  fi
fi

{
  printf '# SBOM CycloneDX Validation - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Status: `%s`\n' "${status}"
  printf -- '- SBOM directory: `%s`\n\n' "${SBOM_DIR}"
  printf '## Detail\n\n%s\n' "${detail}"
} > "${REPORT_FILE}"

if [[ "${status}" != "TERMINÉ" && "${STRICT_SBOM_VALIDATION}" == "true" ]]; then
  printf '[ERROR] SBOM CycloneDX validation failed. Report: %s\n' "${REPORT_FILE}" >&2
  exit 1
fi

printf '[INFO] SBOM CycloneDX validation written to %s\n' "${REPORT_FILE}"
