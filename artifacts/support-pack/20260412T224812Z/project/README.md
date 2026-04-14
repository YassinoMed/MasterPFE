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
📦 api-gateway              - Routage centralisé des requêtes
📦 auth-users              - Authentification et gestion profils
📦 chatbot-manager         - Orchestration des chatbots
📦 llm-orchestrator        - Coordination LLM/RAG
📦 security-auditor        - Audit et conformité
📦 knowledge-hub           - Base de connaissances vectorielle
📦 portal-web              - Interface utilisateur Laravel
📦 qdrant                  - Stockage vectoriel
📦 ollama                  - Runtime LLM local
```

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
checkout → lint/test → couverture → Semgrep → Gitleaks → Trivy → archivage rapports
```

### ✓ Phase CD (Déploiement)
```bash
vérification tag → promotion → SBOM → signature → vérification → déploiement → validation
```

### 🔗 Chaîne de confiance
```bash
build → sbom → sign → verify → promote → deploy → validate
```

**Principe clé** : Aucune reconstruction d'image au déploiement.

---

## 📂 Structure du dépôt

```bash
MasterPFE/
├── services/              # Microservices applicatifs
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
Remplace Ollama par un mock HTTP léger pour stabilité maximale.

```bash
REGISTRY_HOST=localhost:5001 IMAGE_PREFIX=securerag-hub IMAGE_TAG=dev \
KUSTOMIZE_OVERLAY=infra/k8s/overlays/demo \
bash scripts/deploy/deploy-kind.sh
```

**Avantages** ✅
- Déploiement fiable et rapide
- Consommation mémoire réduite
- Idéal pour démonstration courte

**Cas d'usage**
- Machine locale limitée en RAM
- Téléchargement lent d'ollama/ollama
- Stabilité prioritaire pour présentation

### Mode DEV (Expérimental avec Ollama)
Runtime LLM authentique et complet.

```bash
REGISTRY_HOST=localhost:5001 IMAGE_PREFIX=securerag-hub IMAGE_TAG=dev \
bash scripts/deploy/deploy-kind.sh
```

**Avantages** ✅
- Runtime fidèle à production
- Chaîne RAG complète

**Limitations** ⚠️
- Premier démarrage lent
- Image volumineuse (~10GB)
- Dépendance aux ressources locales
- Plus fragile pour soutenance

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
- **Mot de passe** : `change-me-now`

### Jobs disponibles
- `securerag-hub-ci` - Pipeline d'intégration
- `securerag-hub-cd` - Pipeline de déploiement

---

## ☸️ Kubernetes & Overlays

### 📦 Base (`infra/k8s/base/`)
Ressources essentielles :
- Namespaces, Services, Deployments, StatefulSets
- Network Policies (sécurité réseau)
- Resource Quotas et Limits
- Pod Disruption Budgets (PDB)
- Horizontal Pod Autoscaler (HPA)

### 🎯 Overlay `dev`
Configuration pour runtime local :
- Images locales `localhost:5001`
- NodePort pour accès externe
- Ollama réel (optionnel)

### 🎭 Overlay `demo`
Configuration pour démonstration :
- Images locales `localhost:5001`
- Mock Ollama HTTP
- Consommation mémoire optimisée

### 🛡️ Policies Kyverno (`infra/k8s/policies/`)
Sécurité d'admission :
- Audit des configurations Pod
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
| `docs/runbooks/jenkins-setup.md` | Credentials Jenkins |

### Pipeline de sécurité
```bash
scripts/release/generate-sbom.sh          # Génération SBOM
scripts/release/sign-images.sh            # Signature des images
scripts/release/verify-signatures.sh      # Vérification Cosign
scripts/release/promote-verified-images.sh    # Promotion
scripts/release/promote-by-digest.sh      # Promotion par digest
scripts/release/record-release-evidence.sh    # Traçabilité
scripts/deploy/verify-and-deploy-kind.sh  # Déploiement sécurisé
```

---

## 🎮 Commandes principales

Le `Makefile` fournit une interface unifiée :

```bash
make help                               # Afficher l'aide
make lint                               # Linting du code
make test                               # Tests unitaires
make verify IMAGE_TAG=dev               # Vérification SBOM/Cosign
make promote SOURCE=dev TARGET=release  # Promotion images
make deploy IMAGE_TAG=release           # Déploiement K8s
make validate                           # Suite de validation
make demo IMAGE_TAG=dev                 # Mode démo complet
make campaign SOURCE=dev TARGET=release # Campagne intégrale
make final-campaign SCENARIO=demo       # Campagne officielle
make release-evidence                   # Preuves release
make final-proof                        # Preuve finale complète
make final-summary                      # Résumé exécutif
make support-pack                       # Package de support
make kyverno-install                    # Installation Kyverno
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
| [release-promotion.md](./docs/runbooks/release-promotion.md) | Promotion d'images |
| [final-campaign.md](./docs/runbooks/final-campaign.md) | Campagne finale |
| [demo-checklist.md](./docs/runbooks/demo-checklist.md) | Checklist de démo |
| [troubleshooting.md](./docs/runbooks/troubleshooting.md) | Résolution problèmes |
| [final-proof.md](./docs/runbooks/final-proof.md) | Génération de preuves |
| [kyverno-install.md](./docs/runbooks/kyverno-install.md) | Installation Kyverno |
| [policy-matrix.md](./docs/security/policy-matrix.md) | Matrice de sécurité |

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
- ✅ Scans critiques (SAST) : **RESOLVED**
- ✅ Images : présentes dans registre cible
- ✅ Cosign : vérification signatures réussie
- ✅ Promotion : digest produit et tracé
- ✅ Checklist démo : **GREEN**

---

## ⚠️ Limitations actuelles

| Limitation | Impact | Mitigation |
|-----------|--------|-----------|
| Kyverno fourni mais non installé | Policies d'audit en read-only | Voir `docs/runbooks/kyverno-install.md` |
| HPA requiert metrics-server | Pas d'auto-scaling sans addon | Installer `infra/k8s/addons/metrics-server/` |
| Mode DEV + Ollama fragile | Risque de timeout déploiement | Préférer mode DÉMO pour soutenance |
| Preuve Jenkins complète locale | Requiert Docker/kind/Cosign | Runner préconfiguré ou pré-test en dev |
| Déploiement par digest tracé | Requiert promotion préalable | Vérifier output promotion avant deploy |

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
