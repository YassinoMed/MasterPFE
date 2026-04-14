FROM composer:2 AS composer-bin

FROM php:8.4-cli-bookworm

ENV COMPOSER_ALLOW_SUPERUSER=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends git curl unzip libicu-dev libsqlite3-dev libzip-dev \
    && docker-php-ext-install pdo_sqlite intl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer-bin /usr/bin/composer /usr/bin/composer

RUN groupadd --gid 10001 app \
    && useradd --uid 10001 --gid 10001 --create-home --shell /usr/sbin/nologin app

WORKDIR /var/www/html

COPY composer.json composer.lock ./
RUN composer install --no-interaction --prefer-dist --optimize-autoloader --no-scripts

COPY --chown=app:app app ./app
COPY --chown=app:app artisan ./
COPY --chown=app:app bootstrap ./bootstrap
COPY --chown=app:app config ./config
COPY --chown=app:app database ./database
COPY --chown=app:app docker ./docker
COPY --chown=app:app public ./public
COPY --chown=app:app resources ./resources
COPY --chown=app:app routes ./routes
COPY --chown=app:app .env.example ./

RUN composer dump-autoload --optimize && php artisan package:discover --ansi

RUN mkdir -p database storage/app storage/framework/cache storage/framework/sessions storage/framework/views storage/logs bootstrap/cache \
    && chown -R app:app /var/www/html \
    && chmod +x docker/entrypoint.sh

EXPOSE 8000

USER 10001:10001

ENTRYPOINT ["docker/entrypoint.sh"]
