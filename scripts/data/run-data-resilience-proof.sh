#!/usr/bin/env bash

set -euo pipefail

REPORT_DIR="${REPORT_DIR:-artifacts/backup}"
SUMMARY_FILE="${SUMMARY_FILE:-${REPORT_DIR}/data-resilience-proof.md}"

mkdir -p "${REPORT_DIR}"

{
  printf '# Data Resilience Proof - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf '| Step | Status | Evidence |\n'
  printf '|---|---:|---|\n'
} > "${SUMMARY_FILE}"

if [[ -z "${DB_HOST:-}" || -z "${DB_USERNAME:-}" || -z "${DB_PASSWORD:-}" ]]; then
  {
    printf '| Production DB secret | PRÊT_NON_EXÉCUTÉ | `DB_HOST`, `DB_USERNAME`, `DB_PASSWORD` required |\n'
    printf '| Backup | PRÊT_NON_EXÉCUTÉ | PostgreSQL credentials required |\n'
    printf '| Restore | PRÊT_NON_EXÉCUTÉ | `BACKUP_FILE` and restore DB required after backup |\n'
  } >> "${SUMMARY_FILE}"
  bash scripts/validate/validate-production-data-resilience.sh >/dev/null || true
  printf '[INFO] Data resilience proof is ready but not executed. Report: %s\n' "${SUMMARY_FILE}"
  exit 0
fi

bash scripts/secrets/create-production-db-secret.sh
printf '| Production DB secret | TERMINÉ | `artifacts/security/production-db-secret.md` |\n' >> "${SUMMARY_FILE}"

bash scripts/data/backup-postgres.sh
printf '| Backup | TERMINÉ | `artifacts/backup/backup-report.md` |\n' >> "${SUMMARY_FILE}"

latest_backup="$(find artifacts/backup -type f -name '*.dump' | sort | tail -n 1)"
if [[ -z "${BACKUP_FILE:-}" && -n "${latest_backup}" ]]; then
  export BACKUP_FILE="${latest_backup}"
fi

if [[ -z "${RESTORE_DB_DATABASE:-}" ]]; then
  export RESTORE_DB_DATABASE="${DB_DATABASE:-securerag}_restore_$(date -u '+%Y%m%d%H%M%S')"
fi

bash scripts/data/restore-postgres.sh
printf '| Restore | TERMINÉ | `artifacts/backup/restore-report.md` |\n' >> "${SUMMARY_FILE}"

bash scripts/validate/validate-production-data-resilience.sh
printf '[INFO] Data resilience proof written to %s\n' "${SUMMARY_FILE}"
