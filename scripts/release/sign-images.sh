#!/usr/bin/env bash

set -euo pipefail

# Sign SecureRAG Hub images with Cosign.
#
# Supported modes:
# - Keyless: when COSIGN_KEY is not provided.
# - Key pair: when COSIGN_KEY points to a private key file.
#
# Notes:
# - Signing targets registry-hosted images. The script therefore verifies that
#   the image reference is reachable in the registry before signing it.
# - By default the script keeps going service by service and aggregates errors.
#   Set FAIL_FAST=true to stop on the first critical failure.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/release/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

REGISTRY_HOST="${REGISTRY_HOST:-localhost:5001}"
IMAGE_TAG="${IMAGE_TAG:-dev}"
IMAGE_PREFIX="${IMAGE_PREFIX:-securerag-hub}"
REPORT_DIR="${REPORT_DIR:-artifacts/release}"
ALLOW_MISSING_IMAGES="${ALLOW_MISSING_IMAGES:-false}"
FAIL_FAST="${FAIL_FAST:-false}"
COSIGN_YES="${COSIGN_YES:-true}"
COSIGN_EXPERIMENTAL="${COSIGN_EXPERIMENTAL:-}"

init_services_array

SUMMARY_FILE="${REPORT_DIR}/sign-summary.txt"
SUMMARY_MD="${REPORT_DIR}/sign-summary.md"
INDEX_JSON="${REPORT_DIR}/sign-index.json"
INDEX_JSONL="${REPORT_DIR}/sign-index.jsonl"

pass_count=0
fail_count=0
skip_count=0

record_result() {
  local status="$1"
  local service="$2"
  local image_ref="$3"
  local mode="$4"
  local artifact="$5"
  local detail="$6"

  printf '%-6s | %-18s | %-64s | %-10s | %-40s | %s\n' \
    "${status}" "${service}" "${image_ref}" "${mode}" "${artifact}" "${detail}" \
    | tee -a "${SUMMARY_FILE}"
}

record_markdown_row() {
  local status="$1"
  local service="$2"
  local image_ref="$3"
  local digest="$4"
  local mode="$5"
  local artifact="$6"
  local detail="$7"

  printf '| `%s` | `%s` | `%s` | `%s` | `%s` | `%s` | %s |\n' \
    "${service}" "${image_ref}" "${status}" "${digest}" "${mode}" "${artifact}" "${detail}" \
    >> "${SUMMARY_MD}"
}

record_json_entry() {
  local status="$1"
  local service="$2"
  local image_ref="$3"
  local digest="$4"
  local mode="$5"
  local artifact="$6"
  local detail="$7"

  python3 - "${INDEX_JSONL}" "${status}" "${service}" "${image_ref}" "${digest}" "${mode}" "${artifact}" "${detail}" <<'PY'
import json
import sys

path, status, service, image_ref, digest, mode, artifact, detail = sys.argv[1:]
entry = {
    "status": status,
    "service": service,
    "image": image_ref,
    "digest": None if digest == "-" else digest,
    "mode": mode,
    "artifact": None if artifact == "-" else artifact,
    "detail": detail,
}

with open(path, "a", encoding="utf-8") as handle:
    handle.write(json.dumps(entry, sort_keys=True) + "\n")
PY
}

require_command cosign
require_command python3
mkdir -p "${REPORT_DIR}"
: > "${INDEX_JSONL}"

if [[ -n "${COSIGN_EXPERIMENTAL}" ]]; then
  export COSIGN_EXPERIMENTAL
fi

mode="keyless"
declare -a sign_args
sign_args=(sign)

if is_true "${COSIGN_YES}"; then
  sign_args+=(--yes)
fi

if [[ -n "${COSIGN_KEY:-}" ]]; then
  if [[ ! -f "${COSIGN_KEY}" ]]; then
    error "COSIGN_KEY points to a non-existent file: ${COSIGN_KEY}"
    exit 2
  fi

  mode="key-pair"
  sign_args+=(--key "${COSIGN_KEY}")
fi

{
  printf '# SecureRAG Hub image signing summary\n'
  printf '# Generated at: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf '# Cosign version: %s\n' "$(cosign version 2>/dev/null | head -n 1 || printf 'unavailable')"
  printf '# Mode: %s\n' "${mode}"
  printf '%-6s | %-18s | %-64s | %-10s | %-40s | %s\n' \
    "STATUS" "SERVICE" "IMAGE" "MODE" "ARTIFACT" "DETAIL"
} > "${SUMMARY_FILE}"

{
  printf '# Cosign Sign Summary - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Cosign version: `%s`\n' "$(cosign version 2>/dev/null | head -n 1 || printf 'unavailable')"
  printf -- '- Mode: `%s`\n\n' "${mode}"
  printf '| Service | Image | Status | Digest | Mode | Log | Detail |\n'
  printf '|---|---|---:|---|---|---|---|\n'
} > "${SUMMARY_MD}"

info "Cosign signing mode: ${mode}"

for service in "${SERVICES_ARRAY[@]}"; do
  image_ref="$(build_image_ref "${service}")"
  log_file="${REPORT_DIR}/${service}-sign.log"

  info "Signing ${service} -> ${image_ref}"

  if ! image_reachable_in_registry "${image_ref}"; then
    message="image is not reachable in the registry; push it before signing"

    if is_true "${ALLOW_MISSING_IMAGES}"; then
      skip_count=$((skip_count + 1))
      record_result "SKIP" "${service}" "${image_ref}" "${mode}" "-" "${message}"
      record_markdown_row "SKIP" "${service}" "${image_ref}" "-" "${mode}" "-" "${message}"
      record_json_entry "SKIP" "${service}" "${image_ref}" "-" "${mode}" "-" "${message}"
      warn "${service}: ${message}"
      continue
    fi

    fail_count=$((fail_count + 1))
    record_result "FAIL" "${service}" "${image_ref}" "${mode}" "-" "${message}"
    record_markdown_row "FAIL" "${service}" "${image_ref}" "-" "${mode}" "-" "${message}"
    record_json_entry "FAIL" "${service}" "${image_ref}" "-" "${mode}" "-" "${message}"
    handle_failure "${service}: ${message}"
    continue
  fi

  sign_ref="${image_ref}"
  digest="-"
  sign_detail="signature created for tag; digest unavailable"
  if resolved_digest="$(resolve_digest "${image_ref}")"; then
    digest="${resolved_digest}"
    sign_ref="$(digest_ref_for "${image_ref}" "${digest}")"
    sign_detail="signature created for digest ${digest}"
  fi

  if cosign "${sign_args[@]}" "${sign_ref}" > "${log_file}" 2>&1; then
    pass_count=$((pass_count + 1))
    record_result "PASS" "${service}" "${sign_ref}" "${mode}" "${log_file}" "${sign_detail}"
    record_markdown_row "PASS" "${service}" "${sign_ref}" "${digest}" "${mode}" "${log_file}" "${sign_detail}"
    record_json_entry "PASS" "${service}" "${sign_ref}" "${digest}" "${mode}" "${log_file}" "${sign_detail}"
    info "${service}: ${sign_detail}"
  else
    fail_count=$((fail_count + 1))
    record_result "FAIL" "${service}" "${sign_ref}" "${mode}" "${log_file}" "cosign sign failed"
    record_markdown_row "FAIL" "${service}" "${sign_ref}" "${digest}" "${mode}" "${log_file}" "cosign sign failed"
    record_json_entry "FAIL" "${service}" "${sign_ref}" "${digest}" "${mode}" "${log_file}" "cosign sign failed"
    handle_failure "${service}: signing failed, inspect ${log_file}"
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
    json.dump({"signatures": entries}, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY

rm -f "${INDEX_JSONL}"

{
  printf '\n## Result\n\n'
  printf -- '- PASS: `%s`\n' "${pass_count}"
  printf -- '- FAIL: `%s`\n' "${fail_count}"
  printf -- '- SKIP: `%s`\n' "${skip_count}"
  printf -- '- JSON index: `%s`\n' "${INDEX_JSON}"
} >> "${SUMMARY_MD}"

printf '\n[INFO] Image signing completed: PASS=%s FAIL=%s SKIP=%s\n' \
  "${pass_count}" "${fail_count}" "${skip_count}" | tee -a "${SUMMARY_FILE}"
info "Cosign sign Markdown summary: ${SUMMARY_MD}"
info "Cosign sign JSON index: ${INDEX_JSON}"

if (( fail_count > 0 )); then
  exit 1
fi

exit 0
