#!/usr/bin/env bash

set -euo pipefail

SONAR_FILE="${SONAR_FILE:-sonar-project.properties}"
REPORT_DIR="${REPORT_DIR:-artifacts/security}"
REPORT_FILE="${REPORT_FILE:-${REPORT_DIR}/sonar-cpd-scope.md}"

required_patterns=(
  "**/config/**"
  "services-laravel/*/config/*.php"
  "platform/portal-web/config/*.php"
  "**/database/migrations/0001_01_01_*.php"
  "services-laravel/*/database/migrations/0001_01_01_*.php"
  "platform/portal-web/database/migrations/0001_01_01_*.php"
  "services-laravel/auth-users-service/database/migrations/2026_04_11_000003_create_permission_role_table.php"
  "services-laravel/auth-users-service/database/migrations/2026_04_11_000004_create_role_user_table.php"
  "**/database/factories/UserFactory.php"
  "services-laravel/*/database/factories/UserFactory.php"
  "platform/portal-web/database/factories/UserFactory.php"
  "services-laravel/*/tests/Feature/AuthorizationSecurityTest.php"
  "platform/portal-web/app/Support/DemoPortalData.php"
)

if [[ ! -f "${SONAR_FILE}" ]]; then
  echo "[ERROR] ${SONAR_FILE} not found" >&2
  exit 1
fi

mkdir -p "${REPORT_DIR}"

missing=()
for pattern in "${required_patterns[@]}"; do
  if ! grep -Fq "${pattern}" "${SONAR_FILE}"; then
    missing+=("${pattern}")
  fi
done

{
  printf '# Sonar CPD Scope Validation - SecureRAG Hub\n\n'
  printf '| Pattern | Status |\n'
  printf '|---|---:|\n'
  for pattern in "${required_patterns[@]}"; do
    if grep -Fq "${pattern}" "${SONAR_FILE}"; then
      printf '| `%s` | TERMINÉ |\n' "${pattern}"
    else
      printf '| `%s` | MANQUANT |\n' "${pattern}"
    fi
  done
  printf '\n## Interpretation\n\n'
  if [[ "${#missing[@]}" -eq 0 ]]; then
    printf 'Statut global: TERMINÉ. Les fichiers Laravel générés ou déclaratifs restent analysés par Sonar, mais exclus du calcul CPD.\n'
  else
    printf 'Statut global: FAIL. Les patterns CPD manquants peuvent faire remonter du bruit de duplication Sonar.\n'
  fi
} > "${REPORT_FILE}"

if [[ "${#missing[@]}" -gt 0 ]]; then
  printf '[ERROR] Missing Sonar CPD exclusion patterns:\n' >&2
  printf ' - %s\n' "${missing[@]}" >&2
  printf '[ERROR] Report: %s\n' "${REPORT_FILE}" >&2
  exit 1
fi

printf '[INFO] Sonar CPD scope validation passed. Report: %s\n' "${REPORT_FILE}"
