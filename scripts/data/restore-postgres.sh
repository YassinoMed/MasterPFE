#!/usr/bin/env bash

set -euo pipefail

BACKUP_FILE="${BACKUP_FILE:-}"
BACKUP_DIR="${BACKUP_DIR:-artifacts/backup}"
REPORT_FILE="${REPORT_FILE:-${BACKUP_DIR}/restore-report.md}"
DB_HOST="${DB_HOST:-}"
DB_PORT="${DB_PORT:-5432}"
DB_USERNAME="${DB_USERNAME:-}"
DB_PASSWORD="${DB_PASSWORD:-}"
DB_DATABASE="${DB_DATABASE:-}"
RESTORE_DB_DATABASE="${RESTORE_DB_DATABASE:-}"
PGSSLMODE="${DB_SSLMODE:-${PGSSLMODE:-prefer}}"
ALLOW_DESTRUCTIVE_RESTORE="${ALLOW_DESTRUCTIVE_RESTORE:-false}"
CONFIRM_DESTRUCTIVE_RESTORE="${CONFIRM_DESTRUCTIVE_RESTORE:-NO}"

info() { printf '[INFO] %s\n' "$*"; }
fail() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

is_true() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|y|Y|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

require_env() {
  [[ -n "${!1:-}" ]] || fail "Missing required environment variable: $1"
}

require_command pg_restore
require_command psql
require_command createdb
require_env BACKUP_FILE
require_env DB_HOST
require_env DB_USERNAME
require_env DB_PASSWORD
require_env RESTORE_DB_DATABASE

[[ -f "${BACKUP_FILE}" ]] || fail "Backup file not found: ${BACKUP_FILE}"

if [[ -n "${DB_DATABASE}" && "${RESTORE_DB_DATABASE}" == "${DB_DATABASE}" ]] && { ! is_true "${ALLOW_DESTRUCTIVE_RESTORE}" || [[ "${CONFIRM_DESTRUCTIVE_RESTORE}" != "YES" ]]; }; then
  fail "Refusing to restore into source DB_DATABASE=${DB_DATABASE}. Set RESTORE_DB_DATABASE to an isolated database, or use ALLOW_DESTRUCTIVE_RESTORE=true CONFIRM_DESTRUCTIVE_RESTORE=YES."
fi

mkdir -p "${BACKUP_DIR}"

export PGPASSWORD="${DB_PASSWORD}"
export PGSSLMODE

if ! psql --host="${DB_HOST}" --port="${DB_PORT}" --username="${DB_USERNAME}" --dbname=postgres \
  --tuples-only --command="SELECT 1 FROM pg_database WHERE datname='${RESTORE_DB_DATABASE}'" | grep -q 1; then
  createdb --host="${DB_HOST}" --port="${DB_PORT}" --username="${DB_USERNAME}" "${RESTORE_DB_DATABASE}"
fi

pg_restore \
  --host="${DB_HOST}" \
  --port="${DB_PORT}" \
  --username="${DB_USERNAME}" \
  --dbname="${RESTORE_DB_DATABASE}" \
  --clean \
  --if-exists \
  --no-owner \
  --no-privileges \
  "${BACKUP_FILE}"

table_count="$(psql --host="${DB_HOST}" --port="${DB_PORT}" --username="${DB_USERNAME}" --dbname="${RESTORE_DB_DATABASE}" --tuples-only --no-align --command="SELECT count(*) FROM information_schema.tables WHERE table_schema='public';" | tr -d ' ')"

{
  printf '# PostgreSQL Restore Evidence - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Backup file: `%s`\n' "${BACKUP_FILE}"
  printf -- '- Restore database: `%s`\n' "${RESTORE_DB_DATABASE}"
  printf -- '- Table count after restore: `%s`\n' "${table_count}"
  printf -- '- Destructive restore allowed: `%s`\n' "${ALLOW_DESTRUCTIVE_RESTORE}"
  printf -- '- Destructive restore confirmed: `%s`\n' "${CONFIRM_DESTRUCTIVE_RESTORE}"
  printf -- '- Status: `TERMINÉ`\n'
} > "${REPORT_FILE}"

info "Restore completed into ${RESTORE_DB_DATABASE}"
info "Restore report written to ${REPORT_FILE}"
