#!/usr/bin/env bash
set -euo pipefail

# Collecte de toutes les preuves cryptographiques pour le rapport d'incident / audit

REPORT_DIR="artifacts/release"
PACK_NAME="artifacts/secure-supply-chain-pack-$(date +%s).tar.gz"

echo "[INFO] Assemblage du paquet de preuves Supply Chain..."

# S'assurer que l'attestation est bien générée avant zippage
bash scripts/release/generate-release-attestation.sh

tar -czf "${PACK_NAME}" -C artifacts release/
echo "[SUCCESS] Evidence Pack DevSecOps consolidé dans : ${PACK_NAME}"
echo "Preuves incluses : SBOM, index, digests, logs de signature et release-attestation.json."
