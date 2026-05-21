# API Contracts — SecureRAG Hub

> Spécifications canoniques pour les endpoints exposés.
> Runtime officiel : **Laravel** (`services-laravel/*` + `platform/portal-web`).
> Voir aussi les OpenAPI sous [`docs/openapi/`](openapi/).

## Conventions

- Toutes les routes API préfixées `/api/v1/`.
- Authentification : `Authorization: Bearer <jwt-sanctum-token>` sauf
  `/api/v1/auth/login` et `/api/v1/auth/register`.
- Réponses JSON conformes à `{ "data": <...>, "meta": {...}, "errors": [] }`.
- Codes HTTP : 200 OK, 201 Created, 204 No Content, 400/401/403/404/409/422.

## 1. `auth-users-service`

### POST `/api/v1/auth/register`
```json
{
  "request": {
    "email": "user@example.com",
    "password": "min8chars",
    "first_name": "Alice",
    "last_name": "Doe"
  },
  "response_201": {
    "data": { "user": { "id": 1, "email": "...", "role": "USER" }, "token": "..." }
  }
}
```

### POST `/api/v1/auth/login`
```json
{
  "request": { "email": "...", "password": "..." },
  "response_200": { "data": { "user": {...}, "token": "..." } },
  "response_401": { "errors": [{ "code": "INVALID_CREDENTIALS" }] }
}
```

### GET `/api/v1/auth/me`
- Auth requise. Renvoie `{ data: { user: {...} } }`.

### GET `/api/v1/users`
- Rôle requis : ADMIN ou AUDITOR.

### PUT `/api/v1/users/{id}/role`
- Rôle requis : ADMIN.
- Body : `{ "role": "USER" | "ADMIN" | "AUDITOR" }`.

### DELETE `/api/v1/users/{id}`
- Rôle requis : ADMIN. Self-delete refusé (400).

## 2. `chatbot-manager-service`

### POST `/api/v1/chat`
```json
{
  "request": {
    "session_id": "sess_01...",
    "message": "Quels sont les effets secondaires du médicament X ?"
  },
  "response_200": {
    "data": {
      "response": "...",
      "audit": { "prompt_score": 12, "response_score": 8, "action": "ALLOWED" },
      "chunks_used": ["chunk_uuid_1", "chunk_uuid_2"],
      "latency_ms": 1880
    }
  },
  "response_403_blocked": {
    "errors": [{ "code": "AUDIT_BLOCKED", "score": 85 }]
  }
}
```

### GET `/api/v1/chat/history/{session_id}`
- Renvoie les `LLM_HISTORY_MAX_TURNS` derniers tours.

### DELETE `/api/v1/chat/history/{session_id}`
- Supprime l'historique de la session.

## 3. `vectorstore` (intégré dans `chatbot-manager-service`)

> Le CDC prévoyait un `vectorstore-service` séparé ; en Laravel, c'est un
> module interne du `chatbot-manager-service`. Les endpoints suivants
> sont **internes au cluster** (pas exposés via portal-web).

### POST `/internal/documents/upload`
- Multipart : `file` + `metadata.allowed_roles[]` + `metadata.document_type`
  + `metadata.owner` + `metadata.sensitivity_level`.
- Retourne `document_id`, lance job async d'indexation.

### POST `/internal/documents/index/{document_id}`
- Re-index si métadonnées modifiées.

### GET `/internal/documents`
- Liste paginée, filtrée par RBAC.

### POST `/internal/search`
```json
{
  "request": { "query": "...", "k": 5, "filters": { "document_type": "PRESCRIPTION" } },
  "response_200": {
    "data": { "chunks": [ { "text": "...", "metadata": {...}, "score": 0.87 } ] }
  }
}
```

### DELETE `/internal/documents/{document_id}`
- Soft delete + retire les chunks de Qdrant.

## 4. `audit-security-service`

### POST `/internal/audit/prompt`
```json
{
  "request": {
    "session_id": "...", "user_id": 42, "role": "USER",
    "prompt": "<full prompt — n'est PAS stocké, juste analysé>"
  },
  "response_200": {
    "data": {
      "score": 85,
      "action": "BLOCKED",
      "patterns_matched": ["ignore previous instructions", "system prompt"],
      "prompt_hash": "sha256:..."
    }
  }
}
```

### POST `/internal/audit/response`
- Analyse la réponse LLM, retourne action ALLOWED/FLAGGED/BLOCKED.

### GET `/internal/audit/logs`
- Rôle requis : AUDITOR ou ADMIN.
- Paramètres : `from`, `to`, `action`, `user_id`.
- Retourne les logs JSON (hashes only, pas de contenu).

### GET `/internal/audit/report`
- Rôle requis : AUDITOR ou ADMIN.
- Génère un rapport synthèse PDF / CSV pour conformité.

## 5. Gateway interne `portal-web`

`portal-web` n'expose pas d'API REST publique ; il proxie vers les
services internes et expose les routes UI :

| Chemin UI | Backend appelé |
|-----------|----------------|
| `/auth/*` | `auth-users-service` |
| `/chat/*` | `chatbot-manager-service` |
| `/documents/*` | `chatbot-manager-service` (vectorstore module) |
| `/audit/*` | `audit-security-service` |

Toutes les requêtes UI sont authentifiées via session web Laravel (CSRF +
cookie). En interne, le portail s'authentifie auprès des microservices
via JWT machine-to-machine (à venir, actuellement même JWT que la session
utilisateur).

## Codes d'erreur métier

| Code | HTTP | Cause |
|------|:----:|-------|
| `INVALID_CREDENTIALS` | 401 | Email/password erronés |
| `JWT_EXPIRED` | 401 | Token expiré, refaire login |
| `JWT_INVALID` | 401 | Token mal formé ou signature invalide |
| `FORBIDDEN_ROLE` | 403 | Rôle insuffisant |
| `AUDIT_BLOCKED` | 403 | Score audit ≥ 70 |
| `AUDIT_FLAGGED_WARNING` | 200 | Score 40-69, réponse fournie mais marquée |
| `DOC_FORBIDDEN_RBAC` | 403 | RBAC métadonnées Qdrant refuse |
| `RATE_LIMITED` | 429 | Throttle middleware |
| `VALIDATION_ERROR` | 422 | Form Request invalide |

## OpenAPI

Specs détaillées par service sous [`docs/openapi/`](openapi/) (à
générer via `php artisan l5-swagger:generate` une fois les services
mappés).
