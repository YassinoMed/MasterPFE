#!/usr/bin/env bash

set -euo pipefail

# Read-only connectivity proof between the Blade portal and Laravel business APIs.
# The script never starts services and never mutates data; it only records what is
# reachable in the current environment.

OUT_DIR="${OUT_DIR:-artifacts/application}"
OUT_FILE="${OUT_FILE:-${OUT_DIR}/portal-service-connectivity.md}"
PORTAL_MODE="${SECURERAG_PORTAL_BACKEND_MODE:-auto}"
TIMEOUT="${SECURERAG_PORTAL_BACKEND_TIMEOUT:-2}"

PORTAL_BASE_URL="${PORTAL_BASE_URL:-http://localhost:8081}"
AUTH_USERS_BASE_URL="${AUTH_USERS_BASE_URL:-http://localhost:8091}"
CHATBOT_MANAGER_BASE_URL="${CHATBOT_MANAGER_BASE_URL:-http://localhost:8092}"
CONVERSATION_BASE_URL="${CONVERSATION_BASE_URL:-http://localhost:8093}"
AUDIT_SECURITY_BASE_URL="${AUDIT_SECURITY_BASE_URL:-http://localhost:8094}"
PORTAL_HEALTH_URL="${PORTAL_HEALTH_URL:-${PORTAL_BASE_URL%/}/health}"

mkdir -p "${OUT_DIR}"

status_for_url() {
  local url="$1"
  local http_code

  if ! command -v curl >/dev/null 2>&1; then
    printf 'curl unavailable'
    return 0
  fi

  http_code="$(curl -fsS -o /dev/null -w '%{http_code}' --max-time "${TIMEOUT}" "${url}" 2>/dev/null || true)"
  if [[ "${http_code}" == "200" ]]; then
    printf 'OK'
  elif [[ "${http_code}" == "000" || -z "${http_code}" ]]; then
    printf 'PARTIEL_UNREACHABLE'
  elif [[ -n "${http_code}" ]]; then
    printf 'PARTIEL_HTTP_%s' "${http_code}"
  else
    printf 'PARTIEL_UNREACHABLE'
  fi
}

file_status() {
  local path="$1"
  if [[ -e "${path}" ]]; then
    printf 'present'
  else
    printf 'missing'
  fi
}

{
  printf '# Portal / Service Connectivity Proof - SecureRAG Hub\n\n'
  printf -- '- Generated at: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Portal backend mode: `%s`\n' "${PORTAL_MODE}"
  printf -- '- Timeout: `%ss`\n\n' "${TIMEOUT}"

  printf '## 1. Runtime endpoints\n\n'
  printf '| Component | URL | Status |\n'
  printf '|---|---|---:|\n'
  printf '| Portal health | `%s` | %s |\n' "${PORTAL_HEALTH_URL}" "$(status_for_url "${PORTAL_HEALTH_URL}")"
  printf '| auth-users-service | `%s/api/v1/health` | %s |\n' "${AUTH_USERS_BASE_URL}" "$(status_for_url "${AUTH_USERS_BASE_URL%/}/api/v1/health")"
  printf '| chatbot-manager-service | `%s/api/v1/health` | %s |\n' "${CHATBOT_MANAGER_BASE_URL}" "$(status_for_url "${CHATBOT_MANAGER_BASE_URL%/}/api/v1/health")"
  printf '| conversation-service | `%s/api/v1/health` | %s |\n' "${CONVERSATION_BASE_URL}" "$(status_for_url "${CONVERSATION_BASE_URL%/}/api/v1/health")"
  printf '| audit-security-service | `%s/api/v1/health` | %s |\n\n' "${AUDIT_SECURITY_BASE_URL}" "$(status_for_url "${AUDIT_SECURITY_BASE_URL%/}/api/v1/health")"

  printf '## 2. Blade pages through portal\n\n'
  printf '| Page | URL | Status |\n'
  printf '|---|---|---:|\n'
  printf '| Admin users | `%s/admin/users` | %s |\n' "${PORTAL_BASE_URL}" "$(status_for_url "${PORTAL_BASE_URL%/}/admin/users")"
  printf '| Admin roles | `%s/admin/roles` | %s |\n' "${PORTAL_BASE_URL}" "$(status_for_url "${PORTAL_BASE_URL%/}/admin/roles")"
  printf '| Chatbots | `%s/chatbots` | %s |\n' "${PORTAL_BASE_URL}" "$(status_for_url "${PORTAL_BASE_URL%/}/chatbots")"
  printf '| Chat | `%s/chat` | %s |\n' "${PORTAL_BASE_URL}" "$(status_for_url "${PORTAL_BASE_URL%/}/chat")"
  printf '| History | `%s/history` | %s |\n' "${PORTAL_BASE_URL}" "$(status_for_url "${PORTAL_BASE_URL%/}/history")"
  printf '| Security | `%s/security` | %s |\n\n' "${PORTAL_BASE_URL}" "$(status_for_url "${PORTAL_BASE_URL%/}/security")"

  printf '## 3. Portal integration files\n\n'
  printf '| File | Status |\n'
  printf '|---|---:|\n'
  printf '| `platform/portal-web/app/Services/PortalBackendClient.php` | %s |\n' "$(file_status platform/portal-web/app/Services/PortalBackendClient.php)"
  printf '| `platform/portal-web/app/Support/DemoPortalData.php` | %s |\n' "$(file_status platform/portal-web/app/Support/DemoPortalData.php)"
  printf '| `platform/portal-web/config/services.php` | %s |\n' "$(file_status platform/portal-web/config/services.php)"
  printf '| `platform/portal-web/routes/web.php` | %s |\n\n' "$(file_status platform/portal-web/routes/web.php)"

  printf '## 4. Laravel service directories\n\n'
  printf '| Service | Directory | API contract |\n'
  printf '|---|---:|---:|\n'
  printf '| auth-users-service | %s | %s |\n' "$(file_status services-laravel/auth-users-service)" "$(file_status docs/openapi/auth-users-service.yaml)"
  printf '| chatbot-manager-service | %s | %s |\n' "$(file_status services-laravel/chatbot-manager-service)" "$(file_status docs/openapi/chatbot-manager-service.yaml)"
  printf '| conversation-service | %s | %s |\n' "$(file_status services-laravel/conversation-service)" "$(file_status docs/openapi/conversation-service.yaml)"
  printf '| audit-security-service | %s | %s |\n\n' "$(file_status services-laravel/audit-security-service)" "$(file_status docs/openapi/audit-security-service.yaml)"

  printf '## 5. Interpretation\n\n'
  printf -- '- `OK` means the API is reachable in the current environment.\n'
  printf -- '- `PARTIEL_UNREACHABLE` usually means the local Laravel service is not running, not that the code is missing.\n'
  printf -- '- In `auto` mode, the Blade portal can fallback to deterministic mock data when APIs are unavailable.\n'
  printf -- '- In `api` mode, API failures are intentionally surfaced to prove real integration readiness.\n'
} > "${OUT_FILE}"

printf 'Portal service connectivity proof written to %s\n' "${OUT_FILE}"
