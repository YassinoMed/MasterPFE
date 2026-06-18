# 34 — AIOps

> **Date :** 2026-06-18  
> **Verdict :** ⚠️ NOT DEPLOYED

---

## Résumé Exécutif

Les règles AIOps sont définies (5 alertes, 4 rules d'enregistrement) mais pas appliquées. Les CRDs PrometheusRules ne sont pas installés.

---

## Règles Définies

| Règle | Type | Seuil | Sévérité |
|-------|:----:|:-----:|:--------:|
| CPUAnomalyDetected | Z-score > 2σ | 10 min | Warning |
| MemoryAnomalyDetected | Z-score > 2σ | 10 min | Warning |
| LatencySpikeDetected | Ratio > 2x baseline | 5 min | Warning |
| ErrorRateSpikeDetected | Ratio > 3x baseline | 5 min | Critical |
| aiops:predict_disk_full_days | Prédictif | 30 jours | Warning |

---

## Dashboard AIOps

| Panneau | Type |
|---------|------|
| CPU Anomaly Detection | Timeseries |
| Memory Anomaly Detection | Timeseries |
| Latency Spike Detection | Timeseries |
| Error Rate Spike | Timeseries |
| Predictive Disk Full | Gauge |
| Anomaly Score by Service | Heatmap |
| Resource Baseline vs Actual | Timeseries |
| Alert History | Table |

---

## Recommandations

1. Installer les CRDs PrometheusRules
2. Appliquer les règles AIOps
3. Ajuster les seuils après collecte de données baseline (7 jours)
4. Ajouter des alertes Slack/PagerDuty

---

## Conclusion

Les règles AIOps sont prêtes. L'installation des CRDs PrometheusRules débloquera l'ensemble. Score : 0% (non appliqué).
