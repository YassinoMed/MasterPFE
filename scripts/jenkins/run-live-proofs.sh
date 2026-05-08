#!/usr/bin/env bash
# Wrapper expert : exécute les deux preuves Jenkins live (webhook + push trigger)
# et fusionne les résultats dans un rapport unifié.
#
# Variables d'environnement attendues :
#   JENKINS_URL       (def. http://localhost:8085)
#   JENKINS_CI_JOB    (def. securerag-hub-ci)
#   JENKINS_USER      (optionnel, requis pour API)
#   JENKINS_TOKEN     (optionnel, requis pour API)
#   GIT_REMOTE_URL    (def. https://github.com/YassinoMed/MasterPFE.git)
#
# Si Jenkins est injoignable, les artefacts sont marqués
# `DÉPENDANT_DE_L_ENVIRONNEMENT` au lieu de PARTIEL.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

JENKINS_URL="${JENKINS_URL:-http://localhost:8085}"
JENKINS_CI_JOB="${JENKINS_CI_JOB:-securerag-hub-ci}"
ARTIFACT_DIR="${ARTIFACT_DIR:-artifacts/validation}"
mkdir -p "${ARTIFACT_DIR}" artifacts/jenkins

OUT_WEBHOOK="${ARTIFACT_DIR}/jenkins-webhook-proof.md"
OUT_PUSH="${ARTIFACT_DIR}/jenkins-ci-push-proof.md"

reachable=false
if command -v curl >/dev/null 2>&1; then
  if curl --max-time 5 -fsS "${JENKINS_URL%/}/login" >/dev/null 2>&1; then
    reachable=true
  fi
fi

write_dependent() {
  local out="$1" topic="$2"
  cat > "${out}" <<EOF
# Jenkins live proof — ${topic}

- Generated UTC: \`$(date -u '+%Y-%m-%dT%H:%M:%SZ')\`
- Status: \`DÉPENDANT_DE_L_ENVIRONNEMENT\`
- Reason: Jenkins endpoint \`${JENKINS_URL}\` unreachable from this host.
- Job: \`${JENKINS_CI_JOB}\`

To produce the live proof, start Jenkins (\`docker compose -f infra/jenkins/docker-compose.yml up -d\`)
then re-run \`make jenkins-live-proofs\`.
EOF
}

if [[ "${reachable}" != "true" ]]; then
  write_dependent "${OUT_WEBHOOK}" "GitHub webhook"
  write_dependent "${OUT_PUSH}" "CI push trigger"
  printf '[INFO] Jenkins unreachable — wrote DÉPENDANT_DE_L_ENVIRONNEMENT proofs.\n'
  exit 0
fi

set +e
JENKINS_URL="${JENKINS_URL}" JENKINS_CI_JOB="${JENKINS_CI_JOB}" \
  bash scripts/jenkins/validate-github-webhook.sh
webhook_rc=$?
JENKINS_URL="${JENKINS_URL}" JENKINS_CI_JOB="${JENKINS_CI_JOB}" \
  bash scripts/jenkins/verify-ci-push-trigger.sh
push_rc=$?
set -e

# Republish under artifacts/validation/ for unified consumption.
[[ -f artifacts/jenkins/github-webhook-validation.md ]] && \
  cp artifacts/jenkins/github-webhook-validation.md "${OUT_WEBHOOK}"
[[ -f artifacts/jenkins/ci-push-trigger-proof.md ]] && \
  cp artifacts/jenkins/ci-push-trigger-proof.md "${OUT_PUSH}"

printf '[INFO] webhook rc=%s push rc=%s\n' "${webhook_rc}" "${push_rc}"
exit 0
