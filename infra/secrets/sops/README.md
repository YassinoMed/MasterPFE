# SOPS/age option for production-like secrets

This directory documents the optional modern secret-management path for
SecureRAG Hub.

It is not enabled by default because the local kind demonstration must stay
simple and deterministic. Use it for a production-like replay when an `age`
recipient and the `sops` binary are available.

## Flow

1. Copy `infra/secrets/production/securerag-database-secrets.template.yaml` to
   a local plaintext file ignored by Git.
2. Replace placeholder values locally.
3. Encrypt the file with SOPS/age.
4. Commit only the encrypted file.
5. Decrypt during deployment in Jenkins or on the operator workstation.

## Example commands

```bash
cp infra/secrets/production/securerag-database-secrets.template.yaml \
  infra/secrets/production/securerag-database-secrets.plain.yaml

sops --config infra/secrets/sops/sops-age.example.yaml \
  --encrypt infra/secrets/production/securerag-database-secrets.plain.yaml \
  > infra/secrets/production/securerag-database-secrets.enc.yaml

sops --decrypt infra/secrets/production/securerag-database-secrets.enc.yaml \
  | kubectl apply -f -
```

## Honest status

- `PRÊT_NON_EXÉCUTÉ`: templates and runbooks are present.
- `TERMINÉ`: an encrypted secret exists and has been applied to the target
  cluster, with evidence archived in `artifacts/security/production-db-secret.md`.
