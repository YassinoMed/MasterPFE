#!/usr/bin/env bash

set -euo pipefail

# Run the reference DevSecOps campaign end to end:
# verify -> promote -> deploy -> validate -> collect evidence

REGISTRY_HOST="${REGISTRY_HOST:-localhost:5001}"
IMAGE_PREFIX="${IMAGE_PREFIX:-securerag-hub}"
SOURCE_IMAGE_TAG="${SOURCE_IMAGE_TAG:-dev}"
TARGET_IMAGE_TAG="${TARGET_IMAGE_TAG:-release-local}"
KUSTOMIZE_OVERLAY="${KUSTOMIZE_OVERLAY:-infra/k8s/overlays/dev}"
REPORT_DIR="${REPORT_DIR:-artifacts/release}"
FINAL_DIR="${FINAL_DIR:-artifacts/final}"
MODE_LABEL="${MODE_LABEL:-$(basename "${KUSTOMIZE_OVERLAY}")}"
RUN_SECURITY_VALIDATION="${RUN_SECURITY_VALIDATION:-true}"
CAMPAIGN_MODE="${CAMPAIGN_MODE:-execute}"
PREPULL_REAL_OLLAMA="${PREPULL_REAL_OLLAMA:-false}"
PROMOTION_STRATEGY="${PROMOTION_STRATEGY:-digest}"
DIGEST_RECORD_FILE="${DIGEST_RECORD_FILE:-${REPORT_DIR}/promotion-digests.txt}"

mkdir -p "${FINAL_DIR}" "${REPORT_DIR}" artifacts/validation artifacts/sbom

SUMMARY_FILE="${FINAL_DIR}/reference-campaign-summary.md"
COMMANDS_FILE="${FINAL_DIR}/reference-campaign-commands.sh"
IMAGES_FILE="${FINAL_DIR}/image-selection.txt"
RENDER_FILE="${FINAL_DIR}/rendered-overlay.yaml"
CONTEXT_FILE="${FINAL_DIR}/cluster-context.txt"

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

cat > "${COMMANDS_FILE}" <<EOF
REGISTRY_HOST=${REGISTRY_HOST}
IMAGE_PREFIX=${IMAGE_PREFIX}
SOURCE_IMAGE_TAG=${SOURCE_IMAGE_TAG}
TARGET_IMAGE_TAG=${TARGET_IMAGE_TAG}
KUSTOMIZE_OVERLAY=${KUSTOMIZE_OVERLAY}
CAMPAIGN_MODE=${CAMPAIGN_MODE}
PROMOTION_STRATEGY=${PROMOTION_STRATEGY}
EOF

cat > "${IMAGES_FILE}" <<EOF
registry=${REGISTRY_HOST}
image_prefix=${IMAGE_PREFIX}
source_tag=${SOURCE_IMAGE_TAG}
target_tag=${TARGET_IMAGE_TAG}
overlay=${KUSTOMIZE_OVERLAY}
mode_label=${MODE_LABEL}
promotion_strategy=${PROMOTION_STRATEGY}
EOF

kubectl config current-context > "${CONTEXT_FILE}" 2>/dev/null || true
kubectl kustomize "${KUSTOMIZE_OVERLAY}" > "${RENDER_FILE}"

{
  printf '# SecureRAG Hub Reference Campaign\n\n'
  printf '%s\n' "- Timestamp (UTC): $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf '%s\n' "- Registry: \`${REGISTRY_HOST}\`"
  printf '%s\n' "- Image prefix: \`${IMAGE_PREFIX}\`"
  printf '%s\n' "- Source tag: \`${SOURCE_IMAGE_TAG}\`"
  printf '%s\n' "- Target tag: \`${TARGET_IMAGE_TAG}\`"
  printf '%s\n' "- Overlay: \`${KUSTOMIZE_OVERLAY}\`"
  printf '%s\n\n' "- Mode label: \`${MODE_LABEL}\`"
  printf '%s\n\n' "- Campaign mode: \`${CAMPAIGN_MODE}\`"
  printf '%s\n\n' "- Promotion strategy: \`${PROMOTION_STRATEGY}\`"
  printf '## Executed steps\n'
} > "${SUMMARY_FILE}"

if [[ "${CAMPAIGN_MODE}" == "dry-run" ]]; then
  {
    printf '%s\n' '- verify source signatures: SKIPPED (dry-run)'
    printf '%s\n' '- promote images without rebuild: SKIPPED (dry-run)'
    printf '%s\n' '- deploy verified images: SKIPPED (dry-run)'
    printf '%s\n' '- validation suite: SKIPPED (dry-run)'
    printf '%s\n' '- runtime evidence collection: SKIPPED (dry-run)'
    printf '\n## Produced artifacts\n'
    printf '%s\n' "- \`${COMMANDS_FILE#${FINAL_DIR}/}\`"
    printf '%s\n' "- \`${IMAGES_FILE#${FINAL_DIR}/}\`"
    printf '%s\n' "- \`${RENDER_FILE#${FINAL_DIR}/}\`"
    printf '%s\n' "- \`${CONTEXT_FILE#${FINAL_DIR}/}\`"
    printf '\n## Environment-dependent notes\n'
    printf '%s\n' '- This run was intentionally executed in dry-run mode.'
    printf '%s\n' '- No signature verification, promotion, deployment, or validation command was executed.'
  } >> "${SUMMARY_FILE}"
  info "Reference campaign prepared in dry-run mode. Summary written to ${SUMMARY_FILE}"
  exit 0
fi

if is_true "${PREPULL_REAL_OLLAMA}" && [[ "${KUSTOMIZE_OVERLAY}" == "infra/k8s/overlays/dev" ]]; then
  info "Pre-pulling Ollama image before the real-mode deployment"
  bash scripts/deploy/prepull-ollama.sh
fi

info "Step 1/5 - verify source signatures"
REGISTRY_HOST="${REGISTRY_HOST}" IMAGE_PREFIX="${IMAGE_PREFIX}" IMAGE_TAG="${SOURCE_IMAGE_TAG}" \
  REPORT_DIR="${REPORT_DIR}" COSIGN_PUBLIC_KEY="${COSIGN_PUBLIC_KEY:-}" \
  COSIGN_CERTIFICATE_IDENTITY="${COSIGN_CERTIFICATE_IDENTITY:-}" \
  COSIGN_CERTIFICATE_IDENTITY_REGEXP="${COSIGN_CERTIFICATE_IDENTITY_REGEXP:-}" \
  COSIGN_CERTIFICATE_OIDC_ISSUER="${COSIGN_CERTIFICATE_OIDC_ISSUER:-}" \
  COSIGN_CERTIFICATE_OIDC_ISSUER_REGEXP="${COSIGN_CERTIFICATE_OIDC_ISSUER_REGEXP:-}" \
  bash scripts/release/verify-signatures.sh
printf '- verify source signatures: OK\n' >> "${SUMMARY_FILE}"

info "Step 2/5 - promote verified images"
if [[ "${PROMOTION_STRATEGY}" == "digest" ]]; then
  REGISTRY_HOST="${REGISTRY_HOST}" IMAGE_PREFIX="${IMAGE_PREFIX}" SOURCE_IMAGE_TAG="${SOURCE_IMAGE_TAG}" \
    TARGET_IMAGE_TAG="${TARGET_IMAGE_TAG}" REPORT_DIR="${REPORT_DIR}" DIGEST_RECORD_FILE="${DIGEST_RECORD_FILE}" \
    COSIGN_PUBLIC_KEY="${COSIGN_PUBLIC_KEY:-}" \
    COSIGN_CERTIFICATE_IDENTITY="${COSIGN_CERTIFICATE_IDENTITY:-}" \
    COSIGN_CERTIFICATE_IDENTITY_REGEXP="${COSIGN_CERTIFICATE_IDENTITY_REGEXP:-}" \
    COSIGN_CERTIFICATE_OIDC_ISSUER="${COSIGN_CERTIFICATE_OIDC_ISSUER:-}" \
    COSIGN_CERTIFICATE_OIDC_ISSUER_REGEXP="${COSIGN_CERTIFICATE_OIDC_ISSUER_REGEXP:-}" \
    bash scripts/release/promote-by-digest.sh
else
  REGISTRY_HOST="${REGISTRY_HOST}" IMAGE_PREFIX="${IMAGE_PREFIX}" SOURCE_IMAGE_TAG="${SOURCE_IMAGE_TAG}" \
    TARGET_IMAGE_TAG="${TARGET_IMAGE_TAG}" REPORT_DIR="${REPORT_DIR}" \
    COSIGN_PUBLIC_KEY="${COSIGN_PUBLIC_KEY:-}" \
    COSIGN_CERTIFICATE_IDENTITY="${COSIGN_CERTIFICATE_IDENTITY:-}" \
    COSIGN_CERTIFICATE_IDENTITY_REGEXP="${COSIGN_CERTIFICATE_IDENTITY_REGEXP:-}" \
    COSIGN_CERTIFICATE_OIDC_ISSUER="${COSIGN_CERTIFICATE_OIDC_ISSUER:-}" \
    COSIGN_CERTIFICATE_OIDC_ISSUER_REGEXP="${COSIGN_CERTIFICATE_OIDC_ISSUER_REGEXP:-}" \
    bash scripts/release/promote-verified-images.sh
fi
printf '- promote images without rebuild: OK\n' >> "${SUMMARY_FILE}"

info "Step 3/5 - deploy verified promoted images"
REGISTRY_HOST="${REGISTRY_HOST}" IMAGE_PREFIX="${IMAGE_PREFIX}" IMAGE_TAG="${TARGET_IMAGE_TAG}" \
  KUSTOMIZE_OVERLAY="${KUSTOMIZE_OVERLAY}" REPORT_DIR="${REPORT_DIR}" \
  IMAGE_DIGEST_FILE="${DIGEST_RECORD_FILE}" \
  COSIGN_PUBLIC_KEY="${COSIGN_PUBLIC_KEY:-}" \
  COSIGN_CERTIFICATE_IDENTITY="${COSIGN_CERTIFICATE_IDENTITY:-}" \
  COSIGN_CERTIFICATE_IDENTITY_REGEXP="${COSIGN_CERTIFICATE_IDENTITY_REGEXP:-}" \
  COSIGN_CERTIFICATE_OIDC_ISSUER="${COSIGN_CERTIFICATE_OIDC_ISSUER:-}" \
  COSIGN_CERTIFICATE_OIDC_ISSUER_REGEXP="${COSIGN_CERTIFICATE_OIDC_ISSUER_REGEXP:-}" \
  RUN_POSTDEPLOY_VALIDATION=false ENSURE_KIND_CLUSTER=true \
  bash scripts/deploy/verify-and-deploy-kind.sh
printf '- deploy verified images: OK\n' >> "${SUMMARY_FILE}"

info "Step 4/5 - run post-deployment validation"
export REGISTRY_HOST IMAGE_TAG="${TARGET_IMAGE_TAG}"
bash scripts/validate/smoke-tests.sh
if is_true "${RUN_SECURITY_VALIDATION}"; then
  bash scripts/validate/security-smoke.sh
  bash scripts/validate/security-adversarial-advanced.sh
fi
bash scripts/validate/e2e-functional-flow.sh
bash scripts/validate/rag-smoke.sh
bash scripts/validate/generate-validation-report.sh
printf '- validation suite: OK\n' >> "${SUMMARY_FILE}"

info "Step 5/5 - collect runtime evidence"
bash scripts/validate/collect-runtime-evidence.sh
printf '- runtime evidence collection: OK\n' >> "${SUMMARY_FILE}"

{
  printf '\n## Produced artifacts\n'
  printf '- `artifacts/final/reference-campaign-commands.sh`\n'
  printf '- `artifacts/final/image-selection.txt`\n'
  printf '- `artifacts/final/rendered-overlay.yaml`\n'
  printf '- `artifacts/final/cluster-context.txt`\n'
  printf '- `artifacts/release/verify-summary.txt`\n'
  printf '- `artifacts/release/promotion-summary.txt`\n'
  printf '- `artifacts/release/promotion-by-digest-summary.txt`\n'
  printf '- `artifacts/release/promotion-digests.txt`\n'
  printf '- `artifacts/validation/validation-summary.md`\n'
  printf '- `artifacts/validation/k8s-get-all.txt`\n'
  printf '- `artifacts/validation/k8s-pods.txt`\n'
  printf '- `artifacts/validation/k8s-pdb.txt`\n'
  printf '- `artifacts/validation/k8s-hpa.txt`\n'
  printf '- `artifacts/validation/k8s-resourcequota.txt`\n'
  printf '- `artifacts/validation/k8s-limitrange.txt`\n'
  printf '\n## Environment-dependent notes\n'
  if kubectl get crd clusterpolicies.kyverno.io >/dev/null 2>&1; then
    printf '- Kyverno CRDs detected in cluster.\n'
  else
    printf '- Kyverno CRDs not detected; Kyverno policies are present in the repo but were not applied by this script.\n'
  fi
  if kubectl top pods -n securerag-hub >/dev/null 2>&1; then
    printf '- metrics-server detected; HPA metrics should be observable.\n'
  else
    printf '- metrics-server not detected; HPA objects exist but CPU targets may remain `unknown`.\n'
  fi
} >> "${SUMMARY_FILE}"

info "Reference campaign completed. Summary written to ${SUMMARY_FILE}"
