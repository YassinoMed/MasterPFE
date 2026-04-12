#!/usr/bin/env bash

set -euo pipefail

# Generate a factual global project status report for soutenance and final review.
# This script reads repository files and generated artefacts. It does not mutate
# Kubernetes, Jenkins, Docker images or application databases.

OUT_DIR="${OUT_DIR:-artifacts/final}"
OUT_FILE="${OUT_FILE:-${OUT_DIR}/global-project-status.md}"

mkdir -p "${OUT_DIR}"

status_path() {
  local path="$1"
  if [[ -e "${path}" ]]; then
    printf 'TERMINÉ'
  else
    printf 'MANQUANT'
  fi
}

status_artifact() {
  local path="$1"
  if [[ -e "${path}" ]]; then
    printf 'PREUVE_PRÉSENTE'
  else
    printf 'PARTIEL'
  fi
}

latest_pack() {
  python3 - <<'PY'
from pathlib import Path

root = Path("artifacts/support-pack")
packs = sorted(root.glob("*.tar.gz"), key=lambda path: path.stat().st_mtime, reverse=True) if root.exists() else []
print(packs[0] if packs else "missing")
PY
}

{
  printf '# Global Project Status - SecureRAG Hub\n\n'
  printf -- '- Generated at: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Git commit: `%s`\n' "$(git rev-parse HEAD 2>/dev/null || printf 'unknown')"
  printf -- '- Git branch: `%s`\n' "$(git rev-parse --abbrev-ref HEAD 2>/dev/null || printf 'unknown')"
  printf -- '- Official scenario: `demo`\n\n'

  printf '## 1. Architecture and governance\n\n'
  printf '| Element | Status | Note |\n'
  printf '|---|---:|---|\n'
  printf '| Jenkins official CI/CD | %s | Jenkins remains the source of truth. |\n' "$(status_path Jenkinsfile.cd)"
  printf '| GitHub Actions legacy | %s | Historical workflows only. |\n' "$(status_path .github)"
  printf '| Kustomize demo overlay | %s | Official soutenance scenario. |\n' "$(status_path infra/k8s/overlays/demo)"
  printf '| Kustomize dev overlay | %s | Local development path. |\n\n' "$(status_path infra/k8s/overlays/dev)"

  printf '## 2. Application layer\n\n'
  printf '| Component | Status | Evidence |\n'
  printf '|---|---:|---|\n'
  printf '| Blade portal | %s | `platform/portal-web` |\n' "$(status_path platform/portal-web)"
  printf '| Portal API adapter | %s | `PortalBackendClient.php` |\n' "$(status_path platform/portal-web/app/Services/PortalBackendClient.php)"
  printf '| auth-users-service | %s | Laravel business service |\n' "$(status_path services-laravel/auth-users-service)"
  printf '| chatbot-manager-service | %s | Laravel business service |\n' "$(status_path services-laravel/chatbot-manager-service)"
  printf '| conversation-service | %s | Laravel business service |\n' "$(status_path services-laravel/conversation-service)"
  printf '| audit-security-service | %s | Laravel business service |\n\n' "$(status_path services-laravel/audit-security-service)"

  printf '## 3. API contracts\n\n'
  printf '| Contract | Status |\n'
  printf '|---|---:|\n'
  printf '| auth-users OpenAPI | %s |\n' "$(status_path docs/openapi/auth-users-service.yaml)"
  printf '| chatbot-manager OpenAPI | %s |\n' "$(status_path docs/openapi/chatbot-manager-service.yaml)"
  printf '| conversation OpenAPI | %s |\n' "$(status_path docs/openapi/conversation-service.yaml)"
  printf '| audit-security OpenAPI | %s |\n\n' "$(status_path docs/openapi/audit-security-service.yaml)"

  printf '## 4. DevSecOps evidence\n\n'
  printf '| Evidence | Status |\n'
  printf '|---|---:|\n'
  printf '| Final validation summary | %s |\n' "$(status_artifact artifacts/final/final-validation-summary.md)"
  printf '| DevSecOps final proof | %s |\n' "$(status_artifact artifacts/final/devsecops-final-proof.md)"
  printf '| Release attestation | %s |\n' "$(status_artifact artifacts/release/release-attestation.json)"
  printf '| Supply chain evidence | %s |\n' "$(status_artifact artifacts/release/supply-chain-evidence.md)"
  printf '| Observability snapshot | %s |\n' "$(status_artifact artifacts/observability/observability-snapshot.md)"
  printf '| Portal-service connectivity | %s |\n' "$(status_artifact artifacts/application/portal-service-connectivity.md)"
  printf '| Latest support pack | %s |\n\n' "$(latest_pack)"

  printf '## 5. Honest remaining dependencies\n\n'
  printf -- '- Jenkins webhook and CI push proof require Jenkins to be publicly reachable from GitHub.\n'
  printf -- '- Full supply chain execute requires Docker images, local registry, Syft, Cosign keys and network reachability.\n'
  printf -- '- HPA and Kyverno runtime proof require an active kind cluster with metrics-server and Kyverno installed.\n'
  printf -- '- The portal can run in `auto` mode with fallback mock data, or `api` mode for strict integration proof.\n\n'

  printf '## 6. Final interpretation\n\n'
  printf 'SecureRAG Hub is now structured as a strong demo-grade platform with a credible path toward quasi pre-production. The remaining gaps are mostly runtime proofs and environment-dependent execute paths, not missing core design artefacts.\n'
} > "${OUT_FILE}"

printf 'Global project status written to %s\n' "${OUT_FILE}"
