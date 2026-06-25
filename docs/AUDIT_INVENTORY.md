# Phase 0 — Inventaire Global & Cartographie du Dépôt

Ce document fournit un inventaire complet, exhaustif et professionnel de l'ensemble du projet **SecureRAG Hub**. Il sert de base de référence (Single Source of Truth) pour toutes les étapes de l'audit.

---

## 1. Structure Globale du Répertoire

La structure physique du dépôt `/root/MasterPFE` se décompose comme suit :

```text
/root/MasterPFE/
├── .github/                      # Workflows CI/CD GitHub Actions (legacy/maintenance)
├── platform/                     # Composants de la plateforme utilisateur
│   └── portal-web/               # Portail web central (Laravel + Blade + TailwindCSS)
├── services-laravel/             # Microservices métier officiels rédigés en Laravel 10
│   ├── auth-users-service/       # Gestion des utilisateurs et rôles (RBAC)
│   ├── chatbot-manager-service/  # Gestion des chatbots et de la configuration des prompts
│   ├── conversation-service/     # Historique et persistance des messages avec redondance/redaction
│   ├── audit-security-service/   # Traçabilité des incidents, logs d'audit et intégrité
│   └── shared-security/          # Librairie partagée d'autorisation service-to-service
├── services/                     # Squelettes des microservices Python FastAPI (legacy/partiel)
│   ├── api-gateway/              # API Gateway (FastAPI)
│   ├── auth-users/               # Service authentification Python
│   ├── chatbot-manager/          # Catalogue de chatbots Python
│   ├── llm-orchestrator/         # Orchestrateur RAG + LLM Python
│   ├── security-auditor/         # Audit et scoring Python
│   └── knowledge-hub/            # Gestion documentaire Python
├── ai-security/                  # Couche d'analyse IA et détection des menaces (CyberGuard)
│   ├── backend/                  # API FastAPI d'analyse et WebSocket
│   ├── frontend/                 # Dashboard React en mode sombre (MUI + TypeScript)
│   └── log_collector.py          # Script de collecte des logs Loki/Prometheus/K8s
├── infra/                        # Fichiers de configuration d'infrastructure et d'orchestration
│   ├── ansible/                  # Configuration Ansible pour le durcissement des nœuds (CIS)
│   ├── helm/                     # Charts Helm personnalisés et overrides tiers
│   ├── jenkins/                  # Configuration de Jenkins (CasC, Dockerfile Agent, compose)
│   ├── k8s/                      # Fichiers d'infrastructure Kubernetes (Kustomize, ArgoCD)
│   ├── kind/                     # Configuration locale du cluster Kind
│   ├── monitoring/               # Règles d'alertes Prometheus et Dashboards Grafana
│   ├── secrets/                  # Scripts et modèles pour ESO/SOPS/Vault
│   ├── sonarqube/                # Docker-compose pour analyse statique de code
│   └── wazuh/                    # Intégration SIEM Wazuh
├── scripts/                      # Scripts d'automatisation d'administration et DevSecOps
│   ├── ci/                       # Scripts exécutés dans les pipelines CI (Semgrep, Gitleaks)
│   ├── cd/                       # Scripts exécutés dans les pipelines CD (Trivy Image, etc.)
│   ├── deploy/                   # Déploiement des outils (Vault, ESO, Velero)
│   ├── jenkins/                  # Préparation des credentials et kubeconfig
│   ├── release/                  # Gestion de la Supply Chain (SBOM, Cosign, signatures)
│   └── validate/                 # Scripts de validation fonctionnelle et de sécurité
├── security/                     # Configurations de sécurité centralisées
│   ├── semgrep/                  # Règles Semgrep personnalisées
│   ├── trivy/                    # Fichiers de configuration Trivy
│   └── vault/                    # Scripts d'initialisation et de déscellage Vault
├── tests/                        # Tests d'admission Kubernetes et d'intégration
└── docs/                         # Documentation d'architecture, d'exploitation et de conformité
```

---

## 2. Inventaire des Services et Microservices

### A. Périmètre Laravel-First (Officiel & Actif)

| Nom du Service | Langage / Framework | Emplacement | Rôle Fonctionnel | Port |
| :--- | :--- | :--- | :--- | :--- |
| **portal-web** | PHP 8.2 / Laravel 10 | `[platform/portal-web](file:///root/MasterPFE/platform/portal-web)` | Interface utilisateur Web (UI Blade, Administration, DevSecOps) | 8000 (8082 local) |
| **auth-users-service** | PHP 8.2 / Laravel 10 | `[services-laravel/auth-users-service](file:///root/MasterPFE/services-laravel/auth-users-service)` | Fournit le RBAC, les permissions et la gestion des comptes | 8000 (8091 local) |
| **chatbot-manager-service** | PHP 8.2 / Laravel 10 | `[services-laravel/chatbot-manager-service](file:///root/MasterPFE/services-laravel/chatbot-manager-service)` | Catalogue des chatbots et configuration des prompts | 8000 (8092 local) |
| **conversation-service** | PHP 8.2 / Laravel 10 | `[services-laravel/conversation-service](file:///root/MasterPFE/services-laravel/conversation-service)` | Persistance des messages RAG et anonymisation des données | 8000 (8093 local) |
| **audit-security-service** | PHP 8.2 / Laravel 10 | `[services-laravel/audit-security-service](file:///root/MasterPFE/services-laravel/audit-security-service)` | Enregistrement des incidents, logs d'audit avec clé d'intégrité SHA256 | 8000 (8094 local) |

### B. Périmètre AI Security Layer (Actif)

| Nom du Service | Langage / Framework | Emplacement | Rôle Fonctionnel | Port |
| :--- | :--- | :--- | :--- | :--- |
| **ai-inference-service** | Python 3.11 / PyTorch | `[ai-security](file:///root/MasterPFE/ai-security)` | Héberge le modèle `cyberguard-ai-security-analyzer` ou fallback | 8000 |
| **ai-security-backend** | Python 3.11 / FastAPI | `[ai-security/backend](file:///root/MasterPFE/ai-security/backend)` | API orchestratrice, WebSocket, base PostgreSQL | 8080 |
| **ai-security-frontend** | React / MUI / TS | `[ai-security/frontend](file:///root/MasterPFE/ai-security/frontend)` | Dashboard Web de supervision de la sécurité par IA | 5173 |
| **log-collector** | Python 3.11 | `[ai-security/log_collector.py](file:///root/MasterPFE/ai-security/log_collector.py)` | Collecteur asynchrone pour Loki, Prometheus et K8s API | N/A |

### C. Périmètre FastAPI (Squelettes - Exclus de la production active)

| Nom du Service | Langage / Framework | Emplacement | Rôle Fonctionnel | Statut |
| :--- | :--- | :--- | :--- | :--- |
| **api-gateway** | Python 3.11 / FastAPI | `services/api-gateway` | Routage et validation JWT | Partiel (Dockerfile + reqs) |
| **auth-users** | Python 3.11 / FastAPI | `services/auth-users` | Squelette d'authentification Python | Partiel (Dockerfile + reqs) |
| **llm-orchestrator** | Python 3.11 / FastAPI | `services/llm-orchestrator` | Orchestrateur RAG / LLM mock | Partiel (Dockerfile + reqs) |
| **security-auditor** | Python 3.11 / FastAPI | `services/security-auditor` | Analyseur de conformité Python | Partiel (Dockerfile + reqs) |
| **knowledge-hub** | Python 3.11 / FastAPI | `services/knowledge-hub` | Vectorisation de fichiers | Partiel (Dockerfile + reqs) |

---

## 3. Pipelines de CI/CD et Outils Associés

Le moteur CI/CD de référence est **Jenkins** (avec configuration automatisée). Les fichiers et pipelines identifiés sont :

*   **Pipelines Jenkins :**
    *   `[Jenkinsfile](file:///root/MasterPFE/Jenkinsfile)` : Pipeline CI principal (15 étapes : Lint, Tests unitaires PHP, Semgrep SAST, Gitleaks, Trivy FS, Hadolint, SonarQube, etc.).
    *   `[Jenkinsfile.cd](file:///root/MasterPFE/Jenkinsfile.cd)` : Pipeline CD principal (Promotion par digest des images validées, génération du SBOM Syft, signatures Cosign, déploiement dans le cluster de production/kind, validation de DR).
    *   `[Jenkinsfile.recette](file:///root/MasterPFE/Jenkinsfile.recette)` : Déploiement en pré-production/recette avec tests ZAP DAST et tests fonctionnels.
    *   `[Jenkinsfile.weekly](file:///root/MasterPFE/Jenkinsfile.weekly)` : Pipeline hebdomadaire de vérification des dépendances (Renovate).
    *   `[Jenkinsfile.dr](file:///root/MasterPFE/Jenkinsfile.dr)` : Simulation de plan de reprise d'activité (Disaster Recovery).
    *   `[Jenkinsfile.ai](file:///root/MasterPFE/Jenkinsfile.ai)` : Automatisation du déploiement de la stack AI/CyberGuard.
    *   `[Jenkinsfile.nightly](file:///root/MasterPFE/Jenkinsfile.nightly)` : Scans de vulnérabilité planifiés la nuit.
*   **Workflows GitHub Actions (Considérés comme Legacy / Déclenchement manuel) :**
    *   `.github/workflows/ci.yml` : CI basique.
    *   `.github/workflows/ci-pr.yml` : Exécution sur PR (obsolète).
    *   `.github/workflows/build-sign.yml` : Signature (obsolète).
    *   `.github/workflows/rotate-cosign.yml` : Rotation automatisée des clés Cosign.
    *   `.github/workflows/validate-postdeploy.yml` : Tests post-déploiement.

---

## 4. Manifestes Kubernetes et Helm Charts

L'infrastructure Kubernetes utilise le modèle de gestion **Kustomize** pour segmenter les environnements (`base/`, `overlays/dev/`, `overlays/demo/`, `overlays/production/`).

### A. Fichiers de Déploiement K8s Applicatifs (`base/` et `k8s/`)

*   `[k8s/deployments/portal-web-deployment.yaml](file:///root/MasterPFE/k8s/deployments/portal-web-deployment.yaml)` : Déploiement du portail.
*   `[k8s/deployments/falcosidekick-deployment.yaml](file:///root/MasterPFE/k8s/deployments/falcosidekick-deployment.yaml)` : Collecteur des alertes Falco.
*   `[infra/k8s/base/kustomization.yaml](file:///root/MasterPFE/infra/k8s/base/kustomization.yaml)` : Orchestration de la base (portal-web, auth-users, chatbot-manager, conversation-service, audit-security-service, ollama, postgres-auth, qdrant).
*   `[infra/k8s/base/namespace.yaml](file:///root/MasterPFE/infra/k8s/base/namespace.yaml)` : Configuration des namespaces avec enforcement strict des Pod Security Standards (`pod-security.kubernetes.io/enforce: restricted`).
*   `[infra/k8s/base/limitrange.yaml](file:///root/MasterPFE/infra/k8s/base/limitrange.yaml)` & `resourcequota.yaml` : Isolation des ressources.
*   `[k8s/serviceaccounts/](file:///root/MasterPFE/k8s/serviceaccounts/)` : ServiceAccounts individuels avec `automountServiceAccountToken: false`.

### B. Network Policies K8s

*   `[k8s/network-policies/00-default-deny-all.yaml](file:///root/MasterPFE/k8s/network-policies/00-default-deny-all.yaml)` : Zero-Trust Ingress/Egress par défaut.
*   `[k8s/network-policies/01-portal-web-policy.yaml](file:///root/MasterPFE/k8s/network-policies/01-portal-web-policy.yaml)` : Flux portail (limité à l'Ingress Kong/API Gateway).
*   `[k8s/network-policies/02-chatbot-manager-policy.yaml](file:///root/MasterPFE/k8s/network-policies/02-chatbot-manager-policy.yaml)` : Flux vers Ollama et Qdrant.
*   `[k8s/network-policies/03-auth-users-policy.yaml](file:///root/MasterPFE/k8s/network-policies/03-auth-users-policy.yaml)` : Flux authentification vers Postgres.
*   `[k8s/network-policies/04-conversation-service-policy.yaml](file:///root/MasterPFE/k8s/network-policies/04-conversation-service-policy.yaml)` : Flux conversationnel.
*   `[k8s/network-policies/05-audit-security-policy.yaml](file:///root/MasterPFE/k8s/network-policies/05-audit-security-policy.yaml)` : Flux d'audit et incident.
*   `[k8s/network-policies/06-postgresql-policy.yaml](file:///root/MasterPFE/k8s/network-policies/06-postgresql-policy.yaml)` : Isolation des bases relationnelles SQL.
*   `[k8s/network-policies/07-chromadb-qdrant-policy.yaml](file:///root/MasterPFE/k8s/network-policies/07-chromadb-qdrant-policy.yaml)` : Isolation des bases vectorielles.

### C. Helm Charts (Sous `infra/helm/`)

Ces répertoires contiennent des configurations locales et des overrides de valeurs pour :
*   `prometheus` & `grafana` & `loki` & `tempo` (Observabilité)
*   `vault` (Secrets Management)
*   `external-secrets` (ESO Integration)
*   `falco` (Runtime Security)
*   `alertmanager` (Alerte et notification)
*   `postgresql` (Bases de données)
*   `harbor` (Container Registry)

---

## 5. Dockerfiles et Fichiers de Configuration IaC / Provisioning

*   **Dockerfiles applicatifs :**
    *   `[platform/portal-web/Dockerfile](file:///root/MasterPFE/platform/portal-web/Dockerfile)` : Version multi-stage standard.
    *   `[platform/portal-web/Dockerfile.distroless](file:///root/MasterPFE/platform/portal-web/Dockerfile.distroless)` : Version durcie basée sur Distroless PHP.
    *   `[services-laravel/auth-users-service/Dockerfile](file:///root/MasterPFE/services-laravel/auth-users-service/Dockerfile)` : Dockerfile de service PHP/Laravel optimisé.
    *   `[services-laravel/chatbot-manager-service/Dockerfile](file:///root/MasterPFE/services-laravel/chatbot-manager-service/Dockerfile)` : Idem.
    *   `[services-laravel/conversation-service/Dockerfile](file:///root/MasterPFE/services-laravel/conversation-service/Dockerfile)` : Idem.
    *   `[services-laravel/audit-security-service/Dockerfile](file:///root/MasterPFE/services-laravel/audit-security-service/Dockerfile)` : Idem.
    *   `[ai-security/Dockerfile](file:///root/MasterPFE/ai-security/Dockerfile)` : Dockerfile de l'inference engine (CyberGuard).
    *   `[ai-security/backend/Dockerfile](file:///root/MasterPFE/ai-security/backend/Dockerfile)` : Backend FastAPI.
*   **Terraform (IaC - Provisioning) :**
    *   `[infra/terraform/main.tf](file:///root/MasterPFE/infra/terraform/main.tf)` : Déclaration principale supportant AWS, Azure, et GCP.
    *   `[infra/terraform/provider.tf](file:///root/MasterPFE/infra/terraform/provider.tf)` : Déclaration des providers cloud.
    *   `[infra/terraform/remote-state.tf](file:///root/MasterPFE/infra/terraform/remote-state.tf)` : Backend S3/DynamoDB pour stocker les states Terraform.
*   **Ansible (Configuration Management) :**
    *   `[infra/ansible/inventory.ini](file:///root/MasterPFE/infra/ansible/inventory.ini)` : Inventaire des nœuds physiques/VMs.
    *   `[infra/ansible/playbooks/site.yml](file:///root/MasterPFE/infra/ansible/playbooks/site.yml)` : Orchestrateur.
    *   `[infra/ansible/playbooks/cis-node-hardening.yml](file:///root/MasterPFE/infra/ansible/playbooks/cis-node-hardening.yml)` : Application des benchmarks de sécurité CIS sur l'OS hôte.

---

## 6. Outils de Sécurité Détectés et Intégrations

*   **Secrets Management :**
    *   **HashiCorp Vault** : Déploiement structuré sous `security/vault/` avec scripts d'auto-initialisation (`vault-init.sh`).
    *   **External Secrets Operator (ESO)** : Déploiement K8s avec configuration `ClusterSecretStore` et `ExternalSecret` pointant vers Vault.
    *   **SOPS** : Fichier `.sops.yaml` présent à la racine pour chiffrer les fichiers de configuration via PGP/Age.
*   **SAST & SCA Scanners :**
    *   **Semgrep** : Intégration CI bloquante avec règles personnalisées (`security/semgrep/semgrep.yml`).
    *   **Gitleaks** : Scan anti-credentials à la racine (`.gitleaks.toml`).
    *   **Trivy** : Scans FS et images (`security/trivy/trivy.yaml`).
    *   **Checkov** : Scan statique d'IaC Terraform et Helm (`security/checkov-config.yaml`).
    *   **OWASP Dependency-Check** : Audit des vulnérabilités de dépendances PHP/JS (`scripts/ci/run-owasp-dependency-check.sh`).
*   **Admission Control & Policy-as-Code :**
    *   **Kyverno** : Politiques d'admission en mode Audit et Enforce (`infra/k8s/policies/kyverno/`).
    *   **OPA Gatekeeper** : Templates et contraintes de politique en Rego (`infra/k8s/opa-gatekeeper/`).
*   **Runtime Security :**
    *   **Falco** : Agent de détection des comportements anormaux eBPF/K8s avec règles personnalisées (`security/falco/custom-rules.yaml`).
    *   **Falco Talon** : Réaction automatisée aux alertes Falco (kill de pods, isolation réseau).
    *   **Tetragon** : Hardening au niveau eBPF (actuellement optionnel).
    *   **Wazuh** : Agent SIEM configuré sur les workloads.
*   **Supply Chain Trust :**
    *   **Cosign** : Signature des conteneurs via clé privée statique et vérification par Kyverno dans le cluster.
    *   **Syft** : Générateur de SBOM au format CycloneDX.

---

## 7. Composants RAG / IA & Bases Vectorielles

*   **Ollama (LLM Orchestration) :** Déployé sous `infra/k8s/base/ollama/` pour exécuter localement les modèles (Mistral, LLaMA3) sans dépendance cloud.
*   **Qdrant (Vector Database) :** Déployé sous `infra/k8s/base/qdrant/` comme base vectorielle pour l'indexation sémantique.
*   **Embeddings Model :** Sentence-transformers `all-MiniLM-L6-v2` exécuté localement en sidecar.
*   **Pipeline de RAG :** Défini sous `docs/rag-design.md` avec contrôle RBAC-aware direct dans Qdrant (filtre strict sur `metadata.allowed_roles` et `metadata.sensitivity_level`).
