# Phase 8 — Observability Audit

Ce document présente l'audit de la stack d'observabilité (Prometheus, Grafana, Loki, Tempo, OpenTelemetry) de la plateforme, incluant la couverture des métriques, des logs et des traces.

---

## 1. Cartographie de la Stack d'Observabilité

La plateforme dispose d'une infrastructure d'observabilité mature, structurée dans le namespace `securerag-monitoring`.

### 1.1 Collecte des Métriques (Prometheus & ServiceMonitors)
*   **Moteur** : Prometheus s'exécute sous forme de Déploiement Kubernetes.
*   **Couverture (28 ServiceMonitors)** : La plateforme collecte les métriques système, K8s et applicatives grâce à 28 ServiceMonitors ciblés (`infra/k8s/monitoring/`). Ils couvrent :
    *   Les microservices applicatifs Laravel et Python.
    *   L'infrastructure (Qdrant, PostgreSQL, MinIO, Vault, ESO, Cert-Manager).
    *   L'Ingress Kong.
*   **Règles d'Alerte** : 57 alertes Prometheus configurées (`prometheus-rules-security.yaml` et `prometheus-rules.yaml`) couvrant les taux d'erreur HTTP 5xx, l'épuisement des ressources CPU/RAM et les alertes de sécurité runtime.

### 1.2 Centralisation des Logs (Loki & Promtail)
*   **Moteur** : Loki est déployé en tant que service de stockage de logs.
*   **Collecte** : Le DaemonSet Promtail est déployé sur tous les nœuds Kubernetes. Il capture automatiquement les flux `stdout` et `stderr` de l'ensemble des conteneurs du cluster et les pousse vers Loki.
*   **Rétention** : Rétention configurée à 7 jours par défaut.

### 1.3 Tracing Distribué (OpenTelemetry & Tempo)
*   **Moteur** : OpenTelemetry Collector (`infra/k8s/otel/`) et Grafana Tempo sont prévus dans l'architecture.
*   **Statut opérationnel** : **Inactif**. Le tracing distribué (Tempo et l'injection d'headers de trace W3C) est désactivé par défaut (le feature flag `otel.enabled` est à `false`).

---

## 2. Analyse de Couverture (Metrics, Logs, Traces)

```
  Métriques (Prometheus)   [█████████████████████] 95%
  Logs (Loki/Promtail)    [████████████████████] 90%
  Traces (Tempo/OTel)     [██] 10%
```

### 2.1 Couverture des Métriques : 95%
*   **Forces** : Pratiquement toutes les API métiers et d'infrastructure publient des métriques Prometheus. L'intégration de Grafana permet une visualisation immédiate via 24 dashboards dédiés (dont un dashboard avancé pour les SLOs et les budgets d'erreurs).
*   **Faiblesses** : Les métriques Qdrant et Ollama ne sont pas entièrement corrélées avec les tableaux de bord applicatifs principaux.

### 2.2 Couverture des Logs : 90%
*   **Forces** : Tous les logs système et applicatifs sont ingérés. Intégration de Falco pour transformer les logs système eBPF en métadonnées de sécurité ingérées par Loki.
*   **Faiblesses** : Absence de persistance des disques de Loki (emptyDir par défaut). En cas de crash du pod Loki, l'historique complet des logs d'audit est perdu, ce qui représente un risque de conformité SOC2/ISO27001 critique.

### 2.3 Couverture des Traces : 10%
*   **Forces** : Les librairies d'instrumentation OTel sont configurées dans le code applicatif Python/Laravel, prêtes à émettre des spans.
*   **Faiblesses** : Le collecteur OTel et Tempo étant désactivés en production locale Kind, il est impossible de suivre une requête utilisateur d'un bout à l'autre de la stack (ex. Portail -> API Gateway -> Chatbot Manager -> Qdrant -> Ollama) pour identifier précisément les goulots d'étranglement de latence.

---

## 3. Scoreboard Observabilité

### Note Globale : 86/100 (Observability Score)

| Critère d'Évaluation | Score | Justification |
| :--- | :--- | :--- |
| **Couverture Métriques** | 95/100 | ServiceMonitors complets, 57 règles d'alerte configurées, dashboards Grafana très avancés. |
| **Couverture Logs** | 90/100 | Promtail capture 100% des flux logs, mais la perte d'historique sur `emptyDir` Loki est une vulnérabilité critique. |
| **Couverture Traces** | 10/100 | Tempo et OTel désactivés par défaut sur le runtime actif. |
| **Persistance des Données** | 50/100 | Prometheus, Loki et Grafana s'exécutent sur du stockage temporaire (`emptyDir`) par défaut. |
