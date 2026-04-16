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

summary=".coverage-artifacts/laravel-test-summary.txt"
: > "${summary}"

for app in "${apps[@]}"; do
  if [[ ! -f "${app}/artisan" ]]; then
    echo "[FAIL] Missing Laravel artisan entrypoint: ${app}" | tee -a "${summary}"
    exit 1
  fi

  report_name="$(printf '%s' "${app}" | tr '/-' '__')"
  echo "[INFO] Running Laravel tests for ${app}" | tee -a "${summary}"
  (
    cd "${app}"
    php artisan config:clear --ansi
    php artisan test --log-junit "../../.coverage-artifacts/junit-${report_name}.xml"
  )
done

echo "[INFO] Laravel test suite completed" | tee -a "${summary}"
