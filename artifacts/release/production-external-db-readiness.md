# Production External DB Readiness - SecureRAG Hub

- Generated at UTC: `2026-07-18T13:10:14Z`
- Overlay: `infra/k8s/overlays/production-external-db`

| Control | Status | Evidence |
|---|---:|---|
| External DB overlay render | TERMINÉ | `infra/k8s/overlays/production-external-db` renders successfully |
| SQLite removed from external DB overlay | FAIL | `infra/k8s/overlays/production-external-db` still renders SQLite |
| Kubernetes Secret references | TERMINÉ | workloads reference `securerag-database-secrets` |
| Direct secret bootstrap | TERMINÉ | `scripts/secrets/create-production-db-secret.sh` executable |
| SOPS bootstrap path | TERMINÉ | `scripts/secrets/apply-sops-production-db-secret.sh` executable |
| External Secrets bootstrap path | TERMINÉ | `scripts/secrets/render-production-db-external-secret.sh` executable |
| Direct secret runtime evidence | PRÊT_NON_EXÉCUTÉ | `artifacts/security/production-db-secret.md` |
| SOPS runtime evidence | PRÊT_NON_EXÉCUTÉ | `artifacts/security/sops-production-db-secret.md` |
| External Secrets runtime evidence | PRÊT_NON_EXÉCUTÉ | `artifacts/security/external-secrets-runtime.md` |

## Global status

Statut global: `FAIL`

## Interpretation

Blocking static gaps remain in the external database readiness path. Fix FAIL rows before calling it production-ready.
