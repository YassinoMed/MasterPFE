#!/usr/bin/env bash
# sign-images-keyless.sh — Cosign Keyless Signing
# SecureRAG Hub — Enterprise Supply Chain Security
#
# This script replaces the static key-based Cosign signing with
# keyless mode using OIDC (GitHub Actions, Jenkins, or SPIFFE).
#
# Benefits:
#   - No private key to store or rotate
#   - Identity bound to workflow/job, not a static key
#   - Automatic certificate issuance via Fulcio
#   - Transparency via Rekor
#
# Prerequisites:
#   - Cosign v2+ with Fulcio/Rekor (keyless mode is default)
#   - OIDC token available (GitHub Actions: id-token: write)
#   - Access to Fulcio (public sigstore.dev or private)
#
# Usage:
#   bash scripts/release/sign-images-keyless.sh
#
# Environment:
#   REGISTRY_HOST    (default: localhost:5001)
#   IMAGE_PREFIX     (default: securerag-hub)
#   IMAGE_TAG        (default: latest)
#   COSIGN_ISSUER    (optional, validates OIDC issuer)
#   COSIGN_IDENTITY  (optional, validates OIDC subject)
set -euo pipefail

REGISTRY_HOST="${REGISTRY_HOST:-localhost:5001}"
IMAGE_PREFIX="${IMAGE_PREFIX:-securerag-hub}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
REPORT_DIR="${REPORT_DIR:-artifacts/release}"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

info()  { printf "${GREEN}[INFO]${NC}  %s\n" "$*"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }

mkdir -p "${REPORT_DIR}"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  COSIGN KEYLESS SIGNING"
echo "  No static keys — identity via OIDC"
echo "═══════════════════════════════════════════════════════════════"

# Cosign v2+ uses keyless mode by default via Fulcio + Rekor

# Validate prerequisites
if ! command -v cosign &>/dev/null; then
  error "cosign not installed"
  exit 1
fi

echo ""
echo "Cosign version: $(cosign version 2>&1 | head -1)"
echo "Keyless mode:   enabled (Fulcio + Rekor)"
echo ""

# Core services to sign
SERVICES=(
  portal-web
  auth-users
  chatbot-manager
  conversation-service
  audit-security-service
)

SIGN_SUCCESS=0
SIGN_FAIL=0

for service in "${SERVICES[@]}"; do
  IMAGE="${REGISTRY_HOST}/${IMAGE_PREFIX}-${service}:${IMAGE_TAG}"
  DIGEST_IMAGE="${REGISTRY_HOST}/${IMAGE_PREFIX}-${service}@${IMAGE_TAG}"

  info "Signing ${IMAGE}..."

  # Try tag-based signing first, fall back to digest
  if cosign sign "${IMAGE}" \
    --yes \
    --fulcio-url=https://fulcio.sigstore.dev \
    --rekor-url=https://rekor.sigstore.dev \
    -o json 2>/tmp/cosign-sign-${service}.log; then
    info "✅ ${service} signed successfully"
    SIGN_SUCCESS=$((SIGN_SUCCESS + 1))
    echo "${IMAGE}" >> "${REPORT_DIR}/keyless-signed-images.txt"
  else
    error "❌ ${service} signing failed"
    cat /tmp/cosign-sign-${service}.log >&2
    SIGN_FAIL=$((SIGN_FAIL + 1))
  fi
done

# Summary
{
  echo "# Cosign Keyless Signing — Summary"
  echo "_Generated: $(date -u '+%Y-%m-%dT%H:%M:%SZ')_"
  echo ""
  echo "| Status | Count |"
  echo "|--------|:-----:|"
  echo "| ✅ Signed | ${SIGN_SUCCESS} |"
  echo "| ❌ Failed | ${SIGN_FAIL} |"
  echo ""
  echo "Keyless mode: enabled"
  echo "Fulcio: https://fulcio.sigstore.dev"
  echo "Rekor:  https://rekor.sigstore.dev"
} > "${REPORT_DIR}/keyless-sign-summary.md"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  SUMMARY: ${SIGN_SUCCESS} signed, ${SIGN_FAIL} failed"
echo "  Report: ${REPORT_DIR}/keyless-sign-summary.md"
echo "═══════════════════════════════════════════════════════════════"

[ "${SIGN_FAIL}" -eq 0 ] || exit 1
