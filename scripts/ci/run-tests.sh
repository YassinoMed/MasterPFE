#!/usr/bin/env bash
# run-tests.sh — SecureRAG Hub
# Exécute les tests Laravel pour les 5 applications et collecte les rapports
# JUnit + Clover. Échoue si le driver de couverture est absent.
#
# Prérequis : Xdebug ou PCOV installé et activé (mode coverage).
# Sorties :
#   .coverage-artifacts/junit-*.xml     (JUnit par application)
#   .coverage-artifacts/coverage-*.xml  (Clover par application)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ARTIFACT_DIR="${REPO_ROOT}/.coverage-artifacts"

mkdir -p "${ARTIFACT_DIR}"
rm -f "${ARTIFACT_DIR}"/junit-*.xml "${ARTIFACT_DIR}"/junit.xml "${ARTIFACT_DIR}"/coverage-*.xml "${ARTIFACT_DIR}"/coverage.xml "${ARTIFACT_DIR}"/coverage-summary.txt

apps=(
  platform/portal-web
  services-laravel/auth-users-service
  services-laravel/chatbot-manager-service
  services-laravel/conversation-service
  services-laravel/audit-security-service
)

summary="${ARTIFACT_DIR}/laravel-test-summary.txt"
: > "${summary}"

ALLOW_NO_COVERAGE="${ALLOW_NO_COVERAGE:-false}"

# ── 1. Vérification OBLIGATOIRE du driver de couverture ────────────────

coverage_driver_available=false
if php -m 2>/dev/null | grep -qiE '^(xdebug|pcov)$'; then
  coverage_driver_available=true
  echo "[INFO] Coverage driver detected: $(php -m 2>/dev/null | grep -iE '^(xdebug|pcov)$' | head -1)" | tee -a "${summary}"
elif [ "${ALLOW_NO_COVERAGE}" = "true" ]; then
  echo "[WARN] No coverage driver detected, but ALLOW_NO_COVERAGE=true. Proceeding without coverage." | tee -a "${summary}"
else
  echo "[FATAL] No coverage driver (Xdebug or PCOV) detected." | tee -a "${summary}"
  echo "[FATAL] Install php-xdebug or php-pcov and configure: xdebug.mode=coverage" | tee -a "${summary}"
  exit 1
fi

# Afficher la version du driver
php --ri xdebug 2>/dev/null | head -3 | tee -a "${summary}" || php --ri pcov 2>/dev/null | head -3 | tee -a "${summary}" || true

# ── 2. Exécuter les tests pour chaque application ───────────────────────

total_failures=0

for app in "${apps[@]}"; do
  if [[ ! -f "${REPO_ROOT}/${app}/artisan" ]]; then
    echo "[FAIL] Missing Laravel artisan entrypoint: ${app}" | tee -a "${summary}"
    exit 1
  fi

  report_name="$(printf '%s' "${app}" | tr '/-' '__')"
  echo "[INFO] Running Laravel tests for ${app}" | tee -a "${summary}"

  set +e
  (
    cd "${REPO_ROOT}/${app}"
    php artisan config:clear --ansi
    if [ "${coverage_driver_available}" = "true" ]; then
      php artisan test \
        --log-junit "${ARTIFACT_DIR}/junit-${report_name}.xml" \
        --coverage-clover "${ARTIFACT_DIR}/coverage-${report_name}.xml"
    else
      php artisan test --log-junit "${ARTIFACT_DIR}/junit-${report_name}.xml"
    fi
    exit_code=$?
    exit "${exit_code}"
  )
  app_exit=$?
  set -e

  if [[ "${app_exit}" -ne 0 ]]; then
    echo "[FAIL] Tests failed for ${app} (exit code ${app_exit})" | tee -a "${summary}"
    total_failures=$((total_failures + 1))
  else
    echo "[PASS] Tests passed for ${app}" | tee -a "${summary}"
  fi

  # Vérifier que le coverage.xml a bien été généré (si driver présent)
  if [[ "${coverage_driver_available}" = "true" ]]; then
    if [[ -s "${ARTIFACT_DIR}/coverage-${report_name}.xml" ]]; then
      lines=$(grep -o 'line-rate="[0-9.]*"' "${ARTIFACT_DIR}/coverage-${report_name}.xml" | head -1 | grep -o '[0-9.]*' || echo "0")
      if [[ -n "${lines}" ]]; then
        cov_pct=$(python3 -c "print(round(float(${lines}) * 100, 2))" 2>/dev/null || echo "?")
        echo "  Coverage: ${cov_pct}%" | tee -a "${summary}"
      fi
    else
      echo "[FAIL] No coverage report generated for ${app}" | tee -a "${summary}"
      total_failures=$((total_failures + 1))
    fi
  fi
done

# ── 3. Vérification finale ─────────────────────────────────────────────

summary_files_exist=0
for app in "${apps[@]}"; do
  report_name="$(printf '%s' "${app}" | tr '/-' '__')"
  if [[ -s "${ARTIFACT_DIR}/coverage-${report_name}.xml" ]]; then
    summary_files_exist=$((summary_files_exist + 1))
  fi
done

echo "[INFO] Coverage files found: ${summary_files_exist}/5" | tee -a "${summary}"

if [[ "${summary_files_exist}" -eq 0 ]]; then
  echo "[FATAL] No coverage files were generated for any application." | tee -a "${summary}"
  exit 1
fi

if [[ "${total_failures}" -gt 0 ]]; then
  echo "[FAIL] ${total_failures} application(s) failed tests or coverage." | tee -a "${summary}"
  exit 1
fi

echo "[INFO] Laravel test suite completed. ${summary_files_exist}/5 apps with coverage." | tee -a "${summary}"
exit 0
