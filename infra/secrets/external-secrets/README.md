# External Secrets Operator / Vault production-like path

This directory contains the repository-side artifacts for a modern secret
delivery path based on External Secrets Operator.

The default templates assume a Vault-like key/value backend, but the target
`SecretStore` or `ClusterSecretStore` reference can be changed without touching
application manifests.

## Included templates

- `cluster-secret-store.vault.template.yaml`
- `securerag-database.external-secret.template.yaml`

## Render without exposing values

```bash
make external-secret-render
```

The rendered manifest is written under `artifacts/security/` and contains only
metadata and backend references, never secret values.

## Runtime proof

Apply the rendered `ExternalSecret` and a real `SecretStore` or
`ClusterSecretStore`, then run:

```bash
make external-secret-runtime-proof
```

## Honest status

- `TERMINÉ` repository-side when templates and rendering scripts exist.
- `PRÊT_NON_EXÉCUTÉ` until an operator-managed runtime sync has been replayed.
- `TERMINÉ` runtime-side only when the `ExternalSecret` is Ready and the target
  Secret `securerag-database-secrets` exists in the cluster.
