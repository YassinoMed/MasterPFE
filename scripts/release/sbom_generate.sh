#!/usr/bin/env bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════
# sbom_generate.sh — SLSA L3 Supply Chain Hardening
# Generates SBOMs using Syft and attests them to the image with Cosign.
# Pipeline MUST FAIL if any step is missing.
# ═══════════════════════════════════════════════════════════════════════

REGISTRY_HOST="${REGISTRY_HOST:-localhost:5001}"
IMAGE_PREFIX="${IMAGE_PREFIX:-securerag-hub}"
IMAGE_TAG="${IMAGE_TAG:-dev}"
REPORT_DIR="artifacts/release/sboms"

SERVICES=(
  portal-web
  auth-users
  chatbot-manager
  conversation-service
  audit-security-service
)

mkdir -p "${REPORT_DIR}"

echo "[INFO] Commencing SBOM Generation and Attestation..."

for service in "${SERVICES[@]}"; do
  IMAGE="${REGISTRY_HOST}/${IMAGE_PREFIX}-${service}:${IMAGE_TAG}"
  SBOM_FILE="${REPORT_DIR}/${service}-sbom.spdx.json"
  
  echo "[INFO] Generating SBOM for ${IMAGE}..."
  syft "${IMAGE}" -o spdx-json > "${SBOM_FILE}" || {
    echo "[ERROR] Failed to generate SBOM for ${IMAGE}. Failing build."
    exit 1
  }

  echo "[INFO] Attesting SBOM to ${IMAGE}..."
  # Fails the pipeline if attestation fails
  cosign attest --yes --type spdxjson --predicate "${SBOM_FILE}" "${IMAGE}" || {
    echo "[ERROR] Failed to attest SBOM for ${IMAGE}. Failing build."
    exit 1
  }
  
  echo "[SUCCESS] SBOM generated and attested for ${IMAGE}."
done

echo "[INFO] SBOM operations completed successfully."
exit 0
