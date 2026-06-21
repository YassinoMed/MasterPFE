# SecureRAG Hub Platform

This directory contains the Laravel-based User/Admin platform for SecureRAG Hub.

## Services

- `auth-users-service`
- `chatbot-manager-service`
- `conversation-service`
- `audit-security-service`
- `portal-web`
- `gateway`
- `shared`

## Boundary

These services implement the application platform only:

- authentication and profile management
- RBAC and access governance
- chatbot catalog and configuration
- conversation orchestration and history
- audit and security event consultation
- admin and user dashboards

AI engines, vector stores, and LLM runtimes stay outside this scope and are consumed through integration contracts.

## Deployment placement

The Laravel platform is part of the global SecureRAG Hub deployment target.

- `portal-web` is the User/Admin entrypoint
- it is designed to call the SecureRAG Hub cluster HTTP entrypoint
- the deployment target is documented in `docs/architecture/securerag-deployment-target.puml`

This keeps the Laravel application aligned with the secured runtime, without embedding AI engines directly in the platform layer.
