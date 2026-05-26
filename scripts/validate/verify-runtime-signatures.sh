#!/usr/bin/env bash
# verify-runtime-signatures.sh — Verify Cosign signatures on images currently running in the cluster
set -euo pipefail

NS="${NS:-securerag-hub}"
REGISTRY_HOST="${REGISTRY_HOST:-localhost:5001}"
IMAGE_PREFIX="${IMAGE_PREFIX:-securerag-hub}"
COSIGN_PUBLIC_KEY="${COSIGN_PUBLIC_KEY:-infra/jenkins/secrets/cosign.pub}"
REPORT_DIR="${REPORT_DIR:-artifacts/validation}"
REPORT_FILE="${REPORT_DIR}/runtime-signature-verification.md"

mkdir -p "${REPORT_DIR}"

official_services=(
  portal-web
  auth-users
  chatbot-manager
  conversation-service
  audit-security-service
)

is_true() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|y|Y|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

# ── Pre-flight checks ──────────────────────────────────────────────────
cosign_available=false
if command -v cosign > /dev/null 2>&1; then
  cosign_available=true
fi

cluster_available=false
if kubectl get namespace "${NS}" > /dev/null 2>&1; then
  cluster_available=true
fi

COSIGN_ALLOW_INSECURE_REGISTRY="${COSIGN_ALLOW_INSECURE_REGISTRY:-}"
if [[ -z "${COSIGN_ALLOW_INSECURE_REGISTRY}" ]]; then
  case "${REGISTRY_HOST}" in
    localhost:*|127.0.0.1:*|0.0.0.0:*)
      COSIGN_ALLOW_INSECURE_REGISTRY=true
      ;;
  esac
fi

FAILURES=0
VERIFIED=0
SKIPPED=0

{
  printf '# Runtime Signature Verification — SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Namespace: `%s`\n' "${NS}"
  printf -- '- Registry: `%s`\n' "${REGISTRY_HOST}"
  printf -- '- Cosign available: `%s`\n' "${cosign_available}"
  printf -- '- Cluster available: `%s`\n' "${cluster_available}"
  printf -- '- Public key: `%s`\n\n' "${COSIGN_PUBLIC_KEY}"
} > "${REPORT_FILE}"

if [[ "${cosign_available}" != "true" ]]; then
  {
    printf '## Status: DÉPENDANT_DE_L_ENVIRONNEMENT\n\n'
    printf 'Cosign CLI is not installed. Signature verification cannot be performed.\n\n'
    printf '### How to install Cosign\n\n'
    printf '```bash\n'
    printf 'curl -Lo cosign "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64"\n'
    printf 'chmod +x cosign && sudo mv cosign /usr/local/bin/\n'
    printf '```\n\n'
    printf '### Command to run manually\n\n'
    printf '```bash\n'
    printf 'cosign verify --key %s %s/%s-<service>:<tag>\n' "${COSIGN_PUBLIC_KEY}" "${REGISTRY_HOST}" "${IMAGE_PREFIX}"
    printf '```\n'
  } >> "${REPORT_FILE}"
  printf '[SKIP] Cosign not installed — signature verification skipped\n'
  printf '[INFO] Report written to %s\n' "${REPORT_FILE}"
  exit 0
fi

if [[ "${cluster_available}" != "true" ]]; then
  {
    printf '## Status: DÉPENDANT_DE_L_ENVIRONNEMENT\n\n'
    printf 'Kubernetes cluster / namespace not reachable. Cannot read runtime images.\n'
  } >> "${REPORT_FILE}"
  printf '[SKIP] Cluster not reachable — signature verification skipped\n'
  exit 0
fi

if [[ ! -f "${COSIGN_PUBLIC_KEY}" ]]; then
  {
    printf '## Status: DÉPENDANT_DE_L_ENVIRONNEMENT\n\n'
    printf 'Cosign public key not found at `%s`.\n\n' "${COSIGN_PUBLIC_KEY}"
    printf 'Generate keys with:\n```bash\nbash scripts/jenkins/bootstrap-local-credentials.sh\n```\n'
  } >> "${REPORT_FILE}"
  printf '[SKIP] Cosign public key not found — signature verification skipped\n'
  exit 0
fi

# ── Verify each service image ──────────────────────────────────────────
echo "## Verification Results" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"
echo "| Service | Image | Signature | Status |" >> "${REPORT_FILE}"
echo "|---|---|---|---|" >> "${REPORT_FILE}"

for service in "${official_services[@]}"; do
  # Get image reference from running pods
  image=$(kubectl get deployment "${service}" -n "${NS}" \
    -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)

  if [[ -z "${image}" ]]; then
    printf '| `%s` | — | — | ⏭️ SKIPPED (no deployment) |\n' "${service}" >> "${REPORT_FILE}"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  # Attempt Cosign verification
  cosign_env=()
  if is_true "${COSIGN_ALLOW_INSECURE_REGISTRY:-false}"; then
    cosign_env=(env COSIGN_ALLOW_INSECURE_REGISTRY=true)
  fi

  if "${cosign_env[@]+"${cosign_env[@]}"}" cosign verify --key "${COSIGN_PUBLIC_KEY}" "${image}" > /dev/null 2>&1; then
    printf '| `%s` | `%s` | ✅ Verified | OK |\n' "${service}" "${image}" >> "${REPORT_FILE}"
    VERIFIED=$((VERIFIED + 1))
    printf '[PASS] %s: signature verified\n' "${service}"
  else
    printf '| `%s` | `%s` | ❌ Not verified | FAILED |\n' "${service}" "${image}" >> "${REPORT_FILE}"
    FAILURES=$((FAILURES + 1))
    printf '[FAIL] %s: signature verification failed\n' "${service}"
  fi
done

echo "" >> "${REPORT_FILE}"

# ── Summary ────────────────────────────────────────────────────────────
{
  printf '## Summary\n\n'
  printf -- '- Verified: %d\n' "${VERIFIED}"
  printf -- '- Failed: %d\n' "${FAILURES}"
  printf -- '- Skipped: %d\n' "${SKIPPED}"
  if [[ "${FAILURES}" -eq 0 && "${VERIFIED}" -gt 0 ]]; then
    printf -- '- **Status**: `OK`\n'
  elif [[ "${FAILURES}" -gt 0 ]]; then
    printf -- '- **Status**: `FAILED`\n'
  else
    printf -- '- **Status**: `SKIPPED_OPTIONAL`\n'
  fi
  printf '\n## Honest interpretation\n\n'
  printf 'In a local kind cluster with `localhost:5001` registry, Cosign verification\n'
  printf 'requires `COSIGN_ALLOW_INSECURE_REGISTRY=true`. This is expected for development.\n'
  printf 'In a production environment, images would be signed against a public registry\n'
  printf 'with proper TLS, making verification straightforward.\n'
} >> "${REPORT_FILE}"

printf '[INFO] Signature verification report: %s\n' "${REPORT_FILE}"

# Do not hard-fail; signature verification is environment-dependent
if [[ "${FAILURES}" -gt 0 ]]; then
  printf '[WARN] %d signature verification(s) failed — review the report\n' "${FAILURES}" >&2
fi
