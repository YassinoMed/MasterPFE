# syntax=docker/dockerfile:1
# ── Stage 1: Composer Binary ─────────────────────────────────────
FROM composer:2@sha256:dc292c5c0f95f526b051d4c341bf08e7e2b18504c74625e3203d7f123050e318 AS composer-bin

# ── Stage 2: Builder (compile extensions + install deps) ─────────
FROM php:8.4-cli-alpine@sha256:1f044d6de9f2338df85f32719dfd2938e284f848a91b5ccee6a3d375ca81caa5 AS builder

ENV COMPOSER_ALLOW_SUPERUSER=1

RUN apk add --no-cache icu-dev sqlite-dev libzip-dev postgresql-dev unzip \
    && docker-php-ext-install pdo_sqlite pdo_mysql pdo_pgsql intl

COPY --from=composer-bin /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

COPY services-laravel/auth-users-service/composer.json services-laravel/auth-users-service/composer.lock ./
COPY services-laravel/shared-security /var/www/shared-security
RUN --mount=type=cache,target=/tmp/composer composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader --no-scripts

COPY services-laravel/auth-users-service/app ./app
COPY services-laravel/auth-users-service/artisan ./
COPY services-laravel/auth-users-service/bootstrap ./bootstrap
COPY services-laravel/auth-users-service/config ./config
COPY services-laravel/auth-users-service/database ./database
COPY services-laravel/auth-users-service/docker ./docker
COPY services-laravel/auth-users-service/public ./public
COPY services-laravel/auth-users-service/resources ./resources
COPY services-laravel/auth-users-service/routes ./routes
COPY services-laravel/auth-users-service/.env.example ./

RUN APP_ENV=production APP_KEY=base64:7n+2wA7QWsh1oFq0n0l9l7W5vX5D7e3W8q8e1r2t3y4= DB_CONNECTION=sqlite DB_DATABASE=:memory: composer dump-autoload --optimize && APP_ENV=production APP_KEY=base64:7n+2wA7QWsh1oFq0n0l9l7W5vX5D7e3W8q8e1r2t3y4= DB_CONNECTION=sqlite DB_DATABASE=:memory: php artisan package:discover --ansi

# ── Stage 3: Runtime (Minimal — no apt, no curl, no shell tools) ─
FROM php:8.4-cli-alpine@sha256:1f044d6de9f2338df85f32719dfd2938e284f848a91b5ccee6a3d375ca81caa5 AS runtime

RUN apk add --no-cache icu-libs libpq sqlite-libs libzip \
    && addgroup -g 10001 app \
    && adduser -u 10001 -G app -H -s /sbin/nologin -D app \
    && rm -rf /var/cache/apk/* /usr/sbin/apk /usr/bin/apk 2>/dev/null || true

COPY --from=builder /usr/local/lib/php/extensions /usr/local/lib/php/extensions
COPY --from=builder /usr/local/etc/php/conf.d /usr/local/etc/php/conf.d
COPY --from=builder /var/www/html /var/www/html
COPY --from=builder /var/www/shared-security /var/www/shared-security
COPY --from=builder /var/www/shared-security /var/shared-security

WORKDIR /var/www/html

ENV CREATE_DOTENV=false \
    SECURERAG_RUNTIME_ROOT=/tmp/securerag-runtime \
    DB_DATABASE=/tmp/securerag-runtime/database/database.sqlite \
    LARAVEL_STORAGE_PATH=/tmp/securerag-runtime/storage \
    VIEW_COMPILED_PATH=/tmp/securerag-runtime/storage/framework/views \
    APP_SERVICES_CACHE=/tmp/securerag-runtime/bootstrap-cache/services.php \
    APP_PACKAGES_CACHE=/tmp/securerag-runtime/bootstrap-cache/packages.php \
    APP_CONFIG_CACHE=/tmp/securerag-runtime/bootstrap-cache/config.php \
    APP_ROUTES_CACHE=/tmp/securerag-runtime/bootstrap-cache/routes-v7.php \
    APP_EVENTS_CACHE=/tmp/securerag-runtime/bootstrap-cache/events.php

RUN chmod +x docker/entrypoint.sh

EXPOSE 8000
USER 10001:10001
ENTRYPOINT ["docker/entrypoint.sh"]
