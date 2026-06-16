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

  npm_app_dirs="${app}/node_modules"
  if [[ ! -d "${app}/node_modules" ]] && [[ -f "${app}/package.json" ]]; then
    echo "[INFO] Installing npm dependencies for ${app} (required for audit)"
    (cd "${app}" && npm install --no-fund --no-audit --ignore-scripts)
  fi

  if [[ -f "${app}/package-lock.json" ]]; then
    output="${REPORT_DIR}/npm-audit-${slug}.json"
    # Audit production dependencies (blocking)
    if (cd "${app}" && npm audit --production --json > "../../${output}" 2>/dev/null) && \
       (cd "${app}" && npm audit --production --audit-level=critical 2>/dev/null); then
      record "${app} npm (prod)" "TERMINÉ" "${output}"
    else
      record "${app} npm (prod)" "PARTIEL" "${output}"
      failures=$((failures + 1))
    fi
    # Full audit for reporting (non-blocking)
    (cd "${app}" && npm audit --json > "../../${REPORT_DIR}/npm-audit-full-${slug}.json" 2>/dev/null) || true
  else
    record "${app} npm" "PRÊT_NON_EXÉCUTÉ" "package-lock.json absent"
  fi
done

if (( failures > 0 )); then
  echo "[FAIL] Dependency audit found vulnerabilities in ${failures} component(s). See ${SUMMARY_FILE}" >&2
  exit 1
fi
echo "[INFO] Dependency audit completed successfully. Summary: ${SUMMARY_FILE}"
exit 0
