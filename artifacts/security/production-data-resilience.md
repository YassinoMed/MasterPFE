# Production Data Resilience - SecureRAG Hub

- Generated at UTC: `2026-04-22T14:54:46Z`
- Strict mode: `false`

| Control | Status | Evidence |
|---|---:|---|
| `platform/portal-web` external DB PHP drivers | TERMINÉ | `pdo_mysql` and `pdo_pgsql` installed in Dockerfile |
| `services-laravel/auth-users-service` external DB PHP drivers | TERMINÉ | `pdo_mysql` and `pdo_pgsql` installed in Dockerfile |
| `services-laravel/chatbot-manager-service` external DB PHP drivers | TERMINÉ | `pdo_mysql` and `pdo_pgsql` installed in Dockerfile |
| `services-laravel/conversation-service` external DB PHP drivers | TERMINÉ | `pdo_mysql` and `pdo_pgsql` installed in Dockerfile |
| `services-laravel/audit-security-service` external DB PHP drivers | TERMINÉ | `pdo_mysql` and `pdo_pgsql` installed in Dockerfile |
| Production kind overlay DB mode | PRÊT_NON_EXÉCUTÉ | `infra/k8s/overlays/production` keeps SQLite for local/kind compatibility |
| External DB overlay SQLite removal | TERMINÉ | `production-external-db` renders without SQLite |
| External DB secret references | TERMINÉ | workloads reference `securerag-database-secrets` |
| Data resilience runbook | TERMINÉ | `docs/runbooks/data-resilience.md` present |
| Backup and restore scripts | TERMINÉ | `scripts/data/backup-postgres.sh` and `scripts/data/restore-postgres.sh` are executable |
| Backup runtime proof | PRÊT_NON_EXÉCUTÉ | run `scripts/data/backup-postgres.sh` against an external PostgreSQL DB |
| Restore runtime proof | PRÊT_NON_EXÉCUTÉ | run `scripts/data/restore-postgres.sh` into an isolated restore database |

## Global status

Statut global: `PRÊT_NON_EXÉCUTÉ`

## Interpretation

Static production data resilience is ready. Runtime backup and restore still require an external PostgreSQL endpoint and credentials.

## Required production evidence

- External database endpoint and credentials injected through non-Git secrets.
- Successful application migrations against the external database.
- Backup artifact with checksum.
- Restore test evidence on an isolated database or namespace.
