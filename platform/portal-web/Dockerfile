# syntax=docker/dockerfile:1
# SecureRAG Hub — Portal Web Laravel (Chainguard Wolfi PHP Multi-stage)

# ==============================================================================
# STAGE 1: Builder (PHP Dev Image via Chainguard)
# ==============================================================================
FROM cgr.dev/chainguard/php:latest-dev AS builder

ENV COMPOSER_ALLOW_SUPERUSER=1

WORKDIR /var/www/html

COPY platform/portal-web/composer.json platform/portal-web/composer.lock ./
COPY services-laravel/shared-security /var/services-laravel/shared-security

RUN composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader --no-scripts

COPY platform/portal-web/app ./app
COPY platform/portal-web/artisan ./
COPY platform/portal-web/bootstrap ./bootstrap
COPY platform/portal-web/config ./config
COPY platform/portal-web/database ./database
COPY platform/portal-web/docker ./docker
COPY platform/portal-web/public ./public
COPY platform/portal-web/resources ./resources
COPY platform/portal-web/routes ./routes
COPY platform/portal-web/.env.example ./

RUN composer dump-autoload --optimize && php artisan package:discover --ansi

# ==============================================================================
# STAGE 2: Runtime Minimal (Chainguard Wolfi PHP - Zero Shell / Rootless)
# ==============================================================================
FROM cgr.dev/chainguard/php:latest AS runtime

WORKDIR /var/www/html

COPY --from=builder --chown=nonroot:nonroot /var/www/html /var/www/html

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

EXPOSE 8000

USER nonroot

ENTRYPOINT ["php", "artisan", "serve", "--host=0.0.0.0", "--port=8000"]
