#!/usr/bin/env bash

set -euo pipefail

# Promote previously verified images by digest without rebuilding them.
# The target tag is created from the exact digest resolved for the source tag,
# and a digest evidence file is produced for downstream deployment and audit.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/release/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

REGISTRY_HOST="${REGISTRY_HOST:-localhost:5001}"
IMAGE_PREFIX="${IMAGE_PREFIX:-securerag-hub}"
SOURCE_IMAGE_TAG="${SOURCE_IMAGE_TAG:-${IMAGE_TAG:-dev}}"
TARGET_IMAGE_TAG="${TARGET_IMAGE_TAG:-release-local}"
REPORT_DIR="${REPORT_DIR:-artifacts/release}"
DIGEST_RECORD_FILE="${DIGEST_RECORD_FILE:-${REPORT_DIR}/promotion-digests.txt}"
VERIFY_SOURCE_BEFORE_PROMOTION="${VERIFY_SOURCE_BEFORE_PROMOTION:-true}"
VERIFY_TARGET_AFTER_PROMOTION="${VERIFY_TARGET_AFTER_PROMOTION:-true}"
ALLOW_MISSING_IMAGES="${ALLOW_MISSING_IMAGES:-false}"
FAIL_FAST="${FAIL_FAST:-false}"

init_services_array

SUMMARY_FILE="${REPORT_DIR}/promotion-by-digest-summary.txt"
SUMMARY_MD="${REPORT_DIR}/promotion-by-digest-summary.md"
MANIFEST_JSON="${REPORT_DIR}/promotion-digests.json"
MANIFEST_JSONL=""

pass_count=0
fail_count=0
skip_count=0

record_result() {
  local status="$1"
  local service="$2"
  local source_ref="$3"
  local target_ref="$4"
  local digest="$5"
  local artifact="$6"
  local detail="$7"

  printf '%-6s | %-18s | %-64s | %-64s | %-71s | %-40s | %s\n' \
    "${status}" "${service}" "${source_ref}" "${target_ref}" "${digest}" "${artifact}" "${detail}" \
    | tee -a "${SUMMARY_FILE}"
}

record_markdown_row() {
  local status="$1"
  local service="$2"
  local source_ref="$3"
  local target_ref="$4"
  local digest="$5"
  local artifact="$6"
  local detail="$7"

  printf '| `%s` | `%s` | `%s` | `%s` | `%s` | `%s` | %s |\n' \
    "${service}" "${status}" "${source_ref}" "${target_ref}" "${digest}" "${artifact}" "${detail}" \
    >> "${SUMMARY_MD}"
}

record_json_entry() {
  local status="$1"
  local service="$2"
  local source_ref="$3"
  local target_ref="$4"
  local digest="$5"
  local artifact="$6"
  local detail="$7"

  python3 - "${MANIFEST_JSONL}" "${status}" "${service}" "${source_ref}" "${target_ref}" "${digest}" "${artifact}" "${detail}" <<'PY'
import json
import sys

path, status, service, source_ref, target_ref, digest, artifact, detail = sys.argv[1:]
entry = {
    "status": status,
    "service": service,
    "source_ref": source_ref,
    "target_ref": target_ref,
    "digest": None if digest == "-" else digest,
    "artifact": None if artifact == "-" else artifact,
    "detail": detail,
}

with open(path, "a", encoding="utf-8") as handle:
    handle.write(json.dumps(entry, sort_keys=True) + "\n")
PY
}

promote_exact_digest() {
  local source_ref="$1"
  local target_ref="$2"
  local digest="$3"
  local source_digest_ref

  source_digest_ref="$(digest_ref_for "${source_ref}" "${digest}")"

  if docker buildx version >/dev/null 2>&1; then
    if docker buildx imagetools create --tag "${target_ref}" "${source_digest_ref}" >/dev/null; then
      docker pull "${target_ref}" >/dev/null 2>&1 || true
      return 0
    fi
    warn "buildx digest promotion failed for ${source_digest_ref}; falling back to pull/tag/push"
  fi

  docker pull "${source_digest_ref}" >/dev/null
  docker tag "${source_digest_ref}" "${target_ref}"
  docker push "${target_ref}" >/dev/null
}

require_command docker
require_command python3
mkdir -p "${REPORT_DIR}"
MANIFEST_JSONL="$(mktemp "${REPORT_DIR}/promotion-digests.jsonl.XXXXXX")"
trap 'rm -f "${MANIFEST_JSONL}"' EXIT
: > "${MANIFEST_JSONL}"

{
  printf '# SecureRAG Hub digest promotion summary\n'
  printf '# Generated at: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf '# Source tag: %s\n' "${SOURCE_IMAGE_TAG}"
  printf '# Target tag: %s\n' "${TARGET_IMAGE_TAG}"
  printf '# Digest record: %s\n' "${DIGEST_RECORD_FILE}"
  printf '%-6s | %-18s | %-64s | %-64s | %-71s | %-40s | %s\n' \
    "STATUS" "SERVICE" "SOURCE IMAGE" "TARGET IMAGE" "DIGEST" "ARTIFACT" "DETAIL"
} > "${SUMMARY_FILE}"

{
  printf '# Digest Promotion Manifest - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Source tag: `%s`\n' "${SOURCE_IMAGE_TAG}"
  printf -- '- Target tag: `%s`\n' "${TARGET_IMAGE_TAG}"
  printf -- '- Digest record: `%s`\n' "${DIGEST_RECORD_FILE}"
  printf -- '- JSON manifest: `%s`\n\n' "${MANIFEST_JSON}"
  printf '| Service | Status | Source image | Target image | Digest | Log | Detail |\n'
  printf '|---|---:|---|---|---|---|---|\n'
} > "${SUMMARY_MD}"

printf '# service|source_ref|target_ref|digest\n' > "${DIGEST_RECORD_FILE}"

if is_true "${VERIFY_SOURCE_BEFORE_PROMOTION}"; then
  info "Verifying source images before digest promotion"
  REGISTRY_HOST="${REGISTRY_HOST}" IMAGE_PREFIX="${IMAGE_PREFIX}" IMAGE_TAG="${SOURCE_IMAGE_TAG}" \
    REPORT_DIR="${REPORT_DIR}" ALLOW_MISSING_IMAGES="${ALLOW_MISSING_IMAGES}" FAIL_FAST="${FAIL_FAST}" \
    COSIGN_PUBLIC_KEY="${COSIGN_PUBLIC_KEY:-}" \
    COSIGN_CERTIFICATE_IDENTITY="${COSIGN_CERTIFICATE_IDENTITY:-}" \
    COSIGN_CERTIFICATE_IDENTITY_REGEXP="${COSIGN_CERTIFICATE_IDENTITY_REGEXP:-}" \
    COSIGN_CERTIFICATE_OIDC_ISSUER="${COSIGN_CERTIFICATE_OIDC_ISSUER:-}" \
    COSIGN_CERTIFICATE_OIDC_ISSUER_REGEXP="${COSIGN_CERTIFICATE_OIDC_ISSUER_REGEXP:-}" \
    COSIGN_ALLOW_INSECURE_REGISTRY="${COSIGN_ALLOW_INSECURE_REGISTRY:-false}" \
    bash scripts/release/verify-signatures.sh
fi

for service in "${SERVICES_ARRAY[@]}"; do
  source_ref="$(build_image_ref "${service}" "${SOURCE_IMAGE_TAG}")"
  target_ref="$(build_image_ref "${service}" "${TARGET_IMAGE_TAG}")"
  log_file="${REPORT_DIR}/${service}-promote-by-digest.log"

  info "Promoting ${source_ref} -> ${target_ref} by digest"

  if ! image_reachable_in_registry "${source_ref}"; then
    message="source image is not reachable in the registry"
    if is_true "${ALLOW_MISSING_IMAGES}"; then
      skip_count=$((skip_count + 1))
      record_result "SKIP" "${service}" "${source_ref}" "${target_ref}" "-" "-" "${message}"
      record_markdown_row "SKIP" "${service}" "${source_ref}" "${target_ref}" "-" "-" "${message}"
      record_json_entry "SKIP" "${service}" "${source_ref}" "${target_ref}" "-" "-" "${message}"
      warn "${service}: ${message}"
      continue
    fi

    fail_count=$((fail_count + 1))
    record_result "FAIL" "${service}" "${source_ref}" "${target_ref}" "-" "-" "${message}"
    record_markdown_row "FAIL" "${service}" "${source_ref}" "${target_ref}" "-" "-" "${message}"
    record_json_entry "FAIL" "${service}" "${source_ref}" "${target_ref}" "-" "-" "${message}"
    handle_failure "${service}: ${message}"
    continue
  fi

  if ! digest="$(resolve_digest "${source_ref}")"; then
    fail_count=$((fail_count + 1))
    record_result "FAIL" "${service}" "${source_ref}" "${target_ref}" "-" "-" "unable to resolve manifest digest"
    record_markdown_row "FAIL" "${service}" "${source_ref}" "${target_ref}" "-" "-" "unable to resolve manifest digest"
    record_json_entry "FAIL" "${service}" "${source_ref}" "${target_ref}" "-" "-" "unable to resolve manifest digest"
    handle_failure "${service}: unable to resolve digest"
    continue
  fi

  if promote_exact_digest "${source_ref}" "${target_ref}" "${digest}" > "${log_file}" 2>&1; then
    if ! target_digest="$(resolve_digest "${target_ref}")"; then
      fail_count=$((fail_count + 1))
      record_result "FAIL" "${service}" "${source_ref}" "${target_ref}" "${digest}" "${log_file}" "target digest could not be resolved after promotion"
      record_markdown_row "FAIL" "${service}" "${source_ref}" "${target_ref}" "${digest}" "${log_file}" "target digest could not be resolved after promotion"
      record_json_entry "FAIL" "${service}" "${source_ref}" "${target_ref}" "${digest}" "${log_file}" "target digest could not be resolved after promotion"
      handle_failure "${service}: target digest could not be resolved after promotion"
      continue
    fi

    if [[ "${target_digest}" != "${digest}" ]]; then
      fail_count=$((fail_count + 1))
      record_result "FAIL" "${service}" "${source_ref}" "${target_ref}" "${digest}" "${log_file}" "target digest mismatch: ${target_digest}"
      record_markdown_row "FAIL" "${service}" "${source_ref}" "${target_ref}" "${digest}" "${log_file}" "target digest mismatch: ${target_digest}"
      record_json_entry "FAIL" "${service}" "${source_ref}" "${target_ref}" "${digest}" "${log_file}" "target digest mismatch: ${target_digest}"
      handle_failure "${service}: target digest mismatch after promotion"
      continue
    fi

    printf '%s|%s|%s|%s\n' "${service}" "${source_ref}" "${target_ref}" "${digest}" >> "${DIGEST_RECORD_FILE}"
    pass_count=$((pass_count + 1))
    record_result "PASS" "${service}" "${source_ref}" "${target_ref}" "${digest}" "${log_file}" "image promoted by digest without rebuild; target digest matched"
    record_markdown_row "PASS" "${service}" "${source_ref}" "${target_ref}" "${digest}" "${log_file}" "image promoted by digest without rebuild; target digest matched"
    record_json_entry "PASS" "${service}" "${source_ref}" "${target_ref}" "${digest}" "${log_file}" "image promoted by digest without rebuild; target digest matched"
  else
    fail_count=$((fail_count + 1))
    record_result "FAIL" "${service}" "${source_ref}" "${target_ref}" "${digest}" "${log_file}" "digest promotion failed"
    record_markdown_row "FAIL" "${service}" "${source_ref}" "${target_ref}" "${digest}" "${log_file}" "digest promotion failed"
    record_json_entry "FAIL" "${service}" "${source_ref}" "${target_ref}" "${digest}" "${log_file}" "digest promotion failed"
    handle_failure "${service}: digest promotion failed, inspect ${log_file}"
    continue
  fi
done

if is_true "${VERIFY_TARGET_AFTER_PROMOTION}"; then
  info "Verifying promoted images after digest promotion"
  REGISTRY_HOST="${REGISTRY_HOST}" IMAGE_PREFIX="${IMAGE_PREFIX}" IMAGE_TAG="${TARGET_IMAGE_TAG}" \
    REPORT_DIR="${REPORT_DIR}" ALLOW_MISSING_IMAGES="${ALLOW_MISSING_IMAGES}" FAIL_FAST="${FAIL_FAST}" \
    COSIGN_PUBLIC_KEY="${COSIGN_PUBLIC_KEY:-}" \
    COSIGN_CERTIFICATE_IDENTITY="${COSIGN_CERTIFICATE_IDENTITY:-}" \
    COSIGN_CERTIFICATE_IDENTITY_REGEXP="${COSIGN_CERTIFICATE_IDENTITY_REGEXP:-}" \
    COSIGN_CERTIFICATE_OIDC_ISSUER="${COSIGN_CERTIFICATE_OIDC_ISSUER:-}" \
    COSIGN_CERTIFICATE_OIDC_ISSUER_REGEXP="${COSIGN_CERTIFICATE_OIDC_ISSUER_REGEXP:-}" \
    COSIGN_ALLOW_INSECURE_REGISTRY="${COSIGN_ALLOW_INSECURE_REGISTRY:-false}" \
    bash scripts/release/verify-signatures.sh
fi

python3 - "${MANIFEST_JSONL}" "${MANIFEST_JSON}" "${SOURCE_IMAGE_TAG}" "${TARGET_IMAGE_TAG}" "${DIGEST_RECORD_FILE}" "${REPORT_DIR}" <<'PY'
import json
import os
import sys

jsonl_path, json_path, source_tag, target_tag, digest_record, report_dir = sys.argv[1:]
entries = []

if os.path.exists(jsonl_path):
    with open(jsonl_path, encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if line:
                entries.append(json.loads(line))

if not entries and os.path.exists(digest_record):
    with open(digest_record, encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split("|")
            if len(parts) != 4:
                continue
            service, source_ref, target_ref, digest = parts
            entries.append(
                {
                    "status": "PASS",
                    "service": service,
                    "source_ref": source_ref,
                    "target_ref": target_ref,
                    "digest": digest,
                    "artifact": f"{report_dir.rstrip('/')}/{service}-promote-by-digest.log",
                    "detail": "image promoted by digest without rebuild; target digest matched",
                }
            )

with open(json_path, "w", encoding="utf-8") as handle:
    json.dump(
        {
            "source_tag": source_tag,
            "target_tag": target_tag,
            "digest_record": digest_record,
            "promotions": entries,
        },
        handle,
        indent=2,
        sort_keys=True,
    )
    handle.write("\n")
PY

{
  printf '\n## Result\n\n'
  printf -- '- PASS: `%s`\n' "${pass_count}"
  printf -- '- FAIL: `%s`\n' "${fail_count}"
  printf -- '- SKIP: `%s`\n' "${skip_count}"
  printf -- '- Digest record: `%s`\n' "${DIGEST_RECORD_FILE}"
  printf -- '- JSON manifest: `%s`\n' "${MANIFEST_JSON}"
} >> "${SUMMARY_MD}"

printf '\n[INFO] Digest promotion completed: PASS=%s FAIL=%s SKIP=%s\n' \
  "${pass_count}" "${fail_count}" "${skip_count}" | tee -a "${SUMMARY_FILE}"
info "Digest promotion Markdown summary: ${SUMMARY_MD}"
info "Digest promotion JSON manifest: ${MANIFEST_JSON}"

if (( fail_count > 0 )); then
  exit 1
fi

exit 0
