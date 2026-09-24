#!/usr/bin/env bash
# scripts/jenkins/from-jenkins.sh — Récupère une URL Jenkins (artifact/console' oks) dans artifacts/jenkins/
#  Usage : scripts/jenkins/from-jenkins.sh <chemin_api> [nom_sortie]
set -euo pipefail

PATH_API="${1:-}"
NAME="${2:-$(basename "${PATH_API}" | tr '/:-' '_').out}"
BASE="http://localhost:8085/job/securerag-hub-ci"
JENKINS_PASS="$(cat infra/jenkins/secrets/jenkins-admin-password)"
OUTDIR="artifacts/jenkins"

mkdir -p "${OUTDIR}"
OUTFILE="${OUTDIR}/${NAME}"

# cookie + crumb pour éviter 403
COOKIE=$(mktemp)
CRUMB=$(curl -s -c "${COOKIE}" -u "admin:${JENKINS_PASS}" "${BASE}/../../crumbIssuer/api/json" \
  | python3 -c "import json,sys;print(json.load(sys.stdin).get('crumb',''))" 2>/dev/null || echo "")

curl -s -b "${COOKIE}" -u "admin:${JENKINS_PASS}" ${CRUMB:+-H "Jenkins-Crumb:$CRUMB"} \
  "${BASE}/${PATH_API}" > "${OUTFILE}"

rm -f "${COOKIE}"
echo "${OUTFILE}"
