#!/usr/bin/env bash

set -euo pipefail

REPORT_DIR="${REPORT_DIR:-security/reports}"
SUMMARY_FILE="${SUMMARY_FILE:-${REPORT_DIR}/dependency-audit-summary.md}"

apps=(
  platform/portal-web
  services-laravel/auth-users-service
  services-laravel/chatbot-manager-service
  services-laravel/conversation-service
  services-laravel/audit-security-service
)

mkdir -p "${REPORT_DIR}"

failures=0

slug_for() {
  printf '%s' "$1" | tr '/-' '__'
}

record() {
  printf '| `%s` | %s | `%s` |\n' "$1" "$2" "$3" >> "${SUMMARY_FILE}"
}

{
  printf '# Dependency Audit Summary - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf '| Component | Status | Evidence |\n'
  printf '|---|---:|---|\n'
} > "${SUMMARY_FILE}"

for app in "${apps[@]}"; do
  slug="$(slug_for "${app}")"

  if [[ -f "${app}/composer.lock" ]]; then
    output="${REPORT_DIR}/composer-audit-${slug}.json"
    if (cd "${app}" && composer audit --locked --format=json --no-interaction > "../../${output}"); then
      record "${app} composer" "TERMINÉ" "${output}"
    else
      record "${app} composer" "PARTIEL" "${output}"
      failures=$((failures + 1))
    fi
  else
    record "${app} composer" "PRÊT_NON_EXÉCUTÉ" "composer.lock missing"
  fi

  if [[ -f "${app}/package-lock.json" ]]; then
    output="${REPORT_DIR}/npm-audit-${slug}.json"
    if (cd "${app}" && npm audit --json > "../../${output}"); then
      record "${app} npm" "TERMINÉ" "${output}"
    else
      record "${app} npm" "PARTIEL" "${output}"
      failures=$((failures + 1))
    fi
  else
    record "${app} npm" "PRÊT_NON_EXÉCUTÉ" "package-lock.json absent"
  fi
done

if (( failures > 0 )); then
  echo "[ERROR] Dependency audit found blocking failures. See ${SUMMARY_FILE}" >&2
  exit 1
fi

echo "[INFO] Dependency audit completed. Summary: ${SUMMARY_FILE}"
