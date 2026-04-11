# SecureRAG Hub - Chatbot Manager Service

## Role
`chatbot-manager-service` is the Laravel business microservice responsible for chatbot catalog governance.

It manages:

- business domains
- sensitivity levels
- chatbot metadata
- prompt configuration versions
- role-based chatbot access
- access rules and guardrail metadata

It does not run a real LLM, RAG engine, Qdrant workflow or Ollama model. This service stores governance metadata consumed by the SecureRAG Hub portal and future orchestration services.

## API
Base path:

```text
/api/v1
```

Main endpoints:

```text
GET    /api/v1/health
GET    /api/v1/business-domains
POST   /api/v1/business-domains
GET    /api/v1/business-domains/{domain}
PUT    /api/v1/business-domains/{domain}
GET    /api/v1/sensitivity-levels
POST   /api/v1/sensitivity-levels
GET    /api/v1/sensitivity-levels/{level}
PUT    /api/v1/sensitivity-levels/{level}
GET    /api/v1/chatbots
POST   /api/v1/chatbots
GET    /api/v1/chatbots/{chatbot}
PUT    /api/v1/chatbots/{chatbot}
PATCH  /api/v1/chatbots/{chatbot}/status
GET    /api/v1/chatbots/{chatbot}/roles
PUT    /api/v1/chatbots/{chatbot}/roles
GET    /api/v1/chatbots/{chatbot}/prompt-configs
POST   /api/v1/chatbots/{chatbot}/prompt-configs
```

`{domain}`, `{level}` and `{chatbot}` use UUID route binding.

## Seeded demo catalog
Business domains:

- `rh`
- `support-it`

Sensitivity levels:

- `faible`
- `moyen`
- `eleve`

Chatbots:

- `chatbot-rh`
- `chatbot-support-it`

Role slugs are aligned with `auth-users-service`:

- `super-admin`
- `admin-plateforme`
- `admin-securite`
- `user-rh`
- `user-it`

## Local setup
```bash
cd services-laravel/chatbot-manager-service
composer install
cp .env.example .env
php artisan key:generate
touch database/database.sqlite
php artisan migrate --seed
php artisan serve --host=127.0.0.1 --port=8092
```

Health check:

```bash
curl http://127.0.0.1:8092/api/v1/health
```

## Tests
```bash
cd services-laravel/chatbot-manager-service
php artisan test
```

Expected result:

```text
Feature and unit tests pass.
```

## Security notes
- No real secret is committed.
- Prompt configs are metadata only and must not contain credentials.
- Role slugs are governance inputs aligned with the auth-users-service RBAC baseline.
- LLM/RAG execution is intentionally out of scope for this service.
