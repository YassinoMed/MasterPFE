# test-agent — PHPUnit + Laravel Tests + Coverage
# Image légère optimisée pour l'exécution parallèle de tests PHP.
FROM php:8.4-cli-alpine

RUN apk add --no-cache \
    autoconf g++ make linux-headers \
    git unzip sqlite-dev icu-dev \
    && pecl install xdebug \
    && docker-php-ext-enable xdebug \
    && docker-php-ext-install pdo_sqlite intl \
    && echo "xdebug.mode=coverage" > /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && echo "xdebug.start_with_request=no" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

ENV COMPOSER_HOME=/tmp/composer
ENV COMPOSER_CACHE_DIR=/tmp/composer/cache

WORKDIR /workspace
ENTRYPOINT ["/bin/sh", "-c"]
CMD ["php artisan test"]
