#!/usr/bin/env bash
# scripts/validate/extract_kyverno_reports.sh
# Extrait les métriques de conformité Kyverno (Pass, Fail, Warn, etc.) à partir des PolicyReports réels du cluster.

set -euo pipefail

OUT_FILE="${1:-}"

# Définition des couleurs
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== Kyverno Compliance Report Extraction ==="

# Récupération des rapports
if ! command -v kubectl &>/dev/null; then
    echo -e "${RED}[ERROR] kubectl est requis.${NC}"
    exit 1
fi

echo "[INFO] Extraction des PolicyReports depuis le cluster..."
policy_reports="$(kubectl get policyreports.wgpolicyk8s.io -A -o json 2>/dev/null || echo "")"
cluster_policy_reports="$(kubectl get clusterpolicyreports.wgpolicyk8s.io -o json 2>/dev/null || echo "")"

if [[ -z "${policy_reports}" && -z "${cluster_policy_reports}" ]]; then
    echo -e "${YELLOW}[WARN] Aucun PolicyReport ou ClusterPolicyReport trouvé dans le cluster.${NC}"
    # Mode fallback : recherche locale d'un fichier extrait
    fallback_file="real-data/securerag-hub-support-pack-20260621T090302Z_kyverno-policyreports.yaml"
    if [[ -f "${fallback_file}" ]]; then
        echo "[INFO] Fallback : Extraction à partir du rapport archivé : ${fallback_file}"
        # Extraction via python simple
        python3 - "${fallback_file}" <<'PY'
import sys, yaml
with open(sys.argv[1]) as f:
    data = yaml.safe_load(f)
items = data.get('items', [])
total = len(items)
passes = sum(len([r for r in item.get('results', []) if r.get('result') == 'pass']) for item in items)
fails = sum(len([r for r in item.get('results', []) if r.get('result') in ('fail', 'error')]) for item in items)
warns = sum(len([r for r in item.get('results', []) if r.get('result') == 'warn']) for item in items)
print(f"Rapports trouvés : {total}")
print(f"Vérifications validées (Pass) : {passes}")
print(f"Vérifications en échec (Fail/Error) : {fails}")
print(f"Vérifications suspectes (Warn) : {warns}")
PY
    else:
        echo -e "${RED}[ERROR] Aucun fichier de secours trouvé.${NC}"
        exit 1
    fi
    exit 0
fi

# Calcul des totaux en live
echo "[INFO] Analyse des résultats en cours..."
total_reports=$(echo "${policy_reports}" | jq '.items | length')
total_passes=$(echo "${policy_reports}" | jq '[.items[].results[]? | select(.result == "pass")] | length')
total_fails=$(echo "${policy_reports}" | jq '[.items[].results[]? | select(.result == "fail" or .result == "error")] | length')
total_warns=$(echo "${policy_reports}" | jq '[.items[].results[]? | select(.result == "warn")] | length')

echo -e "Rapports Kyverno actifs: ${GREEN}${total_reports}${NC}"
echo -e "Vérifications validées (Pass): ${GREEN}${total_passes}${NC}"
echo -e "Vérifications en échec (Fail/Error): ${RED}${total_fails}${NC}"
echo -e "Vérifications suspectes (Warn): ${YELLOW}${total_warns}${NC}"

if [[ -n "${OUT_FILE}" ]]; then
    cat > "${OUT_FILE}" <<EOF
# Kyverno Real Compliance Metrics
- Reports analyzed: ${total_reports}
- Total passes: ${total_passes}
- Total failures: ${total_fails}
- Total warnings: ${total_warns}
EOF
    echo "[INFO] Résultats écrits dans : ${OUT_FILE}"
fi
