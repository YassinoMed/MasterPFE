#!/usr/bin/env bash

set -euo pipefail

NAMESPACE="${NAMESPACE:-securerag-hub}"
SECRET_NAME="${SECRET_NAME:-securerag-database-secrets}"
ENCRYPTED_SECRET_FILE="${ENCRYPTED_SECRET_FILE:-infra/secrets/production/securerag-database-secrets.enc.yaml}"
REPORT_DIR="${REPORT_DIR:-artifacts/security}"
REPORT_FILE="${REPORT_FILE:-${REPORT_DIR}/sops-production-db-secret.md}"
DRY_RUN="${DRY_RUN:-false}"

info() { printf '[INFO] %s\n' "$*"; }
error() { printf '[ERROR] %s\n' "$*" >&2; }

require_command() {
  command -v "$1" >/dev/null 2>&1 || { error "Missing required command: $1"; exit 2; }
}

is_true() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|y|Y|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

require_command sops
require_command kubectl
require_command python3

[[ -s "${ENCRYPTED_SECRET_FILE}" ]] || { error "Encrypted SOPS file not found: ${ENCRYPTED_SECRET_FILE}"; exit 1; }

mkdir -p "${REPORT_DIR}"

decrypted_file="$(mktemp)"
trap 'rm -f "${decrypted_file}"' EXIT

sops --decrypt "${ENCRYPTED_SECRET_FILE}" > "${decrypted_file}"

python3 - "${decrypted_file}" "${SECRET_NAME}" "${NAMESPACE}" <<'PY'
import sys
import yaml

path, expected_name, expected_ns = sys.argv[1:]
with open(path, encoding="utf-8") as handle:
    payload = yaml.safe_load(handle)

if payload.get("kind") != "Secret":
    raise SystemExit("decrypted manifest is not a Kubernetes Secret")

metadata = payload.get("metadata") or {}
if metadata.get("name") != expected_name:
    raise SystemExit(f"Secret name {metadata.get('name')!r} does not match expected {expected_name!r}")

namespace = metadata.get("namespace")
if namespace and namespace != expected_ns:
    raise SystemExit(f"Secret namespace {namespace!r} does not match expected {expected_ns!r}")

required = {
    "DB_CONNECTION",
    "DB_HOST",
    "DB_PORT",
    "DB_USERNAME",
    "DB_PASSWORD",
    "DB_SSLMODE",
    "PORTAL_WEB_DB_DATABASE",
    "AUTH_USERS_DB_DATABASE",
    "CHATBOT_MANAGER_DB_DATABASE",
    "CONVERSATION_SERVICE_DB_DATABASE",
    "AUDIT_SECURITY_SERVICE_DB_DATABASE",
}
string_data = payload.get("stringData") or {}
missing = sorted(required - set(string_data))
if missing:
    raise SystemExit(f"missing keys in stringData: {', '.join(missing)}")

for key, value in string_data.items():
    if isinstance(value, str) and "change-me" in value.lower():
        raise SystemExit(f"{key} still contains a placeholder value")

if string_data.get("DB_CONNECTION") != "pgsql":
    raise SystemExit("DB_CONNECTION must be pgsql")

if len(str(string_data.get("DB_PASSWORD", ""))) < 20:
    raise SystemExit("DB_PASSWORD must be at least 20 characters")
PY

if is_true "${DRY_RUN}"; then
  kubectl apply --dry-run=client -f "${decrypted_file}" >/dev/null
  status="PRÊT_NON_EXÉCUTÉ"
  action="client dry-run only; decrypted Secret validated but not applied"
else
  kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  kubectl apply -f "${decrypted_file}" >/dev/null
  status="TERMINÉ"
  action="decrypted SOPS Secret applied on the target cluster"
fi

{
  printf '# SOPS Production DB Secret Evidence - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Namespace: `%s`\n' "${NAMESPACE}"
  printf -- '- Secret: `%s`\n' "${SECRET_NAME}"
  printf -- '- Source file: `%s`\n' "${ENCRYPTED_SECRET_FILE}"
  printf -- '- Status: `%s`\n\n' "${status}"
  printf '## Validation\n\n'
  printf '- manifest decrypted successfully with `sops`;\n'
  printf '- kind/name/namespace validated;\n'
  printf '- required PostgreSQL keys present;\n'
  printf '- no placeholder value persisted;\n'
  printf '- no secret value is written to this report.\n\n'
  printf '## Action\n\n%s.\n' "${action}"
} > "${REPORT_FILE}"

info "SOPS production DB secret report written to ${REPORT_FILE}"
