#!/usr/bin/env bash

set -euo pipefail

JENKINS_RBAC_CASC="${JENKINS_RBAC_CASC:-infra/jenkins/casc/jenkins-rbac.matrix.yaml}"
REPORT_FILE="${REPORT_FILE:-artifacts/jenkins/rbac-proof.md}"

mkdir -p "$(dirname "${REPORT_FILE}")"

if [[ -s "${JENKINS_RBAC_CASC}" ]]; then
  status="PRÊT_NON_EXÉCUTÉ"
  detail="Matrix/role-based RBAC JCasC profile is versioned but not proven against the live Jenkins instance."
else
  status="PARTIEL"
  detail="RBAC JCasC profile is missing."
fi

if [[ -n "${JENKINS_URL:-}" && -n "${JENKINS_USER:-}" && -n "${JENKINS_TOKEN:-}" ]] && command -v curl >/dev/null 2>&1; then
  if curl -fsS -u "${JENKINS_USER}:${JENKINS_TOKEN}" "${JENKINS_URL%/}/whoAmI/api/json" >/tmp/securerag-jenkins-whoami.json 2>/tmp/securerag-jenkins-rbac.err; then
    status="TERMINÉ"
    detail="Jenkins API is reachable with a non-embedded credential. RBAC profile still must be applied through the Jenkins configuration channel selected by the operator."
  else
    status="PARTIEL"
    detail="$(cat /tmp/securerag-jenkins-rbac.err)"
  fi
fi

{
  printf '# Jenkins RBAC Proof - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Status: `%s`\n' "${status}"
  printf -- '- RBAC JCasC profile: `%s`\n\n' "${JENKINS_RBAC_CASC}"
  printf '## Detail\n\n%s\n' "${detail}"
} > "${REPORT_FILE}"

printf '[INFO] Jenkins RBAC report written to %s\n' "${REPORT_FILE}"
