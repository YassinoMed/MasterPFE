#!/usr/bin/env bash
set -euo pipefail

# Simulateur de Webhook GitHub pour prouver l'intégration Jenkins locale.

JENKINS_URL="${1:-http://localhost:8085}"
REPO_NAME="securerag-hub"
WEBHOOK_ENDPOINT="${JENKINS_URL}/github-webhook/"
EVIDENCE_DIR="artifacts/release"

mkdir -p "${EVIDENCE_DIR}"

echo "[INFO] Simulation d'un payload GitHub Push vers ${WEBHOOK_ENDPOINT}"

PAYLOAD=$(cat <<EOF
{
  "ref": "refs/heads/main",
  "repository": {
    "name": "${REPO_NAME}",
    "url": "https://github.com/votre-user/${REPO_NAME}"
  },
  "pusher": {
    "name": "yassino"
  }
}
EOF
)

# Envoi de la requête en mockant les headers GitHub (X-GitHub-Event)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Content-Type: application/json" \
  -H "X-GitHub-Event: push" \
  -X POST "${WEBHOOK_ENDPOINT}" \
  -d "${PAYLOAD}")

if [ "${HTTP_CODE}" == "200" ]; then
    echo "[SUCCESS] Webhook reçu par Jenkins (HTTP 200)."
    echo "Webhook Trigger : SUCCESS at $(date)" > "${EVIDENCE_DIR}/webhook-trigger-evidence.txt"
    echo "Jenkins a bien initié l'examen du SCM suite à ce push."
    exit 0
else
    echo "[ERROR] Échec webhook, code HTTP: ${HTTP_CODE}. Jenkins est-il lancé sur ${JENKINS_URL} ?"
    exit 1
fi
