# SecureRAG Hub - Auth Users Service

## Role
`auth-users-service` is the first Laravel business microservice for SecureRAG Hub.

It provides a versioned REST API for:

- users
- roles
- permissions
- RBAC seed data
- user status management
- role assignment

This service is intentionally not a production OAuth/JWT authority yet. It is a clean RBAC business foundation that can be consumed by the Blade portal and later fronted by the API gateway.

## API
Base path:

```text
/api/v1
```

Main endpoints:

```text
GET    /api/v1/health
GET    /api/v1/users
POST   /api/v1/users
GET    /api/v1/users/{user}
PUT    /api/v1/users/{user}
PATCH  /api/v1/users/{user}/status
POST   /api/v1/users/{user}/roles
GET    /api/v1/roles
POST   /api/v1/roles
GET    /api/v1/roles/{role}
PUT    /api/v1/roles/{role}
GET    /api/v1/permissions
```

`{user}` and `{role}` use UUID route binding.

## RBAC baseline
Seeded roles:

- `super-admin`
- `admin-plateforme`
- `admin-securite`
- `user-rh`
- `user-it`

Seeded permissions:

- `users.view`
- `users.create`
- `users.update`
- `users.disable`
- `roles.view`
- `roles.manage`
- `security.view`
- `chatbots.view`
- `chatbots.manage`
- `conversations.use.rh`
- `conversations.use.it`

## Local setup
```bash
cd services-laravel/auth-users-service
composer install
cp .env.example .env
php artisan key:generate
touch database/database.sqlite
php artisan migrate --seed
php artisan serve --host=127.0.0.1 --port=8091
```

Health check:

```bash
curl http://127.0.0.1:8091/api/v1/health
```

## Tests
```bash
cd services-laravel/auth-users-service
php artisan test
```

Expected result:

```text
Feature and unit tests pass.
```

## Security notes
- No real secret is committed.
- `AUTH_USERS_DEMO_PASSWORD` is a local demo placeholder only.
- OAuth/JWT is intentionally deferred to a later hardening phase.
- Policies are present for sensitive RBAC actions and can be wired to gateway authentication later.
