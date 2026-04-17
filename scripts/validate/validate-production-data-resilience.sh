#!/usr/bin/env bash

set -euo pipefail

REPORT_DIR="${REPORT_DIR:-artifacts/security}"
REPORT_FILE="${REPORT_FILE:-${REPORT_DIR}/production-data-resilience.md}"
STRICT_PRODUCTION_DATA="${STRICT_PRODUCTION_DATA:-false}"

mkdir -p "${REPORT_DIR}"

apps=(
  "platform/portal-web"
  "services-laravel/auth-users-service"
  "services-laravel/chatbot-manager-service"
  "services-laravel/conversation-service"
  "services-laravel/audit-security-service"
)

is_true() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|y|Y|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

status="PARTIEL"
failures=()

{
  printf '# Production Data Resilience - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Strict mode: `%s`\n\n' "${STRICT_PRODUCTION_DATA}"
  printf '| Control | Status | Evidence |\n'
  printf '|---|---:|---|\n'
} > "${REPORT_FILE}"

for app in "${apps[@]}"; do
  dockerfile="${app}/Dockerfile"
  if grep -Fq 'pdo_mysql' "${dockerfile}" && grep -Fq 'pdo_pgsql' "${dockerfile}"; then
    printf '| `%s` external DB PHP drivers | TERMINÉ | `pdo_mysql` and `pdo_pgsql` installed in Dockerfile |\n' "${app}" >> "${REPORT_FILE}"
  else
    printf '| `%s` external DB PHP drivers | FAIL | Dockerfile does not install both `pdo_mysql` and `pdo_pgsql` |\n' "${app}" >> "${REPORT_FILE}"
    failures+=("${app}: missing pdo_mysql or pdo_pgsql")
  fi
done

if kubectl kustomize infra/k8s/overlays/production >/tmp/securerag-production-data.yaml 2>/dev/null; then
  if grep -Fq 'value: sqlite' /tmp/securerag-production-data.yaml; then
    printf '| Production overlay DB mode | PARTIEL | Render still contains `DB_CONNECTION=sqlite` for local/kind compatibility |\n' >> "${REPORT_FILE}"
    failures+=("production overlay still uses sqlite; external DB target is documented but not enforced")
  else
    printf '| Production overlay DB mode | TERMINÉ | Render does not contain `DB_CONNECTION=sqlite` |\n' >> "${REPORT_FILE}"
  fi
else
  printf '| Production overlay render | FAIL | `kubectl kustomize infra/k8s/overlays/production` failed |\n' >> "${REPORT_FILE}"
  failures+=("production overlay render failed")
fi

if [[ -f docs/runbooks/data-resilience.md ]]; then
  printf '| Data resilience runbook | TERMINÉ | `docs/runbooks/data-resilience.md` present |\n' >> "${REPORT_FILE}"
else
  printf '| Data resilience runbook | FAIL | `docs/runbooks/data-resilience.md` missing |\n' >> "${REPORT_FILE}"
  failures+=("data resilience runbook missing")
fi

if [[ "${#failures[@]}" -eq 0 ]]; then
  status="TERMINÉ"
fi

{
  printf '\n## Global status\n\n'
  printf 'Statut global: `%s`\n\n' "${status}"
  printf '## Interpretation\n\n'
  if [[ "${status}" == "TERMINÉ" ]]; then
    printf 'Production data resilience prerequisites are satisfied statically.\n'
  else
    printf 'Data resilience is not fully production-grade yet. The code is prepared for external databases, but runtime production still requires an external database, secrets, backup and restore execution.\n'
  fi
  printf '\n## Required production evidence\n\n'
  printf -- '- External database endpoint and credentials injected through non-Git secrets.\n'
  printf -- '- Successful application migrations against the external database.\n'
  printf -- '- Backup artifact with checksum.\n'
  printf -- '- Restore test evidence on an isolated database or namespace.\n'
} >> "${REPORT_FILE}"

if [[ "${status}" != "TERMINÉ" ]] && is_true "${STRICT_PRODUCTION_DATA}"; then
  printf '[ERROR] Production data resilience is incomplete. Report: %s\n' "${REPORT_FILE}" >&2
  exit 1
fi

printf '[INFO] Production data resilience report written to %s\n' "${REPORT_FILE}"
