#!/usr/bin/env bash

set -euo pipefail

TEMPLATE_FILE="${TEMPLATE_FILE:-infra/secrets/production/securerag-database-secrets.template.yaml}"
ENCRYPTED_SECRET_FILE="${ENCRYPTED_SECRET_FILE:-infra/secrets/production/securerag-database-secrets.enc.yaml}"
REPORT_FILE="${REPORT_FILE:-artifacts/security/secret-rotation-proof.md}"
ROTATE_SOPS_SECRET="${ROTATE_SOPS_SECRET:-false}"
APPLY_ROTATED_SECRET="${APPLY_ROTATED_SECRET:-false}"
DB_PORT="${DB_PORT:-5432}"
DB_SSLMODE="${DB_SSLMODE:-require}"

is_true() { case "${1:-}" in 1|true|TRUE|yes|YES|on|ON) return 0 ;; *) return 1 ;; esac; }
info() { printf '[INFO] %s\n' "$*"; }

mkdir -p "$(dirname "${REPORT_FILE}")"

write_report() {
  local status="$1"
  local detail="$2"
  {
    printf '# SOPS Secret Rotation Proof - SecureRAG Hub\n\n'
    printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf -- '- Status: `%s`\n' "${status}"
    printf -- '- Encrypted secret file: `%s`\n' "${ENCRYPTED_SECRET_FILE}"
    printf -- '- Apply rotated secret: `%s`\n\n' "${APPLY_ROTATED_SECRET}"
    printf '## Detail\n\n%s\n\n' "${detail}"
    printf 'No secret value is written to this report.\n'
  } > "${REPORT_FILE}"
}

if ! is_true "${ROTATE_SOPS_SECRET}"; then
  write_report "PRÊT_NON_EXÉCUTÉ" "Rotation is disabled by default. Re-run with `ROTATE_SOPS_SECRET=true`, `SOPS_AGE_RECIPIENT`, `DB_HOST` and `DB_USERNAME`."
  info "Secret rotation report written to ${REPORT_FILE}"
  exit 0
fi

for command_name in sops openssl python3; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    write_report "DÉPENDANT_DE_L_ENVIRONNEMENT" "Missing required command: `${command_name}`."
    info "Secret rotation report written to ${REPORT_FILE}"
    exit 0
  fi
done

if [[ -z "${SOPS_AGE_RECIPIENT:-}" || -z "${DB_HOST:-}" || -z "${DB_USERNAME:-}" ]]; then
  write_report "PRÊT_NON_EXÉCUTÉ" "Required inputs are missing. Provide `SOPS_AGE_RECIPIENT`, `DB_HOST` and `DB_USERNAME`. `DB_PASSWORD` is optional and generated when absent."
  info "Secret rotation report written to ${REPORT_FILE}"
  exit 0
fi

[[ -s "${TEMPLATE_FILE}" ]] || {
  write_report "PARTIEL" "Template file is missing: `${TEMPLATE_FILE}`."
  info "Secret rotation report written to ${REPORT_FILE}"
  exit 0
}

generated_password="${DB_PASSWORD:-$(openssl rand -base64 30 | tr -d '\n')}"
if [[ "${#generated_password}" -lt 20 ]]; then
  write_report "PARTIEL" "Provided DB_PASSWORD is shorter than 20 characters."
  info "Secret rotation report written to ${REPORT_FILE}"
  exit 0
fi

export DB_HOST DB_USERNAME ROTATED_DB_PASSWORD="${generated_password}" DB_PORT DB_SSLMODE

plain_file="$(mktemp)"
trap 'rm -f "${plain_file}"' EXIT
python3 - "${TEMPLATE_FILE}" "${plain_file}" <<'PY'
import json
import os
import sys

src, dst = sys.argv[1:]
mapping = {
    "DB_HOST": os.environ["DB_HOST"],
    "DB_PORT": os.environ.get("DB_PORT", "5432"),
    "DB_USERNAME": os.environ["DB_USERNAME"],
    "DB_PASSWORD": os.environ["ROTATED_DB_PASSWORD"],
    "DB_SSLMODE": os.environ.get("DB_SSLMODE", "require"),
    "PORTAL_WEB_DB_DATABASE": os.environ.get("PORTAL_WEB_DB_DATABASE", "portal_web"),
    "AUTH_USERS_DB_DATABASE": os.environ.get("AUTH_USERS_DB_DATABASE", "auth_users"),
    "CHATBOT_MANAGER_DB_DATABASE": os.environ.get("CHATBOT_MANAGER_DB_DATABASE", "chatbot_manager"),
    "CONVERSATION_SERVICE_DB_DATABASE": os.environ.get("CONVERSATION_SERVICE_DB_DATABASE", "conversation_service"),
    "AUDIT_SECURITY_SERVICE_DB_DATABASE": os.environ.get("AUDIT_SECURITY_SERVICE_DB_DATABASE", "audit_security"),
}

with open(src, encoding="utf-8") as handle:
    lines = handle.readlines()

with open(dst, "w", encoding="utf-8") as handle:
    for line in lines:
        stripped = line.lstrip()
        replaced = False
        for key, value in mapping.items():
            if stripped.startswith(f"{key}:"):
                indent = line[: len(line) - len(stripped)]
                handle.write(f"{indent}{key}: {json.dumps(value)}\n")
                replaced = True
                break
        if not replaced:
            handle.write(line)
PY

ROTATED_DB_PASSWORD="${generated_password}" \
  sops --encrypt --age "${SOPS_AGE_RECIPIENT}" "${plain_file}" > "${ENCRYPTED_SECRET_FILE}"

if is_true "${APPLY_ROTATED_SECRET}"; then
  ENCRYPTED_SECRET_FILE="${ENCRYPTED_SECRET_FILE}" DRY_RUN=false bash scripts/secrets/apply-sops-production-db-secret.sh >/dev/null
  status="TERMINÉ"
  detail="SOPS-encrypted Secret was rotated and applied to the target cluster."
else
  status="PRÊT_NON_EXÉCUTÉ"
  detail="SOPS-encrypted Secret was rotated locally but not applied. Re-run with `APPLY_ROTATED_SECRET=true` after review."
fi

write_report "${status}" "${detail}"
info "Secret rotation report written to ${REPORT_FILE}"
