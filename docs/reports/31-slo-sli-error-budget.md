# 31 — SLO / SLI / Error Budget

> **Date :** 2026-06-18  
> **Verdict :** ⚠️ DESIGNED, NOT ENFORCED

---

## Résumé Exécutif

Les SLO sont définis avec des cibles par service (99.5% à 99.95%). Le dashboard Grafana est conçu (11 panels, multi-window burn rate). Mais les PrometheusRules ne sont pas installées, donc les SLO ne sont pas mesurés en production.

---

## Cibles SLO par Service

| Service | Availability | Latency p95 | Fenêtre |
|---------|:------------:|:-----------:|:-------:|
| portal-web | 99.9% | < 500ms | 30d |
| auth-users | 99.95% | < 300ms | 30d |
| chatbot-manager | 99.5% | < 2s | 30d |
| conversation-service | 99.9% | < 300ms | 30d |
| audit-security-service | 99.9% | < 300ms | 30d |

---

## Dashboard SLO

| Panneau | Type |
|---------|------|
| Availability SLO (5m) | Stat |
| Error Budget Remaining | Gauge |
| Burn Rate (1h) | Stat |
| p95 Latency | Stat |
| Availability SLI Trend | Timeseries |
| Error Budget Burn Rate | Timeseries |
| Error Rate by Service | Timeseries |
| Multi-window Burn Rate | Table |

---

## Recording Rules (configurées, pas appliquées)

| Rule | Description |
|------|-------------|
| `securerag:sli:availability:rate5m` | SLI availability |
| `securerag:slo:error_budget_remaining:minutes` | Budget restant |
| `securerag:slo:burn_rate_1h` | Taux de consommation |

---

## Recommandations

1. Installer les CRDs PrometheusRules
2. Appliquer les recording rules SLO
3. Configurer les alertes multi-window burn rate
4. Mesurer les SLO sur 30 jours glissants

---

## Conclusion

Les SLO sont bien conçus mais pas mesurés. L'installation des CRDs est le blocage principal. Score : 80% (conception) × 50% (exécution) = 40%.
