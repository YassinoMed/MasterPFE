#!/usr/bin/env bash

set -euo pipefail

ENV=$1
SERVICE=$2
DIGEST=$3
BRANCH="main"

if [ -z "$ENV" ] || [ -z "$SERVICE" ] || [ -z "$DIGEST" ]; then
    echo "Usage: $0 <environment> <service> <digest>"
    exit 1
fi

OVERLAY_DIR="infra/k8s/overlays/${ENV}"
KUSTOMIZATION_FILE="${OVERLAY_DIR}/kustomization.yaml"

if [ ! -f "$KUSTOMIZATION_FILE" ]; then
    echo "Error: $KUSTOMIZATION_FILE does not exist."
    exit 1
fi

echo "[INFO] Updating image digest for $SERVICE in $ENV environment..."

# Utilisons un script Python pour remplacer le tag par le digest dans le bloc images:
python3 - "$SERVICE" "$DIGEST" "${KUSTOMIZATION_FILE}" <<'EOF'
import sys
import re

service = sys.argv[1]
digest = sys.argv[2]
filepath = sys.argv[3]

with open(filepath, "r") as f:
    lines = f.read().splitlines()

in_images = False
current_service = None

for i, line in enumerate(lines):
    if line.strip() == "images:":
        in_images = True
        continue
        
    if in_images and line.strip().startswith("- name:"):
        if f"securerag-hub-{service}" in line:
            current_service = service
        else:
            current_service = None
        continue
        
    if in_images and current_service == service:
        if line.strip().startswith("newTag:") or line.strip().startswith("digest:"):
            indent = line.split(line.strip())[0]
            lines[i] = f"{indent}digest: {digest}"
            break

with open(filepath, "w") as f:
    f.write("\n".join(lines) + "\n")
EOF

# Configuration Git
git config user.email "jenkins@securerag.local"
git config user.name "Jenkins GitOps Bot"

git add "${KUSTOMIZATION_FILE}"

if git diff --staged --quiet; then
    echo "[INFO] No changes to commit for $SERVICE"
else
    echo "[INFO] Committing and pushing changes for $SERVICE..."
    git commit -m "gitops: update digest for $SERVICE to $DIGEST"
    # Note: En environnement CI réel, l'authentification Git doit être déjà configurée
    git push origin "$BRANCH"
fi

echo "[OK] GitOps update for $SERVICE completed."
