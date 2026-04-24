#!/usr/bin/env bash

set -euo pipefail

REPORT_DIR="${REPORT_DIR:-artifacts/backup}"
SUMMARY_FILE="${SUMMARY_FILE:-${REPORT_DIR}/data-resilience-proof.md}"
BACKUP_TARGET_SERVICE="${BACKUP_TARGET_SERVICE:-portal-web}"

mkdir -p "${REPORT_DIR}"

infer_db_database() {
  local service="$1"
  case "${service}" in
    portal-web) printf '%s' "${PORTAL_WEB_DB_DATABASE:-}" ;;
    auth-users) printf '%s' "${AUTH_USERS_DB_DATABASE:-}" ;;
    chatbot-manager) printf '%s' "${CHATBOT_MANAGER_DB_DATABASE:-}" ;;
    conversation-service) printf '%s' "${CONVERSATION_SERVICE_DB_DATABASE:-}" ;;
    audit-security-service) printf '%s' "${AUDIT_SECURITY_SERVICE_DB_DATABASE:-}" ;;
    *) printf '' ;;
  esac
}

set_summary_status() {
  local status="$1"
  python3 - "${SUMMARY_FILE}" "${status}" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
status = sys.argv[2]
content = path.read_text(encoding="utf-8")
path.write_text(content.replace("- Status: `PENDING`", f"- Status: `{status}`", 1), encoding="utf-8")
PY
}

{
  printf '# Data Resilience Proof - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Status: `PENDING`\n\n'
  printf '| Step | Status | Evidence |\n'
  printf '|---|---:|---|\n'
} > "${SUMMARY_FILE}"

if [[ -z "${DB_DATABASE:-}" ]]; then
  inferred_db="$(infer_db_database "${BACKUP_TARGET_SERVICE}")"
  if [[ -n "${inferred_db}" ]]; then
    export DB_DATABASE="${inferred_db}"
  fi
fi

if [[ -z "${DB_HOST:-}" || -z "${DB_USERNAME:-}" || -z "${DB_PASSWORD:-}" || -z "${DB_DATABASE:-}" ]]; then
  {
    printf '| Production DB secret | PRÊT_NON_EXÉCUTÉ | `DB_HOST`, `DB_USERNAME`, `DB_PASSWORD` required |\n'
    printf '| Backup | PRÊT_NON_EXÉCUTÉ | PostgreSQL credentials and `DB_DATABASE` or `BACKUP_TARGET_SERVICE` required |\n'
    printf '| Restore | PRÊT_NON_EXÉCUTÉ | `BACKUP_FILE` and restore DB required after backup |\n'
  } >> "${SUMMARY_FILE}"
  bash scripts/validate/validate-production-data-resilience.sh >/dev/null || true
  set_summary_status "PRÊT_NON_EXÉCUTÉ"
  printf '[INFO] Data resilience proof is ready but not executed. Report: %s\n' "${SUMMARY_FILE}"
  exit 0
fi

missing_tools=()
for tool in pg_dump pg_restore psql createdb; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    missing_tools+=("${tool}")
  fi
done

if ((${#missing_tools[@]} > 0)); then
  {
    printf '| Production DB secret | PRÊT_NON_EXÉCUTÉ | backup/restore preflight stopped before mutation |\n'
    printf '| Backup | DÉPENDANT_DE_L_ENVIRONNEMENT | missing commands: `%s` |\n' "${missing_tools[*]}"
    printf '| Restore | DÉPENDANT_DE_L_ENVIRONNEMENT | missing commands: `%s` |\n' "${missing_tools[*]}"
  } >> "${SUMMARY_FILE}"
  bash scripts/validate/validate-production-data-resilience.sh >/dev/null || true
  set_summary_status "DÉPENDANT_DE_L_ENVIRONNEMENT"
  printf '[INFO] Data resilience proof is environment-dependent. Missing commands: %s\n' "${missing_tools[*]}"
  exit 0
fi

if bash scripts/secrets/create-production-db-secret.sh; then
  printf '| Production DB secret | TERMINÉ | `artifacts/security/production-db-secret.md` |\n' >> "${SUMMARY_FILE}"
else
  printf '| Production DB secret | PARTIEL | `scripts/secrets/create-production-db-secret.sh` failed |\n' >> "${SUMMARY_FILE}"
  bash scripts/validate/validate-production-data-resilience.sh >/dev/null || true
  set_summary_status "PARTIEL"
  printf '[WARN] Production DB secret step failed. Report: %s\n' "${SUMMARY_FILE}" >&2
  exit 0
fi

if bash scripts/data/backup-postgres.sh; then
  printf '| Backup | TERMINÉ | `artifacts/backup/backup-report.md` |\n' >> "${SUMMARY_FILE}"
else
  printf '| Backup | PARTIEL | `scripts/data/backup-postgres.sh` failed |\n' >> "${SUMMARY_FILE}"
  bash scripts/validate/validate-production-data-resilience.sh >/dev/null || true
  set_summary_status "PARTIEL"
  printf '[WARN] Backup step failed. Report: %s\n' "${SUMMARY_FILE}" >&2
  exit 0
fi

latest_backup="$(find artifacts/backup -type f -name '*.dump' | sort | tail -n 1)"
if [[ -z "${BACKUP_FILE:-}" && -n "${latest_backup}" ]]; then
  export BACKUP_FILE="${latest_backup}"
fi

if [[ -z "${RESTORE_DB_DATABASE:-}" ]]; then
  export RESTORE_DB_DATABASE="${DB_DATABASE:-securerag}_restore_$(date -u '+%Y%m%d%H%M%S')"
fi

if bash scripts/data/restore-postgres.sh; then
  printf '| Restore | TERMINÉ | `artifacts/backup/restore-report.md` |\n' >> "${SUMMARY_FILE}"
else
  printf '| Restore | PARTIEL | `scripts/data/restore-postgres.sh` failed |\n' >> "${SUMMARY_FILE}"
  bash scripts/validate/validate-production-data-resilience.sh >/dev/null || true
  set_summary_status "PARTIEL"
  printf '[WARN] Restore step failed. Report: %s\n' "${SUMMARY_FILE}" >&2
  exit 0
fi

bash scripts/validate/validate-production-data-resilience.sh
set_summary_status "TERMINÉ"
printf '[INFO] Data resilience proof written to %s\n' "${SUMMARY_FILE}"
