# Plan d'améliorations — SecureRAG Hub

**Généré le :** 2026-06-18T17:13:07Z  
**Score actuel :** 97-98/100  
**Objectif :** 100/100

---

## 1. Istio — Réinjection des sidecars + tuning probes

**Problème :** Les pods avec sidecars Istio crashloopent (app container exit 0). L'injection a été désactivée pour stabiliser le cluster.

**Actions :**
- Ajouter `initialDelaySeconds: 45` et `periodSeconds: 15` aux liveness/readiness probes des 5 déploiements
- Ajouter `holdApplicationUntilProxyStarts: true` sur l'IstioOperator
- Réactiver `istio-injection=enabled` sur le namespace `securerag-hub`
- Valider avec `istioctl proxy-status` — tous les pods doivent être `SYNCED`

**Priorité :** Haute | **Impact :** +0.5 pt

---

## 2. OpenCost — Correction des flags CLI

**Problème :** `ghcr.io/opencost/opencost:latest` ne supporte plus `--kubecost-namespace` ni `--prometheus-server-endpoint`. CrashLoopBackOff.

**Actions :**
- Remplacer par `opencost/opencost:1.108.x` (version stable)
- Ou utiliser l'installation Helm : `helm install opencost opencost/opencost`
- Flags corrects pour latest : `--prometheus-url`, `--cluster-id`

**Priorité :** Haute | **Impact :** +0.5 pt

---

## 3. Chaos Mesh — Automatisation via Schedule CRDs

**Problème :** Les 6 expériences sont one-shot (appliquées manuellement, durée limitée).

**Actions :**
- Créer 6 `Schedule` CRDs wrapant chaque expérience
- Cron: `@every 1h` pour pod-kill, `@every 3h` pour stress, `@every 6h` pour postgres-outage
- Ajouter un `Workflow` Chaos Mesh pour exécuter les expériences en séquence
- Mesurer RTO (target < 60s) et Availability (target > 99.5%) après chaque run

**Priorité :** Moyenne | **Impact :** +0.5 pt

---

## 4. Kiali — Exposition via IngressGateway

**Problème :** Kiali est accessible seulement en ClusterIP:20001 dans le cluster.

**Actions :**
- Ajouter une `VirtualService` dans `istio-system` routant `/kiali` vers le service `kiali:20001`
- Configurer l'auth Kiali en mode `anonymous` ou intégrer avec OIDC
- Valider l'accès via `http://localhost:30081/kiali`

**Priorité :** Moyenne | **Impact :** +0.25 pt

---

## 5. k6 — Load test complet avec auth-users stabilisé

**Problème :** auth-users OOMKilled à 10 VUs (memory limit 256Mi insuffisante). Seulement 9% de success.

**Actions :**
- Augmenter memory limit de auth-users à 512Mi (comme portal-web)
- Re-run le load test (10 VUs, 2 min)
- Ajouter un test spike (20 VUs, 30s) et soak (5 VUs, 10 min)
- Publier les résultats p50/p95/p99 dans le rapport

**Priorité :** Moyenne | **Impact :** +0.5 pt

---

## 6. DORA — Dashboard + collecte réelle

**Problème :** Les 4 recording rules Prometheus sont déployées mais sans exporteur de métriques DORA réel (GitHub/Jenkins).

**Actions :**
- Déployer le Grafana dashboard DORA (11 panels dans `infra/k8s/dora/grafana-dashboard-dora.yaml`)
- Configurer jenkins-exporter pour `deployment_frequency` et `lead_time`
- Configurer github-exporter pour les PRs mergées
- Classifier par niveau DORA (Elite/High/Medium/Low)

**Priorité :** Moyenne | **Impact :** +0.5 pt

---

## 7. SLO — Alertmanager + escalade

**Problème :** Les règles SLO brûlent des alertes Prometheus mais aucun Alertmanager/config d'escalade.

**Actions :**
- Déployer Alertmanager avec routing par sévérité (critical → PagerDuty, warning → Slack)
- Configurer les notifications pour les burn rate alerts (multi-window)
- Ajouter un runbook SLO dans `docs/runbooks/slo-burn-rate.md`

**Priorité :** Basse | **Impact :** +0.25 pt

---

## 8. Tetragon — Tests d'intrusion automatisés

**Problème :** Les 5 TracingPolicies sont appliquées mais aucun test automatisé ne valide qu'elles détectent bien les menaces.

**Actions :**
- Exécuter `scripts/tetragon/test-tetragon-policies.sh` pour valider chaque politique
- Vérifier que les événements apparaissent dans les logs Tetragon
- Intégrer les résultats dans le pipeline CI

**Priorité :** Basse | **Impact :** +0.25 pt

---

## Résumé des impacts

| Amélioration | Priorité | Impact | Effort estimé |
|---|---|---|---|
| Istio sidecars + probes | Haute | +0.5 | 1h |
| OpenCost flags | Haute | +0.5 | 30min |
| Chaos Mesh Schedules | Moyenne | +0.5 | 1h |
| Kiali ingress | Moyenne | +0.25 | 30min |
| k6 load test | Moyenne | +0.5 | 1h |
| DORA dashboard | Moyenne | +0.5 | 2h |
| SLO Alertmanager | Basse | +0.25 | 1h |
| Tetragon tests | Basse | +0.25 | 30min |
| **Total potentiel** | | **+3.25** | **~8h** |
