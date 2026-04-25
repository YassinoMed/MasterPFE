# Observability Runbook - SecureRAG Hub

## Objectif

Opérer un profil SRE léger pour kind/VPS : Prometheus, Grafana, Loki, Alertmanager, dashboards minimaux, alertes et SLOs.

## Profil versionné

- `infra/observability/kube-prometheus-stack/values-kind.yaml`
- `infra/observability/loki/values-kind.yaml`
- `infra/observability/rules/securerag-slo-rules.yaml`
- `infra/observability/dashboards/securerag-sre-dashboard.configmap.yaml`
- `infra/observability/servicemonitors/portal-health.yaml`

## Validation

```bash
make observability-stack-proof
```

Artefacts :

- `artifacts/observability/prometheus-targets.md`
- `artifacts/observability/grafana-dashboard-proof.md`
- `artifacts/observability/loki-logs-proof.md`
- `artifacts/observability/alertmanager-rules.md`
- `artifacts/observability/slo-summary.md`

## SLOs

- portail health disponible > 99 % ;
- pods officiels Ready > 99 % ;
- P95 health < 500 ms.

## Diagnostic

Si les rapports sont `PRÊT_NON_EXÉCUTÉ`, installer le stack monitoring puis appliquer `kubectl apply -k infra/observability`.
