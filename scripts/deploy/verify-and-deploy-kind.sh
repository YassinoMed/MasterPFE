#!/usr/bin/env bash

set -euo pipefail

# Verify the signatures of the images selected for deployment and only then
# deploy them to the target kind overlay. This script is intended to be the
# deployment entry point used by Jenkins CD.

REGISTRY_HOST="${REGISTRY_HOST:-localhost:5001}"
IMAGE_PREFIX="${IMAGE_PREFIX:-securerag-hub}"
IMAGE_TAG="${IMAGE_TAG:-release-local}"
REPORT_DIR="${REPORT_DIR:-artifacts/release}"
KUSTOMIZE_OVERLAY="${KUSTOMIZE_OVERLAY:-infra/k8s/overlays/dev}"
ENSURE_KIND_CLUSTER="${ENSURE_KIND_CLUSTER:-true}"
RUN_POSTDEPLOY_VALIDATION="${RUN_POSTDEPLOY_VALIDATION:-false}"
IMAGE_DIGEST_FILE="${IMAGE_DIGEST_FILE:-}"

info() { printf '[INFO] %s\n' "$*"; }
error() { printf '[ERROR] %s\n' "$*" >&2; }

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    error "Missing required command: $1"
    exit 2
  fi
}

is_true() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|y|Y|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

require_command bash
require_command kubectl

mkdir -p "${REPORT_DIR}"

info "Verifying signatures for deployment tag ${IMAGE_TAG}"
REGISTRY_HOST="${REGISTRY_HOST}" IMAGE_PREFIX="${IMAGE_PREFIX}" IMAGE_TAG="${IMAGE_TAG}" \
  REPORT_DIR="${REPORT_DIR}" COSIGN_PUBLIC_KEY="${COSIGN_PUBLIC_KEY:-}" \
  COSIGN_CERTIFICATE_IDENTITY="${COSIGN_CERTIFICATE_IDENTITY:-}" \
  COSIGN_CERTIFICATE_IDENTITY_REGEXP="${COSIGN_CERTIFICATE_IDENTITY_REGEXP:-}" \
  COSIGN_CERTIFICATE_OIDC_ISSUER="${COSIGN_CERTIFICATE_OIDC_ISSUER:-}" \
  COSIGN_CERTIFICATE_OIDC_ISSUER_REGEXP="${COSIGN_CERTIFICATE_OIDC_ISSUER_REGEXP:-}" \
  bash scripts/release/verify-signatures.sh

if is_true "${ENSURE_KIND_CLUSTER}"; then
  info "Ensuring the local kind cluster and registry are available"
  REGISTRY_HOST="${REGISTRY_HOST}" bash scripts/deploy/create-kind.sh
fi

info "Deploying verified images to ${KUSTOMIZE_OVERLAY}"
REGISTRY_HOST="${REGISTRY_HOST}" IMAGE_PREFIX="${IMAGE_PREFIX}" IMAGE_TAG="${IMAGE_TAG}" \
  IMAGE_DIGEST_FILE="${IMAGE_DIGEST_FILE}" \
  KUSTOMIZE_OVERLAY="${KUSTOMIZE_OVERLAY}" \
  bash scripts/deploy/deploy-kind.sh

if is_true "${RUN_POSTDEPLOY_VALIDATION}"; then
  info "Running post-deployment validation"
  export REGISTRY_HOST="${REGISTRY_HOST}"
  export IMAGE_TAG="${IMAGE_TAG}"
  bash scripts/validate/smoke-tests.sh
  bash scripts/validate/security-smoke.sh
  bash scripts/validate/e2e-functional-flow.sh
  bash scripts/validate/rag-smoke.sh
  bash scripts/validate/security-adversarial-advanced.sh
  bash scripts/validate/generate-validation-report.sh
fi
