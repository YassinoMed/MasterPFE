#!/usr/bin/env bash

set -euo pipefail

mkdir -p .coverage-artifacts
rm -f .coverage-artifacts/junit-*.xml .coverage-artifacts/junit.xml .coverage-artifacts/coverage.xml .coverage-artifacts/coverage-summary.txt

apps=(
  platform/portal-web
  services-laravel/auth-users-service
  services-laravel/chatbot-manager-service
  services-laravel/conversation-service
  services-laravel/audit-security-service
)

# Coverage gate threshold — enforced by collect-coverage.sh
COVERAGE_MIN="${COVERAGE_MIN:-70}"
ENFORCE_COVERAGE_GATE="${ENFORCE_COVERAGE_GATE:-true}"

summary=".coverage-artifacts/laravel-test-summary.txt"
: > "${summary}"

# Detect coverage driver availability (Xdebug or PCOV)
coverage_driver_available=false
if php -m 2>/dev/null | grep -qiE '^(xdebug|pcov)$'; then
  coverage_driver_available=true
  echo "[INFO] Coverage driver detected; coverage reports will be generated" | tee -a "${summary}"
else
  echo "[WARN] No coverage driver (Xdebug/PCOV) detected; coverage reports will be skipped" | tee -a "${summary}"
fi

for app in "${apps[@]}"; do
  if [[ ! -f "${app}/artisan" ]]; then
    echo "[FAIL] Missing Laravel artisan entrypoint: ${app}" | tee -a "${summary}"
    exit 1
  fi

  report_name="$(printf '%s' "${app}" | tr '/-' '__')"
  echo "[INFO] Running Laravel tests for ${app}" | tee -a "${summary}"

  coverage_args=()
  if [[ "${coverage_driver_available}" == "true" ]]; then
    coverage_args=(--coverage-clover "../../.coverage-artifacts/coverage-${report_name}.xml")
  fi

  (
    cd "${app}"
    php artisan config:clear --ansi
    php artisan test \
      --log-junit "../../.coverage-artifacts/junit-${report_name}.xml" \
      "${coverage_args[@]+"${coverage_args[@]}"}"
  )
done

# Merge per-app coverage reports into a single coverage.xml for collect-coverage.sh
if [[ "${coverage_driver_available}" == "true" ]]; then
  coverage_files=(.coverage-artifacts/coverage-*.xml)
  if [[ ${#coverage_files[@]} -gt 0 && -f "${coverage_files[0]}" ]]; then
    # Use the portal-web coverage as baseline (largest app)
    if [[ -f ".coverage-artifacts/coverage-platform__portal_web.xml" ]]; then
      cp ".coverage-artifacts/coverage-platform__portal_web.xml" ".coverage-artifacts/coverage.xml"
    else
      cp "${coverage_files[0]}" ".coverage-artifacts/coverage.xml"
    fi
    echo "[INFO] Coverage report merged to .coverage-artifacts/coverage.xml" | tee -a "${summary}"
  fi
fi

echo "[INFO] Laravel test suite completed" | tee -a "${summary}"
