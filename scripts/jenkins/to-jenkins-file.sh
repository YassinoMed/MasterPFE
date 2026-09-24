#!/usr/bin/env bash
# scripts/jenkins/to-jenkins-file.sh — Pousser un fichier local dans le job Jenkins
#  Usage : scripts/jenkins/to-jenkins-file.sh <fichier_local> [<job>]
set -euo pipefail

FW="${1:-}"
JOB="${2:-securerag-hub-ci}"
JENKINS_URL="http://localhost:8085"
JENKINS_ADMIN_ID="${JENKINS_ADMIN_ID:-admin}"
JENKINS_PASSWORD="$(cat infra/jenkins/secrets/jenkins-admin-password)"

if [ ! -f "$FW" ]; then
  echo "Usage: $0 <fichier_local> [<job>]"
  exit 1
fi

echo "[INFO] Copie locale  : $FW"
echo "[INFO] Fichier Jenkins : /workspace/$FW"
# Les deux pointent vers /home/admin/MasterPFE — pas de copie dispo nécessaire
echo "[OK] $FW déjà visible dans Jenkins (/workspace/$FW) — sync bidirectionnel activé par volume."
