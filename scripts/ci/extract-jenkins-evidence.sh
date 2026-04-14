#!/usr/bin/env bash
set -euo pipefail

# Extracteur de preuves Jenkins
# Permet de geler l'état du dernier build et prouver qu'un COMMIT précis a été validé.

JENKINS_URL="${1:-http://localhost:8085}"
JOB_NAME="securerag-hub-ci"
USER="${JENKINS_USER:-admin}"
TOKEN="${JENKINS_TOKEN:-change-me-now}" # A remplacer par un API Token Jenkins
EVIDENCE_FILE="artifacts/release/jenkins-runtime-evidence.json"

mkdir -p artifacts/release
echo "[INFO] Récupération de l'évidence du pipeline ${JOB_NAME}..."

# Appel API REST Jenkins pour récupérer les infos du dernier Build complété
curl -s -u "${USER}:${TOKEN}" \
  "${JENKINS_URL}/job/${JOB_NAME}/lastCompletedBuild/api/json" > "${EVIDENCE_FILE}" || {
    echo "[WARN] Impossible de joindre l'API Jenkins ou aucun build complété. Mode hors-ligne détecté."
    echo '{ "status": "PRÊT_NON_EXÉCUTÉ_HORS_LIGNE" }' > "${EVIDENCE_FILE}"
    exit 0
}

# Extraction via jq si disponible
if command -v jq >/dev/null 2>&1; then
    BUILD_NUM=$(jq -r '.number' "${EVIDENCE_FILE}")
    BUILD_RESULT=$(jq -r '.result' "${EVIDENCE_FILE}")
    COMMIT_SHA=$(jq -r '.actions[]? | select(._class=="hudson.plugins.git.util.BuildData") | .lastBuiltRevision.SHA1' "${EVIDENCE_FILE}" | head -n 1)

    echo "[RESULT] Build #$BUILD_NUM => $BUILD_RESULT"
    echo "[RESULT] Ref Git testée : $COMMIT_SHA"
    echo "Date de preuve: $(date)" >> artifacts/release/webhook-trigger-evidence.txt
else
    echo "[INFO] Fichier json brut sauvegardé (jq non détecté)."
fi
echo "[SUCCESS] Evidence exportée dans ${EVIDENCE_FILE}."
