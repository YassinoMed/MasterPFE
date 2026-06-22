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
    echo "[INFO] No changes to commit for $SERVICE in monorepo"
else
    echo "[INFO] Committing and pushing changes for $SERVICE in monorepo..."
    git commit -m "gitops: update digest for $SERVICE to $DIGEST"
    git push origin HEAD:"$BRANCH"
fi

# ── Sync with dedicated GitOps repository ─────────────────────────────
GITOPS_DIR="/root/securerag-hub-gitops"
if [ -d "$GITOPS_DIR" ]; then
    echo "[INFO] Syncing with dedicated GitOps repository locally at $GITOPS_DIR..."
    mkdir -p "${GITOPS_DIR}/${OVERLAY_DIR}"
    cp "${KUSTOMIZATION_FILE}" "${GITOPS_DIR}/${KUSTOMIZATION_FILE}"
    
    # Run git commit in dedicated repo directory
    (
        cd "$GITOPS_DIR"
        git config user.email "jenkins@securerag.local"
        git config user.name "Jenkins GitOps Bot"
        git add "${KUSTOMIZATION_FILE}"
        if git diff --staged --quiet; then
            echo "[INFO] No changes to commit for $SERVICE in dedicated GitOps repo"
        else
            echo "[INFO] Committing in dedicated GitOps repo..."
            git commit -m "gitops: update digest for $SERVICE to $DIGEST"
        fi
    )
else
    # Try syncing via git daemon if running in container and host is reachable
    GITOPS_REMOTE="git://host.docker.internal/securerag-hub-gitops"
    # Fallback to local network IP if needed
    if ! git ls-remote "$GITOPS_REMOTE" &>/dev/null; then
        GITOPS_REMOTE="git://83.229.82.46/securerag-hub-gitops"
    fi
    
    if git ls-remote "$GITOPS_REMOTE" &>/dev/null; then
        echo "[INFO] Syncing with dedicated GitOps repository via daemon at $GITOPS_REMOTE..."
        TEMP_CLONE=$(mktemp -d)
        git clone "$GITOPS_REMOTE" "$TEMP_CLONE"
        mkdir -p "${TEMP_CLONE}/${OVERLAY_DIR}"
        cp "${KUSTOMIZATION_FILE}" "${TEMP_CLONE}/${KUSTOMIZATION_FILE}"
        (
            cd "$TEMP_CLONE"
            git config user.email "jenkins@securerag.local"
            git config user.name "Jenkins GitOps Bot"
            git add "${KUSTOMIZATION_FILE}"
            if git diff --staged --quiet; then
                echo "[INFO] No changes to commit for $SERVICE via daemon"
            else
                echo "[INFO] Committing and pushing to dedicated GitOps repo via daemon..."
                git commit -m "gitops: update digest for $SERVICE to $DIGEST"
                git push origin HEAD:"$BRANCH"
            fi
        )
        rm -rf "$TEMP_CLONE"
    else
        echo "[WARN] Dedicated GitOps repository not found locally and daemon unreachable. Skipping sync."
    fi
fi

echo "[OK] GitOps update for $SERVICE completed."

