# 🔐 SecureRAG Hub

Plateforme unifiée de chatbots métier sécurisés conçue comme projet Master DSIR avec architecture microservices et chaîne DevSecOps complète.

## 📋 Vue d'ensemble

**SecureRAG Hub** est une solution d'entreprise robuste qui combine :
- ✅ Orchestration sécurisée de chatbots métier
- ✅ Architecture microservices scalable
- ✅ Pipeline DevSecOps industrialisé
- ✅ Infrastructure Kubernetes reproductible
- ✅ Chaîne de confiance certificatrice (verify → promote → deploy → validate)

Ce dépôt contient l'intégralité du système : microservices, portail web, infrastructure, automatisation et documentation.

---

## 🎯 Objectifs stratégiques

| Objectif | Description |
|----------|-------------|
| **Plateforme multi-tenant** | Héberger plusieurs chatbots métier indépendants et sécurisés |
| **Portail unifié** | Interface utilisateur et admin cohérente et ergonomique |
| **Industrialisation** | Construction, vérification, signature et déploiement automatisés |
| **DevSecOps** | Démonstration d'une démarche sécurité reproductible en local |
| **Traçabilité complète** | Preuves documentées pour mémoire et soutenance |

---

## 🏗️ Architecture

### Composants applicatifs
```bash
📦 portal-web              - Interface Laravel utilisateur/admin/sécurité
📦 auth-users              - Service Laravel utilisateurs, rôles, permissions
📦 chatbot-manager         - Service Laravel catalogue et gouvernance chatbots
📦 conversation-service    - Service Laravel conversations et messages
📦 audit-security-service  - Service Laravel audit, incidents, conformité
```

Les dossiers Python legacy sous `services/` ne sont plus dans la build/deploy officielle car les sources applicatives `.py` sont absentes. Ils ne doivent pas être cités comme runtime validé.

### Stack technologique

| Composant | Technologie | Rôle |
|-----------|-------------|------|
| **CI/CD** | Jenkins | Source de vérité officielle |
| **Conteneurisation** | Docker | Construction d'images |
| **Orchestration** | Kubernetes (kind) | Runtime local |
| **Manifests** | Kustomize | Base/Overlays |
| **Sécurité code** | Semgrep, Gitleaks | Scan SAST |
| **Sécurité images** | Trivy, Cosign | Scan SBOM et signature |
| **Policies** | Kyverno | Admission controller |

---

## 🚀 Pipeline CI/CD

### ✓ Phase CI (Intégration)
```bash
checkout → lint/test → couverture → dependency audit → Semgrep → Gitleaks → Trivy FS → Kyverno static policy check → Sonar optionnel → archivage rapports
```

### ✓ Phase CD (Déploiement)
```bash
scan images → signature → vérification tag → promotion digest → SBOM → attestation SBOM → gate preuves → déploiement → validation
```

### 🔗 Chaîne de confiance
```bash
build → image scan → sign → verify → promote by digest → sbom → sbom attest → evidence gate → deploy → validate
```

**Principe clé** : Aucune reconstruction d'image au déploiement.

---

## 📂 Structure du dépôt

```bash
MasterPFE/
├── services-laravel/      # Services Laravel officiels
├── services/              # Runtime Python legacy exclu de la build officielle
├── platform/              # Portail Laravel et couche app
├── infra/
│   ├── kind/              # Cluster Kubernetes local
│   ├── k8s/               # Manifests base/overlays/policies
│   └── jenkins/           # Jenkins reproductible
├── scripts/
│   ├── ci/                # Tests et couverture
│   ├── release/           # SBOM, signature, promotion
│   ├── deploy/            # Cluster et déploiement
│   ├── validate/          # Validation post-déploiement
│   ├── secrets/           # Bootstrap secrets
│   └── jenkins/           # Bootstrap Jenkins
├── security/              # Règles et conventions
├── docs/                  # Architecture et runbooks
└── Makefile               # Interface de commandes
```

---

## ⚡ Démarrage rapide

### 1️⃣ Vérifier les prérequis
```bash
docker --version
kind --version
kubectl version --client
```

### 2️⃣ Créer cluster et registre local
```bash
bash scripts/deploy/create-kind.sh
```

### 3️⃣ Initialiser les secrets
```bash
bash scripts/secrets/bootstrap-local-secrets.sh
bash scripts/secrets/create-dev-secrets.sh
```

### 4️⃣ Construire les images
```bash
REGISTRY_HOST=localhost:5001 IMAGE_TAG=dev bash scripts/deploy/build-local-images.sh
```

### 5️⃣ Déployer sur le cluster
```bash
REGISTRY_HOST=localhost:5001 IMAGE_PREFIX=securerag-hub IMAGE_TAG=dev \
bash scripts/deploy/deploy-kind.sh
```

### 6️⃣ Valider le déploiement
```bash
bash scripts/validate/smoke-tests.sh
bash scripts/validate/security-smoke.sh
bash scripts/validate/e2e-functional-flow.sh
bash scripts/validate/rag-smoke.sh
bash scripts/validate/generate-validation-report.sh
```

---

## 🎭 Modes de déploiement

### Mode DÉMO (Recommandé pour soutenance)
Déploie le runtime Laravel officiel via l’overlay `demo`.

```bash
REGISTRY_HOST=localhost:5001 IMAGE_PREFIX=securerag-hub IMAGE_TAG=dev \
KUSTOMIZE_OVERLAY=infra/k8s/overlays/demo \
bash scripts/deploy/deploy-kind.sh
```

**Avantages**
- périmètre cohérent avec les sources réellement présentes ;
- déploiement fiable et rapide ;
- validation sécurité Kubernetes reproductible.

### Mode DEV
Déploie le même périmètre Laravel avec tags `dev` et `imagePullPolicy: Always`.

```bash
REGISTRY_HOST=localhost:5001 IMAGE_PREFIX=securerag-hub IMAGE_TAG=dev \
bash scripts/deploy/deploy-kind.sh
```

Le scénario legacy RAG/Ollama n’est pas officiel tant que les sources Python correspondantes ne sont pas restaurées.

### VPS Debian 12 depuis Git
Pour un serveur cloud, utilisez l'URL Git complète avec `.git`. Ne laissez pas un `\` seul après `REPO_URL`.

```bash
apt-get update
apt-get install -y ca-certificates git

REPO_URL="https://github.com/YassinoMed/MasterPFE.git"
APP_DIR="/MasterPFE"
BRANCH="main"

git clone --branch "${BRANCH}" "${REPO_URL}" "${APP_DIR}"
cd "${APP_DIR}"

bash scripts/deploy/cloud-debian12-full-run.sh
```

Voir aussi `docs/runbooks/cloud-debian12-vps.md`.

Si le dépôt est déjà présent dans `/MasterPFE`, l'installation all-in-one ne nécessite plus de définir `REPO_URL` :

```bash
cd /MasterPFE
chmod +x install_securerag_hub_all_in_one.sh securerag-launch-all.sh

./install_securerag_hub_all_in_one.sh

MODE=production RUN_METRICS=true RUN_KYVERNO_AUDIT=true RUN_SUPPORT_PACK=true \
./securerag-launch-all.sh
```

---

## 🔐 Jenkins local

### Lancement
```bash
bash scripts/jenkins/bootstrap-local-credentials.sh
bash scripts/jenkins/bootstrap-local-kubeconfig.sh
docker compose -f infra/jenkins/docker-compose.yml up --build -d
bash scripts/jenkins/wait-for-jenkins.sh
```

### Accès
- **URL** : http://localhost:8085
- **Utilisateur** : `admin`
- **Mot de passe** : lire `infra/jenkins/secrets/jenkins-admin-password` après `bash scripts/jenkins/bootstrap-local-credentials.sh`

### Jobs disponibles
- `securerag-hub-ci` - Pipeline d'intégration
- `securerag-hub-cd` - Pipeline de déploiement

---

## ☸️ Kubernetes & Overlays

### 📦 Base (`infra/k8s/base/`)
Ressources essentielles :
- Namespace, Services, Deployments
- Network Policies (sécurité réseau)
- Resource Quotas et Limits
- Pod Disruption Budgets (PDB)
- Horizontal Pod Autoscaler (HPA) pour `portal-web`

### 🎯 Overlay `dev`
Configuration pour runtime local :
- Images locales `localhost:5001`
- NodePort pour accès externe
- Pull policy `Always`

### 🎭 Overlay `demo`
Configuration pour démonstration :
- Images locales `localhost:5001`
- Runtime Laravel officiel
- Pull policy `IfNotPresent`

### 🏭 Overlay `production`
Configuration production-like sans casser le mode démo :
- replicas HA pour les cinq services Laravel officiels ;
- PDB cohérents, rolling updates `maxUnavailable=0`, anti-affinity et topology spread ;
- HPA CPU/mémoire pour tous les services officiels ;
- exposition officielle du portail via `Service/portal-web` en `NodePort` `30081` ;
- validation du périmètre production propre via `make production-cluster-clean-proof` ;
- validation non destructive via `make production-ha`.

### 🛡️ Policies Kyverno (`infra/k8s/policies/`)
Sécurité d'admission :
- Audit des configurations Pod
- Audit des registres/images et interdiction `latest`
- Vérification signatures Cosign des images
- Enforcement optionnel

---

## 🔐 Secrets, signatures & vérification

### Gestion des secrets
| Fichier | Usage |
|---------|-------|
| `security/secrets/.env.example` | Modèles de secrets |
| `scripts/secrets/bootstrap-local-secrets.sh` | Génération locale |
| `scripts/secrets/create-dev-secrets.sh` | Injection K8s |
| `scripts/secrets/create-production-db-secret.sh` | Secret DB externe production-like |
| `infra/secrets/sops/` | Option SOPS/age préparée, non active par défaut |
| `scripts/jenkins/bootstrap-local-credentials.sh` | Credentials Jenkins/Cosign locaux |

### Pipeline de sécurité
```bash
scripts/release/generate-sbom.sh          # Génération SBOM
scripts/release/scan-images.sh            # Scan Trivy des images candidates
scripts/release/sign-images.sh            # Signature des images
scripts/release/verify-signatures.sh      # Vérification Cosign
scripts/release/promote-verified-images.sh    # Promotion
scripts/release/promote-by-digest.sh      # Promotion par digest
scripts/release/attest-sboms.sh           # Attestation Cosign des SBOM
scripts/release/record-release-evidence.sh    # Traçabilité
scripts/deploy/verify-and-deploy-kind.sh  # Déploiement sécurisé
```

---

## 🎮 Commandes principales

Le `Makefile` fournit une interface unifiée :

```bash
make help                               # Afficher l'aide
make lint                               # Linting du code
make test                               # Tests Laravel et collecte éventuelle couverture
make sonar-analysis                     # Sonar si SONAR_HOST_URL/SONAR_TOKEN sont fournis
make kyverno-policy-check               # Validation Kyverno hors cluster si CLI disponible
make image-scan IMAGE_TAG=dev           # Scan Trivy des images candidates
make sbom-validate                      # Validation CycloneDX des SBOM générés
make sbom-attest TARGET_IMAGE_TAG=release-local # Attestation Cosign des SBOM
make production-ha                      # Validation statique HA de l'overlay production
make production-runtime-evidence        # Preuves runtime production en lecture seule
make production-proof-full              # Orchestrateur final de preuves production, read-only par défaut
make ha-chaos-lite                      # Preuve HA légère ; mutations opt-in
make hpa-runtime-proof                  # Rapport read-only metrics-server/HPA
make refresh-hpa-runtime-proof          # Installe/répare metrics-server puis prouve HPA
make production-data-resilience         # Readiness données / backup / restore
make data-resilience-proof              # Secret DB + backup + restore si PostgreSQL est fourni
make production-dockerfiles             # Dockerfiles Laravel production sans dépendances dev/runtime inutiles
make image-size-evidence                # Preuve taille images locales
make secrets-management                 # Validation stratégie secrets moderne
make production-db-secret               # Création mutative du Secret DB externe depuis variables d'env
make production-readiness-campaign      # Campagne production globale, lecture seule par défaut
make verify IMAGE_TAG=dev               # Vérification SBOM/Cosign
make promote SOURCE=dev TARGET=release  # Promotion images
make deploy IMAGE_TAG=release           # Déploiement K8s
make validate                           # Suite de validation
make demo IMAGE_TAG=dev                 # Mode démo complet
make campaign SOURCE=dev TARGET=release # Campagne intégrale
make final-campaign SCENARIO=demo       # Campagne officielle
make release-evidence                   # Preuves release
make release-proof-strict               # Supply chain stricte complète
make release-provenance                 # Provenance SLSA-style
make final-proof                        # Preuve finale complète
make final-summary                      # Résumé exécutif
make final-source-of-truth              # Tableaux finaux sécurité/production/release/mémoire
make support-pack                       # Package de support
make security-posture                   # Source de vérité sécurité factuelle
make kyverno-install                    # Installation Kyverno
make kyverno-runtime-proof              # Preuve Kyverno CRDs/pods/policies/PolicyReports
make kyverno-enforce-readiness          # Décision Enforce prudente
make k8s-ultra-hardening                # Validation PSA restricted / RBAC / NetworkPolicy / probes
make metrics-install                    # Installation metrics-server
make production-cluster                 # Cluster kind production-like, garde destructif
make production-cleanup-plan            # Inventaire legacy sans suppression
CONFIRM_CLEANUP=YES make production-cleanup # Nettoyage legacy runtime, mutatif
make production-cluster-clean-proof     # Preuve production-only runtime et exposition portail
make data-backup                        # Backup PostgreSQL externe si credentials fournis
make data-restore                       # Restore PostgreSQL dans une base isolée
```

---

## 📋 Scénario officiel de soutenance

Configuration recommandée :

```bash
OFFICIAL_SCENARIO=demo \
CAMPAIGN_MODE=dry-run \
make final-campaign
```

Ensuite :
```bash
make final-proof
make final-summary
make supply-chain-evidence
make support-pack
```

**Paramètres** :
- `OFFICIAL_SCENARIO=demo` - Mode déploiement
- `CAMPAIGN_MODE=dry-run` - Simulation (sans forcer vérification/promotion)
- `CAMPAIGN_MODE=execute` - Exécution réelle (Docker, kind, kubectl, Cosign requis)

---

## 📚 Documentation complète

| Runbook | Sujet |
|---------|-------|
| [jenkins-setup.md](./docs/runbooks/jenkins-setup.md) | Configuration Jenkins locale |
| [local-kind.md](./docs/runbooks/local-kind.md) | Cluster Kubernetes kind |
| [production-cluster-clean.md](./docs/runbooks/production-cluster-clean.md) | Cluster production propre et sans legacy runtime |
| [release-promotion.md](./docs/runbooks/release-promotion.md) | Promotion d'images |
| [production-ha.md](./docs/runbooks/production-ha.md) | Overlay production et haute disponibilité |
| [production-readiness-roadmap.md](./docs/runbooks/production-readiness-roadmap.md) | Trajectoire production, HA et exploitation |
| [data-resilience.md](./docs/runbooks/data-resilience.md) | Stratégie données, backup et restore |
| [final-campaign.md](./docs/runbooks/final-campaign.md) | Campagne finale |
| [demo-checklist.md](./docs/runbooks/demo-checklist.md) | Checklist de démo |
| [troubleshooting.md](./docs/runbooks/troubleshooting.md) | Résolution problèmes |
| [final-proof.md](./docs/runbooks/final-proof.md) | Génération de preuves |
| [kyverno-install.md](./docs/runbooks/kyverno-install.md) | Installation Kyverno |
| [control-matrix.md](./docs/security/control-matrix.md) | Source de vérité des contrôles |
| [security-status-source-of-truth.md](./docs/security/security-status-source-of-truth.md) | Règles de statut des preuves |
| [policy-matrix.md](./docs/security/policy-matrix.md) | Matrice de sécurité |
| [devsecops-hardening-applied.md](./docs/security/devsecops-hardening-applied.md) | Renforcements DevSecOps appliqués |

---

## 🏛️ Gouvernance CI/CD

### Source de vérité
**Jenkins est la source de vérité officielle** pour CI/CD.

### Workflows GitHub Actions
- Conservés à titre historique et de référence
- Limités à `workflow_dispatch` (relance manuelle)
- Aucune exécution automatique sur `push`/`pull_request`
- Voir [.github/workflows/README.md](./.github/workflows/README.md)

---

## ⛔ Gates obligatoires (CI → CD)

La promotion vers CD n'est autorisée que si :
- ✅ Tests applicatifs : **PASS**
- ✅ Scans critiques (SAST, secrets, dépendances, Trivy FS) : **PASS**
- ✅ Validation Sonar CPD : **PASS**
- ✅ Images : présentes dans registre cible
- ✅ Trivy image scan : **PASS** ou **WARN** sans `CRITICAL` ; `HIGH` reste documenté et non bloquant par défaut
- ✅ Cosign : vérification signatures réussie
- ✅ Promotion : digest produit et tracé
- ✅ SBOM : générés et attestés
- ✅ Checklist démo : **GREEN**

---

## ⚠️ Limitations actuelles

| Limitation | Impact | Mitigation |
|-----------|--------|-----------|
| Kyverno fourni mais non installé | Policies d'audit en read-only | Voir `docs/runbooks/kyverno-install.md` |
| HPA requiert metrics-server | Pas d'auto-scaling sans addon | Installer `infra/k8s/addons/metrics-server/` |
| Runtime Python legacy absent | Build/deploy non prouvable pour `services/` | Runtime officiel Laravel sous `services-laravel/` |
| Preuve Jenkins complète locale | Requiert Docker/kind/Cosign | Runner préconfiguré ou pré-test en dev |
| Déploiement par digest tracé | Requiert promotion préalable | Vérifier output promotion avant deploy |
| DB externe / backup / restore | Requiert PostgreSQL externe et credentials hors Git | Overlay `production-external-db` + `make data-backup` / `make data-restore` |

---

## 🔮 Roadmap

- [ ] Installation automatique Kyverno dans cluster démo
- [ ] Vérification de signature enforcée à l'admission
- [ ] Renforcement couche observabilité (metrics, logs, traces)
- [ ] Extension tests applicatifs
- [ ] Intégration gestion secrets (Vault, External Secrets)
- [ ] Consolidation preuves Jenkins CI/CD

---

## 📞 Support

Pour assistance :
1. Consulter la documentation dans `docs/runbooks/`
2. Vérifier `docs/runbooks/troubleshooting.md`
3. Lancer les logs support : `make support-pack`
4. Examiner `artifacts/` pour preuves et diagnostics

---

## 📄 Licence & Authorship

Projet Master DSIR - SecureRAG Hub  BY Yassino
2026-2027
