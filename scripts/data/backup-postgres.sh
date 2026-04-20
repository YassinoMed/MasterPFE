#!/usr/bin/env bash

set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-artifacts/backup}"
SERVICE_NAME="${SERVICE_NAME:-securerag}"
DB_HOST="${DB_HOST:-}"
DB_PORT="${DB_PORT:-5432}"
DB_USERNAME="${DB_USERNAME:-}"
DB_PASSWORD="${DB_PASSWORD:-}"
DB_DATABASE="${DB_DATABASE:-}"
PGSSLMODE="${DB_SSLMODE:-${PGSSLMODE:-prefer}}"
STAMP="$(date -u '+%Y%m%dT%H%M%SZ')"
BACKUP_FILE="${BACKUP_FILE:-${BACKUP_DIR}/${SERVICE_NAME}-${DB_DATABASE:-database}-${STAMP}.dump}"
REPORT_FILE="${REPORT_FILE:-${BACKUP_DIR}/backup-report.md}"

info() { printf '[INFO] %s\n' "$*"; }
fail() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

require_env() {
  [[ -n "${!1:-}" ]] || fail "Missing required environment variable: $1"
}

require_command pg_dump
require_env DB_HOST
require_env DB_USERNAME
require_env DB_PASSWORD
require_env DB_DATABASE

mkdir -p "${BACKUP_DIR}"

export PGPASSWORD="${DB_PASSWORD}"
export PGSSLMODE

pg_dump \
  --host="${DB_HOST}" \
  --port="${DB_PORT}" \
  --username="${DB_USERNAME}" \
  --dbname="${DB_DATABASE}" \
  --format=custom \
  --no-owner \
  --no-privileges \
  --file="${BACKUP_FILE}"

if command -v sha256sum >/dev/null 2>&1; then
  checksum="$(sha256sum "${BACKUP_FILE}" | awk '{print $1}')"
elif command -v shasum >/dev/null 2>&1; then
  checksum="$(shasum -a 256 "${BACKUP_FILE}" | awk '{print $1}')"
else
  checksum="unavailable"
fi

printf '%s  %s\n' "${checksum}" "${BACKUP_FILE}" >> "${BACKUP_DIR}/checksums.txt"

{
  printf '# PostgreSQL Backup Evidence - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Service: `%s`\n' "${SERVICE_NAME}"
  printf -- '- Database host: `%s`\n' "${DB_HOST}"
  printf -- '- Database name: `%s`\n' "${DB_DATABASE}"
  printf -- '- Backup file: `%s`\n' "${BACKUP_FILE}"
  printf -- '- SHA256: `%s`\n' "${checksum}"
  printf -- '- Status: `TERMINÉ`\n'
} > "${REPORT_FILE}"

info "Backup written to ${BACKUP_FILE}"
info "Backup report written to ${REPORT_FILE}"
