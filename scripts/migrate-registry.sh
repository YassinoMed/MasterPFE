#!/bin/bash
set -euo pipefail

# File: scripts/migrate-registry.sh
# Description: Migration des images de localhost:5001 vers harbor.securerag.local et vérification des signatures.
# Modified by: DevSecOps Agent — 2026-06-13

SOURCE_REGISTRY="localhost:5001"
TARGET_REGISTRY="harbor.securerag.local/securerag-hub"
IMAGES=(
    "securerag-hub-app:v1"
    "securerag-hub-worker:v1"
)

echo "Début de la migration des images..."

for IMAGE in "${IMAGES[@]}"; do
    SOURCE_IMAGE="${SOURCE_REGISTRY}/${IMAGE}"
    TARGET_IMAGE="${TARGET_REGISTRY}/${IMAGE}"

    echo "Extraction de l'image source: ${SOURCE_IMAGE}"
    docker pull "${SOURCE_IMAGE}" || {
        echo "Erreur lors du pull de ${SOURCE_IMAGE}" >&2
        exit 1
    }

    echo "Tag de l'image vers: ${TARGET_IMAGE}"
    docker tag "${SOURCE_IMAGE}" "${TARGET_IMAGE}" || {
        echo "Erreur lors du tag de ${TARGET_IMAGE}" >&2
        exit 1
    }

    echo "Poussée de l'image cible: ${TARGET_IMAGE}"
    docker push "${TARGET_IMAGE}" || {
        echo "Erreur lors du push de ${TARGET_IMAGE}" >&2
        exit 1
    }

    echo "Vérification Cosign de l'image cible..."
    cosign verify --key cosign.pub "${TARGET_IMAGE}" || {
        echo "Échec de la vérification Cosign pour ${TARGET_IMAGE}" >&2
        exit 1
    }
done

echo "✓ OK"
