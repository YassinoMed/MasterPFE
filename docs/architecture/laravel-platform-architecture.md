# SecureRAG Hub Laravel Platform Architecture

## Scope

This architecture covers only the User/Admin application platform around SecureRAG Hub.
It does not implement LLM, RAG, Qdrant, Ollama, or AI scoring engines.
Those concerns are integrated through contracts, adapters, and mocked REST endpoints.

## Services

- `auth-users-service`: identity, profiles, RBAC, token lifecycle
- `chatbot-manager-service`: chatbot catalog, domains, prompt configuration, access rules
- `conversation-service`: conversations, messages, AI integration adapters, response metadata
- `audit-security-service`: audit logs, security events, blocked responses, admin action trail
- `portal-web`: Laravel + Inertia + Vue 3 User/Admin UI and API client orchestration
- `gateway`: reverse proxy and entrypoint routing layer

## Key decisions

- Keep the existing Python/AI mock services under `services/` untouched.
- Build the Laravel platform under `platform/` to avoid coupling platform concerns to AI services.
- Use one codebase per business capability instead of a disguised monolith.
- Use REST JSON between services with explicit service clients and versioned APIs.
- Centralize identity and RBAC in `auth-users-service`.
- Keep AI integrations behind interfaces in `conversation-service`.

## Recommended auth approach

- `auth-users-service` acts as the authorization service.
- Recommended token model: OAuth2/JWT via Laravel Passport for service trust and admin APIs.
- `portal-web` keeps server-side session UX and calls internal APIs through authenticated service clients.

## Frontend choice

- `portal-web` uses Laravel + Inertia + Vue 3.
- This gives a professional SaaS B2B admin experience while keeping Laravel conventions and server ownership.

## Deployment integration

- The Laravel platform is not isolated from the SecureRAG Hub runtime.
- `portal-web` is the User/Admin web surface and calls the cluster entrypoint exposed by the SecureRAG Hub deployment.
- In the current local setup, this entrypoint is represented by the development HTTP exposure of the cluster.
- The deployment target is documented in `docs/architecture/securerag-deployment-target.puml`.
- This target view explicitly separates:
  - the web portal
  - the cluster HTTP entrypoint
  - the `api-gateway` service
  - the application pods
  - the DevSecOps supply chain

## Deployment note

- The local Kubernetes deployment remains under `infra/` and `services/`.
- The Laravel platform remains under `platform/`.
- This repository therefore models both:
  - the secured chatbot runtime
  - the User/Admin application surface around it

## Next implementation sequence

1. database design and migrations
2. versioned API routes
3. DTOs / requests / policies
4. service clients and mock adapters
5. user portal screens
6. admin portal screens
7. Docker and compose
