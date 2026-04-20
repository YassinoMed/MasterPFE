# Production Dockerfiles - SecureRAG Hub

- Generated at UTC: `2026-04-20T10:18:32Z`
- Strict mode: `true`

| Component | Control | Status | Evidence |
|---|---|---:|---|
| `platform/portal-web` | Dockerfile present | TERMINÉ | `platform/portal-web/Dockerfile` |
| `platform/portal-web` | Pinned base images | TERMINÉ | `all FROM lines include sha256 digests` |
| `platform/portal-web` | Composer production install | TERMINÉ | `--no-dev present` |
| `platform/portal-web` | No unnecessary runtime CLIs | TERMINÉ | `git and DB clients absent from apt install` |
| `platform/portal-web` | Database driver compatibility | TERMINÉ | `pdo_sqlite, pdo_mysql, pdo_pgsql and intl installed` |
| `platform/portal-web` | APT cache cleanup | TERMINÉ | `apt lists removed` |
| `platform/portal-web` | Non-root runtime user | TERMINÉ | `USER 10001:10001` |
| `services-laravel/auth-users-service` | Dockerfile present | TERMINÉ | `services-laravel/auth-users-service/Dockerfile` |
| `services-laravel/auth-users-service` | Pinned base images | TERMINÉ | `all FROM lines include sha256 digests` |
| `services-laravel/auth-users-service` | Composer production install | TERMINÉ | `--no-dev present` |
| `services-laravel/auth-users-service` | No unnecessary runtime CLIs | TERMINÉ | `git and DB clients absent from apt install` |
| `services-laravel/auth-users-service` | Database driver compatibility | TERMINÉ | `pdo_sqlite, pdo_mysql, pdo_pgsql and intl installed` |
| `services-laravel/auth-users-service` | APT cache cleanup | TERMINÉ | `apt lists removed` |
| `services-laravel/auth-users-service` | Non-root runtime user | TERMINÉ | `USER 10001:10001` |
| `services-laravel/chatbot-manager-service` | Dockerfile present | TERMINÉ | `services-laravel/chatbot-manager-service/Dockerfile` |
| `services-laravel/chatbot-manager-service` | Pinned base images | TERMINÉ | `all FROM lines include sha256 digests` |
| `services-laravel/chatbot-manager-service` | Composer production install | TERMINÉ | `--no-dev present` |
| `services-laravel/chatbot-manager-service` | No unnecessary runtime CLIs | TERMINÉ | `git and DB clients absent from apt install` |
| `services-laravel/chatbot-manager-service` | Database driver compatibility | TERMINÉ | `pdo_sqlite, pdo_mysql, pdo_pgsql and intl installed` |
| `services-laravel/chatbot-manager-service` | APT cache cleanup | TERMINÉ | `apt lists removed` |
| `services-laravel/chatbot-manager-service` | Non-root runtime user | TERMINÉ | `USER 10001:10001` |
| `services-laravel/conversation-service` | Dockerfile present | TERMINÉ | `services-laravel/conversation-service/Dockerfile` |
| `services-laravel/conversation-service` | Pinned base images | TERMINÉ | `all FROM lines include sha256 digests` |
| `services-laravel/conversation-service` | Composer production install | TERMINÉ | `--no-dev present` |
| `services-laravel/conversation-service` | No unnecessary runtime CLIs | TERMINÉ | `git and DB clients absent from apt install` |
| `services-laravel/conversation-service` | Database driver compatibility | TERMINÉ | `pdo_sqlite, pdo_mysql, pdo_pgsql and intl installed` |
| `services-laravel/conversation-service` | APT cache cleanup | TERMINÉ | `apt lists removed` |
| `services-laravel/conversation-service` | Non-root runtime user | TERMINÉ | `USER 10001:10001` |
| `services-laravel/audit-security-service` | Dockerfile present | TERMINÉ | `services-laravel/audit-security-service/Dockerfile` |
| `services-laravel/audit-security-service` | Pinned base images | TERMINÉ | `all FROM lines include sha256 digests` |
| `services-laravel/audit-security-service` | Composer production install | TERMINÉ | `--no-dev present` |
| `services-laravel/audit-security-service` | No unnecessary runtime CLIs | TERMINÉ | `git and DB clients absent from apt install` |
| `services-laravel/audit-security-service` | Database driver compatibility | TERMINÉ | `pdo_sqlite, pdo_mysql, pdo_pgsql and intl installed` |
| `services-laravel/audit-security-service` | APT cache cleanup | TERMINÉ | `apt lists removed` |
| `services-laravel/audit-security-service` | Non-root runtime user | TERMINÉ | `USER 10001:10001` |

## Global status

Statut global: `TERMINÉ`

Production Dockerfiles install Laravel dependencies without Composer dev packages, keep DB driver compatibility, remove unnecessary runtime CLIs, clean APT metadata and run as non-root.
