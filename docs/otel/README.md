# OpenTelemetry + Tempo — Traces Distribuées

## Architecture
- **Collector** : reçoit OTLP (gRPC:4317, HTTP:4318) → exporte vers Tempo
- **Tempo** : stockage local, query frontend sur `tempo.otel-system.svc:3200`
- **Grafana** : datasource Tempo ajoutée → `http://tempo.otel-system.svc:3200`

## Feature Flag
`ENABLE_OPENTELEMETRY=false` (défaut)

## Installation
```bash
# Ajouter datasource Tempo dans Grafana (manuel ou via ConfigMap)
kubectl create namespace otel-system
kubectl apply -f infra/k8s/otel/deployment.yaml
```

## Validation
```bash
# Vérifier les pods
kubectl get pods -n otel-system

# Tester le collector
kubectl run otel-test --rm -i --restart=Never --image=curlimages/curl -n otel-system -- \
  curl -s -o /dev/null -w "%{http_code}" http://otel-collector.otel-system.svc:8888/metrics

# Vérifier Tempo
kubectl port-forward -n otel-system svc/tempo 3200:3200
curl http://localhost:3200/ready
```

## Rollback
```bash
kubectl delete ns otel-system --timeout=60s
# Grafana datasource : supprimer manuellement la datasource Tempo
```

## Risques
| Risque | Probabilité | Impact | Mitigation |
|--------|:----------:|:------:|------------|
| Surcharge mémoire Tempo | Faible | Faible | emptyDir, pas PVC |
| Latence réseau OTLP | Faible | Faible | gRPC compressé |
| Conflit namespace | Nul | Nul | Namespace dédié |

## Dépendances
- Grafana (datasource additionnelle)
- Aucune dépendance sur les services métier
