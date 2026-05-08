#!/usr/bin/env bash
# Bascule Kyverno Audit <-> Enforce avec garde-fou et rollback automatique.
#
# Usage :
#   scripts/deploy/kyverno-enforce-toggle.sh on   # Audit -> Enforce
#   scripts/deploy/kyverno-enforce-toggle.sh off  # Enforce -> Audit (rollback)
#
# 'on' :
#   1. exécute test-kyverno-admission.sh — abort si écarts
#   2. apply infra/k8s/policies/kyverno-enforce
#   3. attend stabilisation puis vérifie qu'aucun PolicyReport en violation
#      n'apparaît sur les workloads de securerag-hub
#   4. si violation détectée, retour automatique en Audit + archive de la cause
#
# Sortie : artifacts/security/kyverno-enforce-toggle.md

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

ACTION="${1:-on}"
NS="${NS:-securerag-hub}"
REPORT_FILE="${REPORT_FILE:-artifacts/security/kyverno-enforce-toggle.md}"
mkdir -p "$(dirname "${REPORT_FILE}")"

require() { command -v "$1" >/dev/null 2>&1 || { echo "[ERROR] missing $1" >&2; exit 2; }; }
require kubectl

write_dependent() {
  cat > "${REPORT_FILE}" <<EOF
# Kyverno enforce toggle

- Generated UTC: \`$(date -u '+%Y-%m-%dT%H:%M:%SZ')\`
- Action: \`${ACTION}\`
- Status: \`DÉPENDANT_DE_L_ENVIRONNEMENT\`
- Reason: $1
EOF
  echo "[INFO] $1 -> ${REPORT_FILE}"
}

if ! kubectl get crd clusterpolicies.kyverno.io >/dev/null 2>&1; then
  write_dependent "Kyverno CRDs not installed"
  exit 0
fi

case "${ACTION}" in
  on|enforce)
    echo "[INFO] running admission tests pre-flight"
    if ! REPORT_FILE="artifacts/security/kyverno-admission-tests.md" \
         bash scripts/validate/test-kyverno-admission.sh; then
      cat > "${REPORT_FILE}" <<EOF
# Kyverno enforce toggle

- Generated UTC: \`$(date -u '+%Y-%m-%dT%H:%M:%SZ')\`
- Action: \`on\`
- Status: \`PARTIEL\`
- Reason: admission tests failed; cluster left in Audit mode.
- See: \`artifacts/security/kyverno-admission-tests.md\`
EOF
      echo "[ERROR] admission tests failed; aborting toggle"
      exit 1
    fi

    echo "[INFO] applying Enforce overlay"
    kubectl apply -k infra/k8s/policies/kyverno-enforce
    sleep 15

    violations="$(kubectl get policyreports -A \
      -o jsonpath='{range .items[*]}{.metadata.namespace}{"/"}{.metadata.name}{" "}{.summary.fail}{"\n"}{end}' \
      2>/dev/null | awk '$2 > 0' || true)"

    if [[ -n "${violations}" ]]; then
      echo "[WARN] PolicyReport violations detected — rolling back to Audit"
      kubectl apply -k infra/k8s/policies/kyverno
      cat > "${REPORT_FILE}" <<EOF
# Kyverno enforce toggle

- Generated UTC: \`$(date -u '+%Y-%m-%dT%H:%M:%SZ')\`
- Action: \`on -> rollback\`
- Status: \`PARTIEL\`
- Reason: violations detected after Enforce, automatic rollback to Audit.

## Violations

\`\`\`
${violations}
\`\`\`
EOF
      exit 1
    fi

    cat > "${REPORT_FILE}" <<EOF
# Kyverno enforce toggle

- Generated UTC: \`$(date -u '+%Y-%m-%dT%H:%M:%SZ')\`
- Action: \`on\`
- Status: \`TERMINÉ\`
- ClusterPolicies in Enforce: $(kubectl get clusterpolicy -o json \
    | python3 -c "import sys,json; print(sum(1 for p in json.load(sys.stdin)['items'] if p['spec'].get('validationFailureAction')=='Enforce'))")
EOF
    echo "[OK] Kyverno enforce ON -> ${REPORT_FILE}"
    ;;

  off|audit)
    echo "[INFO] reverting to Audit overlay"
    kubectl apply -k infra/k8s/policies/kyverno
    cat > "${REPORT_FILE}" <<EOF
# Kyverno enforce toggle

- Generated UTC: \`$(date -u '+%Y-%m-%dT%H:%M:%SZ')\`
- Action: \`off\`
- Status: \`TERMINÉ\`
- All ClusterPolicies reverted to Audit.
EOF
    echo "[OK] Kyverno reverted to Audit -> ${REPORT_FILE}"
    ;;

  *)
    echo "Usage: $0 {on|off}" >&2
    exit 64
    ;;
esac
