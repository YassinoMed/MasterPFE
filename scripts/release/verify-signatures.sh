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

require_command cosign
require_command python3
mkdir -p "${REPORT_DIR}"

mode="keyless"
declare -a verify_args
verify_args=(verify)

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
      warn "${service}: ${message}"
      continue
    fi

    fail_count=$((fail_count + 1))
    record_result "FAIL" "${service}" "${image_ref}" "${mode}" "-" "${message}"
    handle_failure "${service}: ${message}"
    continue
  fi

  verify_ref="${image_ref}"
  verify_detail="signature verified for tag; digest unavailable"
  if digest="$(resolve_digest "${image_ref}")"; then
    verify_ref="$(digest_ref_for "${image_ref}" "${digest}")"
    verify_detail="signature verified for digest ${digest}"
  fi

  if cosign "${verify_args[@]}" "${verify_ref}" > "${log_file}" 2>&1; then
    pass_count=$((pass_count + 1))
    record_result "PASS" "${service}" "${verify_ref}" "${mode}" "${log_file}" "${verify_detail}"
    info "${service}: ${verify_detail}"
  else
    fail_count=$((fail_count + 1))
    record_result "FAIL" "${service}" "${verify_ref}" "${mode}" "${log_file}" "verification failed or signature missing"
    handle_failure "${service}: verification failed, inspect ${log_file}"
  fi
done

printf '\n[INFO] Signature verification completed: PASS=%s FAIL=%s SKIP=%s\n' \
  "${pass_count}" "${fail_count}" "${skip_count}" | tee -a "${SUMMARY_FILE}"

if (( fail_count > 0 )); then
  exit 1
fi

exit 0
