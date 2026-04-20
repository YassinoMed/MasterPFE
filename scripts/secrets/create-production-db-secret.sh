#!/usr/bin/env bash

set -euo pipefail

NAMESPACE="${NAMESPACE:-securerag-hub}"
SECRET_NAME="${SECRET_NAME:-securerag-database-secrets}"
REPORT_DIR="${REPORT_DIR:-artifacts/security}"
REPORT_FILE="${REPORT_FILE:-${REPORT_DIR}/production-db-secret.md}"
DRY_RUN="${DRY_RUN:-false}"

DB_CONNECTION="${DB_CONNECTION:-pgsql}"
DB_HOST="${DB_HOST:-}"
DB_PORT="${DB_PORT:-5432}"
DB_USERNAME="${DB_USERNAME:-}"
DB_PASSWORD="${DB_PASSWORD:-}"
DB_SSLMODE="${DB_SSLMODE:-require}"
PORTAL_WEB_DB_DATABASE="${PORTAL_WEB_DB_DATABASE:-portal_web}"
AUTH_USERS_DB_DATABASE="${AUTH_USERS_DB_DATABASE:-auth_users}"
CHATBOT_MANAGER_DB_DATABASE="${CHATBOT_MANAGER_DB_DATABASE:-chatbot_manager}"
CONVERSATION_SERVICE_DB_DATABASE="${CONVERSATION_SERVICE_DB_DATABASE:-conversation_service}"
AUDIT_SECURITY_SERVICE_DB_DATABASE="${AUDIT_SECURITY_SERVICE_DB_DATABASE:-audit_security}"

info() { printf '[INFO] %s\n' "$*"; }
error() { printf '[ERROR] %s\n' "$*" >&2; }

require_command() {
  command -v "$1" >/dev/null 2>&1 || { error "Missing required command: $1"; exit 2; }
}

require_env() {
  local name="$1"
  local value="${!name:-}"
  if [[ -z "${value}" ]]; then
    error "Missing required environment variable: ${name}"
    exit 1
  fi
}

is_true() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|y|Y|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

require_command kubectl
require_env DB_HOST
require_env DB_USERNAME
require_env DB_PASSWORD

export DB_CONNECTION DB_HOST DB_PORT DB_USERNAME DB_PASSWORD DB_SSLMODE
export PORTAL_WEB_DB_DATABASE AUTH_USERS_DB_DATABASE CHATBOT_MANAGER_DB_DATABASE
export CONVERSATION_SERVICE_DB_DATABASE AUDIT_SECURITY_SERVICE_DB_DATABASE

python3 - <<'PY'
import os
import re

weak = {"", "change-me", "changeme", "password", "password123", "admin", "secret", "default"}
required = ["DB_HOST", "DB_USERNAME", "DB_PASSWORD"]
for key in required:
    value = os.environ.get(key, "")
    if value.strip() == "":
        raise SystemExit(f"{key} is empty")
    if value.lower() in weak:
        raise SystemExit(f"{key} uses a refused placeholder or weak value")

password = os.environ["DB_PASSWORD"]
if len(password) < 20:
    raise SystemExit("DB_PASSWORD must be at least 20 characters for production-like use")

for key in [
    "PORTAL_WEB_DB_DATABASE",
    "AUTH_USERS_DB_DATABASE",
    "CHATBOT_MANAGER_DB_DATABASE",
    "CONVERSATION_SERVICE_DB_DATABASE",
    "AUDIT_SECURITY_SERVICE_DB_DATABASE",
]:
    value = os.environ.get(key, "")
    if not re.fullmatch(r"[A-Za-z0-9_][A-Za-z0-9_-]{1,62}", value):
        raise SystemExit(f"{key} has an unsafe database identifier")

if os.environ.get("DB_CONNECTION", "pgsql") != "pgsql":
    raise SystemExit("DB_CONNECTION must be pgsql for the production-external-db overlay")
PY

mkdir -p "${REPORT_DIR}"

secret_env_file="$(mktemp)"
trap 'rm -f "${secret_env_file}"' EXIT
chmod 600 "${secret_env_file}"

cat > "${secret_env_file}" <<EOF
DB_CONNECTION=${DB_CONNECTION}
DB_HOST=${DB_HOST}
DB_PORT=${DB_PORT}
DB_USERNAME=${DB_USERNAME}
DB_PASSWORD=${DB_PASSWORD}
DB_SSLMODE=${DB_SSLMODE}
PORTAL_WEB_DB_DATABASE=${PORTAL_WEB_DB_DATABASE}
AUTH_USERS_DB_DATABASE=${AUTH_USERS_DB_DATABASE}
CHATBOT_MANAGER_DB_DATABASE=${CHATBOT_MANAGER_DB_DATABASE}
CONVERSATION_SERVICE_DB_DATABASE=${CONVERSATION_SERVICE_DB_DATABASE}
AUDIT_SECURITY_SERVICE_DB_DATABASE=${AUDIT_SECURITY_SERVICE_DB_DATABASE}
EOF

if is_true "${DRY_RUN}"; then
  kubectl create secret generic "${SECRET_NAME}" \
    --namespace "${NAMESPACE}" \
    --from-env-file="${secret_env_file}" \
    --dry-run=client -o yaml >/dev/null
  status="PRÊT_NON_EXÉCUTÉ"
  action="client dry-run only; no secret applied"
else
  kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
  kubectl create secret generic "${SECRET_NAME}" \
    --namespace "${NAMESPACE}" \
    --from-env-file="${secret_env_file}" \
    --dry-run=client -o yaml | kubectl apply -f -
  status="TERMINÉ"
  action="secret applied to namespace ${NAMESPACE}"
fi

{
  printf '# Production DB Secret Evidence - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Namespace: `%s`\n' "${NAMESPACE}"
  printf -- '- Secret: `%s`\n' "${SECRET_NAME}"
  printf -- '- Status: `%s`\n\n' "${status}"
  printf '| Key | Evidence |\n'
  printf '|---|---|\n'
  printf '| DB_CONNECTION | `pgsql` |\n'
  printf '| DB_HOST | configured, value redacted |\n'
  printf '| DB_PORT | `%s` |\n' "${DB_PORT}"
  printf '| DB_USERNAME | configured, value redacted |\n'
  printf '| DB_PASSWORD | configured, value redacted, length >= 20 |\n'
  printf '| DB_SSLMODE | `%s` |\n' "${DB_SSLMODE}"
  printf '| Service databases | `portal_web`, `auth_users`, `chatbot_manager`, `conversation_service`, `audit_security` by default or explicit env overrides |\n'
  printf '\n## Action\n\n%s.\n' "${action}"
  printf '\n## Security note\n\nNo secret value is written to this report. The temporary env file is mode 600 and removed after execution.\n'
} > "${REPORT_FILE}"

info "Production DB secret report written to ${REPORT_FILE}"
