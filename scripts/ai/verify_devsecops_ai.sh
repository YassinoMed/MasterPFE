#!/usr/bin/env bash
# scripts/ai/verify_devsecops_ai.sh
# Envoie une alerte de sécurité du cluster DevSecOps à l'AI Orchestrator distant pour évaluation par le conseil de sécurité.

set -euo pipefail

ORCHESTRATOR_URL="${1:-http://10.15.10.119:8082/api/v1/security/council}"
OUT_JSON="docs/security/evidence/ai-security-verdict-raw.json"
OUT_MD="docs/security/evidence/ai-security-advisory.md"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== AI Security Integration Verification ==="
echo "[INFO] Cible de l'Orchestrateur : ${ORCHESTRATOR_URL}"

# 1. Préparation du log d'alerte (une violation réelle de Kyverno extraite du cluster)
SECURITY_LOG="Kyverno PolicyViolation: pod/postgres-auth-867ddc6dc8-w9xgr policy securerag-restrict-image-references/restrict-registries fail: validation failure: Runtime images must come from localhost:5001 or ghcr.io."

echo -e "[INFO] Log d'alerte envoyé : ${YELLOW}${SECURITY_LOG}${NC}"

# 2. Appel de l'Orchestrateur via curl
echo "[INFO] Consultation du Conseil de Sécurité IA (Consensus Multi-Master)..."

response=$(curl -s -X POST -H "Content-Type: application/json" \
  -d "{\"query\": \"${SECURITY_LOG}\"}" \
  "${ORCHESTRATOR_URL}" || echo "")

if [[ -z "${response}" ]]; then
  echo -e "${RED}[ERROR] Impossible de contacter l'Orchestrateur IA à l'adresse ${ORCHESTRATOR_URL}.${NC}"
  echo -e "${YELLOW}[WARN] Assurez-vous que le VPN est connecté et que le serveur sur la machine GPU écoute bien sur 0.0.0.0 (port 8082).${NC}"
  exit 1
fi

# Sauvegarde du JSON brut
mkdir -p "$(dirname "${OUT_JSON}")"
echo "${response}" > "${OUT_JSON}"
echo -e "${GREEN}[OK] Verdict brut sauvegardé dans ${OUT_JSON}${NC}"

# 3. Extraction et affichage du verdict dans la console
decision=$(echo "${response}" | jq -r '.consensus.verdict_final // "N/A"')
score=$(echo "${response}" | jq -r '.consensus.score_consensus // "N/A"')
resolved=$(echo "${response}" | jq -r '.consensus.consensus_reached // "false"')

echo "--------------------------------------------------------"
echo -e "DÉCISION DU CONSEIL IA : ${RED}${decision}${NC}"
echo -e "SCORE DU CONSENSUS     : ${GREEN}${score}%${NC}"
echo -e "CONTRADICTIONS RÉSOLUES: ${YELLOW}${resolved}${NC}"
echo "--------------------------------------------------------"

# 4. Génération d'un rapport Markdown lisible (Advisory)
cat > "${OUT_MD}" <<EOF
# Rapport d'Analyse IA de Sécurité - DevSecOps Chain
- **Date** : $(date -u '+%Y-%m-%dT%H:%M:%SZ')
- **Source d'Alerte** : Kyverno Policy Engine
- **Événement analysé** : \`${SECURITY_LOG}\`
- **Décision Finale** : **${decision}** (Score de consensus : **${score}%**)

## Rôle et Délibération des Master AIs

$(echo "${response}" | jq -r '.consensus.votes_detail | to_entries[] | "### 🛡️ \(.key)\n- **Verdict** : \(.value.verdict)\n- **Confiance** : \(.value.confiance)%\n"')

## Experts Consultés
$(echo "${response}" | jq -r '.experts[] | "- **\(.expert_name)** : \(.conclusion) (Confiance: \(.confidence)%, Sévérité: \(.severity)) \n  *\(.response)*"')

## Preuves et Indices de Compromission
$(echo "${response}" | jq -r '.decision_journal.evidence_summary[]? | "  - \(.)"' || echo "  - Aucun indice supplémentaire détecté")

## Plan de Remédiation Préconisé par l'IA
$(echo "${response}" | jq -r '.report' | sed -n '/Plan de réponse:/,$p' | sed 's/Plan de réponse://g' || echo "Aucune recommandation générée.")
EOF

echo -e "${GREEN}[OK] Rapport Markdown généré avec succès dans : ${OUT_MD}${NC}"

