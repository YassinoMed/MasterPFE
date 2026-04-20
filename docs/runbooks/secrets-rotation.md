# Secrets Rotation Runbook - SecureRAG Hub

## Objectif

Décrire une rotation crédible des secrets sans exposer les valeurs dans Git ou
dans les artefacts.

## Périmètre

| Secret | Rotation | Impact | Preuve |
|---|---|---|---|
| `SECURERAG_SHARED_API_TOKEN` | Regénérer dans `security/secrets/.env.local`, réappliquer `securerag-common-secrets` | Redémarrage workloads recommandé | `make secrets-management` |
| `APP_KEY` | Rotation planifiée uniquement | Peut rendre illisibles les données Laravel chiffrées | ticket/runbook dédié |
| DB externe | Regénérer côté PostgreSQL, puis `make production-db-secret` | Redémarrage workloads + test connexion | `artifacts/security/production-db-secret.md` |
| Cosign keypair | Créer nouvelle paire, mettre à jour Jenkins credentials | Anciennes signatures à conserver pour audit | `sign-summary.md`, `verify-summary.md` |
| Sonar token | Regénérer côté Sonar, mettre à jour Jenkins credential | Prochaine analyse Sonar | `security/reports/sonar-analysis.md` |
| Jenkins admin/API token | Regénérer côté Jenkins | Session/API Jenkins | preuve Jenkins sans valeur |

## Procédure DB externe

Action mutative sur le cluster cible :

```bash
DB_HOST='<postgres-host>' \
DB_USERNAME='<postgres-user>' \
DB_PASSWORD='<new-strong-password>' \
make production-db-secret

kubectl rollout restart deploy -n securerag-hub
kubectl rollout status deploy/portal-web -n securerag-hub
```

## Procédure SOPS/age optionnelle

```bash
sops --encrypt infra/secrets/production/securerag-database-secrets.plain.yaml \
  > infra/secrets/production/securerag-database-secrets.enc.yaml

sops --decrypt infra/secrets/production/securerag-database-secrets.enc.yaml \
  | kubectl apply -f -
```

## Critères de succès

- Aucun secret réel dans Git.
- Les rapports n'affichent jamais la valeur des secrets.
- `make secrets-management` passe.
- Les workloads sont `Ready` après rollout.
