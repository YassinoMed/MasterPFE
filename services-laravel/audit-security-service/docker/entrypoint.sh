#!/usr/bin/env sh

set -eu

cd /var/www/html

RUNTIME_ROOT="${SECURERAG_RUNTIME_ROOT:-/tmp/securerag-runtime}"
export DB_DATABASE="${DB_DATABASE:-${RUNTIME_ROOT}/database/database.sqlite}"
export LARAVEL_STORAGE_PATH="${LARAVEL_STORAGE_PATH:-${RUNTIME_ROOT}/storage}"
export VIEW_COMPILED_PATH="${VIEW_COMPILED_PATH:-${LARAVEL_STORAGE_PATH}/framework/views}"
export APP_SERVICES_CACHE="${APP_SERVICES_CACHE:-${RUNTIME_ROOT}/bootstrap-cache/services.php}"
export APP_PACKAGES_CACHE="${APP_PACKAGES_CACHE:-${RUNTIME_ROOT}/bootstrap-cache/packages.php}"
export APP_CONFIG_CACHE="${APP_CONFIG_CACHE:-${RUNTIME_ROOT}/bootstrap-cache/config.php}"
export APP_ROUTES_CACHE="${APP_ROUTES_CACHE:-${RUNTIME_ROOT}/bootstrap-cache/routes-v7.php}"
export APP_EVENTS_CACHE="${APP_EVENTS_CACHE:-${RUNTIME_ROOT}/bootstrap-cache/events.php}"

mkdir -p \
  "$(dirname "${DB_DATABASE}")" \
  "${LARAVEL_STORAGE_PATH}/app" \
  "${LARAVEL_STORAGE_PATH}/framework/cache" \
  "${LARAVEL_STORAGE_PATH}/framework/sessions" \
  "${LARAVEL_STORAGE_PATH}/framework/views" \
  "${LARAVEL_STORAGE_PATH}/logs" \
  "$(dirname "${APP_SERVICES_CACHE}")" \
  "$(dirname "${APP_PACKAGES_CACHE}")" \
  "$(dirname "${APP_CONFIG_CACHE}")" \
  "$(dirname "${APP_ROUTES_CACHE}")" \
  "$(dirname "${APP_EVENTS_CACHE}")"
touch "${DB_DATABASE}"

if [ ! -f .env ] && [ "${CREATE_DOTENV:-false}" = "true" ]; then
  cp .env.example .env
fi

if [ -z "${APP_KEY:-}" ] && [ -f .env ] && ! grep -q '^APP_KEY=base64:' .env; then
  php artisan key:generate --force
fi

# Ensure runtime env vars win over any cached local config baked into the image.
php artisan optimize:clear >/dev/null 2>&1 || true

php artisan migrate --force --graceful

exec php artisan serve --host=0.0.0.0 --port=8000
