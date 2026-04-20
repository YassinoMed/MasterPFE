FROM composer:2@sha256:dc292c5c0f95f526b051d4c341bf08e7e2b18504c74625e3203d7f123050e318 AS composer-bin

FROM php:8.4-cli-bookworm@sha256:4714c394e9ea215809c4b68da9fda778044c723435279f7188a251134c64502a

ENV COMPOSER_ALLOW_SUPERUSER=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl unzip libicu-dev libsqlite3-dev libzip-dev libpq-dev \
    && docker-php-ext-install pdo_sqlite pdo_mysql pdo_pgsql intl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer-bin /usr/bin/composer /usr/bin/composer

RUN groupadd --gid 10001 app \
    && useradd --uid 10001 --gid 10001 --create-home --shell /usr/sbin/nologin app

WORKDIR /var/www/html

COPY services-laravel/auth-users-service/composer.json services-laravel/auth-users-service/composer.lock ./
COPY services-laravel/shared-security /var/www/shared-security
RUN composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader --no-scripts

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
