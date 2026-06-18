#!/usr/bin/env bash
# verify-signatures-keyless.sh — Cosign Keyless Verification
# SecureRAG Hub — Enterprise Supply Chain Security
#
# Verifies Cosign keyless signatures using Fulcio + Rekor.
# No public key needed — verification is identity-based.
#
# The identity is bound to the OIDC token used during signing:
#   - GitHub Actions:  subject=repo/owner/name, issuer=https://token.actions.githubusercontent.com
#   - Jenkins:         subject=jenkins/job-name, issuer=https://jenkins.securerag.local
#   - SPIFFE:          subject=spiffe://securerag.hub/...
#
# Usage:
#   bash scripts/release/verify-signatures-keyless.sh
set -euo pipefail

REGISTRY_HOST="${REGISTRY_HOST:-localhost:5001}"
IMAGE_PREFIX="${IMAGE_PREFIX:-securerag-hub}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
REPORT_DIR="${REPORT_DIR:-artifacts/release}"

# OIDC identity to verify against
# For GitHub Actions:
COSIGN_ISSUER="${COSIGN_ISSUER:-https://token.actions.githubusercontent.com}"
COSIGN_IDENTITY="${COSIGN_IDENTITY:-https://github.com/YassinoMed/MasterPFE/*}"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

info()  { printf "${GREEN}[INFO]${NC}  %s\n" "$*"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }

# Cosign v2+ uses keyless mode by default via Fulcio + Rekor
mkdir -p "${REPORT_DIR}"

SERVICES=(
  portal-web
  auth-users
  chatbot-manager
  conversation-service
  audit-security-service
)

VERIFY_SUCCESS=0
VERIFY_FAIL=0

for service in "${SERVICES[@]}"; do
  IMAGE="${REGISTRY_HOST}/${IMAGE_PREFIX}-${service}:${IMAGE_TAG}"
  info "Verifying ${IMAGE}..."

  if cosign verify "${IMAGE}" \
    --certificate-identity-regexp="${COSIGN_IDENTITY}" \
    --certificate-oidc-issuer-regexp="${COSIGN_ISSUER}" \
    --rekor-url=https://rekor.sigstore.dev \
    -o json 2>/tmp/cosign-verify-${service}.log; then
    info "✅ ${service} verified"
    VERIFY_SUCCESS=$((VERIFY_SUCCESS + 1))
  else
    error "❌ ${service} verification failed"
    cat /tmp/cosign-verify-${service}.log
    VERIFY_FAIL=$((VERIFY_FAIL + 1))
  fi
done

{
  echo "# Cosign Keyless Verification — Summary"
  echo "_Generated: $(date -u '+%Y-%m-%dT%H:%M:%SZ')_"
  echo ""
  echo "| Status | Count |"
  echo "|--------|:-----:|"
  echo "| ✅ Verified | ${VERIFY_SUCCESS} |"
  echo "| ❌ Failed    | ${VERIFY_FAIL} |"
  echo ""
  echo "Identity: ${COSIGN_IDENTITY}"
  echo "Issuer:   ${COSIGN_ISSUER}"
} > "${REPORT_DIR}/keyless-verify-summary.md"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  VERIFICATION SUMMARY: ${VERIFY_SUCCESS} OK, ${VERIFY_FAIL} FAIL"
echo "═══════════════════════════════════════════════════════════════"

[ "${VERIFY_FAIL}" -eq 0 ] || exit 1
