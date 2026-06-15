# ==========================================
# Étape 1 : Installation des dépendances (deps)
# ==========================================
FROM composer:2 AS deps
WORKDIR /var/www/html

# Copier uniquement les fichiers nécessaires pour les dépendances
COPY platform/portal-web/composer.json platform/portal-web/composer.lock ./
COPY services-laravel/shared-security /var/services-laravel/shared-security

# Installer sans dev ni scripts ni autoloader en ignorant les prérequis de plateforme
RUN composer install --no-dev --no-interaction --prefer-dist --no-scripts --no-autoloader --ignore-platform-reqs

# Copier le reste du code applicatif nécessaire pour générer l'autoloader
COPY platform/portal-web/app ./app
COPY platform/portal-web/bootstrap ./bootstrap
COPY platform/portal-web/config ./config
COPY platform/portal-web/database ./database
COPY platform/portal-web/public ./public
COPY platform/portal-web/resources ./resources
COPY platform/portal-web/routes ./routes
COPY platform/portal-web/artisan ./

# Générer l'autoloader optimisé en ignorant les prérequis de plateforme
RUN composer dump-autoload --no-dev --optimize --ignore-platform-reqs

# ==========================================
# Étape 2 : Optimisation et caching (optimizer)
# ==========================================
FROM php:8.2-cli-bookworm AS optimizer

# Installer les dépendances système minimales et extensions PHP requises
RUN apt-get update && apt-get install -y --no-install-recommends \
    libicu-dev \
    libsqlite3-dev \
    libzip-dev \
    libpq-dev \
    unzip \
    && docker-php-ext-install pdo_sqlite pdo_mysql pdo_pgsql intl \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /var/www/html

# Copier l'environnement préparé par l'étape deps
COPY --from=deps /var/www/html /var/www/html
COPY --from=deps /var/services-laravel/shared-security /var/services-laravel/shared-security

# Créer les répertoires nécessaires si manquants
RUN mkdir -p storage/framework/views storage/framework/cache storage/framework/sessions bootstrap/cache

# Définir les variables nécessaires pour exécuter php artisan config/route/view cache en production
ENV APP_ENV=production \
    APP_KEY=base64:7n+2wA7QWsh1oFq0n0l9l7W5vX5D7e3W8q8e1r2t3y4= \
    DB_CONNECTION=sqlite \
    DB_DATABASE=:memory:

# Cache Laravel
RUN php artisan config:cache \
    && php artisan route:cache \
    && php artisan view:cache

# ==========================================
# Étape 3 : Image de production finale (runtime)
# ==========================================
FROM gcr.io/distroless/php-debian12:8.2
WORKDIR /var/www/html

# Ajouter les LABEL OCI standard
LABEL org.opencontainers.image.title="SecureRAG Hub Portal Web" \
      org.opencontainers.image.description="Hardened PHP-FPM runtime for Laravel Portal Web in PSS Restricted environments" \
      org.opencontainers.image.source="https://github.com/YassinoMed/MasterPFE" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.vendor="Google DeepMind Advanced Agentic Coding"

# Copier uniquement les répertoires nécessaires avec les bonnes permissions non-root
COPY --chown=10001:10001 --from=optimizer /var/www/html/app ./app
COPY --chown=10001:10001 --from=optimizer /var/www/html/bootstrap ./bootstrap
COPY --chown=10001:10001 --from=optimizer /var/www/html/config ./config
COPY --chown=10001:10001 --from=optimizer /var/www/html/database ./database
COPY --chown=10001:10001 --from=optimizer /var/www/html/public ./public
COPY --chown=10001:10001 --from=optimizer /var/www/html/resources ./resources
COPY --chown=10001:10001 --from=optimizer /var/www/html/routes ./routes
COPY --chown=10001:10001 --from=optimizer /var/www/html/vendor ./vendor
COPY --chown=10001:10001 --from=optimizer /var/www/html/artisan ./artisan

# Copier le package partagé indispensable pour l'autoloader
COPY --chown=10001:10001 --from=optimizer /var/services-laravel/shared-security /var/services-laravel/shared-security

# Définir l'environnement de production PSS Restricted
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

# Exposer le port PHP-FPM par défaut
EXPOSE 9000

# Exécuter en tant qu'utilisateur non-root 10001 (PSS Restricted)
USER 10001:10001

# Lancer php-fpm en avant-plan (foreground)
ENTRYPOINT ["/usr/sbin/php-fpm8.2", "-F"]
