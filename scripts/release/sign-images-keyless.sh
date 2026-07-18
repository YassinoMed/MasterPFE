#!/usr/bin/env bash
# sign-images-keyless.sh — Cosign Keyless Signing
# SecureRAG Hub — Enterprise Supply Chain Security

set -euo pipefail

REGISTRY_HOST="${REGISTRY_HOST:-localhost:5001}"
IMAGE_PREFIX="${IMAGE_PREFIX:-securerag-hub}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
REPORT_DIR="${REPORT_DIR:-artifacts/release}"
LOCAL_SIGSTORE="${LOCAL_SIGSTORE:-true}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { printf "${GREEN}[INFO]${NC}  %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }

mkdir -p "${REPORT_DIR}"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  COSIGN KEYLESS SIGNING"
echo "  No static keys — identity via OIDC"
echo "═══════════════════════════════════════════════════════════════"

# Validate prerequisites
if ! command -v cosign &>/dev/null; then
  error "cosign not installed"
  exit 1
fi
if ! command -v jq &>/dev/null; then
  error "jq is required but not installed"
  exit 1
fi

echo ""
echo "Cosign version: $(cosign version 2>&1 | head -1)"
echo ""

# Retrieve OIDC token if using local sigstore stack
OIDC_TOKEN_ARG=""
FULCIO_URL="https://fulcio.sigstore.dev"
REKOR_URL="https://rekor.sigstore.dev"
OIDC_ISSUER=""

if [ "${LOCAL_SIGSTORE}" = "true" ]; then
  info "Configuring for local Sigstore environment..."
  
  # Fetch Keycloak token
  # Try both internal service name and external localhost mapping depending on where this script is running
  TOKEN=""
  if curl -s --connect-timeout 5 -f -X POST http://keycloak.sigstore-system/realms/securerag-cicd/protocol/openid-connect/token \
    -d "client_id=jenkins-cosign&client_secret=jenkins-cosign-secret&grant_type=client_credentials" >/tmp/kc-token.json; then
    TOKEN=$(jq -r .access_token /tmp/kc-token.json)
  elif curl -s --connect-timeout 5 -f -X POST http://127.0.0.1:30080/realms/securerag-cicd/protocol/openid-connect/token \
    -d "client_id=jenkins-cosign&client_secret=jenkins-cosign-secret&grant_type=client_credentials" >/tmp/kc-token.json; then
    TOKEN=$(jq -r .access_token /tmp/kc-token.json)
  fi

  if [ -n "${TOKEN}" ] && [ "${TOKEN}" != "null" ]; then
    info "Successfully retrieved OIDC token from local Keycloak."
    export COSIGN_IDENTITY_TOKEN="${TOKEN}"
    OIDC_TOKEN_ARG="--identity-token=${TOKEN}"
    FULCIO_URL="http://fulcio.sigstore-system"
    REKOR_URL="http://rekor.sigstore-system"
    OIDC_ISSUER="http://keycloak.sigstore-system/realms/securerag-cicd"
  else
    warn "Failed to retrieve local Keycloak token. Falling back to public Sigstore."
  fi
fi

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
  info "Signing ${IMAGE}..."

  # Build sign arguments
  declare -a sign_args
  sign_args=(sign --yes)
  
  if [ -n "${OIDC_TOKEN_ARG}" ]; then
    sign_args+=("${OIDC_TOKEN_ARG}")
  fi
  
  sign_args+=(
    "--fulcio-url=${FULCIO_URL}"
    "--rekor-url=${REKOR_URL}"
  )
  
  if [ -n "${OIDC_ISSUER}" ]; then
    sign_args+=("--oidc-issuer=${OIDC_ISSUER}")
  fi

  if cosign "${sign_args[@]}" "${IMAGE}" -o json 2>/tmp/cosign-sign-${service}.log; then
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
  echo "Fulcio: ${FULCIO_URL}"
  echo "Rekor:  ${REKOR_URL}"
} > "${REPORT_DIR}/keyless-sign-summary.md"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  SUMMARY: ${SIGN_SUCCESS} signed, ${SIGN_FAIL} failed"
echo "  Report: ${REPORT_DIR}/keyless-sign-summary.md"
echo "═══════════════════════════════════════════════════════════════"

[ "${SIGN_FAIL}" -eq 0 ] || exit 1
