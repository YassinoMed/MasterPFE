#!/usr/bin/env bash
# File: scripts/kyverno-verify/apply-verify-policies.sh
# Description: Applique toutes les politiques Kyverno de vérification d'images.
# Date: 2026-06-18
set -euo pipefail

POLICIES_DIR="infra/k8s/policies/kyverno-verify-images"

echo "[INFO] Application des politiques de vérification d'images Kyverno..."
echo ""

if [[ -f "${POLICIES_DIR}/kustomization.yaml" ]]; then
  echo "[INFO] Déploiement via Kustomize..."
  kubectl apply -k "${POLICIES_DIR}"
else
  echo "[INFO] Déploiement des fichiers YAML individuels..."
  for f in "${POLICIES_DIR}"/*.yaml; do
    [[ "$(basename "$f")" == "kustomization.yaml" ]] && continue
    echo "  -> Applying $(basename "$f")"
    kubectl apply -f "$f"
  done
fi

echo ""
echo "[INFO] Vérification des politiques appliquées..."
kubectl get clusterpolicies -l app.kubernetes.io/part-of=securerag-hub 2>/dev/null || \
  kubectl get clusterpolicies | grep securerag || true

echo ""
echo "[INFO] Statut des politiques:"
for p in $(kubectl get clusterpolicies -o name 2>/dev/null | grep securerag | cut -d/ -f2); do
  ACTION=$(kubectl get clusterpolicy "$p" -o jsonpath='{.spec.validationFailureAction}' 2>/dev/null || echo "unknown")
  echo "  - ${p}: ${ACTION}"
done

echo ""
echo "✓ Politiques de vérification d'images appliquées avec succès."
