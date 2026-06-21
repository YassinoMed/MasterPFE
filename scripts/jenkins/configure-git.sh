#!/usr/bin/env bash
# File: scripts/jenkins/configure-git.sh
# Description: Configure Git pour le bot Jenkins (signatures GPG obligatoires).
# Modified by: DevSecOps Agent — 2026-06-13

set -euo pipefail

JENKINS_EMAIL="jenkins-bot@securerag.local"
JENKINS_NAME="SecureRAG Jenkins Bot"

echo "[INFO] Configuration de Git pour ${JENKINS_NAME} (${JENKINS_EMAIL})"

# 1. Configuration de l'identité
git config --global user.name "${JENKINS_NAME}"
git config --global user.email "${JENKINS_EMAIL}"

# 2. Importation de la clé GPG (si présente via secrets Jenkins/Vault)
if [ -f "/run/secrets/jenkins-gpg-key" ]; then
  echo "[INFO] Importation de la clé GPG privée..."
  gpg --batch --import "/run/secrets/jenkins-gpg-key"
fi

# 3. Récupération du Key ID
KEY_ID=$(gpg --list-secret-keys --keyid-format LONG "${JENKINS_EMAIL}" | grep sec | awk '{print $2}' | cut -d'/' -f2)

if [ -n "${KEY_ID}" ]; then
  echo "[INFO] Clé GPG trouvée: ${KEY_ID}"
  
  # 4. Configuration des signatures Git
  git config --global user.signingkey "${KEY_ID}"
  git config --global commit.gpgsign true
  git config --global tag.gpgsign true
  
  # 5. Export de la clé publique pour validation
  mkdir -p /var/jenkins_home/public-keys
  gpg --armor --export "${KEY_ID}" > /var/jenkins_home/public-keys/jenkins-bot.pub.asc
  echo "[SUCCESS] Configuration des signatures GPG terminée."
else
  echo "[WARNING] Aucune clé GPG trouvée pour ${JENKINS_EMAIL}. Signatures non configurées."
fi
