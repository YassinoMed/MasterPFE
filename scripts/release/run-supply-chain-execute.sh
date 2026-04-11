#!/usr/bin/env bash

set -euo pipefail

# Execute the advanced supply-chain chain of custody:
# sign -> verify -> promote by digest -> generate SBOM -> record evidence.
#
# This script does not build images. It assumes the source images already exist
# in the target registry under SOURCE_IMAGE_TAG.

REGISTRY_HOST="${REGISTRY_HOST:-localhost:5001}"
IMAGE_PREFIX="${IMAGE_PREFIX:-securerag-hub}"
SOURCE_IMAGE_TAG="${SOURCE_IMAGE_TAG:-dev}"
TARGET_IMAGE_TAG="${TARGET_IMAGE_TAG:-release-local}"
REPORT_DIR="${REPORT_DIR:-artifacts/release}"
SBOM_DIR="${SBOM_DIR:-artifacts/sbom}"
DIGEST_RECORD_FILE="${DIGEST_RECORD_FILE:-${REPORT_DIR}/promotion-digests.txt}"
COSIGN_KEY="${COSIGN_KEY:-infra/jenkins/secrets/cosign.key}"
COSIGN_PUBLIC_KEY="${COSIGN_PUBLIC_KEY:-infra/jenkins/secrets/cosign.pub}"
COSIGN_PASSWORD_FILE="${COSIGN_PASSWORD_FILE:-infra/jenkins/secrets/cosign.password}"
SUPPLY_CHAIN_MODE="${SUPPLY_CHAIN_MODE:-execute}"
FAIL_FAST="${FAIL_FAST:-true}"

SUMMARY_FILE="${REPORT_DIR}/supply-chain-execute-summary.md"

info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
fail() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

image_ref() {
  local service="$1"
  local tag="$2"
  printf '%s/%s-%s:%s' "${REGISTRY_HOST%/}" "${IMAGE_PREFIX}" "${service}" "${tag}"
}

services=(
  api-gateway
  auth-users
  chatbot-manager
  llm-orchestrator
  security-auditor
  knowledge-hub
  portal-web
)

if [[ -n "${SERVICES:-}" ]]; then
  # shellcheck disable=SC2206
  services=(${SERVICES//,/ })
fi

mkdir -p "${REPORT_DIR}" "${SBOM_DIR}"

{
  printf '# Supply Chain Execute Summary\n\n'
  printf -- '- Generated at: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Mode: `%s`\n' "${SUPPLY_CHAIN_MODE}"
  printf -- '- Registry: `%s`\n' "${REGISTRY_HOST}"
  printf -- '- Image prefix: `%s`\n' "${IMAGE_PREFIX}"
  printf -- '- Source tag: `%s`\n' "${SOURCE_IMAGE_TAG}"
  printf -- '- Target tag: `%s`\n\n' "${TARGET_IMAGE_TAG}"
  printf '## Preflight\n\n'
} > "${SUMMARY_FILE}"

require_command docker
require_command cosign
require_command syft
require_command python3

[[ -f "${COSIGN_KEY}" ]] || fail "Cosign private key not found: ${COSIGN_KEY}"
[[ -f "${COSIGN_PUBLIC_KEY}" ]] || fail "Cosign public key not found: ${COSIGN_PUBLIC_KEY}"
[[ -f "${COSIGN_PASSWORD_FILE}" ]] || fail "Cosign password file not found: ${COSIGN_PASSWORD_FILE}"

export COSIGN_PASSWORD
COSIGN_PASSWORD="$(tr -d '\n' < "${COSIGN_PASSWORD_FILE}")"
export COSIGN_YES=true

for service in "${services[@]}"; do
  source_ref="$(image_ref "${service}" "${SOURCE_IMAGE_TAG}")"
  if docker manifest inspect "${source_ref}" >/dev/null 2>&1; then
    printf -- '- OK: `%s`\n' "${source_ref}" >> "${SUMMARY_FILE}"
  else
    printf -- '- FAIL: `%s` not reachable\n' "${source_ref}" >> "${SUMMARY_FILE}"
    fail "Source image is not reachable: ${source_ref}"
  fi
done

if [[ "${SUPPLY_CHAIN_MODE}" == "dry-run" ]]; then
  {
    printf '\n## Dry-run result\n\n'
    printf -- '- Source images were checked.\n'
    printf -- '- Signing, verification, promotion and SBOM generation were not executed.\n'
  } >> "${SUMMARY_FILE}"
  info "Dry-run supply-chain preflight written to ${SUMMARY_FILE}"
  exit 0
fi

info "Signing source images"
REGISTRY_HOST="${REGISTRY_HOST}" IMAGE_PREFIX="${IMAGE_PREFIX}" IMAGE_TAG="${SOURCE_IMAGE_TAG}" \
  REPORT_DIR="${REPORT_DIR}" COSIGN_KEY="${COSIGN_KEY}" FAIL_FAST="${FAIL_FAST}" \
  bash scripts/release/sign-images.sh

info "Verifying source signatures"
REGISTRY_HOST="${REGISTRY_HOST}" IMAGE_PREFIX="${IMAGE_PREFIX}" IMAGE_TAG="${SOURCE_IMAGE_TAG}" \
  REPORT_DIR="${REPORT_DIR}" COSIGN_PUBLIC_KEY="${COSIGN_PUBLIC_KEY}" FAIL_FAST="${FAIL_FAST}" \
  bash scripts/release/verify-signatures.sh

info "Promoting verified images by digest"
REGISTRY_HOST="${REGISTRY_HOST}" IMAGE_PREFIX="${IMAGE_PREFIX}" \
  SOURCE_IMAGE_TAG="${SOURCE_IMAGE_TAG}" TARGET_IMAGE_TAG="${TARGET_IMAGE_TAG}" \
  REPORT_DIR="${REPORT_DIR}" DIGEST_RECORD_FILE="${DIGEST_RECORD_FILE}" \
  COSIGN_PUBLIC_KEY="${COSIGN_PUBLIC_KEY}" FAIL_FAST="${FAIL_FAST}" \
  VERIFY_SOURCE_BEFORE_PROMOTION=false VERIFY_TARGET_AFTER_PROMOTION=true \
  bash scripts/release/promote-by-digest.sh

info "Generating SBOMs for promoted images"
REGISTRY_HOST="${REGISTRY_HOST}" IMAGE_PREFIX="${IMAGE_PREFIX}" IMAGE_TAG="${TARGET_IMAGE_TAG}" \
  SBOM_DIR="${SBOM_DIR}" REPORT_DIR="${REPORT_DIR}" \
  bash scripts/release/generate-sbom.sh

info "Recording release and supply-chain evidence"
REGISTRY_HOST="${REGISTRY_HOST}" IMAGE_PREFIX="${IMAGE_PREFIX}" \
  SOURCE_IMAGE_TAG="${SOURCE_IMAGE_TAG}" TARGET_IMAGE_TAG="${TARGET_IMAGE_TAG}" \
  REPORT_DIR="${REPORT_DIR}" SBOM_DIR="${SBOM_DIR}" DIGEST_RECORD_FILE="${DIGEST_RECORD_FILE}" \
  bash scripts/release/record-release-evidence.sh

REPORT_DIR="${REPORT_DIR}" SBOM_DIR="${SBOM_DIR}" \
  bash scripts/release/collect-supply-chain-evidence.sh

{
  printf '\n## Executed steps\n\n'
  printf -- '- sign source images: OK\n'
  printf -- '- verify source signatures: OK\n'
  printf -- '- promote by digest without rebuild: OK\n'
  printf -- '- verify promoted images: OK\n'
  printf -- '- generate SBOMs: OK\n'
  printf -- '- record release evidence: OK\n\n'
  printf '## Produced evidence\n\n'
  printf -- '- `%s/sign-summary.txt`\n' "${REPORT_DIR}"
  printf -- '- `%s/verify-summary.txt`\n' "${REPORT_DIR}"
  printf -- '- `%s/promotion-by-digest-summary.txt`\n' "${REPORT_DIR}"
  printf -- '- `%s/promotion-digests.txt`\n' "${REPORT_DIR}"
  printf -- '- `%s/sbom-summary.txt`\n' "${REPORT_DIR}"
  printf -- '- `%s/release-evidence.md`\n' "${REPORT_DIR}"
  printf -- '- `%s/supply-chain-evidence.md`\n' "${REPORT_DIR}"
  printf -- '- `%s/sbom-index.txt`\n' "${SBOM_DIR}"
} >> "${SUMMARY_FILE}"

info "Supply-chain execute summary written to ${SUMMARY_FILE}"
