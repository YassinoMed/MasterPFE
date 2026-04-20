#!/usr/bin/env bash

set -euo pipefail

REPORT_DIR="${REPORT_DIR:-artifacts/security}"
REPORT_FILE="${REPORT_FILE:-${REPORT_DIR}/production-dockerfiles.md}"
STRICT_DOCKERFILES="${STRICT_DOCKERFILES:-true}"

apps=(
  "platform/portal-web"
  "services-laravel/auth-users-service"
  "services-laravel/chatbot-manager-service"
  "services-laravel/conversation-service"
  "services-laravel/audit-security-service"
)

mkdir -p "${REPORT_DIR}"

failures=()

row() {
  local component="$1"
  local control="$2"
  local status="$3"
  local evidence="$4"
  printf '| `%s` | %s | %s | `%s` |\n' "${component}" "${control}" "${status}" "${evidence}" >> "${REPORT_FILE}"
  if [[ "${status}" == "FAIL" ]]; then
    failures+=("${component}: ${control} -- ${evidence}")
  fi
}

{
  printf '# Production Dockerfiles - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Strict mode: `%s`\n\n' "${STRICT_DOCKERFILES}"
  printf '| Component | Control | Status | Evidence |\n'
  printf '|---|---|---:|---|\n'
} > "${REPORT_FILE}"

for app in "${apps[@]}"; do
  dockerfile="${app}/Dockerfile"

  if [[ ! -s "${dockerfile}" ]]; then
    row "${app}" "Dockerfile present" "FAIL" "${dockerfile} missing"
    continue
  fi

  row "${app}" "Dockerfile present" "TERMINÉ" "${dockerfile}"

  if awk '/^FROM / && $2 !~ /@sha256:[0-9a-f]{64}/ {bad=1} END {exit bad ? 0 : 1}' "${dockerfile}"; then
    row "${app}" "Pinned base images" "FAIL" "one or more FROM lines are not pinned by sha256 digest"
  else
    row "${app}" "Pinned base images" "TERMINÉ" "all FROM lines include sha256 digests"
  fi

  if grep -Eq 'composer install .*--no-dev|composer install --no-dev' "${dockerfile}"; then
    row "${app}" "Composer production install" "TERMINÉ" "--no-dev present"
  else
    row "${app}" "Composer production install" "FAIL" "--no-dev missing"
  fi

  if grep -Eq 'apt-get install .*\b(git|default-mysql-client|postgresql-client)\b' "${dockerfile}"; then
    row "${app}" "No unnecessary runtime CLIs" "FAIL" "git/default-mysql-client/postgresql-client still installed"
  else
    row "${app}" "No unnecessary runtime CLIs" "TERMINÉ" "git and DB clients absent from apt install"
  fi

  if grep -Fq 'docker-php-ext-install pdo_sqlite pdo_mysql pdo_pgsql intl' "${dockerfile}"; then
    row "${app}" "Database driver compatibility" "TERMINÉ" "pdo_sqlite, pdo_mysql, pdo_pgsql and intl installed"
  else
    row "${app}" "Database driver compatibility" "FAIL" "required PHP extensions missing"
  fi

  if grep -Fq 'rm -rf /var/lib/apt/lists/*' "${dockerfile}"; then
    row "${app}" "APT cache cleanup" "TERMINÉ" "apt lists removed"
  else
    row "${app}" "APT cache cleanup" "FAIL" "apt lists cleanup missing"
  fi

  if grep -Fq 'USER 10001:10001' "${dockerfile}"; then
    row "${app}" "Non-root runtime user" "TERMINÉ" "USER 10001:10001"
  else
    row "${app}" "Non-root runtime user" "FAIL" "runtime user not pinned to non-root uid/gid"
  fi
done

{
  printf '\n## Global status\n\n'
  if [[ "${#failures[@]}" -eq 0 ]]; then
    printf 'Statut global: `TERMINÉ`\n\n'
    printf 'Production Dockerfiles install Laravel dependencies without Composer dev packages, keep DB driver compatibility, remove unnecessary runtime CLIs, clean APT metadata and run as non-root.\n'
  else
    printf 'Statut global: `FAIL`\n\n'
    printf 'Blocking Dockerfile gaps:\n'
    for failure in "${failures[@]}"; do
      printf -- '- %s\n' "${failure}"
    done
  fi
} >> "${REPORT_FILE}"

if [[ "${#failures[@]}" -gt 0 && "${STRICT_DOCKERFILES}" == "true" ]]; then
  printf '[ERROR] Production Dockerfile validation failed. Report: %s\n' "${REPORT_FILE}" >&2
  exit 1
fi

printf '[INFO] Production Dockerfile report written to %s\n' "${REPORT_FILE}"
