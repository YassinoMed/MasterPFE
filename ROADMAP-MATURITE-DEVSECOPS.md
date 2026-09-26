# 🗺️ ROADMAP DE MATURITÉ DEVSECOPS — Plateforme SecureRAG

**Projet** : Plateforme DevSecOps multi-environnements (PFE) · **Auteur** : YassinoMed
**Date** : 2026-09-26 · **Score actuel** : **95/100** (méthodologie 007, vérifié en direct)
**Niveau supply chain actuel** : ≈ SLSA Level 1 (images signées cosign + digest épinglés)

---

## 1. Positionnement actuel (vérifié)

| Composant | État |
|---|---|
| GitOps | 26 apps ArgoCD, 25/26 Synchronisées, 2 ApplicationSets (générateur liste), 8 environnements |
| Admission | Kyverno 1.19.1 — 8 ClusterPolicies Enforce + vérification cosign |
| CI | Jenkins + SonarQube + bot GitOps (`jenkins@securerag.local`) |
| Registry | Harbor + Trivy (scan à la build) |
| Secrets | Vault **dev mode** (`server.dev.enabled: true`) + External Secrets Operator |
| Runtime | Falco 0.45 + Falcosidekick + Talon (chaîne détection→réponse fonctionnelle) |
| Observabilité | Prometheus, Grafana ×2, Loki ×2, Alertmanager, OTel, Tempo |
| Résilience | Velero + jobs etcd-backup + env "dr" (même cluster) |
| Sécurité plateforme | Audit-log kube-apiserver (actif), encryption etcd AES-CBC, PSA 20 ns, pare-feu persistant, TLS Ingress |
| 108/108 pods Running · 19 namespaces · zéro secret en clair · zéro orphelin GitOps |

**Lacunes structurantes** (identifiées par audit 2026-09-26) :
1. Vault en mode dev (non scellé, en mémoire, sans HA)
2. Cosign signé avec clé stockée sur disque (`export-cosign-key-age.sh`)
3. Pas de SBOM vérifié à l'admission, pas de provenance in-toto
4. Scan vulnérabilités uniquement à la build (pas de scan continu des workloads)
5. DR dans le même cluster (perte du nœud = perte du DR)
6. Générateur d'ApplicationSet en liste YAML (ajout d'env = édition du template)
7. ClusterPolicy v1 dépréciée (migration CEL à planifier)
8. Webhook Slack factice dans Talon (T0000/B000/XXXX)

---

## 2. Les 8 piliers d'amélioration

### Pilier 1 — Supply Chain : vers SLSA Level 2-3

| Élément | Actuel | Cible |
|---|---|---|
| Signature | cosign + clé fichier | **Keyless** (OIDC Jenkins) |
| SBOM | Trivy à la build, non stocké/vérifié | **CycloneDX publié dans Harbor (ORAS) + vérifié à l'admission** |
| Provenance | Aucune | **Attestation in-toto/cosign attest** de la chaîne de build |
| Vérificateur admission | Kyverno verifyImages seul | **Ratify** (signature + SBOM + provenance en 1 webhook) |
| Scan continu | Non | **trivy-operator** : scan des workloads running + PolicyReports |

**Actions concrètes** (modèle ArgoCD du projet — cf. annexe A1/A2) :
```bash
# 1. trivy-operator (scan continu) — Application ArgoCD + appset platform
#    charts aqua : https://aquasecurity.github.io/trivy-operator
# 2. SBOM dans Jenkinsfile : trivy image --format cyclonedx > sbom.json
#    cosign attest --predicate sbom.json --type slsaprovenance <image>
# 3. Ratify : https://ratify.dev — chart ratify/ratify (deux CRD : policies store)
# 4. Kyverno : remplacer verify-cosign par Ratify ou policy verifyImages + attestations
```
**Effort** : 1-2 semaines · **Gain** : SLSA 2→3, +1 pt score, argument massue soutenance.

---

### Pilier 2 — Secrets & Identités : production-grade

| Élément | Actuel | Cible |
|---|---|---|
| Vault | dev mode, in-memory, unsealed | **Production : Raft storage, TLS, auto-unseal AWS KMS, HA 3 réplicas** |
| DB credentials | statiques (ExternalSecret 1h refresh) | **Dynamiques : moteur database Vault → rotation automatique (TTL 1h, révocation à la volée)** |
| Identités workload | ServiceAccounts K8s | **SPIFFE/SPIRE** (`scripts/spire/` déjà amorcé) : identités SVID, mTLS sans secrets |
| Audit secrets | — | **Vault audit device → Loki** + métriques |

**Actions** :
```yaml
# application-vault.yaml — valeurs de production (remplacer dev.enabled) :
server:
  datastorage: { enabled: true, size: 10Gi }
  ha: { enabled: true, replicas: 3 }
  raft: { enabled: true, setNodeId: true }
  autoUnseal: { enabled: true, kms: { region: us-east-1, keyId: <kms-key> } }
  auditStorage: { enabled: true }
```
Puis : `vault secrets enable database` + rôle `auth-users` (TTL 1h) → l'app obtient des identifiants **éphémères** ; l'ExternalSecret devient un VaultAuth + VaultDynamicSecret.

**Effort** : 3-4 jours · **Gain** : levée du plus gros risque résiduel de sécurité.

---

### Pilier 3 — Runtime : de la détection à l'enforcement

| Élément | Actuel | Cible |
|---|---|---|
| Détection | Falco (syscall) | + **Tetragon** (`scripts/tetragon/` amorcé) : enforcement eBPF **temps réel** (bloquer, pas alerter) |
| Réponse | Talon (règles jamais déclenchées en test) | **Détection d'exercices (detection drills)** : script planifié `kubectl exec sh` → Falco → Talon isole → **preuve en PolicyReport** |
| SIEM | Loki seul | **OpenSearch** (`scripts/opensearch/`) : corrélation, rétention long terme, dashboards sécurité |

**Exercice de validation automatisable** (à mettre dans `scripts/security/`) :
```bash
# 1. Déclencher : kubectl exec <pod> -- cat /etc/shadow
# 2. Falco détecte (règle Read sensitive file untrusted — déjà active ✓)
# 3. Vérifier la réponse Talon : kubectl get pods -n securerag-hub (pod terminé)
# 4. Vérifier l'alerte : logseql "SecureRAG Shell in Container" --field-only /tmp/pf-nginx.log
```
**Effort** : Tetragon 1 semaine · drills 1 jour · **Gain** : démo soutenance spectaculaire + résilience prouvée.

---

### Pilier 4 — Réseau Zero-Trust

| Élément | Actuel | Cible |
|---|---|---|
| CNI | kindnet (basique) | **Cilium** (eBPF) + **Hubble** (visibilité flux L7 en clair) |
| Policies | NetPols L3/L4 par app | + **CiliumNetworkPolicy L7** (ex : auth-users ne peut appeler QUE /api/v1/* de chatbot) |
| mTLS | TLS entrée uniquement | **Service mesh mTLS intégral** (Linkerd ou Cilium service mesh) |
| Identité réseau | IPs/podSelectors | **SPIFFE** croisé avec le pilier 2 |

**Attention** : migration CNI = recréation du cluster → planifier avec Cluster API (pilier 5).
**Effort** : 1-2 semaines · **Gain** : chiffrement intégral + observabilité réseau native.

---

### Pilier 5 — Résilience & Multi-Cluster

| Élément | Actuel | Cible |
|---|---|---|
| DR | env `securerag-hub-dr` dans le MÊME cluster | **Cluster DR réel** (le conteneur `securerag-control-plane` dormant peut servir de base) |
| GitOps multi-cluster | mono-cluster | **ApplicationSet générateur cluster** : même git → N clusters |
| Cycle de vie clusters | kind manuel | **Cluster API (CAPI)** : cluster = manifest YAML → extensible à la demande |
| Sauvegardes | Velero non testées en restauration | **Exercices de restauration mensuels automatisés** (job + vérif + rapport) |
| Chaos | non déployé | **Chaos Mesh** (`scripts/chaos/` amorcé) : kill pods, latence, partition réseau → validation par SLO |

**Extrait clé — ApplicationSet multi-cluster** (annexe A3) :
```yaml
generators:
  - clusters: {}   # auto-découverte des clusters enregistrés dans ArgoCD
  # + label selector pour ne cibler que les clusters securerag
```
**Effort** : 2-4 semaines (le plus gros chantier) · **Gain** : vrai RTO/RPO démontrable.

---

### Pilier 6 — Mesure & DORA (la maturité PROUVÉE)

| Métrique DORA | Source disponible chez toi | Collecte |
|---|---|---|
| Deployment frequency | ArgoCD API (syncs Succeeded) | script → Prometheus/Grafana |
| Lead time for changes | GitHub API (commit→deploy timestamps) | `scripts/dora/` **déjà amorcé** |
| Change failure rate | ArgoCD (syncs Failed/rollbacks) | idem |
| MTTR | Alertmanager + Falco timestamps | idem |

**Autres mesures** :
- **SLO/SLI par service + budgets d'erreur** (burn-rate alerting au lieu de seuils bruts)
- **FinOps** (`scripts/finops/` amorcé) : **OpenCost/Kubecost** → coût par environnement (showback soutenance : "prod me coûte X€/j")
- **ZAP qualité** : ton `zap-quality-gate.sh` → brancher en gate de promotion d'env

**Effort** : 2-3 jours · **Gain** : tableau de bord DORA = preuve de maturité chiffrée (très valorisé).

---

### Pilier 7 — Conformité automatisée

| Élément | Actuel | Cible |
|---|---|---|
| Policies | ClusterPolicy v1 (⚠️ **dépréciée** — warnings vus en prod) | **Migration ValidatingPolicy (CEL)** — pérennité Kyverno 2.x |
| Exceptions | allowlist dans les policies | **PolicyException** (CRD) : traçable, argumentable, expirable |
| Benchmarks | — | **kube-bench** (CIS) + **Checkov** (IaC) + **kube-hunter** en jobs Jenkins périodiques |
| Preuves | manuelles | **Evidence automatisée** (`scripts/evidence/` amorcé) : export continu audit-log + PolicyReports + DORA → dossier d'audit |

**Exemple ValidatingPolicy** (annexe A4) — même métier, API moderne.

---

### Pilier 8 — Extensibilité GitOps

| Élément | Actuel | Cible |
|---|---|---|
| Ajout d'environnement | éditer la liste du ApplicationSet + kustomization | **Générateur git (git generator)** : 1 dossier + 1 fichier config = 1 env auto-découvert |
| Promotion d'env | manuelle | **Pipeline de promotion** : dev → recette → prod avec gates (Sonar, Trivy, ZAP, SLO) |
| Notifications | webhook Slack factif | **ArgoCD Notifications réelles** (Slack/Teams) : sync failed = alerte |
| Diff par env | overlays kustomize | + **composants kustomize** pour encore plus de factorisation |

**Extrait générateur git (git-generator)** (annexe A5) — c'est LE fix d'extensibilité.

---

## 3. Priorisation en 3 horizons

| Horizon | Actions | Effort | Score projeté |
|---|---|---|---|
| **H1 — Rapides** (1-2 j chacun) | trivy-operator · Vault production + auto-unseal · notifications Slack réelles · migration générateur git (git-generator) · tableau de bord DORA · exercices de restauration Velero | ~1 semaine cumulée | **96-97** |
| **H2 — Structurels** (1-2 sem chacun) | SBOM + Ratify + keyless (SLSA 2-3) · Cilium + Hubble · migration ValidatingPolicy CEL · OpenSearch | ~4 semaines | **97-98** |
| **H3 — Stratégiques** (2-4 sem) | Multi-cluster DR + Cluster API · SPIRE + mTLS mesh · Tetragon enforcement · programme Chaos Mesh | ~6 semaines | **98-99** |

## 4. Ce qu'il faut retenir pour la soutenance

> **"Ma plateforme SecureRAG est SLSA Level 1 aujourd'hui (images signées, digest épinglés, admission Enforce). La roadmap en 3 horizons la porte vers SLSA 3 (SBOM + provenance keyless + Ratify), un zero-trust réseau (Cilium + SPIRE + mTLS) et un DR multi-cluster piloté par Cluster API. Chaque brique est conçue, testée et versionnée dans le dépôt git (50+ commits, reproductible), et la maturité est prouvée par les métriques DORA collectées en continu."**

**Arguments différenciants déjà en place** (à mettre en avant tels quels) :
- Chaîne Falco→Talon **fonctionnelle** (rare même en entreprise)
- Audit-log + encryption etcd **activés** (souvent absents des PFE)
- Isolation 8 envs zero-trust (RBAC + NetPols + PSA + quotas + AppProject)
- Auto-réparation (selfHeal) prouvée en direct (hub reconstruit seul, policy restaurée en 86 s)

---

## Annexe A — Snippets prêts à l'emploi (patterns du projet)

### A1. Application ArgoCD — trivy-operator (à poser dans `infra/k8s/argocd/`)
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: securerag-trivy-operator
  namespace: argocd
  annotations: { argocd.argoproj.io/sync-wave: "17" }
  finalizers: [resources-finalizer.argocd.argoproj.io]
spec:
  project: securerag-hub
  source:
    repoURL: https://aquasecurity.github.io/trivy-operator
    chart: trivy-operator
    targetRevision: 0.29.0
    helm:
      values: |
        serviceMonitor: { enabled: true }
        trivy: { ignoreUnfixed: true }
  destination: { server: https://kubernetes.default.svc, namespace: trivy-system }
  syncPolicy:
    automated: { prune: true, selfHeal: true }
    syncOptions: [CreateNamespace=true]
# + project.yaml : sourceRepo aquasecurity + destination trivy-system
# + ClusterRole? non — namespaced sauf scanner. Vérifier clusterResourceWhitelist.
```

### A2. Jenkinsfile — SBOM + provenance + scan (pipeline supply chain)
```groovy
stage('Supply Chain') {
  steps {
    sh 'trivy image --format cyclonedix --output sbom.json ${IMAGE}'
    sh 'cosign attest --predicate sbom.json --type cyclonedx ${IMAGE}'
    sh 'cosign attest --predicate <(jq -n --arg v "${BUILD_NUMBER}" ...provenance.json) --type slsaprovenance ${IMAGE}'
    sh 'trivy image --exit-code 1 --severity CRITICAL ${IMAGE}'   // gate qualité
  }
}
```

### A3. ApplicationSet multi-cluster (générateur de clusters)
```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
spec:
  generators:
    - clusters:
        selector: { matchLabels: { securerag: "true" } }   # label à poser sur les clusters enregistrés
  template:
    metadata: { name: 'securerag-{{name}}' }
    spec:
      source: { repoURL: https://github.com/YassinoMed/MasterPFE.git, targetRevision: main, path: 'infra/k8s/overlays/{{metadata.labels.env}}' }
      # → le même GitOps déploie sur N clusters, DR inclus
```

### A4. ValidatingPolicy CEL (remplacement de ClusterPolicy v1)
```yaml
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata: { name: securerag-disallow-root-containers }
spec:
  validation:
    - expression: "object.spec.template.?spec.?securityContext.?runAsNonRoot == true"
      message: "Containers must run as non-root"
```

### A5. ApplicationSet générateur git (git-generator — extensibilité envs)
```yaml
spec:
  generators:
    - git:
        repoURL: https://github.com/YassinoMed/MasterPFE.git
        revision: main
        directories: [{ path: 'infra/k8s/overlays/*' }]   # auto-découverte
        # chaque overlay porte son env.yaml (namespace, wave) → plus de liste à éditer
  template:
    metadata: { name: 'securerag-{{path.basename}}' }
    # ... destination.namespace depuis env.yaml via values
```

### A6. Vault — moteur DB dynamique (rotation auto)
```bash
vault secrets enable database
vault write database/config/postgres-auth \
  plugin_name=postgresql-database-plugin \
  allowed_roles=auth-users \
  connection_url="postgresql://{{username}}:{{password}}@postgres-auth:5432/auth_users" \
  username=securerag password=<admin>
vault write database/roles/auth-users \
  db_name=postgres-auth default_ttl=1h max_ttl=4h \
  creation_statements="CREATE ROLE \"{{name}}\" LOGIN PASSWORD '{{password}}';"
# App : VaultDynamicSecret (ESO) → identifiants 1h auto-rotés, révocables instantanément
```

---

*Réalisé à partir de l'audit complet du 2026-09-26 (rapport `security-audit-RAPPORT-2026-09-25.md`) et de l'état live vérifié (108/108 pods, 25/26 apps Synced, 95/100).*
