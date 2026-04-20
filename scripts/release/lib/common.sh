#!/usr/bin/env bash

# Shared helpers for SecureRAG release scripts. This file is intended to be
# sourced by Bash scripts, not executed directly.

DEFAULT_SERVICES=(
  auth-users
  chatbot-manager
  conversation-service
  audit-security-service
  portal-web
)

init_services_array() {
  if [[ -n "${SERVICES:-}" ]]; then
    # shellcheck disable=SC2206
    SERVICES_ARRAY=(${SERVICES//,/ })
  else
    SERVICES_ARRAY=("${DEFAULT_SERVICES[@]}")
  fi
}

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
  local tag="${2:-${IMAGE_TAG:-dev}}"
  local registry="${REGISTRY_HOST%/}"

  if [[ -n "${registry}" ]]; then
    printf '%s/%s-%s:%s' "${registry}" "${IMAGE_PREFIX}" "${service}" "${tag}"
  else
    printf '%s-%s:%s' "${IMAGE_PREFIX}" "${service}" "${tag}"
  fi
}

image_reachable_in_registry() {
  local image_ref="$1"

  if command -v docker >/dev/null 2>&1 && docker manifest inspect "${image_ref}" >/dev/null 2>&1; then
    return 0
  fi

  if command -v docker >/dev/null 2>&1 && docker buildx imagetools inspect "${image_ref}" >/dev/null 2>&1; then
    return 0
  fi

  if registry_manifest_digest "${image_ref}" >/dev/null 2>&1; then
    return 0
  fi

  if command -v docker >/dev/null 2>&1 && docker pull "${image_ref}" >/dev/null 2>&1; then
    return 0
  fi

  local -a cosign_args
  cosign_args=(triangulate)
  if is_true "${COSIGN_ALLOW_INSECURE_REGISTRY:-false}"; then
    cosign_args+=(--allow-insecure-registry)
  fi

  if command -v cosign >/dev/null 2>&1 && cosign "${cosign_args[@]}" "${image_ref}" >/dev/null 2>&1; then
    return 0
  fi

  return 1
}

parse_image_ref_for_registry_api() {
  local image_ref="$1"
  local image_without_digest="${image_ref%@*}"
  local image_without_tag
  local tag
  local registry
  local repository

  if [[ "${image_without_digest}" != */* || "${image_without_digest}" != *:* ]]; then
    return 1
  fi

  image_without_tag="${image_without_digest%:*}"
  tag="${image_without_digest##*:}"
  registry="${image_without_tag%%/*}"
  repository="${image_without_tag#*/}"

  if [[ -z "${registry}" || -z "${repository}" || -z "${tag}" || "${registry}" == "${repository}" ]]; then
    return 1
  fi

  printf '%s|%s|%s\n' "${registry}" "${repository}" "${tag}"
}

registry_manifest_digest() {
  local image_ref="$1"
  local parsed
  local registry
  local repository
  local tag
  local scheme
  local url
  local header_file
  local digest

  command -v curl >/dev/null 2>&1 || return 1

  parsed="$(parse_image_ref_for_registry_api "${image_ref}")" || return 1
  registry="${parsed%%|*}"
  parsed="${parsed#*|}"
  repository="${parsed%%|*}"
  tag="${parsed#*|}"

  header_file="$(mktemp)"

  for scheme in http https; do
    url="${scheme}://${registry}/v2/${repository}/manifests/${tag}"
    if curl -fsSIL \
      -H 'Accept: application/vnd.oci.image.index.v1+json' \
      -H 'Accept: application/vnd.docker.distribution.manifest.list.v2+json' \
      -H 'Accept: application/vnd.oci.image.manifest.v1+json' \
      -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' \
      "${url}" > "${header_file}" 2>/dev/null; then
      digest="$(awk -F': ' 'tolower($1)=="docker-content-digest" {gsub(/\r/,"",$2); print $2; exit}' "${header_file}")"
      if [[ "${digest}" =~ ^sha256:[0-9a-f]{64}$ ]]; then
        printf '%s\n' "${digest}"
        rm -f "${header_file}"
        return 0
      fi
    fi
  done

  rm -f "${header_file}"
  return 1
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
        for nested in obj.values():
            found = pick_digest(nested)
            if found:
                return found
    if isinstance(obj, list):
        for nested in obj:
            found = pick_digest(nested)
            if found:
                return found
    return None

with open(sys.argv[1], encoding="utf-8") as handle:
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
  local digest

  if ! command -v docker >/dev/null 2>&1; then
    registry_manifest_digest "${image_ref}"
    return $?
  fi

  inspect_file="$(mktemp)"

  if docker manifest inspect --verbose "${image_ref}" > "${inspect_file}" 2>/dev/null; then
    if resolve_digest_with_python "${inspect_file}" 2>/dev/null; then
      rm -f "${inspect_file}"
      return 0
    fi
  fi

  if docker buildx imagetools inspect "${image_ref}" > "${inspect_file}" 2>/dev/null; then
    digest="$(awk '/^Digest:/ {print $2; exit}' "${inspect_file}")"
    if [[ "${digest}" =~ ^sha256:[0-9a-f]{64}$ ]]; then
      printf '%s\n' "${digest}"
      rm -f "${inspect_file}"
      return 0
    fi
  fi

  if registry_manifest_digest "${image_ref}"; then
    rm -f "${inspect_file}"
    return 0
  fi

  if docker pull "${image_ref}" >/dev/null 2>&1; then
    digest="$(docker image inspect "${image_ref}" --format '{{range .RepoDigests}}{{println .}}{{end}}' 2>/dev/null \
      | sed -n 's/.*@\(sha256:[0-9a-f]\{64\}\).*/\1/p' \
      | head -n 1)"
    if [[ "${digest}" =~ ^sha256:[0-9a-f]{64}$ ]]; then
      printf '%s\n' "${digest}"
      rm -f "${inspect_file}"
      return 0
    fi
  fi

  rm -f "${inspect_file}"
  return 1
}

digest_ref_for() {
  local image_ref="$1"
  local digest="$2"

  printf '%s@%s' "${image_ref%:*}" "${digest}"
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

handle_failure() {
  local message="$1"

  if is_true "${FAIL_FAST:-false}"; then
    error "${message}"
    exit 1
  fi
}
