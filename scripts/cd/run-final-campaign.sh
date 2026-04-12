#!/usr/bin/env bash

set -euo pipefail

OFFICIAL_SCENARIO="${OFFICIAL_SCENARIO:-demo}"
CAMPAIGN_MODE="${CAMPAIGN_MODE:-execute}"
SUPPORT_PACK_ROOT="${SUPPORT_PACK_ROOT:-artifacts/support-pack}"

info() { printf '[INFO] %s\n' "$*"; }
error() { printf '[ERROR] %s\n' "$*" >&2; }

case "${OFFICIAL_SCENARIO}" in
  demo)
    export KUSTOMIZE_OVERLAY="${KUSTOMIZE_OVERLAY:-infra/k8s/overlays/demo}"
    export SOURCE_IMAGE_TAG="${SOURCE_IMAGE_TAG:-demo}"
    export TARGET_IMAGE_TAG="${TARGET_IMAGE_TAG:-demo-release}"
    export VALIDATION_IMAGE="${VALIDATION_IMAGE:-python:3.12-slim}"
    export PREPULL_REAL_OLLAMA="false"
    ;;
  real|ollama-real)
    export KUSTOMIZE_OVERLAY="${KUSTOMIZE_OVERLAY:-infra/k8s/overlays/dev}"
    export SOURCE_IMAGE_TAG="${SOURCE_IMAGE_TAG:-dev}"
    export TARGET_IMAGE_TAG="${TARGET_IMAGE_TAG:-release-local}"
    export VALIDATION_IMAGE="${VALIDATION_IMAGE:-python:3.12-slim}"
    export PREPULL_REAL_OLLAMA="${PREPULL_REAL_OLLAMA:-true}"
    ;;
  *)
    error "Unsupported OFFICIAL_SCENARIO: ${OFFICIAL_SCENARIO}. Expected demo or real."
    exit 2
    ;;
esac

export CAMPAIGN_MODE
export PROMOTION_STRATEGY="${PROMOTION_STRATEGY:-digest}"
export REPORT_DIR="${REPORT_DIR:-artifacts/release}"
export FINAL_DIR="${FINAL_DIR:-artifacts/final}"
export DIGEST_RECORD_FILE="${DIGEST_RECORD_FILE:-${REPORT_DIR}/promotion-digests.txt}"

mkdir -p "${FINAL_DIR}"

cat > "${FINAL_DIR}/final-campaign-profile.env" <<EOF
OFFICIAL_SCENARIO=${OFFICIAL_SCENARIO}
CAMPAIGN_MODE=${CAMPAIGN_MODE}
KUSTOMIZE_OVERLAY=${KUSTOMIZE_OVERLAY}
SOURCE_IMAGE_TAG=${SOURCE_IMAGE_TAG}
TARGET_IMAGE_TAG=${TARGET_IMAGE_TAG}
PROMOTION_STRATEGY=${PROMOTION_STRATEGY}
VALIDATION_IMAGE=${VALIDATION_IMAGE}
EOF

status=0

info "Running final campaign with scenario=${OFFICIAL_SCENARIO} mode=${CAMPAIGN_MODE}"
if ! bash scripts/validate/run-reference-campaign.sh; then
  status=$?
fi

bash scripts/release/record-release-evidence.sh || true
bash scripts/validate/final-proof-check.sh || true
bash scripts/validate/run-devsecops-final-proof.sh || true
bash scripts/validate/generate-final-validation-summary.sh || true
bash scripts/validate/validate-cluster-security-addons.sh || true
bash scripts/release/collect-supply-chain-evidence.sh || true
bash scripts/validate/generate-devsecops-readiness-report.sh || true
PACK_ID="support-${OFFICIAL_SCENARIO}-$(date -u '+%Y%m%dT%H%M%SZ')" \
  SUPPORT_PACK_ROOT="${SUPPORT_PACK_ROOT}" \
  bash scripts/validate/build-support-pack.sh || true

exit "${status}"
