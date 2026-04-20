#!/usr/bin/env bash

set -euo pipefail

# Promote previously signed images from a source tag to a target tag without
# rebuilding them. Promotion happens by re-tagging the same digest in the
# registry. The script can verify the source tag before promotion and the
# target tag after promotion.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/release/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

REGISTRY_HOST="${REGISTRY_HOST:-localhost:5001}"
IMAGE_PREFIX="${IMAGE_PREFIX:-securerag-hub}"
SOURCE_IMAGE_TAG="${SOURCE_IMAGE_TAG:-${IMAGE_TAG:-dev}}"
TARGET_IMAGE_TAG="${TARGET_IMAGE_TAG:-release-local}"
REPORT_DIR="${REPORT_DIR:-artifacts/release}"
VERIFY_SOURCE_BEFORE_PROMOTION="${VERIFY_SOURCE_BEFORE_PROMOTION:-true}"
VERIFY_TARGET_AFTER_PROMOTION="${VERIFY_TARGET_AFTER_PROMOTION:-true}"
ALLOW_MISSING_IMAGES="${ALLOW_MISSING_IMAGES:-false}"
FAIL_FAST="${FAIL_FAST:-false}"

init_services_array

SUMMARY_FILE="${REPORT_DIR}/promotion-summary.txt"

pass_count=0
fail_count=0
skip_count=0

record_result() {
  local status="$1"
  local service="$2"
  local source_ref="$3"
  local target_ref="$4"
  local artifact="$5"
  local detail="$6"

  printf '%-6s | %-18s | %-64s | %-64s | %-40s | %s\n' \
    "${status}" "${service}" "${source_ref}" "${target_ref}" "${artifact}" "${detail}" \
    | tee -a "${SUMMARY_FILE}"
}

promote_with_buildx() {
  local source_ref="$1"
  local target_ref="$2"

  docker buildx imagetools create --tag "${target_ref}" "${source_ref}" >/dev/null
  docker pull "${target_ref}" >/dev/null 2>&1 || true
}

promote_with_pull_push() {
  local source_ref="$1"
  local target_ref="$2"

  docker pull "${source_ref}" >/dev/null
  docker tag "${source_ref}" "${target_ref}"
  docker push "${target_ref}" >/dev/null
}

require_command docker
mkdir -p "${REPORT_DIR}"

{
  printf '# SecureRAG Hub promotion summary\n'
  printf '# Generated at: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf '# Source tag: %s\n' "${SOURCE_IMAGE_TAG}"
  printf '# Target tag: %s\n' "${TARGET_IMAGE_TAG}"
  printf '%-6s | %-18s | %-64s | %-64s | %-40s | %s\n' \
    "STATUS" "SERVICE" "SOURCE IMAGE" "TARGET IMAGE" "ARTIFACT" "DETAIL"
} > "${SUMMARY_FILE}"

if is_true "${VERIFY_SOURCE_BEFORE_PROMOTION}"; then
  info "Verifying source images before promotion"
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
  log_file="${REPORT_DIR}/${service}-promote.log"

  info "Promoting ${source_ref} -> ${target_ref}"

  if ! image_reachable_in_registry "${source_ref}"; then
    message="source image is not reachable in the registry"
    if is_true "${ALLOW_MISSING_IMAGES}"; then
      skip_count=$((skip_count + 1))
      record_result "SKIP" "${service}" "${source_ref}" "${target_ref}" "-" "${message}"
      warn "${service}: ${message}"
      continue
    fi

    fail_count=$((fail_count + 1))
    record_result "FAIL" "${service}" "${source_ref}" "${target_ref}" "-" "${message}"
    handle_failure "${service}: ${message}"
    continue
  fi

  if docker buildx version >/dev/null 2>&1; then
    if promote_with_buildx "${source_ref}" "${target_ref}" > "${log_file}" 2>&1; then
      :
    elif promote_with_pull_push "${source_ref}" "${target_ref}" >> "${log_file}" 2>&1; then
      :
    else
      fail_count=$((fail_count + 1))
      record_result "FAIL" "${service}" "${source_ref}" "${target_ref}" "${log_file}" "buildx and pull/tag/push promotion failed"
      handle_failure "${service}: promotion failed, inspect ${log_file}"
      continue
    fi
  else
    if promote_with_pull_push "${source_ref}" "${target_ref}" > "${log_file}" 2>&1; then
      :
    else
      fail_count=$((fail_count + 1))
      record_result "FAIL" "${service}" "${source_ref}" "${target_ref}" "${log_file}" "pull/tag/push promotion failed"
      handle_failure "${service}: promotion failed, inspect ${log_file}"
      continue
    fi
  fi

  pass_count=$((pass_count + 1))
  record_result "PASS" "${service}" "${source_ref}" "${target_ref}" "${log_file}" "image promoted without rebuild"
done

if is_true "${VERIFY_TARGET_AFTER_PROMOTION}"; then
  info "Verifying promoted images"
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

printf '\n[INFO] Image promotion completed: PASS=%s FAIL=%s SKIP=%s\n' \
  "${pass_count}" "${fail_count}" "${skip_count}" | tee -a "${SUMMARY_FILE}"

if (( fail_count > 0 )); then
  exit 1
fi

exit 0
