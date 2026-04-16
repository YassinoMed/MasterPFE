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
- `gateway`: optional local reverse proxy layer; not part of the current official Kubernetes runtime

## Key decisions

- Keep legacy Python/AI directories under `services/` as historical material only; they are excluded from the official build/deploy path while their application sources are absent.
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

- The Laravel platform is now the official local Kubernetes runtime.
- `portal-web` is the User/Admin web surface and calls the Laravel services exposed inside the cluster.
- In the current local setup, the external demonstration entrypoint is the `portal-web` NodePort.
- The current deployment target separates:
  - the web portal
  - the Laravel business services
  - the security/audit service
  - the Kubernetes guardrails
  - the DevSecOps supply chain

## Deployment note

- The local Kubernetes deployment remains under `infra/` and uses sources from `platform/` and `services-laravel/`.
- The Laravel platform remains under `platform/`.
- This repository therefore models both:
  - the secured Laravel chatbot administration/runtime surface
  - the User/Admin application surface around it

## Next implementation sequence

1. database design and migrations
2. versioned API routes
3. DTOs / requests / policies
4. service clients and mock adapters
5. user portal screens
6. admin portal screens
7. Docker and compose
