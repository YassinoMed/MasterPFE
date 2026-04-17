# Production Data Resilience - SecureRAG Hub

- Generated at UTC: `2026-04-17T06:28:12Z`
- Strict mode: `false`

| Control | Status | Evidence |
|---|---:|---|
| `platform/portal-web` external DB PHP drivers | TERMINÉ | `pdo_mysql` and `pdo_pgsql` installed in Dockerfile |
| `services-laravel/auth-users-service` external DB PHP drivers | TERMINÉ | `pdo_mysql` and `pdo_pgsql` installed in Dockerfile |
| `services-laravel/chatbot-manager-service` external DB PHP drivers | TERMINÉ | `pdo_mysql` and `pdo_pgsql` installed in Dockerfile |
| `services-laravel/conversation-service` external DB PHP drivers | TERMINÉ | `pdo_mysql` and `pdo_pgsql` installed in Dockerfile |
| `services-laravel/audit-security-service` external DB PHP drivers | TERMINÉ | `pdo_mysql` and `pdo_pgsql` installed in Dockerfile |
| Production overlay DB mode | PARTIEL | Render still contains `DB_CONNECTION=sqlite` for local/kind compatibility |
| Data resilience runbook | TERMINÉ | `docs/runbooks/data-resilience.md` present |

## Global status

Statut global: `PARTIEL`

## Interpretation

Data resilience is not fully production-grade yet. The code is prepared for external databases, but runtime production still requires an external database, secrets, backup and restore execution.

## Required production evidence

- External database endpoint and credentials injected through non-Git secrets.
- Successful application migrations against the external database.
- Backup artifact with checksum.
- Restore test evidence on an isolated database or namespace.
