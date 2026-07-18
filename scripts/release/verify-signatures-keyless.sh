#!/usr/bin/env bash
# verify-signatures-keyless.sh — Cosign Keyless Verification
# SecureRAG Hub — Enterprise Supply Chain Security

set -euo pipefail

REGISTRY_HOST="${REGISTRY_HOST:-localhost:5001}"
IMAGE_PREFIX="${IMAGE_PREFIX:-securerag-hub}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
REPORT_DIR="${REPORT_DIR:-artifacts/release}"
LOCAL_SIGSTORE="${LOCAL_SIGSTORE:-true}"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

info()  { printf "${GREEN}[INFO]${NC}  %s\n" "$*"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }

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

# Configure endpoints and expectations
if [ "${LOCAL_SIGSTORE}" = "true" ]; then
  COSIGN_ISSUER="${COSIGN_ISSUER:-http://keycloak.sigstore-system/realms/securerag-cicd}"
  COSIGN_IDENTITY="${COSIGN_IDENTITY:-jenkins-cosign@securerag.local}"
  REKOR_URL="http://rekor.sigstore-system"
  
  # Fetch Fulcio CA cert if needed for verification
  # If local verification runs, we must make sure the system trust bundle or cosign env is aware of local Fulcio CA
  SECRET_NAME=$(kubectl get secrets -n sigstore-system -o name 2>/dev/null | grep fulcio | head -n 1 | cut -d/ -f2 || echo "")
  if [ -n "$SECRET_NAME" ]; then
    FULCIO_CERT_FILE="/tmp/fulcio-root.pem"
    kubectl get secret "$SECRET_NAME" -n sigstore-system -o jsonpath='{.data.cert}' 2>/dev/null | base64 -d > "${FULCIO_CERT_FILE}" 2>/dev/null || \
    kubectl get secret "$SECRET_NAME" -n sigstore-system -o jsonpath='{.data.cert\.pem}' 2>/dev/null | base64 -d > "${FULCIO_CERT_FILE}" 2>/dev/null || \
    kubectl get secret "$SECRET_NAME" -n sigstore-system -o jsonpath='{.data.cacert\.pem}' 2>/dev/null | base64 -d > "${FULCIO_CERT_FILE}" 2>/dev/null || \
    kubectl get secret "$SECRET_NAME" -n sigstore-system -o jsonpath='{.data.root\.pem}' 2>/dev/null | base64 -d > "${FULCIO_CERT_FILE}" 2>/dev/null || true
    if [ -f "${FULCIO_CERT_FILE}" ] && [ -s "${FULCIO_CERT_FILE}" ]; then
      export SIGSTORE_ROOT_FILE="${FULCIO_CERT_FILE}"
      info "Using local Fulcio CA certificate at ${FULCIO_CERT_FILE}"
    fi
  fi
else
  COSIGN_ISSUER="${COSIGN_ISSUER:-https://token.actions.githubusercontent.com}"
  COSIGN_IDENTITY="${COSIGN_IDENTITY:-https://github.com/YassinoMed/MasterPFE/*}"
  REKOR_URL="https://rekor.sigstore.dev"
fi

for service in "${SERVICES[@]}"; do
  IMAGE="${REGISTRY_HOST}/${IMAGE_PREFIX}-${service}:${IMAGE_TAG}"
  info "Verifying ${IMAGE}..."

  declare -a verify_args
  verify_args=(
    verify
    "--certificate-identity-regexp=${COSIGN_IDENTITY}"
    "--certificate-oidc-issuer-regexp=${COSIGN_ISSUER}"
    "--rekor-url=${REKOR_URL}"
  )

  if cosign "${verify_args[@]}" "${IMAGE}" -o json 2>/tmp/cosign-verify-${service}.log; then
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
