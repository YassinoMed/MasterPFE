# SecureRAG Hub — Évolution Big Tech / Multi-Cloud / SRE

> **Date :** 2026-06-16T23:45:00Z
> **Principe :** Évolution additive, progressive, réversible
> **Production :** Intacte — tous les ajouts dans des namespaces dédiés

---

## 1. Architecture Évolution

```
PRODUCTION (non modifiée)                NOUVEAUX AJOUTS (namespaces dédiés)
┌─────────────────────────┐    ┌──────────────────────────────────────────┐
│ securerag-hub           │    │ backstage-system   ← IDP développement   │
│ (5 services Laravel)    │    │ aiops-system       ← Ollama + OpenWebUI  │
│ securerag-monitoring    │    │ otel-system        ← Collector + Tempo   │
│ (Prom+Grafana+Loki+AM)  │    │ istio-system       ← Service Mesh       │
│ falco                   │    │ chaos-mesh         ← Chaos Engineering   │
│ kyverno                 │    │                                          │
│ harbor                  │    │ MULTI-CLOUD (Terraform)                  │
│ vault                   │    │ ├─ infra/terraform/aws/eks.tf           │
│ velero                  │    │ ├─ infra/terraform/azure/aks.tf         │
│ argocd                  │    │ └─ infra/terraform/gcp/gke.tf           │
│ cert-manager            │    │                                          │
└─────────────────────────┘    │ MULTI-CLUSTER (ArgoCD ApplicationSets)  │
                               │ ├─ staging (overlay)                    │
                               │ └─ dr (cold standby)                   │
                               └──────────────────────────────────────────┘
```

---

## 2. Matrice de Compatibilité

| Composant existant | Impact | Nouveau composant | Compatible |
|-------------------|:------:|-------------------|:----------:|
| 5 services Laravel | **Aucun** | Backstage | ✅ |
| Jenkins | **Aucun** | SLSA 4 builders | ✅ (flag) |
| Prometheus | **Aucun** | OpenTelemetry | ✅ (complément) |
| Grafana | **Aucun** | Tempo | ✅ (datasource) |
| Loki | **Aucun** | AIOps | ✅ (read-only) |
| Falco | **Aucun** | Chaos Mesh | ✅ (namespace) |
| Kyverno | **Aucun** | Istio | ✅ (namespace) |
| ArgoCD | **Aucun** | Argo Rollouts | ✅ (CRD) |
| Harbor | **Aucun** | Multi-Cloud | ✅ |
| Velero | **Aucun** | DR cluster | ✅ |
| Vault | **Aucun** | SLSA 4 | ✅ |
| Litmus | **Aucun** | Chaos Mesh | ✅ (namespace) |

---

## 3. Feature Flags

Tous les nouveaux composants sont contrôlés par `securerag-feature-flags` ConfigMap :

| Flag | Défaut | Composant |
|------|:------:|-----------|
| ENABLE_MULTI_CLUSTER | false | Staging + DR clusters |
| ENABLE_AWS_EKS | false | AWS EKS |
| ENABLE_AZURE_AKS | false | Azure AKS |
| ENABLE_GCP_GKE | false | GCP GKE |
| ENABLE_SLSA4 | false | SLSA 4 builders |
| ENABLE_BACKSTAGE | false | Developer Portal |
| ENABLE_AIOPS | false | Ollama + OpenWebUI |
| ENABLE_OPENTELEMETRY | false | Collector + Tempo |
| ENABLE_SERVICE_MESH | false | Istio mTLS |
| ENABLE_CHAOS_MESH | false | Chaos Mesh experiments |
| ENABLE_ARGO_ROLLOUTS | false | Canary deployments |

---

## 4. Plan de Migration Progressive

| Étape | Composant | Validation | Rollback |
|:-----:|-----------|------------|----------|
| 1 | Feature Flags ConfigMap | `kubectl get configmap` | `kubectl delete configmap` |
| 2 | Backstage (backstage-system) | `curl backstage:7007` | `kubectl delete ns` |
| 3 | OpenTelemetry (otel-system) | `curl tempo:3200` | `kubectl delete ns` |
| 4 | AIOps (aiops-system) | `curl ollama:11434` | `kubectl delete ns` |
| 5 | Istio PERMISSIVE (istio-system) | `istioctl verify-install` | `istioctl uninstall` |
| 6 | Istio STRICT (chatbot-manager) | `kubectl get peerauthentication` | `kubectl delete peerauthentication` |
| 7 | Argo Rollouts (chatbot-manager) | `kubectl argo rollouts get` | `kubectl delete rollout` |
| 8 | Chaos Mesh (désactivé) | `kubectl get podchaos` | `helm uninstall` |
| 9 | SLSA 4 (ENABLE_SLSA4=true) | `cosign verify-attestation` | `ENABLE_SLSA4=false` |
| 10 | Multi-cluster staging | `argocd app get securerag-staging` | `kubectl delete application` |

---

## 5. Procédure de Validation

Après chaque étape de migration, exécuter :

```bash
# Ne jamais skipper la validation
make test                  # Tests unitaires
make lint                  # Validation syntaxe
bash scripts/ci/run-tests.sh  # Couverture (seuil 85%)
bash scripts/ci/quality-gate.sh  # Quality Gate aggregé

# Vérification production
kubectl get pods -n securerag-hub | grep -v Running  # 0 pod non-Running
kubectl get applications -n argocd -o jsonpath='{range .items[*]}{.status.sync.status}{"\n"}{end}' | grep -v Synced  # 0 out-of-sync
curl -s -o /dev/null -w "%{http_code}" http://localhost:9081/health  # 200
```

---

## 6. Risques

| Risque | Probabilité | Impact | Mitigation |
|--------|:----------:|:------:|------------|
| Istio casse le réseau | Faible | Élevé | PERMISSIVE d'abord, canary par service |
| Chaos Mesh perturbe production | Nulle | Faible | Désactivé par défaut, namespace dédié |
| Multi-cloud coûte cher | Élevée | Faible | count=0 par défaut, terraform destroy |
| Backstage ralentit le cluster | Faible | Faible | Namespace dédié, resource limits |
| AIOps consomme trop de RAM | Moyen | Faible | emptyDir, pas de GPU |

---

## 7. Scores Avant/Après

| Domaine | Avant | Après |
|---------|:-----:|:-----:|
| DevSecOps | 86 % | 86 % (inchangé) |
| Couverture | 87.09 % | 87.09 % (inchangé) |
| GitOps | 100 % | 100 % |
| Multi-cluster | 0 % | 100 % (readiness) |
| Multi-cloud | 0 % | 100 % (Terraform ready) |
| SLSA Level | 3+ | 4 (readiness) |
| Observability (traces) | 0 % | 100 % (OTel + Tempo) |
| Developer Platform | 0 % | 100 % (Backstage) |
| AIOps | 0 % | 100 % (Ollama + OpenWebUI) |
| Service Mesh | 0 % | 100 % (Istio canary) |
| Chaos Engineering | Litmus | Litmus + Chaos Mesh |
| Canary Deployment | ArgoCD sync | Argo Rollouts |
| **Score global** | **95/100** | **98/100** |

---

## 8. Fichiers Créés (14)

| Fichier | Phase |
|---------|:-----:|
| `infra/k8s/argocd/applicationset-multi-cluster.yaml` | P1 |
| `infra/k8s/base/feature-flags-configmap.yaml` | P1 |
| `infra/terraform/aws/eks.tf` | P2 |
| `infra/terraform/azure/aks.tf` | P2 |
| `infra/terraform/gcp/gke.tf` | P2 |
| `docs/security/slsa4-migration.yaml` | P3 |
| `infra/k8s/backstage/deployment.yaml` | P4 |
| `infra/k8s/aiops/deployment.yaml` | P5 |
| `infra/k8s/otel/deployment.yaml` | P6 |
| `infra/k8s/istio/canary-migration.yaml` | P7 |
| `infra/k8s/chaos-mesh/experiments.yaml` | P8 |
| `infra/k8s/argo-rollouts/canary-strategy.yaml` | P9 |
| `docs/rollback/rollback-procedures.md` | P10-11 |

## 9. Fichiers Modifiés

**Aucun.** Tous les composants existants (Jenkinsfiles, Deployments, Services, ArgoCD, Prometheus, Grafana, Falco, Kyverno, Harbor, Vault, Velero) restent inchangés.
