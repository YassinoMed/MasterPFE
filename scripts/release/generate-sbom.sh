#!/usr/bin/env bash

set -euo pipefail

# Generate CycloneDX SBOMs for SecureRAG Hub images.
#
# Strategy:
# - Prefer a local Docker image when it exists.
# - Fall back to the remote registry reference when the image is not available locally.
# - Continue service by service to produce the largest useful result set possible.
# - Exit non-zero if at least one image could not be processed.

DEFAULT_SERVICES=(
  api-gateway
  auth-users
  chatbot-manager
  llm-orchestrator
  security-auditor
  knowledge-hub
  portal-web
)

REGISTRY_HOST="${REGISTRY_HOST:-localhost:5001}"
IMAGE_TAG="${IMAGE_TAG:-dev}"
IMAGE_PREFIX="${IMAGE_PREFIX:-securerag-hub}"
SBOM_DIR="${SBOM_DIR:-artifacts/sbom}"
REPORT_DIR="${REPORT_DIR:-artifacts/release}"
SYFT_FORMAT="${SYFT_FORMAT:-cyclonedx-json}"
ALLOW_MISSING_IMAGES="${ALLOW_MISSING_IMAGES:-false}"

if [[ -n "${SERVICES:-}" ]]; then
  # shellcheck disable=SC2206
  SERVICES_ARRAY=(${SERVICES//,/ })
else
  SERVICES_ARRAY=("${DEFAULT_SERVICES[@]}")
fi

SUMMARY_FILE="${REPORT_DIR}/sbom-summary.txt"
INDEX_FILE="${SBOM_DIR}/sbom-index.txt"

pass_count=0
fail_count=0
skip_count=0

info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
error() { printf '[ERROR] %s\n' "$*" >&2; }

is_true() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|y|Y|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    error "Missing required command: $1"
    exit 2
  fi
}

build_image_ref() {
  local service="$1"
  local registry="${REGISTRY_HOST%/}"

  if [[ -n "${registry}" ]]; then
    printf '%s/%s-%s:%s' "${registry}" "${IMAGE_PREFIX}" "${service}" "${IMAGE_TAG}"
  else
    printf '%s-%s:%s' "${IMAGE_PREFIX}" "${service}" "${IMAGE_TAG}"
  fi
}

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

file_sha256() {
  local target_file="$1"

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${target_file}" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "${target_file}" | awk '{print $1}'
  else
    printf 'unavailable'
  fi
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

require_command syft
mkdir -p "${SBOM_DIR}" "${REPORT_DIR}"

{
  printf '# SecureRAG Hub SBOM summary\n'
  printf '# Generated at: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf '%-6s | %-18s | %-64s | %-8s | %-40s | %s\n' \
    "STATUS" "SERVICE" "IMAGE" "SOURCE" "ARTIFACT" "DETAIL"
} > "${SUMMARY_FILE}"

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
      warn "${service}: ${message}"
      continue
    fi

    fail_count=$((fail_count + 1))
    record_result "FAIL" "${service}" "${image_ref}" "-" "-" "${message}"
    error "${service}: ${message}"
    continue
  fi

  source_kind="${source_ref%%:*}"

  if run_syft "${source_ref}" "${sbom_file}" "${log_file}"; then
    checksum="$(file_sha256 "${sbom_file}")"
    pass_count=$((pass_count + 1))
    printf '%s|%s|%s|%s|%s\n' \
      "${service}" "${image_ref}" "${source_kind}" "${sbom_file}" "${checksum}" >> "${INDEX_FILE}"
    record_result "PASS" "${service}" "${image_ref}" "${source_kind}" "${sbom_file}" "sha256=${checksum}"
    info "${service}: SBOM written to ${sbom_file}"
  else
    fail_count=$((fail_count + 1))
    record_result "FAIL" "${service}" "${image_ref}" "${source_kind}" "${log_file}" "Syft failed, inspect log file"
    error "${service}: unable to generate SBOM, see ${log_file}"
  fi
done

printf '\n[INFO] SBOM generation completed: PASS=%s FAIL=%s SKIP=%s\n' \
  "${pass_count}" "${fail_count}" "${skip_count}" | tee -a "${SUMMARY_FILE}"
info "SBOM index: ${INDEX_FILE}"

if (( fail_count > 0 )); then
  exit 1
fi

exit 0
