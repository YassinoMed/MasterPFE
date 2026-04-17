FROM composer:2 AS composer-bin

FROM php:8.4-cli-bookworm

ENV COMPOSER_ALLOW_SUPERUSER=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends git curl unzip libicu-dev libsqlite3-dev libzip-dev libpq-dev default-mysql-client postgresql-client \
    && docker-php-ext-install pdo_sqlite pdo_mysql pdo_pgsql intl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer-bin /usr/bin/composer /usr/bin/composer

RUN groupadd --gid 10001 app \
    && useradd --uid 10001 --gid 10001 --create-home --shell /usr/sbin/nologin app

WORKDIR /var/www/html

COPY platform/portal-web/composer.json platform/portal-web/composer.lock ./
COPY services-laravel/shared-security /var/services-laravel/shared-security
RUN composer install --no-interaction --prefer-dist --optimize-autoloader --no-scripts

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
