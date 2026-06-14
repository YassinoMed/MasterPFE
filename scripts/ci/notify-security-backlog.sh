#!/usr/bin/env bash
set -euo pipefail

FAILED_STAGE=${1:-"Quality Gate"}
BUILD_URL=${2:-""}
GITHUB_REPO=${3:-""}
GITHUB_TOKEN=${4:-""}
BUILD_NUMBER=${5:-"Unknown"}

if [ -z "$GITHUB_TOKEN" ] || [ -z "$GITHUB_REPO" ]; then
    echo "[WARN] GITHUB_TOKEN or GITHUB_REPO is missing. Skipping security backlog notification."
    exit 0
fi

ISSUE_TITLE="[SECURITY] Quality gate failed in build #${BUILD_NUMBER}"
ISSUE_BODY="La pipeline CI a détecté des failles bloquantes (Semgrep, Gitleaks, Trivy ou Kube-score).\n\n**Détails de l'échec** :\n- **Stage** : ${FAILED_STAGE}\n- **Lien du Build** : ${BUILD_URL}\n\nMerci d'analyser les rapports de sécurité générés en tant qu'artefacts sur Jenkins."

# Escape double quotes for JSON
ESCAPED_TITLE=$(echo "$ISSUE_TITLE" | sed 's/"/\\"/g')
ESCAPED_BODY=$(echo "$ISSUE_BODY" | sed 's/"/\\"/g')

JSON_PAYLOAD=$(printf '{"title": "%s", "body": "%s", "labels": ["security", "bug"]}' "$ESCAPED_TITLE" "$ESCAPED_BODY")

echo "[INFO] Creating GitHub issue in ${GITHUB_REPO}..."

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/${GITHUB_REPO}/issues \
  -d "$JSON_PAYLOAD")

if [ "$HTTP_STATUS" -eq 201 ]; then
    echo "[INFO] Security backlog issue created successfully on GitHub."
else
    echo "[ERROR] Failed to create GitHub issue. HTTP Status: $HTTP_STATUS"
fi
