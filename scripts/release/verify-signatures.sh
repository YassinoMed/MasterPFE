#!/usr/bin/env bash

set -euo pipefail

# Verify Cosign signatures for SecureRAG Hub images.
#
# Default behaviour:
# - Missing images are treated as FAIL because an unavailable release artifact
#   cannot be promoted safely.
# - Set ALLOW_MISSING_IMAGES=true to downgrade that case to SKIP.
#
# Supported modes:
# - Public key verification when COSIGN_PUBLIC_KEY is provided.
# - Keyless verification when explicit certificate identity settings are provided.
#
# In Jenkins-oriented deployments, key-pair verification is the recommended default.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/release/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

REGISTRY_HOST="${REGISTRY_HOST:-localhost:5001}"
IMAGE_TAG="${IMAGE_TAG:-dev}"
IMAGE_PREFIX="${IMAGE_PREFIX:-securerag-hub}"
REPORT_DIR="${REPORT_DIR:-artifacts/release}"
ALLOW_MISSING_IMAGES="${ALLOW_MISSING_IMAGES:-false}"
FAIL_FAST="${FAIL_FAST:-false}"

COSIGN_CERTIFICATE_IDENTITY="${COSIGN_CERTIFICATE_IDENTITY:-}"
COSIGN_CERTIFICATE_IDENTITY_REGEXP="${COSIGN_CERTIFICATE_IDENTITY_REGEXP:-}"
COSIGN_CERTIFICATE_OIDC_ISSUER="${COSIGN_CERTIFICATE_OIDC_ISSUER:-https://token.actions.githubusercontent.com}"
COSIGN_CERTIFICATE_OIDC_ISSUER_REGEXP="${COSIGN_CERTIFICATE_OIDC_ISSUER_REGEXP:-}"
COSIGN_WORKFLOW_PATH="${COSIGN_WORKFLOW_PATH:-}"

init_services_array

SUMMARY_FILE="${REPORT_DIR}/verify-summary.txt"
SUMMARY_MD="${REPORT_DIR}/verify-summary.md"
INDEX_JSON="${REPORT_DIR}/verify-index.json"
INDEX_JSONL="${REPORT_DIR}/verify-index.jsonl"

pass_count=0
fail_count=0
skip_count=0

derive_repo_slug() {
  local remote_url

  remote_url="$(git config --get remote.origin.url 2>/dev/null || true)"

  case "${remote_url}" in
    git@github.com:*)
      remote_url="${remote_url#git@github.com:}"
      printf '%s' "${remote_url%.git}"
      return 0
      ;;
    https://github.com/*)
      remote_url="${remote_url#https://github.com/}"
      printf '%s' "${remote_url%.git}"
      return 0
      ;;
    http://github.com/*)
      remote_url="${remote_url#http://github.com/}"
      printf '%s' "${remote_url%.git}"
      return 0
      ;;
  esac

  return 1
}

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

mode="keyless"
declare -a verify_args
verify_args=(verify)

if is_true "${COSIGN_ALLOW_INSECURE_REGISTRY:-false}"; then
  verify_args+=(--allow-insecure-registry)
fi

if [[ -n "${COSIGN_PUBLIC_KEY:-}" ]]; then
  if [[ ! -f "${COSIGN_PUBLIC_KEY}" ]]; then
    error "COSIGN_PUBLIC_KEY points to a non-existent file: ${COSIGN_PUBLIC_KEY}"
    exit 2
  fi

  mode="key-pair"
  verify_args+=(--key "${COSIGN_PUBLIC_KEY}")
else
  if [[ -z "${COSIGN_CERTIFICATE_IDENTITY}" && -z "${COSIGN_CERTIFICATE_IDENTITY_REGEXP}" ]]; then
    repo_slug="${GITHUB_REPOSITORY:-}"

    if [[ -z "${repo_slug}" ]]; then
      repo_slug="$(derive_repo_slug || true)"
    fi

    if [[ -n "${repo_slug}" && -n "${COSIGN_WORKFLOW_PATH}" ]]; then
      COSIGN_CERTIFICATE_IDENTITY_REGEXP="^https://github.com/${repo_slug}/${COSIGN_WORKFLOW_PATH}@refs/(heads/main|tags/.+)$"
    else
      error "Verification requires COSIGN_PUBLIC_KEY for key-pair mode, or explicit COSIGN_CERTIFICATE_IDENTITY / COSIGN_CERTIFICATE_IDENTITY_REGEXP for keyless mode."
      exit 2
    fi
  fi

  if [[ -n "${COSIGN_CERTIFICATE_IDENTITY}" ]]; then
    verify_args+=(--certificate-identity "${COSIGN_CERTIFICATE_IDENTITY}")
  else
    verify_args+=(--certificate-identity-regexp "${COSIGN_CERTIFICATE_IDENTITY_REGEXP}")
  fi

  if [[ -n "${COSIGN_CERTIFICATE_OIDC_ISSUER_REGEXP}" ]]; then
    verify_args+=(--certificate-oidc-issuer-regexp "${COSIGN_CERTIFICATE_OIDC_ISSUER_REGEXP}")
  else
    verify_args+=(--certificate-oidc-issuer "${COSIGN_CERTIFICATE_OIDC_ISSUER}")
  fi
fi

{
  printf '# SecureRAG Hub image signature verification summary\n'
  printf '# Generated at: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf '# Cosign version: %s\n' "$(cosign version 2>/dev/null | head -n 1 || printf 'unavailable')"
  printf '# Mode: %s\n' "${mode}"
  printf '%-6s | %-18s | %-64s | %-10s | %-40s | %s\n' \
    "STATUS" "SERVICE" "IMAGE" "MODE" "ARTIFACT" "DETAIL"
} > "${SUMMARY_FILE}"

{
  printf '# Cosign Verify Summary - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Cosign version: `%s`\n' "$(cosign version 2>/dev/null | head -n 1 || printf 'unavailable')"
  printf -- '- Mode: `%s`\n\n' "${mode}"
  printf '| Service | Image | Status | Digest | Mode | Log | Detail |\n'
  printf '|---|---|---:|---|---|---|---|\n'
} > "${SUMMARY_MD}"

info "Cosign verification mode: ${mode}"

for service in "${SERVICES_ARRAY[@]}"; do
  image_ref="$(build_image_ref "${service}")"
  log_file="${REPORT_DIR}/${service}-verify.log"

  info "Verifying ${service} -> ${image_ref}"

  if ! image_reachable_in_registry "${image_ref}"; then
    message="image is not reachable in the registry"

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

  verify_ref="${image_ref}"
  digest="-"
  verify_detail="signature verified for tag; digest unavailable"
  if resolved_digest="$(resolve_digest "${image_ref}")"; then
    digest="${resolved_digest}"
    verify_ref="$(digest_ref_for "${image_ref}" "${digest}")"
    verify_detail="signature verified for digest ${digest}"
  fi

  if cosign "${verify_args[@]}" "${verify_ref}" > "${log_file}" 2>&1; then
    pass_count=$((pass_count + 1))
    record_result "PASS" "${service}" "${verify_ref}" "${mode}" "${log_file}" "${verify_detail}"
    record_markdown_row "PASS" "${service}" "${verify_ref}" "${digest}" "${mode}" "${log_file}" "${verify_detail}"
    record_json_entry "PASS" "${service}" "${verify_ref}" "${digest}" "${mode}" "${log_file}" "${verify_detail}"
    info "${service}: ${verify_detail}"
  else
    fail_count=$((fail_count + 1))
    record_result "FAIL" "${service}" "${verify_ref}" "${mode}" "${log_file}" "verification failed or signature missing"
    record_markdown_row "FAIL" "${service}" "${verify_ref}" "${digest}" "${mode}" "${log_file}" "verification failed or signature missing"
    record_json_entry "FAIL" "${service}" "${verify_ref}" "${digest}" "${mode}" "${log_file}" "verification failed or signature missing"
    handle_failure "${service}: verification failed, inspect ${log_file}"
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
    json.dump({"verifications": entries}, handle, indent=2, sort_keys=True)
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

printf '\n[INFO] Signature verification completed: PASS=%s FAIL=%s SKIP=%s\n' \
  "${pass_count}" "${fail_count}" "${skip_count}" | tee -a "${SUMMARY_FILE}"
info "Cosign verify Markdown summary: ${SUMMARY_MD}"
info "Cosign verify JSON index: ${INDEX_JSON}"

if (( fail_count > 0 )); then
  exit 1
fi

exit 0
