# SecureRAG Hub — Observabilité

Stack autonome (sans opérateur) :

- **Prometheus** v2.54 — scrape pods annotés `prometheus.io/scrape=true`,
  conserve 15 jours (10 GB max).
- **Grafana** 11 — provisionne datasources Prometheus/Loki/Alertmanager et
  un dashboard "SecureRAG Hub — Overview" en lecture seule.
- **Loki** 3.1 (single-binary, filesystem) — logs 7 jours.
- **Alertmanager** 0.27 — 6 règles SLO (Pod down, latence p95, error rate,
  CPU/RAM saturation, crashloop).

## Déploiement

```bash
kubectl apply -k infra/k8s/observability
kubectl rollout status -n securerag-monitoring deploy/prometheus --timeout=180s
kubectl rollout status -n securerag-monitoring deploy/grafana --timeout=180s
kubectl rollout status -n securerag-monitoring deploy/loki --timeout=180s
kubectl rollout status -n securerag-monitoring deploy/alertmanager --timeout=180s
```

## Accès local

```bash
# Grafana (admin / cf. Secret grafana-admin — à rotated en SOPS)
kubectl -n securerag-monitoring port-forward svc/grafana 3000:3000
# Prometheus
kubectl -n securerag-monitoring port-forward svc/prometheus 9090:9090
# Alertmanager
kubectl -n securerag-monitoring port-forward svc/alertmanager 9093:9093
```

## Annotations attendues sur les services Laravel

```yaml
metadata:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/path: "/metrics"
    prometheus.io/port: "9000"
```

## Statut

- `PRÊT_NON_EXÉCUTÉ` : manifests présents et validés `kustomize build`.
- `TERMINÉ` après `make observability-up` réussi + dashboard Grafana
  affichant des métriques live + preuve archivée
  `artifacts/observability/observability-stack-proof.md`.
