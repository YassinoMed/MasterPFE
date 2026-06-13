#!/usr/bin/env bash
set -euo pipefail

# Script : export-cosign-key-age.sh
# Exportateur de la fraicheur de la cle Cosign et signatures Harbor obsoletes.

VAULT_ADDR="${VAULT_ADDR:-http://vault.vault.svc.cluster.local:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-}"
PUSHGATEWAY_URL="${PUSHGATEWAY_URL:-http://pushgateway.monitoring.svc.cluster.local:9091}"
HARBOR_ADDR="${HARBOR_ADDR:-http://harbor-core.harbor.svc.cluster.local}"
HARBOR_USER="${HARBOR_USER:-admin}"
HARBOR_PASSWORD="${HARBOR_PASSWORD:-}"

if [[ -z "${VAULT_TOKEN}" ]]; then
  echo "Erreur : VAULT_TOKEN n'est pas defini."
  exit 1
fi

# 1. Recuperation de la date de creation de la cle dans Vault
echo "Lecture des metadonnees de la cle Cosign dans Vault..."
# Utilisation de l'API KV-v2 metadata
RESPONSE=$(curl -s -f -H "X-Vault-Token: ${VAULT_TOKEN}" "${VAULT_ADDR}/v1/secret/metadata/cosign/public-key")
CREATED_AT=$(echo "${RESPONSE}" | jq -r '.data.created_time')

if [[ -z "${CREATED_AT}" || "${CREATED_AT}" == "null" ]]; then
  echo "Erreur : Impossible de recuperer created_time de la cle."
  exit 1
fi

# Calcul de l'age en jours
CREATED_EPOCH=$(date -d "${CREATED_AT}" +%s)
NOW_EPOCH=$(date +%s)
AGE_DAYS=$(( (NOW_EPOCH - CREATED_EPOCH) / 86400 ))

echo "Age de la cle Cosign : ${AGE_DAYS} jours."

# 2. Requete sur Harbor pour les signatures outdated
echo "Requete de l'API Harbor pour verifier les signatures des images..."
OUTDATED_SIGNATURES=0

if [[ -n "${HARBOR_PASSWORD}" ]]; then
  # Recupere la liste des projets
  PROJECTS=$(curl -s -f -u "${HARBOR_USER}:${HARBOR_PASSWORD}" "${HARBOR_ADDR}/api/v2.0/projects" | jq -r '.[].name')
  for PROJECT in ${PROJECTS}; do
    # Recupere les depots par projet
    REPOS=$(curl -s -f -u "${HARBOR_USER}:${HARBOR_PASSWORD}" "${HARBOR_ADDR}/api/v2.0/projects/${PROJECT}/repositories" | jq -r '.[].name')
    for REPO in ${REPOS}; do
      # Enleve le nom du projet du repo path si necessaire pour l'API
      REPO_CLEANED=${REPO#*/}
      # Recupere les artefacts et verifie leur signature
      # Si l'artefact n'est pas signe ou a une signature invalide
      ARTIFACTS=$(curl -s -f -u "${HARBOR_USER}:${HARBOR_PASSWORD}" "${HARBOR_ADDR}/api/v2.0/projects/${PROJECT}/repositories/${REPO_CLEANED}/artifacts")
      UNSIGNED_COUNT=$(echo "${ARTIFACTS}" | jq '[.[] | select(.signed != true)] | length')
      OUTDATED_SIGNATURES=$((OUTDATED_SIGNATURES + UNSIGNED_COUNT))
    done
  done
fi

echo "Images sans signature valide : ${OUTDATED_SIGNATURES}."

# 3. Envoi des metriques a Pushgateway
echo "Envoi des metriques a Pushgateway..."
cat <<EOF | curl -s --data-binary @- "${PUSHGATEWAY_URL}/metrics/job/cosign-rotation"
# HELP cosign_key_age_days Age en jours de la cle publique de signature Cosign.
# TYPE cosign_key_age_days gauge
cosign_key_age_days ${AGE_DAYS}
# HELP cosign_images_outdated_signature_total Nombre d'images Harbor sans signature Cosign valide.
# TYPE cosign_images_outdated_signature_total gauge
cosign_images_outdated_signature_total ${OUTDATED_SIGNATURES}
EOF

echo "Metriques envoyees avec succes."
