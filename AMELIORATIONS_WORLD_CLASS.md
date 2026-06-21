# SecureRAG Hub — Plan d'Améliorations World-Class (97-98/100)

> **Baseline :** 93/100 (Score Final 2026-06-18)
> **Cible :** 97-98/100
> **Vision :** Plateforme opérationnelle sur cluster réel, résiliente, observable, livrée en continu

---

## ⚠️ Prérequis — Cluster Réel

Toutes les améliorations supposent un cluster **non-kind** (EKS, AKS, GKE, ou K3s HA).
Tant que vous êtes sur kind, la note plafonne à ~93 quoi que vous fassiez.

| Option | Coût | Effort |
|--------|:----:|:------:|
| **K3s HA** (3 VPS chez Hetzner/OVH) | ~15-25 €/mois | 1 jour |
| **EKS** (AWS via Terraform) | ~50-100 €/mois | 2-3 jours |
| **AKS** (Azure via Terraform) | ~50-100 €/mois | 2-3 jours |

**Recommandé : K3s HA** — valide le multi-nœud, multi-AZ, sans coût cloud récurrent.

---

## Phase 1 — Fondations (3-5 jours, impact ~3 points)

### 1.1 Déployer Vault + ESO pour de vrai

| Fichier | Action |
|---------|--------|
| `scripts/deploy/deploy-vault-and-eso.sh` | Exécuter sur le cluster réel |
| `infra/k8s/overlays/production/kustomization.yaml` | Ajouter `../../vault` aux resources |
| `infra/k8s/secrets/eso-cluster-secret-store.yaml` | Vérifier l'adresse du service Vault |
| Jenkinsfile | Passer `DEPLOY_VAULT=true` par défaut |

**Validation :** `kubectl get external-secrets -A` → Tous `SecretSynced`

### 1.2 Activer Velero + exécuter un restore test complet

| Fichier | Action |
|---------|--------|
| `scripts/deploy/deploy-velero.sh` | Exécuter sur le cluster réel |
| `scripts/dr/full-restore-drill.sh --full` | Exécuter et capturer les métriques RTO/RPO |
| Jenkinsfile | Passer `DEPLOY_VELERO=true` par défaut |
| Jenkinsfile | Déplacer `Backup Validation` du nightly vers `always` |

**Validation :** Rapport RTO < 60s, RPO < 1h, intégrité des données vérifiée

### 1.3 Câbler ArgoCD en mode App-of-Apps complet

| Fichier | Action |
|---------|--------|
| `infra/k8s/argocd/` | Ajouter les Applications manquantes (CloudNativePG, Istio, Chaos) |
| `infra/k8s/overlays/production/kustomization.yaml` | Décommenter / nettoyer la délégation ArgoCD |
| `scripts/gitops/bootstrap-gitops.sh` | Tester sur le cluster réel, automatiser le sync |

**Validation :** `argocd app list` → Tout `Synced` et `Healthy`

---

## Phase 2 — Résilience & SRE (3-5 jours, impact ~2 points)

### 2.1 PostgreSQL HA avec CloudNativePG

| Fichier | Action |
|---------|--------|
| `infra/k8s/database/cloudnativepg/` | Ajouter aux resources du overlay production |
| `infra/k8s/argocd/application-cnpg.yaml` | Créer l'Application ArgoCD |
| `infra/k8s/base/postgres-auth/` | Remplacer par la CNPG (ou patcher le service) |
| Script de migration | Basculer les 5 services vers le cluster CNPG |

**Validation :** `kubectl get cluster -n securerag-hub` → 3/3 instances Ready, switchover fonctionnel

### 2.2 Multi-AZ & Disaster Recovery drill destructif

| Fichier | Action |
|---------|--------|
| `scripts/dr/full-restore-drill.sh --full` | Ajouter un flag `--destructive` qui : scale-down tout, restore depuis Velero, valide |
| `scripts/dr/cross-region-failover.sh` | Finaliser et tester |
| Nouveau : SLO multi-AZ | Ajouter une règle Prometheus `kube_pod_status_phase` par zone |

**Validation :** Full DR drill exécuté sans échec, RTO/RPO documentés

### 2.3 Chaos Engineering automatisé dans le pipeline

| Fichier | Action |
|---------|--------|
| `infra/k8s/overlays/production/kustomization.yaml` | Ajouter `../../chaos` aux resources |
| Jenkinsfile | Ajouter stage `CI: Chaos Engineering` (appel à `run-chaos-pipeline.sh`) |
| `tests/chaos/` | Ajouter scénario réseau (network-loss, DNS outage) |
| Nouveau : CronJob Chaos | Créer un CronJob qui lance un scénario aléatoire à 3h du matin |

**Validation :** Pipeline CI avec chaos stage en vert, rapport Aftermath disponible

---

## Phase 3 — Observabilité & Performance (2-3 jours, impact ~1.5 points)

### 3.1 k6 intégré dans le pipeline CI

| Fichier | Action |
|---------|--------|
| Jenkinsfile | Ajouter stage `CI: Performance — k6` entre Deploy et DAST |
| `scripts/performance/run-k6-tests.sh` | Configurer le mode `--ci` (exit code = échec si SLO non tenu) |
| `tests/load/k6-thresholds.js` | Ajuster les seuils (p95 < 500ms, p99 < 1s) |

**Validation :** Commit qui dégrade les perfs → pipeline rouge

### 3.2 SLO/SLI enrichis avec Error Budget "réel"

| Fichier | Action |
|---------|--------|
| `infra/k8s/monitoring/slo-error-budget.yaml` | Ajouter `multiwindow` multi-window burn-rate alerter |
| Dashboard Grafana | Ajouter panneau "Budget restant (%)" par service |
| Nouveau : AlertManager route | Ajouter route pour SLO burn-rate → Pager (ou équivalent) |

**Validation :** Burn-rate alerte feu rouge si budget consommé à 50% en 1h

---

## Phase 4 — Service Mesh & Sécurité (2-3 jours, impact ~1 point)

### 4.1 Activer Istio (mTLS + canary)

| Fichier | Action |
|---------|--------|
| `infra/k8s/overlays/production/kustomization.yaml` | Ajouter `../../istio` aux resources |
| `infra/k8s/argocd/application-istio.yaml` | Créer l'Application ArgoCD |
| `infra/k8s/istio/peer-authentication.yaml` | Passer de PERMISSIVE à STRICT |
| `infra/k8s/istio/virtual-services.yaml` | Décommenter le canary (5% → 50% → 100%) |

**Validation :** `istioctl proxy-status` → Tout SYNCED, mTLS actif

### 4.2 Finaliser la sécurité runtime

| Fichier | Action |
|---------|--------|
| `infra/k8s/policies/kyverno-enforce/` | Déployer les policies en mode enforce (pas audit) |
| `security/falco/` | Ajouter règles de détection d'exfiltration |
| Nouveau : Vault rotation CronJob | Vérifier que le rotation automatique des secrets tourne |

**Validation :** Falco rules testées avec un pod malveillant, alerte reçue

---

## Phase 5 — Polish & Documentation (1-2 jours, impact ~0.5 point)

| Fichier | Action |
|---------|--------|
| `docs/runbooks/` | Centraliser les runbooks dans un dossier unique |
| `docs/ARCHITECTURE-DECISION-RECORDS/` | Compléter les ADRs manquants (ADR-005 à ADR-010) |
| Nouveau : dashboard FinOps | Configurer OpenCost avec budget alerts |
| Nouveau : DORA Four Keys | Créer un dashboard Grafana avec deploy frequency, lead time, MTTR, CFR |

---

## Résumé de l'impact

| Phase | Points gagnés | Temps | Difficulté |
|:-----:|:-------------:|:-----:|:----------:|
| 1. Fondations (cluster réel + Vault + Velero + ArgoCD) | **+3** | 3-5j | ★★☆ |
| 2. Résilience (CNPG + DR + Chaos) | **+2** | 3-5j | ★★★ |
| 3. Observabilité (k6 + SLO) | **+1.5** | 2-3j | ★★☆ |
| 4. Service Mesh & Sécurité | **+1** | 2-3j | ★★★ |
| 5. Polish | **+0.5** | 1-2j | ★☆☆ |
| **Total** | **~97-98/100** | **11-18j** | |

---

## Commande de validation finale

```bash
# 1. Déploiement complet
bash scripts/deploy/deploy-vault-and-eso.sh
bash scripts/deploy/deploy-velero.sh
bash scripts/gitops/bootstrap-gitops.sh

# 2. Validation cluster
bash scripts/bootstrap/bootstrap-cluster-validation.sh

# 3. DR drill
bash scripts/dr/full-restore-drill.sh --full --destructive

# 4. Chaos
bash scripts/chaos/run-chaos-pipeline.sh --all

# 5. Performance
bash scripts/performance/run-k6-tests.sh --ci

# 6. Validation world-class
bash scripts/validate/worldclass-validation.sh
```

---

> **Prochaine étape :** Choisir le cluster réel (K3s HA → EKS → AKS/GKE) et lancer la Phase 1.
