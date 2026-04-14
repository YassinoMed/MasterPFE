#!/usr/bin/env bash
set -euo pipefail

# Déploiement strict K8s par Digest (Garantie No-Rebuild)
# Consomme le fichier produit par la promotion par digest et injecte la ref immuable.

OVERLAY="${KUSTOMIZE_OVERLAY:-infra/k8s/overlays/demo}"
DIGEST_FILE="artifacts/release/promotion-digests.txt"

echo "[INFO] Déploiement Immuable SANS Rebuild - Target: ${OVERLAY}"

if [[ ! -f "${DIGEST_FILE}" ]]; then
    echo "[ERROR] Fichier de digests introuvable : ${DIGEST_FILE}."
    echo "Vous devez absolument exécuter la Promotion par Digest avant de déployer."
    exit 1
fi

echo "[INFO] Injection des Digests garantis dans Kustomize..."

# Se positionner dans l'overlay Kustomize
cd "${OVERLAY}"

# On lit le fichier sans l'entête
tail -n +2 "../../../../${DIGEST_FILE}" | while IFS="|" read -r service source target digest; do
    if [[ -n "${service}" && -n "${digest}" ]]; then
        # Le nom de l'image de base attendu dans le kustomization.yaml
        BASE_IMAGE="securerag-hub-${service}"
        echo "[INJECT] Service: ${BASE_IMAGE} -> Digest: ${digest}"
        # On force Kustomize à réécrire la target vers le digest rigide
        kustomize edit set image "${BASE_IMAGE}=${target}@${digest}"
    fi
done

cd - > /dev/null

echo "[INFO] Validation des manifests finaux..."
kubectl kustomize "${OVERLAY}" > artifacts/release/final-immutable-manifests.yaml

echo "[PASS] Manifests figés produits. Test applicatif de la configuration par dry-run..."
kubectl apply -f artifacts/release/final-immutable-manifests.yaml --dry-run=server

echo "[SUCCESS] Déploiement No-Rebuild validé par l'API Server."
# Note: Retirez le --dry-run=server au sein de votre pipeline pour le déploiement applicatif final.
