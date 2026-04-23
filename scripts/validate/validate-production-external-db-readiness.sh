#!/usr/bin/env bash

set -euo pipefail

REPORT_DIR="${REPORT_DIR:-artifacts/security}"
REPORT_FILE="${REPORT_FILE:-${REPORT_DIR}/production-external-db-readiness.md}"
OVERLAY="${OVERLAY:-infra/k8s/overlays/production-external-db}"

mkdir -p "${REPORT_DIR}"

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
    COMPLETE_PROVEN)
      printf 'TERMINÉ'
      return 0
      ;;
  esac

  if grep -Fq 'TERMINÉ' "${file}"; then
    printf 'TERMINÉ'
  else
    printf 'PRÊT_NON_EXÉCUTÉ'
  fi
}

failures=()
runtime_ready=false
static_ready=true

row() {
  local control="$1"
  local status="$2"
  local evidence="$3"
  printf '| %s | %s | %s |\n' "${control}" "${status}" "${evidence}" >> "${REPORT_FILE}"
  if [[ "${status}" == "FAIL" ]]; then
    failures+=("${control}: ${evidence}")
  fi
}

{
  printf '# Production External DB Readiness - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Overlay: `%s`\n\n' "${OVERLAY}"
  printf '| Control | Status | Evidence |\n'
  printf '|---|---:|---|\n'
} > "${REPORT_FILE}"

rendered_overlay="$(mktemp)"
trap 'rm -f "${rendered_overlay}"' EXIT

if kubectl kustomize "${OVERLAY}" > "${rendered_overlay}" 2>/dev/null; then
  row "External DB overlay render" "TERMINÉ" "\`${OVERLAY}\` renders successfully"
else
  row "External DB overlay render" "FAIL" "\`kubectl kustomize ${OVERLAY}\` failed"
  static_ready=false
fi

if [[ "${static_ready}" == "true" ]]; then
  if grep -Fq 'value: sqlite' "${rendered_overlay}"; then
    row "SQLite removed from external DB overlay" "FAIL" "\`${OVERLAY}\` still renders SQLite"
    static_ready=false
  else
    row "SQLite removed from external DB overlay" "TERMINÉ" "\`${OVERLAY}\` renders without SQLite"
  fi

  if grep -Fq 'name: securerag-database-secrets' "${rendered_overlay}"; then
    row "Kubernetes Secret references" "TERMINÉ" "workloads reference \`securerag-database-secrets\`"
  else
    row "Kubernetes Secret references" "FAIL" "\`securerag-database-secrets\` not found in rendered overlay"
    static_ready=false
  fi
fi

if [[ -x scripts/secrets/create-production-db-secret.sh ]]; then
  row "Direct secret bootstrap" "TERMINÉ" "\`scripts/secrets/create-production-db-secret.sh\` executable"
else
  row "Direct secret bootstrap" "FAIL" "direct production DB secret bootstrap script missing"
  static_ready=false
fi

if [[ -x scripts/secrets/apply-sops-production-db-secret.sh ]]; then
  row "SOPS bootstrap path" "TERMINÉ" "\`scripts/secrets/apply-sops-production-db-secret.sh\` executable"
else
  row "SOPS bootstrap path" "FAIL" "SOPS production DB secret bootstrap script missing"
  static_ready=false
fi

if [[ -x scripts/secrets/render-production-db-external-secret.sh ]]; then
  row "External Secrets bootstrap path" "TERMINÉ" "\`scripts/secrets/render-production-db-external-secret.sh\` executable"
else
  row "External Secrets bootstrap path" "FAIL" "External Secrets render script missing"
  static_ready=false
fi

direct_secret_status="$(status_from_file artifacts/security/production-db-secret.md)"
sops_secret_status="$(status_from_file artifacts/security/sops-production-db-secret.md)"
external_secret_status="$(status_from_file artifacts/security/external-secrets-runtime.md)"

row "Direct secret runtime evidence" "${direct_secret_status}" "\`artifacts/security/production-db-secret.md\`"
row "SOPS runtime evidence" "${sops_secret_status}" "\`artifacts/security/sops-production-db-secret.md\`"
row "External Secrets runtime evidence" "${external_secret_status}" "\`artifacts/security/external-secrets-runtime.md\`"

if [[ "${direct_secret_status}" == "TERMINÉ" || "${sops_secret_status}" == "TERMINÉ" || "${external_secret_status}" == "TERMINÉ" ]]; then
  runtime_ready=true
fi

global_status="FAIL"
if [[ "${#failures[@]}" -eq 0 && "${static_ready}" == "true" && "${runtime_ready}" == "true" ]]; then
  global_status="TERMINÉ"
elif [[ "${#failures[@]}" -eq 0 && "${static_ready}" == "true" ]]; then
  global_status="PRÊT_NON_EXÉCUTÉ"
fi

{
  printf '\n## Global status\n\n'
  printf 'Statut global: `%s`\n\n' "${global_status}"
  printf '## Interpretation\n\n'
  if [[ "${global_status}" == "TERMINÉ" ]]; then
    printf 'The external database overlay renders correctly and at least one production-grade secret delivery path has been proven on a target cluster.\n'
  elif [[ "${global_status}" == "PRÊT_NON_EXÉCUTÉ" ]]; then
    printf 'The external database overlay and secret-delivery paths are repository-ready. Runtime proof still requires a real cluster secret delivery step.\n'
  else
    printf 'Blocking static gaps remain in the external database readiness path. Fix FAIL rows before calling it production-ready.\n'
  fi
} >> "${REPORT_FILE}"

printf '[INFO] Production external DB readiness report written to %s\n' "${REPORT_FILE}"
