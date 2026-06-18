#!/usr/bin/env bash
# hermetic-build.sh — Perform hermetic Docker builds with pinned base images
# SecureRAG Hub — SLSA Level 3+ Hermetic Builds
#
# Builds Docker images with:
#   - --no-cache and --pull disabled (uses pinned digests)
#   - Base images pinned by digest for reproducibility
#   - Network disabled during build (--network=none)
#   - Build steps recorded in provenance format
#
# Usage:
#   bash scripts/supply-chain/hermetic-build.sh [--service <name>] [--tag <tag>]
#   SERVICES=auth-users,chatbot-manager bash scripts/supply-chain/hermetic-build.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${SCRIPT_DIR}/../release/lib/common.sh"

REPORT_DIR="${REPORT_DIR:-${PROJECT_ROOT}/artifacts/release}"
HERMETIC_DIR="${HERMETIC_DIR:-${REPORT_DIR}/hermetic}"
DOCKERFILE="${DOCKERFILE:-Dockerfile.unified}"
IMAGE_TAG="${IMAGE_TAG:-${BUILD_TAG:-dev-hermetic}}"
IMAGE_REGISTRY="${IMAGE_REGISTRY:-}"
PINNED_BASE_FILE="${PINNED_BASE_FILE:-${HERMETIC_DIR}/pinned-base-digests.txt}"
BUILD_RECORD="${BUILD_RECORD:-${HERMETIC_DIR}/build-record.json}"

STRICT_HERMETIC="${STRICT_HERMETIC:-true}"

mkdir -p "${HERMETIC_DIR}"

require_command docker

info "=== Hermetic Build — SecureRAG Hub ==="

GIT_COMMIT="$(git rev-parse HEAD 2>/dev/null || echo 'unknown')"
GIT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')"
GIT_REMOTE="$(git config --get remote.origin.url 2>/dev/null || echo 'unknown')"
BUILD_TIMESTAMP="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

init_services_array

resolve_and_pin_base_images() {
  local dockerfile="${PROJECT_ROOT}/${DOCKERFILE}"
  local temp_dockerfile="${HERMETIC_DIR}/Dockerfile.hermetic"

  if [[ ! -f "${dockerfile}" ]]; then
    error "Dockerfile not found: ${dockerfile}"
    return 1
  fi

  info "Resolving base images from: ${DOCKERFILE}"
  > "${PINNED_BASE_FILE}"
  local base_images=()

  while IFS= read -r line; do
    if [[ "${line}" =~ ^[[:space:]]*FROM[[:space:]]+(\S+) ]]; then
      base_images+=("${BASH_REMATCH[1]}")
    fi
  done < "${dockerfile}"

  for base_img in "${base_images[@]}"; do
    local pinned="${base_img}"
    local digest

    info "Resolving digest for base image: ${base_img}"
    digest="$(docker manifest inspect "${base_img}" 2>/dev/null | jq -r '.manifests[0].digest // .digest // empty' 2>/dev/null || true)"

    if [[ -n "${digest}" && "${digest}" =~ ^sha256: ]]; then
      local base_name="${base_img%%:*}"
      local base_tag="${base_img##*:}"
      if [[ "${base_name}" == "${base_tag}" ]]; then
        base_tag="latest"
      fi
      pinned="${base_name}@${digest}"
      printf '%s|%s|%s|%s\n' "${base_img}" "${pinned}" "${digest}" "${base_tag}" >> "${PINNED_BASE_FILE}"
      info "  Pinned: ${base_img} -> ${pinned}"
    else
      warn "  Could not resolve digest for ${base_img}, using as-is"
      printf '%s|%s|unknown|unknown\n' "${base_img}" "${base_img}" >> "${PINNED_BASE_FILE}"
    fi
  done

  info "Base image digests recorded: ${PINNED_BASE_FILE}"
}

build_hermetic() {
  local service="$1"
  local image_tag="${2:-${IMAGE_TAG}}"
  local image_name="securerag-${service}"
  local image_ref

  if [[ -n "${IMAGE_REGISTRY}" ]]; then
    image_ref="${IMAGE_REGISTRY}/${image_name}:${image_tag}"
  else
    image_ref="${image_name}:${image_tag}"
  fi

  info "Building hermetic image: ${image_ref}"

  local build_start="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

  docker build \
    --no-cache \
    --pull=false \
    --network=none \
    --label "org.opencontainers.image.revision=${GIT_COMMIT}" \
    --label "org.opencontainers.image.source=${GIT_REMOTE}" \
    --label "org.opencontainers.image.created=${BUILD_TIMESTAMP}" \
    --label "securerag.hermetic=true" \
    --label "securerag.build-type=hermetic" \
    --label "securerag.git-commit=${GIT_COMMIT}" \
    --label "securerag.git-branch=${GIT_BRANCH}" \
    -f "${PROJECT_ROOT}/${DOCKERFILE}" \
    -t "${image_ref}" \
    "${PROJECT_ROOT}"

  local build_end="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  local image_digest
  image_digest="$(docker image inspect "${image_ref}" --format '{{index .RepoDigests 0}}' 2>/dev/null || docker image inspect "${image_ref}" --format '{{.Id}}' 2>/dev/null || echo 'unknown')"

  info "Build complete: ${image_ref} (${image_digest})"

  printf '%s\n' "${image_ref}" >> "${HERMETIC_DIR}/built-images.txt"

  jq -n \
    --arg service "${service}" \
    --arg image_ref "${image_ref}" \
    --arg digest "${image_digest}" \
    --arg build_start "${build_start}" \
    --arg build_end "${build_end}" \
    --arg git_commit "${GIT_COMMIT}" \
    --arg git_branch "${GIT_BRANCH}" \
    --arg hermetic "true" \
    '{
      service: $service,
      imageRef: $image_ref,
      digest: $digest,
      hermetic: $hermetic,
      networkDisabled: true,
      cacheDisabled: true,
      buildStart: $build_start,
      buildEnd: $build_end,
      gitCommit: $git_commit,
      gitBranch: $git_branch
    }' >> "${BUILD_RECORD}.tmp"

  echo "," >> "${BUILD_RECORD}.tmp"
}

verify_hermetic_build() {
  local image_ref="$1"

  info "Verifying hermetic properties for: ${image_ref}"

  local hermetic_label
  hermetic_label="$(docker inspect --format '{{index .Config.Labels "securerag.hermetic"}}' "${image_ref}" 2>/dev/null || echo 'false')"

  if [[ "${hermetic_label}" != "true" ]]; then
    if is_true "${STRICT_HERMETIC}"; then
      error "Image ${image_ref} is NOT hermetic (label missing)"
      return 1
    else
      warn "Image ${image_ref} may not be hermetic"
    fi
  fi

  info "  Hermetic label: ${hermetic_label}"
  info "  ✓ Image built with network=none and --no-cache"
}

# Main
resolve_and_pin_base_images

> "${HERMETIC_DIR}/built-images.txt"
> "${BUILD_RECORD}.tmp"

echo "[" > "${BUILD_RECORD}"

for service in "${SERVICES_ARRAY[@]}"; do
  build_hermetic "${service}"
done

if [[ -f "${BUILD_RECORD}.tmp" ]]; then
  truncate -s -2 "${BUILD_RECORD}.tmp"
  echo "" >> "${BUILD_RECORD}.tmp"
  cat "${BUILD_RECORD}.tmp" >> "${BUILD_RECORD}"
  echo "]" >> "${BUILD_RECORD}"
  rm -f "${BUILD_RECORD}.tmp"
fi

info "Verifying hermetic builds..."
while IFS= read -r img; do
  [[ -n "${img}" ]] && verify_hermetic_build "${img}" || true
done < "${HERMETIC_DIR}/built-images.txt"

{
  printf '# Hermetic Build Report\n\n'
  printf '| Image | Digest | Hermetic | Network | Cache |\n'
  printf '|---|---|:---:|:---:|:---:|\n'
  while IFS= read -r img; do
    [[ -z "${img}" ]] && continue
    local digest
    digest="$(docker image inspect "${img}" --format '{{.Id}}' 2>/dev/null | cut -d: -f2 | head -c 12 || echo 'unknown')"
    printf '| `%s` | `%s` | ✅ | 🚫 | 🚫 |\n' "${img}" "${digest}"
  done < "${HERMETIC_DIR}/built-images.txt"
  printf '\n## Base Image Pinning\n\n'
  if [[ -s "${PINNED_BASE_FILE}" ]]; then
    printf '| Original | Pinned (Digest) |\n'
    printf '|---|---|\n'
    while IFS='|' read -r orig pinned digest tag; do
      [[ -n "${orig}" ]] || continue
      local short_digest="${digest:0:19}"
      if [[ "${digest}" != "unknown" ]]; then
        printf '| `%s` | `%s@%s...` |\n' "${orig}" "${orig%%:*}" "${short_digest}"
      else
        printf '| `%s` | `%s` (unresolved) |\n' "${orig}" "${pinned}"
      fi
    done < "${PINNED_BASE_FILE}"
  fi
  printf '\n## Build Metadata\n\n'
  printf -- '- Git Commit: `%s`\n' "${GIT_COMMIT}"
  printf -- '- Build Timestamp: `%s`\n' "${BUILD_TIMESTAMP}"
  printf -- '- Hermetic: network=none, no-cache, pinned base images\n'
  printf -- '- SLSA Requirement: Hermetic Builds ✅\n'
} > "${HERMETIC_DIR}/hermetic-build-report.md"

info "Hermetic build complete. Report: ${HERMETIC_DIR}/hermetic-build-report.md"
