# Production SLO and Alerting Runbook - SecureRAG Hub

## Objectif

Fixer des SLO minimaux, réalistes et démontrables pour le périmètre
DevSecOps/Kubernetes production-like.

## SLO minimaux

| SLO | Cible production-like | Preuve |
|---|---:|---|
| Disponibilité portail health | 99% sur fenêtre de démonstration | `curl /health`, readiness pods |
| Pods officiels Ready | 100% des replicas attendus | `kubectl get deploy,pods` |
| HPA exploitable | aucune cible `<unknown>` | `artifacts/validation/hpa-runtime-report.md` |
| PDB actifs | `ALLOWED DISRUPTIONS >= 1` pour au moins les workloads critiques | `kubectl get pdb` |
| Admission Audit | Kyverno policies + PolicyReports présents | `kyverno-runtime-report.md` |
| Release digest-only | 100% images déployées par digest promu | `promotion-digests.txt`, `no-rebuild-deploy-summary.md` |

## Alertes minimales

| Alerte | Condition | Action |
|---|---|---|
| Pods non Ready | `availableReplicas < desired` pendant 5 min | Runbook incident HA |
| HPA unknown | target CPU/memory `<unknown>` | Vérifier metrics-server |
| Kyverno reports fail | fail/error dans PolicyReports | Revenir Audit, corriger manifest |
| PDB bloque maintenance | `ALLOWED DISRUPTIONS=0` durable | Vérifier replicas/Ready |
| Release evidence missing | attestation non `COMPLETE_PROVEN` | Bloquer promotion |
| Backup absent | pas de backup dans la fenêtre prévue | Lancer `make data-backup` |

## Commandes de preuve

```bash
make production-proof-full
make refresh-hpa-runtime-proof
make kyverno-runtime-proof
make observability-snapshot
make security-posture
```

## Option stack observabilité

Prometheus/Grafana/Loki peuvent être ajoutés plus tard. Ils restent optionnels :
le projet doit d'abord conserver des preuves `kubectl`, HPA, events, logs et
PolicyReports exploitables.
