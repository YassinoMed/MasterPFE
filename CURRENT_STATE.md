# CURRENT_STATE.md — Audit Initial SecureRAG Hub

**Date**: 2026-09-26 · **Branche**: `main` (synchronisée avec origin) · **Cluster**: `kind-securerag-dev`

---

## 1. Architecture Actuelle

```
GitHub (YassinoMed/MasterPFE)
         │
         ▼
    Argo CD ──────────────────────────────────────────┐
    ├── ApplicationSet "all-services" (8 envs)       │
    │   dev · test · demo · recette · staging         │
    │   preprod · production · dr                     │
    ├── ApplicationSet "platform" (9 composants)     │
    └── 26 Applications gérées                       │
                                                      ▼
                                     Kubernetes kind (2 nœuds)
```

## 2. Composants — État Live Vérifié

| Composant | État | Mode/Version | Remarques |
|---|---|---|---|
| Argo CD | 25/26 Synced | v3.5.3 | App `kyverno-policies` en OutOfSync (drift runtime) |
| Kyverno | 8 ClusterPolicies Ready | v1.19.1 | API v1 **dépréciée** (migration CEL requise) |
| Jenkins | Running (namespace jenkins) | Helm-managed | **Non géré par ArgoCD** |
| SonarQube | Running (conteneur Docker) | 10-community | **Non géré par ArgoCD** |
| Harbor | 8/8 Running | helm-chart | Signatures cosign acceptées |
| Trivy CLI | Scripts Jenkins | — | Scan à la build seulement, **pas de trivy-operator** |
| Cosign | Clé sur disque | v2 | **Pas de keyless OIDC** |
| Vault | Running, **dev mode, inmem** | v1.18.1 | **Pas de HA, pas de TLS, pas d'auto-unseal** |
| ESO | 3 deployments Running | 0.9.18 | 23 ExternalSecrets actifs |
| Falco | 2 agents Running | 0.45.0 | Détection fonctionnelle |
| Falcosidekick | 1 Running | — | Relais vers Loki |
| Talon | 1 Running | sha256:ecf352 | **NATS embarqué**, webhook Slack factice |
| Prometheus | Running | kube-prometheus-stack | NodePort 30090 |
| Grafana | 2 instances Running | 11.2.0 | ns monitoring + securerag-monitoring |
| Loki | 2 instances Running | — | ns loki + securerag-monitoring |
| Alertmanager | Running | — | NodePort 30093 |
| OTel | Running | — | ns otel-system |
| Tempo | Running | — | Traces |
| Velero | Running | — | 1 schedule, 2 backups complétés |
| Ingress-nginx | 1 controller Running | 4.15.1 | NodePort 30100/30101 |
| Cert-manager | 3 pods Running | — | ClusterIssuer self-signed |
| PostgreSQL | 1 pod par env | 16.15 | Identifiants statiques via ESO |
| Service CIN (portal-web) | Running ×5 | Laravel 12.62 | 8 envs, 108/108 pods Running |

## 3. ApplicationSets

| Nom | Générateur | Environnements |
|---|---|---|
| `securerag-all-services` | Liste (statique) | dev, test, demo, recette, staging, preprod, production, dr |
| `securerag-platform` | Liste (statique) | observability, otel, backup, runtime-detection, kyverno, kyverno-policies, metrics-server, secrets, cert-manager |

## 4. Overlays — Validation Kustomize

| Overlay | Build | Namespace | Deployments |
|---|---|---|---|
| dev | OK | securerag-dev | 11 |
| demo | OK | securerag-hub | 8 |
| recette | OK | securerag-recette | 7 |
| staging | OK | securerag-staging | 7 |
| production | OK | securerag-prod | 11 |
| dr | OK | securerag-hub-dr | 7 |

**Rendu validé** : tous les environnements build sans erreur. Namespace, replicas et images sont correctement isolés par overlay.

## 5. NetworkPolicies

| Namespace | Policies |
|---|---|
| securerag-dev/test/staging/preprod/prod | 15 chacun |
| securerag-hub | 13 |
| securerag-recette, securerag-hub-dr | 12 chacun |
| argocd | 7 |
| securerag-monitoring | 3 |
| default | 3 |
| securerag-backup | 2 |

Pattern : `default-deny-all` + allowlist par service. Le CNI est **kindnet** (pas de L7).

## 6. Secrets — Vault

| Aspect | État |
|---|---|
| Mode | **dev** (`server.dev.enabled: true`, `dataStorage.enabled: false`) |
| Stockage | **inmem** (perte sur restart) |
| Unseal | Manuel (pas de KMS) |
| TLS | Non |
| HA | Non (1 pod StatefulSet) |
| Dynamic DB secrets | Non (identifiants statiques via ESO) |
| VaultAuth CRD | Non (ESO utilise le token statique) |

## 7. Supply Chain — Pipeline Jenkins

| Étape | État | Fichier |
|---|---|---|
| Build | Implémenté | `Jenkinsfile` |
| SonarQube | Implémenté | Jenkinsfile.cd |
| Trivy scan | Implémenté (gate CRITICAL) | Jenkinsfile |
| SBOM CycloneDX | **Non implémenté** | — |
| Cosign sign | Implémenté (clé disque) | Jenkinsfile |
| Cosign keyless | **Non implémenté** | — |
| Provenance in-toto | **Non implémenté** | — |
| SBOM publié ORAS | **Non implémenté** | — |
| Ratify admission | **Non déployé** | — |
| ZAP quality gate | Script existe | scripts/zap-quality-gate.sh |

## 8. Composants Non Déployés (amorcés dans le repo)

| Répertoire infra/k8s | Fichiers | Déployé ? |
|---|---|---|
| cilium/ | 1 | Non (CNI migration = recréation cluster) |
| istio/ | 11 | Non |
| spiffe/ | 3 | Non |
| tetragon/ | 2 | Non |
| opa-gatekeeper/ | 26 | Non |
| chaos-mesh/ | 1 | Non |
| crossplane/ | 1 | Non |
| wazuh/ | 3 | Non |
| backstage/ | 1 | Non |
| kong/ | 1 | Non |
| coraza/ | 1 | Non |
| finops/ | 1 | Non |
| ml-platform/ | 1 | Non |
| argo-rollouts/ | 3 | Non |
| gpu/ | 1 | Non |

## 9. Scripts Existants

| Répertoire scripts/ | Contenu | Utilisé ? |
|---|---|---|
| dora/ | Ébauche | Non intégré |
| finops/ | Ébauche | Non intégré |
| chaos/ | Ébauche | Non intégré |
| evidence/ | Ébauche | Non intégré |
| ratify/ | Ébauche | Non intégré |
| spire/ | Ébauche | Non intégré |
| tetragon/ | Ébauche | Non intégré |
| trivy-operator/ | Ébauche | Non intégré |
| security/ | Ébauche | Non intégré |
| supply-chain/ | Ébauche | Non intégré |
| export-cosign-key-age.sh | Export clé publique vers Vault | Utilisé |
| zap-quality-gate.sh | ZAP baseline | Partiellement |
| verify-cluster-e2e.sh | E2E complet | Partiellement |
| seed-vault-secrets.sh | Seed initial Vault | Utilisé |

## 10. Jenkinsfiles

| Fichier | Usage |
|---|---|
| Jenkinsfile | Build principal (image + scan + sign) |
| Jenkinsfile.ai | Build IA/secai |
| Jenkinsfile.cd | CD (déclenchement ArgoCD) |
| Jenkinsfile.dr | DR exercises |
| Jenkinsfile.nightly | Nightly build |
| Jenkinsfile.perf | Performance tests |
| Jenkinsfile.recette | Recette build |
| Jenkinsfile.weekly | Weekly build |

## 11. Risques Identifiés

| # | Risque | Gravité | Phase |
|---|---|---|---|
| R1 | Vault en dev mode — secrets perdus au restart, pas de HA | **CRITIQUE** | Phase 3 |
| R2 | Cosign clé privée sur disque — vecteur de compromission supply chain | **HAUTE** | Phase 4 |
| R3 | Jenkins non géré par ArgoCD — configuration non versionnée | **HAUTE** | Phase 1 |
| R4 | Kyverno ClusterPolicy v1 dépréciée — cassera à la prochaine version majeure | **MOYENNE** | Phase 14 |
| R5 | kyverno-policies app en OutOfSync (5 policies, champs runtime) | **BASSE** | Phase 0/14 |
| R6 | Pas de trivy-operator — pas de scan continu des vulnérabilités workloads | **HAUTE** | Phase 2 |
| R7 | Webhook Slack factice dans Talon (T0000/B000/XXXX) | **BASSE** | Phase 20 |
| R8 | DR dans le même cluster — pas un vrai disaster recovery | **HAUTE** | Phase 9 |
| R9 | Identifiants DB statiques — pas de rotation automatique | **MOYENNE** | Phase 3 |
| R10 | 60 fichiers non commités dans artifacts/ (build outputs) | **BASSE** | Phase 24 |
| R11 | CNI kindnet — pas de policies L7, pas de Hubble | **MOYENNE** | Phase 7 |
| R12 | Pas de SBOM ni provenance vérifiés à l'admission | **HAUTE** | Phase 4/5 |

## 12. Fichiers à Modifier (par phase priorisée)

| Phase | Fichiers concernés | Action |
|---|---|---|
| 2 | `infra/k8s/argocd/securerag-trivy-operator.yaml` (créer) + `infra/k8s/argocd/kustomization.yaml` + `project.yaml` | Ajouter trivy-operator |
| 3 | `infra/k8s/argocd/application-vault.yaml` (modifier) | Mode production Raft |
| 4 | `Jenkinsfile` (modifier) | SBOM + provenance + keyless |
| 5 | `infra/k8s/argocd/securerag-ratify.yaml` (créer) | Déployer Ratify |
| 6 | `scripts/security/detection-drill.sh` (créer) + `infra/k8s/tetragon/` | Tetragon + drill |
| 9 | `infra/k8s/argocd/applicationset-multicluster.yaml` (créer) | DR multi-cluster |
| 10 | `scripts/backup/velero-restore-test.sh` (créer) | Restore test |
| 12 | `scripts/dora/` (compléter) + `infra/k8s/observability/dora-exporter/` | DORA metrics |
| 13 | `infra/k8s/finops/` (compléter) | OpenCost |
| 14 | `infra/k8s/policies/kyverno-cel/` (créer) | ValidatingPolicy |
| 15 | `infra/k8s/policies/exceptions/` (créer) | PolicyException |
| 17 | `scripts/evidence/` (compléter) | Evidence collectors |
| 18 | `infra/k8s/argocd/applicationset-all.yaml` (modifier) | Git generator |
| 20 | `infra/k8s/argocd/notifications-cm.yaml` (modifier) | Notifications réelles |

## 13. Ordre d'Implémentation Proposé

```
Phase 2  (trivy-operator)        → 1 jour
Phase 3  (Vault production)      → 3-4 jours
Phase 10 (Velero restore test)   → 1 jour
Phase 20 (Notifications)         → 0.5 jour
Phase 18 (Git generator)          → 1 jour
Phase 12 (DORA)                  → 2 jours
Phase 4  (Supply chain)          → 1 semaine
Phase 5  (Ratify)                → 1 semaine
Phase 6  (Tetragon + drill)       → 1 semaine
Phase 17 (Evidence)              → 2 jours
Phase 14 (Kyverno CEL)           → 3 jours
Phase 15 (PolicyException)       → 1 jour
Phase 13 (FinOps)                → 1 jour
Phase 9  (DR multi-cluster)      → 2 semaines
Phase 7  (Cilium — nouveau cluster) → 2-3 semaines
Phase 8  (SPIRE)                 → 1-2 semaines
```

## 14. Blocages Identifiés

| Blocage | Impact | Solution |
|---|---|---|
| Jenkins hors GitOps | Config CI non versionnée | Créer Application ArgoCD ou Helm chart Jenkins |
| SonarQube hors GitOps | Idem | Container Docker → migrer vers chart Helm ArgoCD |
| Cosign clé sur disque | Keyless OIDC nécessite GitHub Enterprise ou Jenkins OIDC | Configurer Jenkins avec OIDC provider |
| CNI kindnet | Migration nécessite recréation cluster | Créer cluster de test avec kind + Cilium |
| Vault dev mode | Migration = re-seed tous les secrets | Backup via `vault kv get -format=json` + script seed |
| AWS KMS pour auto-unseal | Nécessite clé KMS dédiée | Créer via aws kms create-key (rôle IAM manquant) |
| ApplicationSet statique | Ajout d'env = édition manuelle | Git generator (Phase 18) |

## 15. Commandes de Validation Prévues

```bash
# Après chaque phase :
git status --short
kubectl get applications -n argocd
kubectl get pods -A

# Phase 2 :
kubectl get pods -n trivy-system
kubectl get vulnerabilityreports -A

# Phase 3 :
kubectl exec -n vault securerag-vault-0 -- vault status
kubectl exec -n vault securerag-vault-1 -- vault status

# Phase 4 :
cosign verify-attestation --type slsaprovenance <image>

# Phase 5 :
kubectl get ratifypolicies -A

# Phase 6 :
bash scripts/security/detection-drill.sh

# Phase 10 :
bash scripts/backup/velero-restore-test.sh

# Phase 12 :
curl -s http://dora-exporter.monitoring:9090/metrics | grep dora_

# Phase 18 :
kubectl get applications -n argocd | grep -c Synced

# Build (tous les envs) :
kubectl kustomize infra/k8s/overlays/dev >/dev/null
kubectl kustomize infra/k8s/overlays/demo >/dev/null
kubectl kustomize infra/k8s/overlays/recette >/dev/null
kubectl kustomize infra/k8s/overlays/staging >/dev/null
kubectl kustomize infra/k8s/overlays/production >/dev/null
kubectl kustomize infra/k8s/overlays/dr >/dev/null
```

---

*Réalisé sans aucune modification du code. Audit read-only du 2026-09-26 à 16:50 UTC.*
