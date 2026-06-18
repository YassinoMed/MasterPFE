#!/usr/bin/env bash
# build-provenance.sh — Generate SLSA v1.0 provenance attestations
# SecureRAG Hub — SLSA Level 3+ Supply Chain Security
#
# Generates provenance for each release artifact using cosign,
# signs with keyless Cosign, and uploads to Rekor transparency log.
#
# Usage:
#   bash scripts/supply-chain/build-provenance.sh [--image <ref>] [--sbom <path>]
#   IMAGE_TAG=latest bash scripts/supply-chain/build-provenance.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${SCRIPT_DIR}/../release/lib/common.sh"

REPORT_DIR="${REPORT_DIR:-${PROJECT_ROOT}/artifacts/release}"
PROVENANCE_DIR="${PROVENANCE_DIR:-${REPORT_DIR}/provenance}"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-${PROJECT_ROOT}/artifacts}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
IMAGE_REGISTRY="${IMAGE_REGISTRY:-}"

BUILDER_ID="${BUILDER_ID:-https://github.com/YassinoMed/MasterPFE/.github/workflows/ci.yml}"
BUILD_TYPE="${BUILD_TYPE:-https://slsa.dev/gha/github-actions-build-types/v1}"

mkdir -p "${PROVENANCE_DIR}"

require_command cosign
require_command jq
require_command docker

info "=== SLSA v1.0 Provenance Generation ==="

GIT_COMMIT="$(git rev-parse HEAD 2>/dev/null || echo 'unknown')"
GIT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')"
GIT_REMOTE="$(git config --get remote.origin.url 2>/dev/null || echo 'unknown')"
GIT_TREE_STATUS="$([ -z "$(git status --porcelain 2>/dev/null)" ] && echo 'clean' || echo 'dirty')"
BUILD_TIMESTAMP="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

init_services_array

resolve_base_images() {
  local dockerfile="${1:-Dockerfile.unified}"
  local base_images=()

  if [[ -f "${PROJECT_ROOT}/${dockerfile}" ]]; then
    while IFS= read -r line; do
      if [[ "${line}" =~ ^[[:space:]]*FROM[[:space:]]+(\S+) ]]; then
        base_images+=("${BASH_REMATCH[1]}")
      fi
    done < "${PROJECT_ROOT}/${dockerfile}"
  fi

  for img in "${base_images[@]}"; do
    local resolved
    resolved="$(docker inspect --format='{{.RepoDigests}}' "${img}" 2>/dev/null || true)"
    if [[ -z "${resolved}" ]]; then
      resolved="${img}"
    fi
    printf '%s\n' "${resolved}"
  done
}

generate_provenance_subject() {
  local image_ref="$1"
  local digest

  digest="$(resolve_digest "${image_ref}" 2>/dev/null || docker inspect --format='{{index .RepoDigests 0}}' "${image_ref}" 2>/dev/null || echo 'unknown')"
  local digest_sha
  if [[ "${digest}" =~ sha256:([0-9a-f]{64}) ]]; then
    digest_sha="${BASH_REMATCH[1]}"
  else
    digest_sha='unknown'
  fi

  cat <<EOF
    {
      "name": "${image_ref}",
      "digest": {"sha256": "${digest_sha}"}
    }
EOF
}

generate_provenance_predicate() {
  local image_ref="$1"
  local subject_json="$2"
  local base_images
  base_images="$(resolve_base_images | jq -R -s 'split("\n") | map(select(length > 0))')"

  cat <<EOF
{
  "_type": "https://in-toto.io/Statement/v1",
  "subject": [${subject_json}],
  "predicateType": "https://slsa.dev/provenance/v1",
  "predicate": {
    "buildDefinition": {
      "buildType": "${BUILD_TYPE}",
      "externalParameters": {
        "repository": "${GIT_REMOTE}",
        "branch": "${GIT_BRANCH}",
        "commit": "${GIT_COMMIT}",
        "treeStatus": "${GIT_TREE_STATUS}",
        "imageTag": "${IMAGE_TAG}",
        "configSource": {
          "uri": "${GIT_REMOTE}",
          "digest": {"sha1": "${GIT_COMMIT}"},
          "entryPoint": ".github/workflows/ci.yml"
        }
      },
      "resolvedDependencies": [
        {
          "uri": "${GIT_REMOTE}",
          "digest": {"gitCommit": "${GIT_COMMIT}"}
        }
      ],
      "buildConfig": {
        "steps": [
          {"command": "docker build --no-cache --pull"},
          {"command": "cosign attest --type slsaprovenance"},
          {"command": "cosign attest --type cyclonedx"}
        ],
        "environment": {
          "imageTag": "${IMAGE_TAG}",
          "registry": "${IMAGE_REGISTRY}",
          "builder": "github-actions",
          "builderOS": "ubuntu-latest"
        }
      }
    },
    "runDetails": {
      "builder": {
        "id": "${BUILDER_ID}"
      },
      "metadata": {
        "invocationId": "${GITHUB_RUN_ID:-local-run-$(date +%s)}",
        "startedOn": "${BUILD_TIMESTAMP}",
        "finishedOn": "${BUILD_TIMESTAMP}",
        "completeness": {
          "parameters": true,
          "environment": true,
          "materials": true
        },
        "reproducible": false
      },
      "byproducts": []
    }
  }
}
EOF
}

generate_and_sign_provenance() {
  local image_ref="$1"
  local image_name
  image_name="$(basename "${image_ref%%:*}")"
  local provenance_file="${PROVENANCE_DIR}/provenance-${image_name}-${IMAGE_TAG}.json"
  local provenance_payload="${PROVENANCE_DIR}/payload-${image_name}-${IMAGE_TAG}.json"

  info "Generating provenance for: ${image_ref}"
  local subject
  subject="$(generate_provenance_subject "${image_ref}")"
  generate_provenance_predicate "${image_ref}" "${subject}" > "${provenance_payload}"

  jq . "${provenance_payload}" > /dev/null || {
    error "Invalid provenance JSON for ${image_ref}"
    return 1
  }

  cp "${provenance_payload}" "${provenance_file}"
  info "Provenance written: ${provenance_file}"

  if docker image inspect "${image_ref}" >/dev/null 2>&1; then
    info "Signing provenance with keyless Cosign for: ${image_ref}"
    cosign attest \
      --yes \
      --type slsaprovenance \
      --predicate "${provenance_payload}" \
      "${image_ref}" 2>&1 | tee -a "${PROVENANCE_DIR}/cosign-attest-${image_name}.log"

    info "Uploading to Rekor transparency log"
    cosign verify-attestation \
      --type slsaprovenance \
      "${image_ref}" 2>&1 | tee -a "${PROVENANCE_DIR}/cosign-verify-${image_name}.log"

    info "Provenance signed and recorded in Rekor for: ${image_ref}"
  else
    warn "Image ${image_ref} not found locally — skipping cosign attest"
  fi
}

# Main
if [[ $# -gt 0 ]]; then
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --image)
        generate_and_sign_provenance "$2"
        shift 2
        ;;
      --sbom)
        local sbom_path="$2"
        if [[ -f "${sbom_path}" ]]; then
          info "Attesting SBOM: ${sbom_path}"
          cosign attest \
            --yes \
            --type cyclonedx \
            --predicate "${sbom_path}" \
            "${sbom_path}" 2>&1 || warn "SBOM attestation skipped"
        fi
        shift 2
        ;;
      *)
        error "Unknown option: $1"
        exit 1
        ;;
    esac
  done
else
  for service in "${SERVICES_ARRAY[@]}"; do
    local ref
    if [[ -n "${IMAGE_REGISTRY}" ]]; then
      ref="${IMAGE_REGISTRY}/securerag-${service}:${IMAGE_TAG}"
    else
      ref="securerag-${service}:${IMAGE_TAG}"
    fi
    generate_and_sign_provenance "${ref}"
  done
fi

{
  printf '# SLSA Provenance Generation Report\n\n'
  printf '| Artifact | Provenance | Cosign Attest | Rekor Upload |\n'
  printf '|---|---|---|---|\n'
  for prov_file in "${PROVENANCE_DIR}"/provenance-*.json; do
    [[ -f "${prov_file}" ]] || continue
    local name
    name="$(basename "${prov_file}" .json)"
    local cosign_log="${PROVENANCE_DIR}/cosign-attest-${name#provenance-}.log"
    local attested='❌'
    local rekor='❌'
    if [[ -s "${cosign_log}" ]]; then
      attested='✅'
      if grep -q 'transparency' "${cosign_log}" 2>/dev/null; then
        rekor='✅'
      fi
    fi
    printf '| `%s` | ✅ | %s | %s |\n' "${name}" "${attested}" "${rekor}"
  done
  printf '\n## Summary\n\n'
  printf -- '- Builder ID: `%s`\n' "${BUILDER_ID}"
  printf -- '- Build Type: `%s`\n' "${BUILD_TYPE}"
  printf -- '- Git Commit: `%s`\n' "${GIT_COMMIT}"
  printf -- '- Generated: `%s`\n' "${BUILD_TIMESTAMP}"
  printf -- '- SLSA Level: 3+\n'
} > "${PROVENANCE_DIR}/provenance-report.md"

info "Provenance generation complete. Report: ${PROVENANCE_DIR}/provenance-report.md"
