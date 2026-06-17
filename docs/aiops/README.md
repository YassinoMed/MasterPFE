# AIOps — READ ONLY Mode

## Architecture
- **Ollama** : LLM local (CPU, pas GPU), port 11434
- **OpenWebUI** : Interface web, port 8080
- **LangGraph** : Pipeline d'analyse prêt à être déployé
- **Mode** : READ ONLY — accès Prometheus + Loki + Alertmanager uniquement
- **Interdit** : Jenkins, ArgoCD, Vault, Harbor (aucun accès)

## Feature Flag
`ENABLE_AIOPS=false` (défaut)

## Installation
```bash
kubectl create namespace aiops-system
kubectl apply -f infra/k8s/aiops/deployment.yaml
```

## Validation
```bash
kubectl get pods -n aiops-system
kubectl port-forward -n aiops-system svc/openwebui 8080:8080
curl http://localhost:8080
```

## Fonctions (après activation)
- Analyse des logs Loki (dernière heure, erreurs)
- Résumé des alertes Prometheus
- RCA automatique (corrélation logs/alertes)
- Détection d'anomalies (baseline metrics)

## Rollback
```bash
kubectl delete ns aiops-system --timeout=60s
```

## Risques
| Risque | Probabilité | Impact | Mitigation |
|--------|:----------:|:------:|------------|
| Consommation RAM Ollama | Élevée | Faible | emptyDir, pas de GPU |
| Accès non autorisé | Nulle | Faible | READ ONLY mode |
| Latence analyse | Faible | Faible | CronJob asynchrone |

## Dépendances
- Prometheus (read-only HTTP)
- Loki (read-only HTTP)
- Aucune dépendance sur les services métier
