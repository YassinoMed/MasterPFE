#!/usr/bin/env bash

set -euo pipefail

# Generate CycloneDX SBOMs for SecureRAG Hub images.
#
# Strategy:
# - Prefer a local Docker image when it exists.
# - Fall back to the remote registry reference when the image is not available locally.
# - Continue service by service to produce the largest useful result set possible.
# - Exit non-zero if at least one image could not be processed.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/release/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

REGISTRY_HOST="${REGISTRY_HOST:-localhost:5001}"
IMAGE_TAG="${IMAGE_TAG:-dev}"
IMAGE_PREFIX="${IMAGE_PREFIX:-securerag-hub}"
SBOM_DIR="${SBOM_DIR:-artifacts/sbom}"
REPORT_DIR="${REPORT_DIR:-artifacts/release}"
SYFT_FORMAT="${SYFT_FORMAT:-cyclonedx-json}"
ALLOW_MISSING_IMAGES="${ALLOW_MISSING_IMAGES:-false}"

init_services_array

SUMMARY_FILE="${REPORT_DIR}/sbom-summary.txt"
SUMMARY_MD="${REPORT_DIR}/sbom-summary.md"
INDEX_FILE="${SBOM_DIR}/sbom-index.txt"
INDEX_JSON="${SBOM_DIR}/sbom-index.json"
INDEX_JSONL="${SBOM_DIR}/sbom-index.jsonl"

pass_count=0
fail_count=0
skip_count=0

detect_source_ref() {
  local image_ref="$1"

  if command -v docker >/dev/null 2>&1; then
    if docker image inspect "${image_ref}" >/dev/null 2>&1; then
      printf 'docker:%s' "${image_ref}"
      return 0
    fi

    if docker manifest inspect "${image_ref}" >/dev/null 2>&1; then
      printf 'registry:%s' "${image_ref}"
      return 0
    fi
  else
    # Best-effort fallback for CI environments that rely on registry access only.
    printf 'registry:%s' "${image_ref}"
    return 0
  fi

  return 1
}

syft_supports_scan() {
  syft help 2>/dev/null | grep -Eq '(^|[[:space:]])scan([[:space:]]|$)'
}

run_syft() {
  local source_ref="$1"
  local output_file="$2"
  local log_file="$3"

  if syft_supports_scan; then
    syft scan -q -o "${SYFT_FORMAT}" "${source_ref}" > "${output_file}" 2> "${log_file}"
  else
    syft -q -o "${SYFT_FORMAT}" "${source_ref}" > "${output_file}" 2> "${log_file}"
  fi
}

validate_sbom_file() {
  local target_file="$1"

  python3 - "${target_file}" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)

if payload.get("bomFormat") != "CycloneDX":
    raise SystemExit("SBOM is not a CycloneDX document")
PY
}

sbom_component_count() {
  local target_file="$1"

  python3 - "${target_file}" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)

print(len(payload.get("components") or []))
PY
}

record_result() {
  local status="$1"
  local service="$2"
  local image_ref="$3"
  local source_kind="$4"
  local artifact="$5"
  local detail="$6"

  printf '%-6s | %-18s | %-64s | %-8s | %-40s | %s\n' \
    "${status}" "${service}" "${image_ref}" "${source_kind}" "${artifact}" "${detail}" \
    | tee -a "${SUMMARY_FILE}"
}

record_markdown_row() {
  local status="$1"
  local service="$2"
  local image_ref="$3"
  local source_kind="$4"
  local artifact="$5"
  local component_count="$6"
  local checksum="$7"
  local detail="$8"

  printf '| `%s` | `%s` | `%s` | `%s` | `%s` | %s | `%s` | %s |\n' \
    "${service}" "${image_ref}" "${status}" "${source_kind}" "${artifact}" "${component_count}" "${checksum}" "${detail}" \
    >> "${SUMMARY_MD}"
}

record_json_entry() {
  local status="$1"
  local service="$2"
  local image_ref="$3"
  local source_kind="$4"
  local artifact="$5"
  local checksum="$6"
  local component_count="$7"
  local detail="$8"

  python3 - "${INDEX_JSONL}" "${status}" "${service}" "${image_ref}" "${source_kind}" "${artifact}" "${checksum}" "${component_count}" "${detail}" <<'PY'
import json
import sys

path, status, service, image_ref, source_kind, artifact, checksum, component_count, detail = sys.argv[1:]

try:
    component_count_value = int(component_count)
except ValueError:
    component_count_value = None

entry = {
    "status": status,
    "service": service,
    "image": image_ref,
    "source": None if source_kind == "-" else source_kind,
    "sbom": None if artifact == "-" else artifact,
    "sha256": None if checksum == "-" else checksum,
    "component_count": component_count_value,
    "format": "CycloneDX JSON",
    "detail": detail,
}

with open(path, "a", encoding="utf-8") as handle:
    handle.write(json.dumps(entry, sort_keys=True) + "\n")
PY
}

require_command syft
require_command python3
mkdir -p "${SBOM_DIR}" "${REPORT_DIR}"
: > "${INDEX_JSONL}"

{
  printf '# SecureRAG Hub SBOM summary\n'
  printf '# Generated at: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf '# Syft version: %s\n' "$(syft version 2>/dev/null | head -n 1 || printf 'unavailable')"
  printf '%-6s | %-18s | %-64s | %-8s | %-40s | %s\n' \
    "STATUS" "SERVICE" "IMAGE" "SOURCE" "ARTIFACT" "DETAIL"
} > "${SUMMARY_FILE}"

{
  printf '# Syft SBOM Summary - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Syft version: `%s`\n' "$(syft version 2>/dev/null | head -n 1 || printf 'unavailable')"
  printf -- '- Format: `%s`\n\n' "${SYFT_FORMAT}"
  printf '| Service | Image | Status | Source | SBOM | Components | SHA256 | Detail |\n'
  printf '|---|---|---:|---|---|---:|---|---|\n'
} > "${SUMMARY_MD}"

{
  printf '# service|image|source|sbom_file|sha256\n'
} > "${INDEX_FILE}"

info "Generating SBOMs in ${SBOM_DIR}"

for service in "${SERVICES_ARRAY[@]}"; do
  image_ref="$(build_image_ref "${service}")"
  sbom_file="${SBOM_DIR}/${service}-sbom.cdx.json"
  log_file="${REPORT_DIR}/${service}-sbom.log"

  info "Processing ${service} -> ${image_ref}"

  if ! source_ref="$(detect_source_ref "${image_ref}")"; then
    message="image not found locally and not reachable in the registry"
    if is_true "${ALLOW_MISSING_IMAGES}"; then
      skip_count=$((skip_count + 1))
      record_result "SKIP" "${service}" "${image_ref}" "-" "-" "${message}"
      record_markdown_row "SKIP" "${service}" "${image_ref}" "-" "-" "0" "-" "${message}"
      record_json_entry "SKIP" "${service}" "${image_ref}" "-" "-" "-" "0" "${message}"
      warn "${service}: ${message}"
      continue
    fi

    fail_count=$((fail_count + 1))
    record_result "FAIL" "${service}" "${image_ref}" "-" "-" "${message}"
    record_markdown_row "FAIL" "${service}" "${image_ref}" "-" "-" "0" "-" "${message}"
    record_json_entry "FAIL" "${service}" "${image_ref}" "-" "-" "-" "0" "${message}"
    error "${service}: ${message}"
    continue
  fi

  source_kind="${source_ref%%:*}"

  if run_syft "${source_ref}" "${sbom_file}" "${log_file}" && validate_sbom_file "${sbom_file}" >> "${log_file}" 2>&1; then
    checksum="$(file_sha256 "${sbom_file}")"
    components="$(sbom_component_count "${sbom_file}")"
    pass_count=$((pass_count + 1))
    printf '%s|%s|%s|%s|%s\n' \
      "${service}" "${image_ref}" "${source_kind}" "${sbom_file}" "${checksum}" >> "${INDEX_FILE}"
    record_result "PASS" "${service}" "${image_ref}" "${source_kind}" "${sbom_file}" "components=${components}; sha256=${checksum}"
    record_markdown_row "PASS" "${service}" "${image_ref}" "${source_kind}" "${sbom_file}" "${components}" "${checksum}" "CycloneDX JSON valid"
    record_json_entry "PASS" "${service}" "${image_ref}" "${source_kind}" "${sbom_file}" "${checksum}" "${components}" "CycloneDX JSON valid"
    info "${service}: SBOM written to ${sbom_file}"
  else
    fail_count=$((fail_count + 1))
    rm -f "${sbom_file}"
    record_result "FAIL" "${service}" "${image_ref}" "${source_kind}" "${log_file}" "Syft failed or produced an invalid CycloneDX SBOM"
    record_markdown_row "FAIL" "${service}" "${image_ref}" "${source_kind}" "${log_file}" "0" "-" "Syft failed or produced an invalid CycloneDX SBOM"
    record_json_entry "FAIL" "${service}" "${image_ref}" "${source_kind}" "-" "-" "0" "Syft failed or produced an invalid CycloneDX SBOM"
    error "${service}: unable to generate a valid SBOM, see ${log_file}"
  fi
done

python3 - "${INDEX_JSONL}" "${INDEX_JSON}" <<'PY'
import json
import sys

jsonl_path, json_path = sys.argv[1:]
entries = []
with open(jsonl_path, encoding="utf-8") as handle:
    for line in handle:
        line = line.strip()
        if line:
            entries.append(json.loads(line))

with open(json_path, "w", encoding="utf-8") as handle:
    json.dump({"sboms": entries}, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY

rm -f "${INDEX_JSONL}"

{
  printf '\n## Result\n\n'
  printf -- '- PASS: `%s`\n' "${pass_count}"
  printf -- '- FAIL: `%s`\n' "${fail_count}"
  printf -- '- SKIP: `%s`\n' "${skip_count}"
  printf -- '- Text index: `%s`\n' "${INDEX_FILE}"
  printf -- '- JSON index: `%s`\n' "${INDEX_JSON}"
} >> "${SUMMARY_MD}"

printf '\n[INFO] SBOM generation completed: PASS=%s FAIL=%s SKIP=%s\n' \
  "${pass_count}" "${fail_count}" "${skip_count}" | tee -a "${SUMMARY_FILE}"
info "SBOM index: ${INDEX_FILE}"
info "SBOM Markdown summary: ${SUMMARY_MD}"
info "SBOM JSON index: ${INDEX_JSON}"

if (( fail_count > 0 )); then
  exit 1
fi

exit 0
