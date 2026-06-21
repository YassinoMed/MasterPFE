# SecureRAG Hub - Conversation Service

## Role
`conversation-service` is the Laravel business microservice responsible for
persistent conversation history in SecureRAG Hub.

It provides a versioned REST API for:

- conversations
- user messages
- assistant messages
- deterministic mocked assistant replies
- history consumption by the Blade portal

This service does not implement a real LLM, a real RAG engine, Qdrant logic or
Ollama intelligence. It deliberately stores and simulates the conversation flow
needed for the official `demo` scenario.

## API
Base path:

```text
/api/v1
```

Main endpoints:

```text
GET    /api/v1/health
GET    /api/v1/conversations
POST   /api/v1/conversations
GET    /api/v1/conversations/{conversation}
PATCH  /api/v1/conversations/{conversation}/status
GET    /api/v1/conversations/{conversation}/messages
POST   /api/v1/conversations/{conversation}/messages
```

`{conversation}` uses UUID route binding.

## Local setup
```bash
cd services-laravel/conversation-service
composer install
cp .env.example .env
php artisan key:generate
touch database/database.sqlite
php artisan migrate --seed
php artisan serve --host=127.0.0.1 --port=8093
```

Health check:

```bash
curl http://127.0.0.1:8093/api/v1/health
```

## Tests
```bash
cd services-laravel/conversation-service
php artisan test
```

Expected result:

```text
Feature and unit tests pass.
```

## Security notes
- No real secret is committed.
- Assistant answers are deterministic demo stubs.
- The real AI/RAG integration remains an explicit future extension.
