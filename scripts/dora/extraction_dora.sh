#!/usr/bin/env bash
# scripts/dora/extraction_dora.sh
# Calcule les métriques DORA réelles à partir de l'état actuel de l'infrastructure Kubernetes.

set -euo pipefail

NS="${NS:-securerag-hub}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== DORA Metrics Real Extraction ==="

if ! command -v kubectl &>/dev/null; then
    echo -e "${RED}[ERROR] kubectl est requis.${NC}"
    exit 1
fi

echo "[INFO] Analyse de la fréquence de déploiement (Deployment Frequency)..."
deployments="$(kubectl get deployments -n "${NS}" -o json 2>/dev/null || echo "")"

if [[ -z "${deployments}" ]]; then
    echo -e "${YELLOW}[WARN] Aucun déploiement trouvé dans le namespace ${NS}.${NC}"
    exit 0
fi

# Parcourir chaque déploiement et afficher sa révision de rollout actuelle
echo "--------------------------------------------------------"
printf "%-30s | %-10s | %-12s\n" "SERVICE" "REVISION" "REPLICAS"
echo "--------------------------------------------------------"
echo "${deployments}" | jq -r '.items[] | "\(.metadata.name)\t\(.metadata.annotations."deployment.kubernetes.io/revision")\t\(.status.readyReplicas // 0)/\(.status.replicas)"' | while read -r line; do
    name=$(echo "$line" | cut -f1)
    rev=$(echo "$line" | cut -f2)
    rep=$(echo "$line" | cut -f3)
    printf "%-30s | %-10s | %-12s\n" "$name" "$rev" "$rep"
done
echo "--------------------------------------------------------"

# Calcul du taux d'échec de changement (Change Failure Rate) en inspectant les événements récents de crash
echo "[INFO] Analyse du taux d'échec de changement (Change Failure Rate)..."
crashes=$(kubectl get pods -n "${NS}" -o json | jq '[.items[] | select(.status.containerStatuses[]?.state.waiting?.reason == "CrashLoopBackOff" or .status.containerStatuses[]?.state.waiting?.reason == "ImagePullBackOff")] | length')

if [[ "${crashes}" -gt 0 ]]; then
    echo -e "Statut : ${RED}Instable (${crashes} pods en échec/crashloop)${NC}"
else
    echo -e "Statut : ${GREEN}Sain (0 pods en échec)${NC}"
fi
