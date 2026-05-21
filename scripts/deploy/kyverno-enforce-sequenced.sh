#!/usr/bin/env bash
# Bascule Kyverno Audit -> Enforce **policy par policy** avec validation entre
# chaque étape (P0-8 progressif).
#
# Stratégie :
#   1. Pour chaque policy de la liste ordonnée, vérifier qu'aucun
#      PolicyReport en `result: fail` ne concerne le namespace cible.
#   2. Si OK → patcher la ClusterPolicy en `Enforce`, attendre, re-vérifier.
#   3. Si KO → arrêter (laisser les précédentes en Enforce, signaler).
#
# Permet une montée en sécurité graduelle sans casser l'environnement.
#
# Usage :
#   bash scripts/deploy/kyverno-enforce-sequenced.sh
#   POLICIES_TO_ENFORCE="securerag-restrict-image-references" bash ... # subset
#   STOP_AT="securerag-verify-cosign-images" bash ...                  # stop after
#   DRY_RUN=true bash ...                                              # diff only

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

NS="${NS:-securerag-hub}"
DRY_RUN="${DRY_RUN:-false}"
STABILIZE_SECS="${STABILIZE_SECS:-15}"
REPORT_FILE="${REPORT_FILE:-artifacts/security/kyverno-enforce-sequenced.md}"
mkdir -p "$(dirname "${REPORT_FILE}")"

# Order matters: least-impact policies first, image signing last.
# Override with POLICIES_TO_ENFORCE="p1 p2 p3"
DEFAULT_ORDER=(
  "securerag-restrict-image-references"
  "securerag-restrict-volume-types"
  "securerag-require-pod-security"
  "securerag-require-workload-controls"
  "securerag-restrict-service-exposure"
  "securerag-verify-cosign-images"
  "securerag-audit-cleartext-env-values"
)
read -r -a ORDER <<< "${POLICIES_TO_ENFORCE:-${DEFAULT_ORDER[@]}}"

require() { command -v "$1" >/dev/null 2>&1 || { echo "[ERROR] missing $1" >&2; exit 2; }; }
require kubectl

if ! kubectl get crd clusterpolicies.kyverno.io >/dev/null 2>&1; then
  echo "[FAIL] Kyverno CRDs not installed; aborting." >&2
  exit 2
fi

results=()

check_no_violations_for() {
  local pname="$1"
  # Look for any clusterpolicyreport or policyreport entry with this policy + fail
  local fails
  fails=$(kubectl get policyreport,clusterpolicyreport -A -o json 2>/dev/null \
    | jq -r --arg p "${pname}" --arg ns "${NS}" \
        '[.items[].results[]? | select(.policy==$p and .result=="fail" and ((.resources//[])|length==0 or any(.namespace==$ns)))] | length' \
        2>/dev/null || echo "0")
  echo "${fails:-0}"
}

patch_to_enforce() {
  local pname="$1"
  if [ "${DRY_RUN}" = "true" ]; then
    echo "[DRY] kubectl patch clusterpolicy ${pname} → Enforce"
    return 0
  fi
  kubectl patch clusterpolicy "${pname}" --type=merge \
    -p '{"spec":{"validationFailureAction":"Enforce"}}'
}

current_action() {
  kubectl get clusterpolicy "$1" -o jsonpath='{.spec.validationFailureAction}' 2>/dev/null || echo "unknown"
}

for pname in "${ORDER[@]}"; do
  echo
  echo "============================================================="
  echo "[STEP] ${pname}"

  if ! kubectl get clusterpolicy "${pname}" >/dev/null 2>&1; then
    echo "[SKIP] ClusterPolicy '${pname}' not present in cluster"
    results+=("${pname}|SKIPPED|policy not found")
    continue
  fi

  cur="$(current_action "${pname}")"
  echo "[INFO] current action = ${cur}"
  if [ "${cur}" = "Enforce" ]; then
    echo "[OK] already in Enforce, skipping"
    results+=("${pname}|ALREADY_ENFORCE|-")
    continue
  fi

  echo "[CHECK] looking for existing fails on namespace ${NS}…"
  fails="$(check_no_violations_for "${pname}")"
  if [ "${fails}" -gt 0 ]; then
    echo "[ABORT] ${fails} fail(s) reported by '${pname}' on ${NS}; fix violations before enforcing"
    results+=("${pname}|ABORTED|${fails} violations")
    break
  fi
  echo "[OK] 0 violations"

  echo "[ACTION] patching to Enforce"
  patch_to_enforce "${pname}"
  if [ "${DRY_RUN}" = "true" ]; then
    results+=("${pname}|DRY_RUN|-")
    continue
  fi

  echo "[WAIT] ${STABILIZE_SECS}s for re-evaluation…"
  sleep "${STABILIZE_SECS}"

  fails="$(check_no_violations_for "${pname}")"
  if [ "${fails}" -gt 0 ]; then
    echo "[ROLLBACK] ${fails} fail(s) appeared after enforce; reverting to Audit"
    kubectl patch clusterpolicy "${pname}" --type=merge \
      -p '{"spec":{"validationFailureAction":"Audit"}}'
    results+=("${pname}|ROLLED_BACK|${fails} post-enforce violations")
    break
  fi

  results+=("${pname}|ENFORCED|0 violations")

  if [ -n "${STOP_AT:-}" ] && [ "${pname}" = "${STOP_AT}" ]; then
    echo "[STOP] STOP_AT reached after ${pname}"
    break
  fi
done

# Render report
{
  echo "# Kyverno enforce-sequenced report"
  echo
  echo "_Generated UTC: $(date -u '+%Y-%m-%dT%H:%M:%SZ')_"
  echo
  echo "Namespace cible : \`${NS}\` · DRY_RUN=\`${DRY_RUN}\`"
  echo
  echo "| Policy | Result | Detail |"
  echo "|--------|:------:|--------|"
  for r in "${results[@]}"; do
    IFS='|' read -r p s d <<<"${r}"
    icon="✅"
    case "${s}" in
      ABORTED|ROLLED_BACK) icon="❌" ;;
      SKIPPED|DRY_RUN)     icon="⚠️" ;;
    esac
    printf '| `%s` | %s %s | %s |\n' "${p}" "${icon}" "${s}" "${d}"
  done
} > "${REPORT_FILE}"

echo
echo "[INFO] Report: ${REPORT_FILE}"
