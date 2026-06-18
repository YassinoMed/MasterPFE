# 30 — Observabilité

> **Date :** 2026-06-18  
> **Verdict :** ⚠️ WARNING

---

## Résumé Exécutif

Les composants core d'observabilité sont déployés (Prometheus, Grafana, Loki, Alertmanager). Mais les CRDs PrometheusRules et ServiceMonitors ne sont pas installés, limitant les capacités d'alerting et de scraping avancé.

---

## Composants Déployés

| Composant | Statut | Uptime | Endpoint |
|-----------|:------:|:------:|----------|
| Prometheus | ✅ Running | 40h | NodePort 30909 |
| Grafana | ✅ Running | 40h | NodePort 30300 |
| Loki | ✅ Running | 40h | ClusterIP |
| Alertmanager | ✅ Running | 40h | ClusterIP |
| kube-state-metrics | ✅ Running | 17h | ClusterIP |
| metrics-server | ✅ Running | 28h | ClusterIP |

---

## Composants Manquants

| Composant | Statut | Raison |
|-----------|:------:|--------|
| PrometheusRules CRD | ❌ Non installé | kube-prometheus-stack manquant |
| ServiceMonitor CRD | ❌ Non installé | kube-prometheus-stack manquant |
| Tempo | ❌ Non déployé | Tracing distribué |
| OpenTelemetry Collector | ❌ Non déployé | Collecteur traces |
| 28 ServiceMonitors | ⚠️ Configs prêtes | Non appliquées |

---

## Dashboards Grafana

| Dashboard | Statut |
|-----------|:------:|
| SLO & Error Budget v2 | ✅ Config prête (11 panels) |
| Kubernetes Core | ✅ Config prête |
| Trivy Operator | ✅ Config prête |
| Tetragon | ✅ Config prête |
| SPIRE | ✅ Config prête |
| Ratify | ✅ Config prête |
| Vault Dynamic Secrets | ✅ Config prête |
| CIS Benchmark | ✅ Config prête |
| OpenSearch SIEM | ✅ Config prête |
| SLSA Supply Chain | ✅ Config prête |
| Error Budget | ✅ Config prête |
| AIOps | ✅ Config prête |

---

## Score Observabilité

| Métrique | Score |
|----------|:-----:|
| Core stack (Prometheus/Grafana/Loki) | 100% |
| Alerting | 50% (Alertmanager OK, rules non définies) |
| Dashboards | 80% (configs prêtes, non déployées) |
| Tracing | 0% (Tempo non déployé) |
| **Score** | **65%** |

---

## Recommandations

1. Installer kube-prometheus-stack pour les CRDs (PrometheusRules, ServiceMonitors)
2. Déployer Tempo pour le tracing distribué
3. Appliquer les 28 ServiceMonitors
4. Appliquer les dashboards Grafana ConfigMaps

---

## Conclusion

L'observabilité core est solide. L'installation des CRDs manquants et le tracing sont les priorités.
