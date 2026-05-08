#!/usr/bin/env bash
# Vérifie que les overlays officiels respectent le scope défini dans
# docs/architecture/official-scope.md.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

OUT="${OUT:-artifacts/final/official-scope-report.md}"
mkdir -p "$(dirname "${OUT}")"

OFFICIAL_SERVICES=(
  portal-web
  auth-users
  chatbot-manager
  conversation-service
  audit-security-service
)
LEGACY_FORBIDDEN=(
  api-gateway
  knowledge-hub
  llm-orchestrator
  security-auditor
  ollama
  qdrant
)

errors=()
warnings=()

require_tool() {
  command -v "$1" >/dev/null 2>&1 || { errors+=("missing tool: $1"); return 1; }
}

require_tool kubectl || true
require_tool kustomize 2>/dev/null || true

render() {
  local overlay="$1"
  if command -v kustomize >/dev/null 2>&1; then
    kustomize build "${overlay}" 2>/dev/null
  else
    kubectl kustomize "${overlay}" 2>/dev/null
  fi
}

check_overlay() {
  local overlay="$1"
  local label="$2"
  local rendered
  rendered="$(render "${overlay}" || true)"
  if [[ -z "${rendered}" ]]; then
    warnings+=("${label}: render impossible (${overlay})")
    return 0
  fi

  local deploys
  deploys="$(printf '%s\n' "${rendered}" | awk '
    /^kind: Deployment/ {found=1; next}
    found && /^  name:/ {print $2; found=0}
  ')"

  for legacy in "${LEGACY_FORBIDDEN[@]}"; do
    if printf '%s\n' "${deploys}" | grep -Fxq "${legacy}"; then
      errors+=("${label}: legacy component '${legacy}' present in overlay (out-of-scope)")
    fi
  done

  for svc in "${OFFICIAL_SERVICES[@]}"; do
    if ! printf '%s\n' "${deploys}" | grep -Fxq "${svc}"; then
      warnings+=("${label}: official service '${svc}' missing in overlay")
    fi
  done
}

check_overlay "infra/k8s/overlays/demo" "demo"
check_overlay "infra/k8s/overlays/production" "production"

{
  echo "# Official scope validation report"
  echo
  echo "- Generated UTC: \`$(date -u '+%Y-%m-%dT%H:%M:%SZ')\`"
  if ((${#errors[@]} == 0)); then
    if ((${#warnings[@]} == 0)); then
      echo "- Status: \`TERMINÉ\`"
    else
      echo "- Status: \`PARTIEL\`"
    fi
  else
    echo "- Status: \`PARTIEL\`"
  fi
  echo
  echo "## Errors"
  if ((${#errors[@]} == 0)); then
    echo "- (none)"
  else
    for e in "${errors[@]}"; do echo "- ${e}"; done
  fi
  echo
  echo "## Warnings"
  if ((${#warnings[@]} == 0)); then
    echo "- (none)"
  else
    for w in "${warnings[@]}"; do echo "- ${w}"; done
  fi
} > "${OUT}"

printf '[INFO] official scope report -> %s\n' "${OUT}"

if ((${#errors[@]} > 0)); then
  printf '[ERROR] %d scope violation(s) detected\n' "${#errors[@]}" >&2
  exit 1
fi
