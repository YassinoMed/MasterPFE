#!/usr/bin/env sh

set -eu

cd /var/www/html

mkdir -p database storage/app storage/framework/cache storage/framework/sessions storage/framework/views storage/logs bootstrap/cache
touch database/database.sqlite

if [ ! -f .env ] && [ "${CREATE_DOTENV:-true}" = "true" ]; then
  cp .env.example .env
fi

if [ -z "${APP_KEY:-}" ] && [ -f .env ] && ! grep -q '^APP_KEY=base64:' .env; then
  php artisan key:generate --force
fi

# Ensure runtime env vars win over any cached local config baked into the image.
php artisan optimize:clear >/dev/null 2>&1 || true

php artisan migrate --force --graceful

exec php artisan serve --host=0.0.0.0 --port=8000
