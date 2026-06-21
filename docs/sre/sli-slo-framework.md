# SRE Framework — SLI, SLO, Error Budget

## Service Level Indicators (SLI)

| SLI | Métrique Prometheus | Cible |
|-----|---------------------|:-----:|
| Availability | `up{job="portal-web"}` | 99.9 % |
| Latency (p95) | `histogram_quantile(0.95, rate(http_server_request_duration_seconds_bucket[5m]))` | < 500ms |
| Error Rate | `sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))` | < 1 % |
| Throughput | `sum(rate(http_requests_total[1m]))` | > 100 req/s |

## Service Level Objectives (SLO)

| SLO | Target | Window |
|-----|:------:|:------:|
| portal-web availability | 99.9 % | 30 days |
| API p95 latency | < 500ms | 30 days |
| Error rate | < 1 % | 7 days |
| Coverage | > 85 % | Per build |

## Error Budget

| Service | Monthly Budget | Alert at |
|---------|:-------------:|:--------:|
| portal-web | 43.2 min downtime | 80% consumed |
| auth-users | 43.2 min downtime | 80% consumed |
| chatbot-manager | 43.2 min downtime | 80% consumed |

## Prometheus SLO Alerts

```yaml
- alert: SLOErrorBudgetBurn
  expr: (1 - avg_over_time(probe_success{job="portal-web"}[30d])) > 0.001 * 0.8
  for: 5m
  labels: { severity: critical, slo: "availability-99.9" }
  annotations:
    summary: "SLO error budget burning for portal-web"
    description: "Error budget 80% consumed. Remaining: {{ $value | humanizeDuration }}"
```
