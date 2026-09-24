# Gestion des secrets — SecureRAG Hub

## Règles

1. **Jamais en clair dans git** pour une valeur de production.
2. `infra/k8s/overlays/*/portal-admin-secret.yaml` : à générer par e2e/provisioning ou utiliser SOPS.
3. Pour le dev local uniquement : secrets factices autorisés si `SECURITY_MODE=dev`.
4. Production : External Secrets Operator (ESO) ou SOPS (`sops -d ... | kubectl apply -f -`).

## Fichiers concernés

| Chemin | Sensibilité | Procedé recommandé |
|---|---|---|
| `infra/k8s/overlays/dev/portal-admin-secret.yaml` | dev local | Suivi mais marqué `dev-admin-token-change-me` |
| `infra/k8s/overlays/demo/portal-admin-secret.yaml` | demo locale | SOPS chiffré (voir `*.sops.yaml`) |
| `infra/k8s/overlays/production/portal-admin-secret.yaml` | **jamais en clair** | External Secrets (Vault) |
