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

status_from_file() {
  local file="$1"
  local status
  if [[ ! -s "${file}" ]]; then
    printf 'PRÊT_NON_EXÉCUTÉ'
    return 0
  fi
  status="$(grep -E '^- Status: `|^Statut global: `' "${file}" | head -n 1 | sed -E 's/.*Status: `([^`]+)`.*/\1/; s/.*Statut global: `([^`]+)`.*/\1/' || true)"
  case "${status}" in
    TERMINÉ|PARTIEL|PRÊT_NON_EXÉCUTÉ|DÉPENDANT_DE_L_ENVIRONNEMENT|FAIL)
      printf '%s' "${status}"
      return 0
      ;;
  esac
  if grep -Fq 'TERMINÉ' "${file}"; then
    printf 'TERMINÉ'
  else
    printf 'PRÊT_NON_EXÉCUTÉ'
  fi
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

if [[ -s infra/secrets/sops/sops-age.example.yaml && -s infra/secrets/production/securerag-database-secrets.template.yaml && -s infra/secrets/sops/README.md && -x scripts/secrets/apply-sops-production-db-secret.sh ]]; then
  row "SOPS/age repository path" "TERMINÉ" "SOPS config, template and apply script present"
else
  row "SOPS/age repository path" "FAIL" "SOPS/age config, template or apply script missing"
fi

if [[ -s docs/security/secrets-strategy.md ]] && grep -Eq 'External Secrets Operator|Vault' docs/security/secrets-strategy.md && [[ -s infra/secrets/external-secrets/README.md && -s infra/secrets/external-secrets/cluster-secret-store.vault.template.yaml && -s infra/secrets/external-secrets/securerag-database.external-secret.template.yaml && -x scripts/secrets/render-production-db-external-secret.sh && -x scripts/secrets/validate-external-secrets-runtime.sh ]]; then
  row "External Secrets / Vault repository path" "TERMINÉ" "templates, docs and runtime proof script present"
else
  row "External Secrets / Vault repository path" "FAIL" "modern operator path docs, templates or scripts missing"
fi

if [[ -s docs/security/secrets-management-hardening.md && -s docs/security/secrets-strategy.md ]]; then
  row "Secrets documentation" "TERMINÉ" "hardening and strategy docs present"
else
  row "Secrets documentation" "FAIL" "secrets docs missing"
fi

direct_runtime_status="$(status_from_file artifacts/security/production-db-secret.md)"
sops_runtime_status="$(status_from_file artifacts/security/sops-production-db-secret.md)"
external_runtime_status="$(status_from_file artifacts/security/external-secrets-runtime.md)"

row "Direct secret runtime evidence" "${direct_runtime_status}" "artifacts/security/production-db-secret.md"
row "SOPS runtime evidence" "${sops_runtime_status}" "artifacts/security/sops-production-db-secret.md"
row "External Secrets runtime evidence" "${external_runtime_status}" "artifacts/security/external-secrets-runtime.md"

{
  printf '\n## Global status\n\n'
  if [[ "${#failures[@]}" -eq 0 ]]; then
    if [[ "${direct_runtime_status}" == "PARTIEL" || "${sops_runtime_status}" == "PARTIEL" || "${external_runtime_status}" == "PARTIEL" ]]; then
      printf 'Statut global: `PARTIEL`\n\n'
      printf 'At least one runtime secret-delivery path exists but is not clean yet. Inspect the PARTIEL rows above.\n'
    elif [[ "${direct_runtime_status}" == "TERMINÉ" || "${sops_runtime_status}" == "TERMINÉ" || "${external_runtime_status}" == "TERMINÉ" ]]; then
      printf 'Statut global: `TERMINÉ`\n\n'
      printf 'Repository-side secret controls are ready and at least one production-grade runtime secret delivery path has been proven.\n'
    else
      printf 'Statut global: `PRÊT_NON_EXÉCUTÉ`\n\n'
      printf 'Repository-side secret controls are ready. Runtime production secret delivery remains intentionally unexecuted until a target environment is available.\n'
    fi
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
