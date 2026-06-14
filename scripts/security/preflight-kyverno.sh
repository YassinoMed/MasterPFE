#!/usr/bin/env bash
set -euo pipefail

OVERLAY_DIR=${1:-"infra/k8s/overlays/production"}

if [ ! -d "$OVERLAY_DIR" ]; then
    echo "[ERROR] Directory $OVERLAY_DIR does not exist."
    exit 1
fi

echo "[INFO] Running Kubernetes Pre-flight dry-run for $OVERLAY_DIR..."

MANIFEST_TEMP=$(mktemp)
kustomize build "$OVERLAY_DIR" > "$MANIFEST_TEMP"

# 1. Local Kyverno CLI validation (Optionnel mais recommandé)
if command -v kyverno >/dev/null 2>&1; then
    echo "[INFO] Running local Kyverno CLI validation..."
    # Warning: Ensure infra/k8s/policies/kyverno exists locally
    if [ -d "infra/k8s/policies/kyverno" ]; then
        if kyverno apply infra/k8s/policies/kyverno --resource "$MANIFEST_TEMP"; then
            echo "[OK] Local Kyverno validation passed."
        else
            echo "[ERROR] Local Kyverno policy violation detected."
            rm -f "$MANIFEST_TEMP"
            exit 1
        fi
    else
        echo "[WARN] Kyverno policies directory infra/k8s/policies/kyverno not found locally."
    fi
else
    echo "[WARN] kyverno CLI not found locally, skipping client-side policy check."
fi

# 2. Server-side dry-run (Admission controllers)
echo "[INFO] Running API Server dry-run validation..."
if kubectl apply -f "$MANIFEST_TEMP" --dry-run=server --validate=true >/dev/null; then
    echo "[OK] kubectl apply --dry-run=server --validate=true passed."
else
    echo "[ERROR] Pre-flight dry-run validation failed via API Server."
    rm -f "$MANIFEST_TEMP"
    exit 1
fi

rm -f "$MANIFEST_TEMP"
echo "[OK] Pre-flight Kyverno check completed successfully."
