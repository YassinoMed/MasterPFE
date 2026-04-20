#!/usr/bin/env bash

set -euo pipefail

REPORT_DIR="${REPORT_DIR:-artifacts/security}"
REPORT_FILE="${REPORT_FILE:-${REPORT_DIR}/secrets-management.md}"

mkdir -p "${REPORT_DIR}"

failures=()

row() {
  local control="$1"
  local status="$2"
  local evidence="$3"
  printf '| %s | %s | `%s` |\n' "${control}" "${status}" "${evidence}" >> "${REPORT_FILE}"
  if [[ "${status}" == "FAIL" ]]; then
    failures+=("${control}: ${evidence}")
  fi
  return 0
}

contains() {
  local file="$1"
  local pattern="$2"
  [[ -s "${file}" ]] && grep -Fq "${pattern}" "${file}"
}

{
  printf '# Secrets Management Readiness - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf '| Control | Status | Evidence |\n'
  printf '|---|---:|---|\n'
} > "${REPORT_FILE}"

if contains ".gitignore" "security/secrets/.env.local"; then
  row "Local app secrets excluded from Git" "TERMINÉ" ".gitignore contains security/secrets/.env.local"
else
  row "Local app secrets excluded from Git" "FAIL" "security/secrets/.env.local missing from .gitignore"
fi

if [[ -s infra/jenkins/secrets/.gitignore ]]; then
  row "Jenkins local secrets excluded from Git" "TERMINÉ" "infra/jenkins/secrets/.gitignore present"
else
  row "Jenkins local secrets excluded from Git" "FAIL" "infra/jenkins/secrets/.gitignore missing"
fi

if [[ -x scripts/secrets/bootstrap-local-secrets.sh && -x scripts/secrets/create-dev-secrets.sh ]]; then
  row "Demo/dev secret bootstrap" "TERMINÉ" "bootstrap and Kubernetes injection scripts executable"
else
  row "Demo/dev secret bootstrap" "FAIL" "secret bootstrap scripts missing or not executable"
fi

if [[ -x scripts/secrets/create-production-db-secret.sh ]]; then
  row "Production DB secret bootstrap" "TERMINÉ" "scripts/secrets/create-production-db-secret.sh executable"
else
  row "Production DB secret bootstrap" "FAIL" "production DB secret script missing or not executable"
fi

if [[ -s infra/secrets/sops/sops-age.example.yaml && -s infra/secrets/production/securerag-database-secrets.template.yaml ]]; then
  row "SOPS/age production option" "PRÊT_NON_EXÉCUTÉ" "example policy and placeholder Secret template present"
else
  row "SOPS/age production option" "FAIL" "SOPS/age example or Secret template missing"
fi

if [[ -s docs/security/secrets-management-hardening.md && -s docs/security/secrets-strategy.md ]]; then
  row "Secrets documentation" "TERMINÉ" "hardening and strategy docs present"
else
  row "Secrets documentation" "FAIL" "secrets docs missing"
fi

if [[ -s artifacts/security/production-db-secret.md ]] && grep -Fq 'Status: `TERMINÉ`' artifacts/security/production-db-secret.md; then
  row "Production DB secret runtime evidence" "TERMINÉ" "artifacts/security/production-db-secret.md"
else
  row "Production DB secret runtime evidence" "PRÊT_NON_EXÉCUTÉ" "run scripts/secrets/create-production-db-secret.sh with DB env vars"
fi

{
  printf '\n## Global status\n\n'
  if [[ "${#failures[@]}" -eq 0 ]]; then
    printf 'Statut global: `PRÊT_NON_EXÉCUTÉ`\n\n'
    printf 'Repository-side secret controls are ready. Runtime production DB secret evidence is complete only after the Secret is applied on the target cluster.\n'
  else
    printf 'Statut global: `FAIL`\n\n'
    printf 'Blocking gaps:\n'
    for failure in "${failures[@]}"; do
      printf -- '- %s\n' "${failure}"
    done
  fi
} >> "${REPORT_FILE}"

if [[ "${#failures[@]}" -gt 0 ]]; then
  printf '[ERROR] Secrets management validation failed. Report: %s\n' "${REPORT_FILE}" >&2
  exit 1
fi

printf '[INFO] Secrets management report written to %s\n' "${REPORT_FILE}"
