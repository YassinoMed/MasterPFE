# Production DB Secret Evidence - SecureRAG Hub

- Generated at UTC: `2026-04-19T21:35:27Z`
- Namespace: `securerag-hub`
- Secret: `securerag-database-secrets`
- Status: `PRÊT_NON_EXÉCUTÉ`

| Key | Evidence |
|---|---|
| DB_CONNECTION | `pgsql` |
| DB_HOST | configured, value redacted |
| DB_PORT | `5432` |
| DB_USERNAME | configured, value redacted |
| DB_PASSWORD | configured, value redacted, length >= 20 |
| DB_SSLMODE | `require` |
| Service databases | `portal_web`, `auth_users`, `chatbot_manager`, `conversation_service`, `audit_security` by default or explicit env overrides |

## Action

client dry-run only; no secret applied.

## Security note

No secret value is written to this report. The temporary env file is mode 600 and removed after execution.
