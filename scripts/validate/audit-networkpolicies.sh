#!/usr/bin/env bash
# Audit statique des NetworkPolicies (P0-11).
#
# Vérifie pour chaque service workload:
#   1. Existence d'une NetworkPolicy par-service dans base/<svc>/networkpolicy.yaml
#   2. policyTypes inclut Ingress et Egress
#   3. ingress.from non-vide (sinon = autoriser tout, comme port-only)
#   4. egress.to non-vide (sinon = autoriser tout)
#
# Sortie : artifacts/security/networkpolicies-audit.md  + exit 1 si écarts.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT}"
REPORT="${REPORT:-artifacts/security/networkpolicies-audit.md}"
mkdir -p "$(dirname "${REPORT}")"

require() { command -v "$1" >/dev/null 2>&1 || { echo "[FAIL] missing $1" >&2; exit 2; }; }
require yq

services=(api-gateway audit-security-service auth-users chatbot-manager conversation-service knowledge-hub llm-orchestrator ollama portal-web qdrant security-auditor)

failures=0
results=()

audit_one() {
  local svc="$1" file="infra/k8s/base/${svc}/networkpolicy.yaml"
  local issues=()
  if [ ! -s "${file}" ]; then
    issues+=("missing ${file}")
    failures=$((failures + 1))
    results+=("FAIL|${svc}|$(IFS='; '; printf '%s' "${issues[*]}")")
    return
  fi

  local types; types=$(yq eval '.spec.policyTypes // []' "${file}" | tr -d '[:space:]')
  if [[ "${types}" != *Ingress* ]]; then issues+=("policyTypes missing Ingress"); fi
  if [[ "${types}" != *Egress*  ]]; then issues+=("policyTypes missing Egress"); fi

  # Ingress.from must be non-empty (otherwise it's just port-restricted)
  local ing_from_count; ing_from_count=$(yq eval '[.spec.ingress[]?.from[]?] | length' "${file}" 2>/dev/null || echo 0)
  if [ "${ing_from_count}" = "0" ]; then
    issues+=("ingress[].from empty (allows from all pods)")
  fi
  # Egress.to either non-empty or explicitly empty list (deny-all egress)
  local egr_to_count; egr_to_count=$(yq eval '[.spec.egress[]?.to[]?] | length' "${file}" 2>/dev/null || echo 0)
  local egr_count;    egr_count=$(yq eval '.spec.egress | length' "${file}" 2>/dev/null || echo 0)
  if [ "${egr_count}" != "0" ] && [ "${egr_to_count}" = "0" ]; then
    issues+=("egress non-empty but no .to selectors (allows to all)")
  fi

  if [ ${#issues[@]} -eq 0 ]; then
    results+=("OK|${svc}|-")
  else
    failures=$((failures + 1))
    local joined; joined=$(IFS='; '; printf '%s' "${issues[*]}")
    results+=("FAIL|${svc}|${joined}")
  fi
}

for svc in "${services[@]}"; do
  audit_one "${svc}"
done

verdict="TERMINÉ"
[ "${failures}" -gt 0 ] && verdict="PARTIEL"

{
  echo "# NetworkPolicies — Audit statique"
  echo
  echo "_Generated UTC: $(date -u '+%Y-%m-%dT%H:%M:%SZ')_  · Status: \`${verdict}\`"
  echo
  echo "Vérifie : présence par-service, policyTypes={Ingress,Egress}, ingress.from non vide, egress.to cohérent."
  echo
  echo "| Result | Service | Issues |"
  echo "|:------:|---------|--------|"
  for r in "${results[@]}"; do
    IFS='|' read -r res svc issues <<< "${r}"
    icon="✅"; [ "${res}" = "FAIL" ] && icon="❌"
    printf '| %s %s | `%s` | %s |\n' "${icon}" "${res}" "${svc}" "${issues}"
  done
} > "${REPORT}"

echo "[INFO] Report: ${REPORT}"
[ "${failures}" -eq 0 ] || exit 1
