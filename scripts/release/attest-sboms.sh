#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/release/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

REGISTRY_HOST="${REGISTRY_HOST:-localhost:5001}"
IMAGE_TAG="${IMAGE_TAG:-release-local}"
IMAGE_PREFIX="${IMAGE_PREFIX:-securerag-hub}"
REPORT_DIR="${REPORT_DIR:-artifacts/release}"
SBOM_DIR="${SBOM_DIR:-artifacts/sbom}"
COSIGN_YES="${COSIGN_YES:-true}"
ALLOW_MISSING_IMAGES="${ALLOW_MISSING_IMAGES:-false}"
FAIL_FAST="${FAIL_FAST:-false}"

init_services_array

SUMMARY_FILE="${REPORT_DIR}/attest-summary.txt"
pass_count=0
fail_count=0
skip_count=0

record_result() {
  local status="$1"
  local service="$2"
  local image_ref="$3"
  local predicate="$4"
  local artifact="$5"
  local detail="$6"

  printf '%-6s | %-18s | %-64s | %-40s | %-40s | %s\n' \
    "${status}" "${service}" "${image_ref}" "${predicate}" "${artifact}" "${detail}" \
    | tee -a "${SUMMARY_FILE}"
}

require_command cosign
require_command python3
mkdir -p "${REPORT_DIR}" "${SBOM_DIR}"

declare -a attest_args
attest_args=(attest --type cyclonedx)

if is_true "${COSIGN_YES}"; then
  attest_args+=(--yes)
fi

if is_true "${COSIGN_ALLOW_INSECURE_REGISTRY:-false}"; then
  attest_args+=(--allow-insecure-registry)
fi

mode="keyless"
if [[ -n "${COSIGN_KEY:-}" ]]; then
  [[ -f "${COSIGN_KEY}" ]] || { error "COSIGN_KEY points to a non-existent file: ${COSIGN_KEY}"; exit 2; }
  mode="key-pair"
  attest_args+=(--key "${COSIGN_KEY}")
fi

{
  printf '# SecureRAG Hub SBOM attestation summary\n'
  printf '# Generated at: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf '# Mode: %s\n' "${mode}"
  printf '%-6s | %-18s | %-64s | %-40s | %-40s | %s\n' \
    "STATUS" "SERVICE" "IMAGE" "PREDICATE" "ARTIFACT" "DETAIL"
} > "${SUMMARY_FILE}"

for service in "${SERVICES_ARRAY[@]}"; do
  image_ref="$(build_image_ref "${service}")"
  sbom_file="${SBOM_DIR}/${service}-sbom.cdx.json"
  log_file="${REPORT_DIR}/${service}-attest.log"

  if [[ ! -s "${sbom_file}" ]]; then
    fail_count=$((fail_count + 1))
    record_result "FAIL" "${service}" "${image_ref}" "${sbom_file}" "-" "SBOM predicate missing or empty"
    handle_failure "${service}: missing SBOM predicate ${sbom_file}"
    continue
  fi

  if ! image_reachable_in_registry "${image_ref}"; then
    message="image is not reachable in the registry"
    if is_true "${ALLOW_MISSING_IMAGES}"; then
      skip_count=$((skip_count + 1))
      record_result "SKIP" "${service}" "${image_ref}" "${sbom_file}" "-" "${message}"
      continue
    fi

    fail_count=$((fail_count + 1))
    record_result "FAIL" "${service}" "${image_ref}" "${sbom_file}" "-" "${message}"
    handle_failure "${service}: ${message}"
    continue
  fi

  attest_ref="${image_ref}"
  detail="SBOM attested for tag; digest unavailable"
  if digest="$(resolve_digest "${image_ref}")"; then
    attest_ref="$(digest_ref_for "${image_ref}" "${digest}")"
    detail="SBOM attested for digest ${digest}"
  fi

  if cosign "${attest_args[@]}" --predicate "${sbom_file}" "${attest_ref}" > "${log_file}" 2>&1; then
    pass_count=$((pass_count + 1))
    record_result "PASS" "${service}" "${attest_ref}" "${sbom_file}" "${log_file}" "${detail}"
  else
    fail_count=$((fail_count + 1))
    record_result "FAIL" "${service}" "${attest_ref}" "${sbom_file}" "${log_file}" "cosign attest failed"
    handle_failure "${service}: SBOM attestation failed, inspect ${log_file}"
  fi
done

printf '\n[INFO] SBOM attestation completed: PASS=%s FAIL=%s SKIP=%s\n' \
  "${pass_count}" "${fail_count}" "${skip_count}" | tee -a "${SUMMARY_FILE}"

if (( fail_count > 0 )); then
  exit 1
fi
