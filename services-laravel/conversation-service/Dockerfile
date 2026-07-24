# syntax=docker/dockerfile:1
FROM composer:2@sha256:dc292c5c0f95f526b051d4c341bf08e7e2b18504c74625e3203d7f123050e318 AS composer-bin

FROM php:8.4-cli-bookworm@sha256:4714c394e9ea215809c4b68da9fda778044c723435279f7188a251134c64502a AS builder
ENV COMPOSER_ALLOW_SUPERUSER=1
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl unzip libicu-dev libsqlite3-dev libzip-dev libpq-dev \
    && docker-php-ext-install pdo_sqlite pdo_mysql pdo_pgsql intl \
    && apt-get clean && rm -rf /var/lib/apt/lists/*
COPY --from=composer-bin /usr/bin/composer /usr/bin/composer
WORKDIR /var/www/html
COPY services-laravel/conversation-service/composer.json services-laravel/conversation-service/composer.lock ./
COPY services-laravel/shared-security /var/www/shared-security
RUN --mount=type=cache,target=/tmp/composer composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader --no-scripts
COPY services-laravel/conversation-service/app ./app
COPY services-laravel/conversation-service/artisan ./
COPY services-laravel/conversation-service/bootstrap ./bootstrap
COPY services-laravel/conversation-service/config ./config
COPY services-laravel/conversation-service/database ./database
COPY services-laravel/conversation-service/docker ./docker
COPY services-laravel/conversation-service/public ./public
COPY services-laravel/conversation-service/resources ./resources
COPY services-laravel/conversation-service/routes ./routes
COPY services-laravel/conversation-service/.env.example ./
RUN APP_ENV=production APP_KEY=base64:7n+2wA7QWsh1oFq0n0l9l7W5vX5D7e3W8q8e1r2t3y4= DB_CONNECTION=sqlite DB_DATABASE=:memory: composer dump-autoload --optimize && APP_ENV=production APP_KEY=base64:7n+2wA7QWsh1oFq0n0l9l7W5vX5D7e3W8q8e1r2t3y4= DB_CONNECTION=sqlite DB_DATABASE=:memory: php artisan package:discover --ansi

FROM php:8.4-cli-alpine@sha256:f074dc4cd01ef4cba6e3f65301a1c0dad4bde3b3aac923179f6ee6b414e50d1f AS runtime
RUN apk add --no-cache icu-libs libpq sqlite-libs libzip \
    && addgroup -g 10001 app \
    && adduser -u 10001 -G app -H -s /sbin/nologin -D app \
    && rm -rf /var/cache/apk/* /usr/sbin/apk /usr/bin/apk 2>/dev/null || true
COPY --from=builder /usr/local/lib/php/extensions /usr/local/lib/php/extensions
COPY --from=builder /usr/local/etc/php/conf.d /usr/local/etc/php/conf.d
COPY --from=builder /var/www/html /var/www/html
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
