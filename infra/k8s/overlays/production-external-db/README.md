# SecureRAG Hub production external DB overlay

This overlay is the production-grade data posture. It keeps the regular
`production` overlay intact for kind demonstrations, but replaces SQLite with an
external PostgreSQL endpoint injected through `securerag-database-secrets`.

## Required secret

Create the secret outside Git before deploying this overlay. Preferred
repository command:

```bash
DB_HOST='<postgres-host>' \
DB_USERNAME='<postgres-user>' \
DB_PASSWORD='<postgres-password-minimum-20-characters>' \
make production-db-secret
```

Manual equivalent:

```bash
kubectl create secret generic securerag-database-secrets \
  -n securerag-hub \
  --from-literal=DB_CONNECTION=pgsql \
  --from-literal=DB_HOST='<postgres-host>' \
  --from-literal=DB_PORT='5432' \
  --from-literal=DB_USERNAME='<postgres-user>' \
  --from-literal=DB_PASSWORD='<postgres-password>' \
  --from-literal=DB_SSLMODE='require' \
  --from-literal=PORTAL_WEB_DB_DATABASE='portal_web' \
  --from-literal=AUTH_USERS_DB_DATABASE='auth_users' \
  --from-literal=CHATBOT_MANAGER_DB_DATABASE='chatbot_manager' \
  --from-literal=CONVERSATION_SERVICE_DB_DATABASE='conversation_service' \
  --from-literal=AUDIT_SECURITY_SERVICE_DB_DATABASE='audit_security'
```

The repository also contains an optional SOPS/age template under
`infra/secrets/production/`. It is not active by default.

## Deploy

```bash
KUSTOMIZE_OVERLAY=infra/k8s/overlays/production-external-db \
REGISTRY_HOST=securerag-registry:5000 \
IMAGE_PREFIX=securerag-hub \
IMAGE_TAG=release-local \
bash scripts/deploy/deploy-kind.sh
```

## Honest status

- Static readiness: complete when this overlay renders without SQLite.
- Runtime readiness: complete only after migrations, backup and isolated restore
  have been executed and archived.
