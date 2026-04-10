#!/usr/bin/env bash

set -euo pipefail

# Promote previously verified images by digest without rebuilding them.
# The target tag is created from the exact digest resolved for the source tag,
# and a digest evidence file is produced for downstream deployment and audit.

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
IMAGE_PREFIX="${IMAGE_PREFIX:-securerag-hub}"
SOURCE_IMAGE_TAG="${SOURCE_IMAGE_TAG:-${IMAGE_TAG:-dev}}"
TARGET_IMAGE_TAG="${TARGET_IMAGE_TAG:-release-local}"
REPORT_DIR="${REPORT_DIR:-artifacts/release}"
DIGEST_RECORD_FILE="${DIGEST_RECORD_FILE:-${REPORT_DIR}/promotion-digests.txt}"
VERIFY_SOURCE_BEFORE_PROMOTION="${VERIFY_SOURCE_BEFORE_PROMOTION:-true}"
VERIFY_TARGET_AFTER_PROMOTION="${VERIFY_TARGET_AFTER_PROMOTION:-true}"
ALLOW_MISSING_IMAGES="${ALLOW_MISSING_IMAGES:-false}"
FAIL_FAST="${FAIL_FAST:-false}"

if [[ -n "${SERVICES:-}" ]]; then
  # shellcheck disable=SC2206
  SERVICES_ARRAY=(${SERVICES//,/ })
else
  SERVICES_ARRAY=("${DEFAULT_SERVICES[@]}")
fi

SUMMARY_FILE="${REPORT_DIR}/promotion-by-digest-summary.txt"

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
  local tag="$2"
  printf '%s/%s-%s:%s' "${REGISTRY_HOST%/}" "${IMAGE_PREFIX}" "${service}" "${tag}"
}

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

handle_failure() {
  local message="$1"

  if is_true "${FAIL_FAST}"; then
    error "${message}"
    exit 1
  fi
}

resolve_digest_with_python() {
  local json_file="$1"

  python3 - "${json_file}" <<'PY'
import json
import re
import sys

digest_re = re.compile(r"^sha256:[0-9a-f]{64}$")

def is_digest(value):
    return isinstance(value, str) and digest_re.match(value) is not None

def pick_digest(obj):
    if isinstance(obj, dict):
        for field in ("Descriptor", "descriptor", "Manifest", "manifest"):
            nested = obj.get(field)
            if isinstance(nested, dict):
                for key in ("digest", "Digest"):
                    value = nested.get(key)
                    if is_digest(value):
                        return value
        for key in ("digest", "Digest"):
            value = obj.get(key)
            if is_digest(value):
                return value
        for value in obj.values():
            found = pick_digest(value)
            if found:
                return found
    elif isinstance(obj, list):
        for item in obj:
            found = pick_digest(item)
            if found:
                return found
    return None

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    payload = json.load(handle)

digest = pick_digest(payload)
if not digest:
    raise SystemExit(1)

print(digest)
PY
}

resolve_digest() {
  local image_ref="$1"
  local inspect_file

  inspect_file="$(mktemp)"
  trap 'rm -f "${inspect_file}"' RETURN

  if docker manifest inspect --verbose "${image_ref}" > "${inspect_file}" 2>/dev/null; then
    if digest="$(resolve_digest_with_python "${inspect_file}" 2>/dev/null)"; then
      printf '%s\n' "${digest}"
      return 0
    fi
  fi

  return 1
}

promote_exact_digest() {
  local source_ref="$1"
  local target_ref="$2"
  local digest="$3"

  if docker buildx version >/dev/null 2>&1; then
    docker buildx imagetools create --tag "${target_ref}" "${source_ref%@*}@${digest}" >/dev/null
    return 0
  fi

  docker pull "${source_ref}" >/dev/null
  docker tag "${source_ref}" "${target_ref}"
  docker push "${target_ref}" >/dev/null
}

require_command docker
require_command python3
mkdir -p "${REPORT_DIR}"

{
  printf '# SecureRAG Hub digest promotion summary\n'
  printf '# Generated at: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf '# Source tag: %s\n' "${SOURCE_IMAGE_TAG}"
  printf '# Target tag: %s\n' "${TARGET_IMAGE_TAG}"
  printf '# Digest record: %s\n' "${DIGEST_RECORD_FILE}"
  printf '%-6s | %-18s | %-64s | %-64s | %-71s | %-40s | %s\n' \
    "STATUS" "SERVICE" "SOURCE IMAGE" "TARGET IMAGE" "DIGEST" "ARTIFACT" "DETAIL"
} > "${SUMMARY_FILE}"

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
    bash scripts/release/verify-signatures.sh
fi

for service in "${SERVICES_ARRAY[@]}"; do
  source_ref="$(build_image_ref "${service}" "${SOURCE_IMAGE_TAG}")"
  target_ref="$(build_image_ref "${service}" "${TARGET_IMAGE_TAG}")"
  log_file="${REPORT_DIR}/${service}-promote-by-digest.log"

  info "Promoting ${source_ref} -> ${target_ref} by digest"

  if ! docker manifest inspect "${source_ref}" >/dev/null 2>&1; then
    message="source image is not reachable in the registry"
    if is_true "${ALLOW_MISSING_IMAGES}"; then
      skip_count=$((skip_count + 1))
      record_result "SKIP" "${service}" "${source_ref}" "${target_ref}" "-" "-" "${message}"
      warn "${service}: ${message}"
      continue
    fi

    fail_count=$((fail_count + 1))
    record_result "FAIL" "${service}" "${source_ref}" "${target_ref}" "-" "-" "${message}"
    handle_failure "${service}: ${message}"
    continue
  fi

  if ! digest="$(resolve_digest "${source_ref}")"; then
    fail_count=$((fail_count + 1))
    record_result "FAIL" "${service}" "${source_ref}" "${target_ref}" "-" "-" "unable to resolve manifest digest"
    handle_failure "${service}: unable to resolve digest"
    continue
  fi

  if promote_exact_digest "${source_ref}" "${target_ref}" "${digest}" > "${log_file}" 2>&1; then
    printf '%s|%s|%s|%s\n' "${service}" "${source_ref}" "${target_ref}" "${digest}" >> "${DIGEST_RECORD_FILE}"
    pass_count=$((pass_count + 1))
    record_result "PASS" "${service}" "${source_ref}" "${target_ref}" "${digest}" "${log_file}" "image promoted by digest without rebuild"
  else
    fail_count=$((fail_count + 1))
    record_result "FAIL" "${service}" "${source_ref}" "${target_ref}" "${digest}" "${log_file}" "digest promotion failed"
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
    bash scripts/release/verify-signatures.sh
fi

printf '\n[INFO] Digest promotion completed: PASS=%s FAIL=%s SKIP=%s\n' \
  "${pass_count}" "${fail_count}" "${skip_count}" | tee -a "${SUMMARY_FILE}"

if (( fail_count > 0 )); then
  exit 1
fi

exit 0
