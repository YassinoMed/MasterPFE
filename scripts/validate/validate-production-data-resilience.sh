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

status="PRÊT_NON_EXÉCUTÉ"
failures=()
runtime_ready=true
static_ready=true

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
    printf '| Production kind overlay DB mode | PRÊT_NON_EXÉCUTÉ | `infra/k8s/overlays/production` keeps SQLite for local/kind compatibility |\n' >> "${REPORT_FILE}"
  else
    printf '| Production kind overlay DB mode | TERMINÉ | Render does not contain `DB_CONNECTION=sqlite` |\n' >> "${REPORT_FILE}"
  fi
else
  printf '| Production overlay render | FAIL | `kubectl kustomize infra/k8s/overlays/production` failed |\n' >> "${REPORT_FILE}"
  failures+=("production overlay render failed")
  static_ready=false
fi

if kubectl kustomize infra/k8s/overlays/production-external-db >/tmp/securerag-production-external-db.yaml 2>/dev/null; then
  if grep -Fq 'value: sqlite' /tmp/securerag-production-external-db.yaml; then
    printf '| External DB overlay SQLite removal | FAIL | `production-external-db` still renders SQLite |\n' >> "${REPORT_FILE}"
    failures+=("production-external-db still renders sqlite")
    static_ready=false
  else
    printf '| External DB overlay SQLite removal | TERMINÉ | `production-external-db` renders without SQLite |\n' >> "${REPORT_FILE}"
  fi

  if grep -Fq 'name: securerag-database-secrets' /tmp/securerag-production-external-db.yaml; then
    printf '| External DB secret references | TERMINÉ | workloads reference `securerag-database-secrets` |\n' >> "${REPORT_FILE}"
  else
    printf '| External DB secret references | FAIL | `securerag-database-secrets` not found in rendered overlay |\n' >> "${REPORT_FILE}"
    failures+=("external DB secret references missing")
    static_ready=false
  fi
else
  printf '| External DB overlay render | FAIL | `kubectl kustomize infra/k8s/overlays/production-external-db` failed |\n' >> "${REPORT_FILE}"
  failures+=("production-external-db overlay render failed")
  static_ready=false
fi

if [[ -f docs/runbooks/data-resilience.md ]]; then
  printf '| Data resilience runbook | TERMINÉ | `docs/runbooks/data-resilience.md` present |\n' >> "${REPORT_FILE}"
else
  printf '| Data resilience runbook | FAIL | `docs/runbooks/data-resilience.md` missing |\n' >> "${REPORT_FILE}"
  failures+=("data resilience runbook missing")
fi

if [[ -x scripts/data/backup-postgres.sh && -x scripts/data/restore-postgres.sh ]]; then
  printf '| Backup and restore scripts | TERMINÉ | `scripts/data/backup-postgres.sh` and `scripts/data/restore-postgres.sh` are executable |\n' >> "${REPORT_FILE}"
else
  printf '| Backup and restore scripts | FAIL | PostgreSQL backup/restore scripts missing or not executable |\n' >> "${REPORT_FILE}"
  failures+=("backup/restore scripts missing or not executable")
  static_ready=false
fi

if [[ -s artifacts/backup/backup-report.md ]] && grep -Fq 'Status: `TERMINÉ`' artifacts/backup/backup-report.md; then
  printf '| Backup runtime proof | TERMINÉ | `artifacts/backup/backup-report.md` |\n' >> "${REPORT_FILE}"
else
  printf '| Backup runtime proof | PRÊT_NON_EXÉCUTÉ | run `scripts/data/backup-postgres.sh` against an external PostgreSQL DB |\n' >> "${REPORT_FILE}"
  runtime_ready=false
fi

if [[ -s artifacts/backup/restore-report.md ]] && grep -Fq 'Status: `TERMINÉ`' artifacts/backup/restore-report.md; then
  printf '| Restore runtime proof | TERMINÉ | `artifacts/backup/restore-report.md` |\n' >> "${REPORT_FILE}"
else
  printf '| Restore runtime proof | PRÊT_NON_EXÉCUTÉ | run `scripts/data/restore-postgres.sh` into an isolated restore database |\n' >> "${REPORT_FILE}"
  runtime_ready=false
fi

if [[ "${#failures[@]}" -eq 0 && "${static_ready}" == "true" && "${runtime_ready}" == "true" ]]; then
  status="TERMINÉ"
elif [[ "${#failures[@]}" -eq 0 && "${static_ready}" == "true" ]]; then
  status="PRÊT_NON_EXÉCUTÉ"
else
  status="FAIL"
fi

{
  printf '\n## Global status\n\n'
  printf 'Statut global: `%s`\n\n' "${status}"
  printf '## Interpretation\n\n'
  if [[ "${status}" == "TERMINÉ" ]]; then
    printf 'Production data resilience is proven with external DB overlay, backup and isolated restore evidence.\n'
  elif [[ "${status}" == "PRÊT_NON_EXÉCUTÉ" ]]; then
    printf 'Static production data resilience is ready. Runtime backup and restore still require an external PostgreSQL endpoint and credentials.\n'
  else
    printf 'Data resilience has blocking static gaps. Fix FAIL rows before presenting it as production-ready.\n'
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
