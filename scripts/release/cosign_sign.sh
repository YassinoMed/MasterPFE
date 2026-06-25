#!/usr/bin/env bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════
# cosign_sign.sh — SLSA L3 Supply Chain Hardening
# Mandates Cosign Keyless signing for all images.
# Pipeline MUST FAIL if any step is missing.
# ═══════════════════════════════════════════════════════════════════════

REGISTRY_HOST="${REGISTRY_HOST:-localhost:5001}"
IMAGE_PREFIX="${IMAGE_PREFIX:-securerag-hub}"
IMAGE_TAG="${IMAGE_TAG:-dev}"

# Retrieve services dynamically or define standard set
SERVICES=(
  portal-web
  auth-users
  chatbot-manager
  conversation-service
  audit-security-service
)

echo "[INFO] Commencing Cosign Keyless Image Signature..."

if ! command -v cosign &>/dev/null; then
  echo "[ERROR] cosign is not installed"
  exit 1
fi

for service in "${SERVICES[@]}"; do
  IMAGE="${REGISTRY_HOST}/${IMAGE_PREFIX}-${service}:${IMAGE_TAG}"
  echo "[INFO] Signing ${IMAGE} via Keyless Cosign..."
  
  # Fail fast if signing fails
  cosign sign --yes "${IMAGE}" || {
    echo "[ERROR] Keyless signing failed for ${IMAGE}. Supply chain compromise detected. Failing build."
    exit 1
  }
  
  echo "[SUCCESS] Image ${IMAGE} signed."
done

echo "[INFO] All images successfully signed."
exit 0
