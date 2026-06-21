# Documentation complète du projet SecureRAG Hub

Date de consultation locale : 2026-04-16  
Branche consultée : `main`  
Source principale : dépôt local `/Users/mohamedyassine/Desktop/PFE/Master`

## 1. Résumé exécutif

SecureRAG Hub est un projet de plateforme sécurisée de chatbots métier, structuré comme un démonstrateur DevSecOps/Kubernetes pour un projet Master DSIR. Le dépôt contient :

- un portail Laravel `portal-web` pour les vues utilisateur, administration, sécurité et DevSecOps ;
- des microservices Laravel métier sous `services-laravel/` ;
- une couche de déploiement Kubernetes sous `infra/k8s/` ;
- une CI/CD officielle Jenkins ;
- des scripts de release supply chain : SBOM, signature Cosign, vérification, promotion par digest et preuves ;
- des runbooks et artefacts de soutenance ;
- des fichiers legacy GitHub Actions conservés en exécution manuelle uniquement.

Lecture honnête de l’état actuel :

| Domaine | État | Commentaire |
|---|---|---|
| Portail Laravel | TERMINÉ | `platform/portal-web` dispose de routes, vues, tests et Dockerfile. |
| Microservices Laravel métier | TERMINÉ côté code/tests | Présents sous `services-laravel/`, avec API, migrations, seeders et tests. |
| Déploiement Kubernetes officiel | TERMINÉ côté manifests/rendu | Il référence `portal-web`, `auth-users`, `chatbot-manager`, `conversation-service`, `audit-security-service`. La preuve pods `Ready` reste dépendante du cluster. |
| Services Python legacy sous `services/` | PARTIEL | Les Dockerfiles/requirements existent, mais les sources `.py` applicatives ont été retirées ; ils sont exclus de la build/deploy officielle. |
| CI Jenkins | TERMINÉ côté configuration | `Jenkinsfile`, `Jenkinsfile.cd`, Jenkins CasC et Job DSL existent et ciblent le périmètre Laravel officiel. |
| Supply chain | DÉPENDANT_DE_L_ENVIRONNEMENT | SBOM, Cosign, registry, Docker et clés sont requis. |
| Kyverno / metrics-server | DÉPENDANT_DE_L_ENVIRONNEMENT | Manifests et scripts présents ; preuve réelle requiert un cluster actif. |
| Documentation et preuves | PARTIEL | Les documents sécurité et les artefacts finaux critiques ont été réalignés sur le périmètre Laravel-first ; les preuves runtime restent à régénérer après un déploiement réel. |

## 2. Objectif fonctionnel du projet

SecureRAG Hub vise à fournir une plateforme centralisée permettant :

1. d’administrer des utilisateurs, rôles et permissions ;
2. de gouverner un catalogue de chatbots métier ;
3. de consulter des conversations et historiques ;
4. de tracer des incidents, journaux d’audit et preuves de conformité ;
5. de démontrer une chaîne DevSecOps complète, depuis les tests jusqu’au déploiement Kubernetes ;
6. de produire des preuves exploitables pour la soutenance et le mémoire.

Le projet distingue deux périmètres :

- le périmètre applicatif Laravel : portail, APIs métier, RBAC, audit, conversation de démonstration ;
- le périmètre runtime DevSecOps/Kubernetes : images, cluster kind, policies réseau, sécurité pod, supply chain, validation post-déploiement.

## 3. Structure du dépôt

```text
.
├── README.md
├── Makefile
├── Jenkinsfile
├── Jenkinsfile.cd
├── sonar-project.properties
├── platform/
│   ├── portal-web/
│   ├── gateway/
│   ├── docker-compose.yml
│   └── README.md
├── services-laravel/
│   ├── auth-users-service/
│   ├── chatbot-manager-service/
│   ├── conversation-service/
│   ├── audit-security-service/
│   └── shared-security/
├── services/
│   ├── api-gateway/
│   ├── auth-users/
│   ├── chatbot-manager/
│   ├── llm-orchestrator/
│   ├── security-auditor/
│   └── knowledge-hub/
├── infra/
│   ├── jenkins/
│   ├── kind/
│   └── k8s/
├── scripts/
│   ├── ci/
│   ├── cd/
│   ├── deploy/
│   ├── jenkins/
│   ├── release/
│   ├── secrets/
│   └── validate/
├── security/
│   ├── semgrep/
│   └── trivy/
├── docs/
│   ├── architecture/
│   ├── memoire/
│   ├── openapi/
│   ├── runbooks/
│   ├── security/
│   └── soutenance/
└── artifacts/
    ├── application/
    ├── final/
    ├── jenkins/
    ├── observability/
    ├── release/
    ├── security/
    ├── soutenance/
    └── validation/
```

## 4. Architecture applicative

### 4.1 Portail web

Chemin : `platform/portal-web`

Rôle :

- point d’entrée User/Admin ;
- pages Blade pour le portail utilisateur, l’administration, la gestion des utilisateurs/rôles, la gestion des chatbots, l’historique, la supervision sécurité et la supervision DevSecOps ;
- client backend `PortalBackendClient` capable de consommer les APIs métier ou de retomber sur des données mockées pour stabiliser la démonstration.

Routes principales :

| Route | Rôle |
|---|---|
| `/` | Page d’accueil SecureRAG Hub. |
| `/app` | Tableau de bord utilisateur. |
| `/admin` | Console d’administration. |
| `/admin/users` | Gestion utilisateurs. |
| `/admin/roles` | Gestion rôles et permissions. |
| `/chatbots` | Gestion du catalogue de chatbots. |
| `/chat` | Conversation de démonstration. |
| `/history` | Historique des conversations. |
| `/security` | Supervision sécurité. |
| `/devsecops` | Supervision DevSecOps. |
| `/api/v1/platform/summary` | Résumé technique JSON du portail. |
| `/internal/health` | Santé interne du portail. |

Modes de données :

| Mode | Description |
|---|---|
| `mock` | Données locales de démonstration via `DemoPortalData`. |
| `auto` | Appel API si disponible, fallback mock sinon. |
| `api` | Appel strict des APIs ; une indisponibilité remonte une erreur. |

### 4.2 Microservices Laravel métier

Chemin : `services-laravel`

Ces services sont les services métier Laravel les plus complets du dépôt. Ils ont leurs propres modèles, migrations, seeders, contrôleurs, FormRequest, policies et tests.

| Service | Chemin | Rôle |
|---|---|---|
| Auth Users Service | `services-laravel/auth-users-service` | Utilisateurs, rôles, permissions, affectation de rôles, statut utilisateur. |
| Chatbot Manager Service | `services-laravel/chatbot-manager-service` | Domaines métier, niveaux de sensibilité, chatbots, configurations de prompt, accès par rôle. |
| Conversation Service | `services-laravel/conversation-service` | Conversations persistées, messages, réponses de démonstration, historique. |
| Audit Security Service | `services-laravel/audit-security-service` | Incidents sécurité, journaux d’audit, preuves de conformité. |
| Shared Security | `services-laravel/shared-security` | Code partagé : autorisation service-to-service, redaction des données sensibles, assertions de tests. |

### 4.3 Contrats OpenAPI

Chemin : `docs/openapi`

| Contrat | Fichier |
|---|---|
| Auth Users | `docs/openapi/auth-users-service.yaml` |
| Chatbot Manager | `docs/openapi/chatbot-manager-service.yaml` |
| Conversation | `docs/openapi/conversation-service.yaml` |
| Audit Security | `docs/openapi/audit-security-service.yaml` |

Ces contrats documentent les endpoints `/api/v1` et servent de base pour les tests contractuels et l’intégration du portail.

### 4.4 Services runtime legacy sous `services/`

Chemin : `services`

Ces dossiers contiennent encore les Dockerfiles et requirements des services runtime initialement prévus :

- `api-gateway`
- `auth-users`
- `chatbot-manager`
- `llm-orchestrator`
- `security-auditor`
- `knowledge-hub`

État réel consulté :

- les `Dockerfile` attendent `COPY src ./src` puis `python -m uvicorn src.main:app` ;
- les fichiers `.py` applicatifs ne sont plus présents ;
- les dossiers `src/__pycache__` existent encore, mais ne constituent pas du code source exploitable ;
- les builds Docker de ces services sont donc à considérer comme PARTIELS tant que les sources FastAPI ne sont pas restaurées ;
- ils ont été retirés de la build/deploy officielle au profit des services Laravel réellement présents sous `services-laravel/`.

### 4.5 Runtime Kubernetes officiel actuel

Le runtime officiel `dev`/`demo` est Laravel-first :

| Workload | Source | Port interne | État |
|---|---|---:|---:|
| `portal-web` | `platform/portal-web` | 8000 | TERMINÉ côté manifests/tests |
| `auth-users` | `services-laravel/auth-users-service` | 8000 | TERMINÉ côté manifests/tests |
| `chatbot-manager` | `services-laravel/chatbot-manager-service` | 8000 | TERMINÉ côté manifests/tests |
| `conversation-service` | `services-laravel/conversation-service` | 8000 | TERMINÉ côté manifests/tests |
| `audit-security-service` | `services-laravel/audit-security-service` | 8000 | TERMINÉ côté manifests/tests |

Les preuves runtime à archiver après déploiement réel sont produites par :

```bash
bash scripts/validate/smoke-tests.sh
bash scripts/validate/security-smoke.sh
bash scripts/validate/e2e-functional-flow.sh
bash scripts/validate/collect-runtime-evidence.sh
```

## 5. APIs métier Laravel

### 5.1 Auth Users Service

Base path : `/api/v1`

| Méthode | Endpoint | Rôle |
|---|---|---|
| GET | `/health` | Santé du service. |
| GET | `/users` | Liste des utilisateurs. |
| POST | `/users` | Création utilisateur. |
| GET | `/users/{user}` | Détail utilisateur. |
| PUT | `/users/{user}` | Mise à jour utilisateur. |
| PATCH | `/users/{user}/status` | Changement de statut. |
| POST | `/users/{user}/roles` | Affectation de rôles. |
| GET | `/roles` | Liste des rôles. |
| POST | `/roles` | Création rôle. |
| GET | `/roles/{role}` | Détail rôle. |
| PUT | `/roles/{role}` | Mise à jour rôle. |
| GET | `/permissions` | Liste des permissions. |

RBAC seedé :

- `super-admin`
- `admin-plateforme`
- `admin-securite`
- `user-rh`
- `user-it`

Permissions seedées :

- `users.view`
- `users.create`
- `users.update`
- `users.disable`
- `roles.view`
- `roles.manage`
- `security.view`
- `chatbots.view`
- `chatbots.manage`
- `conversations.use.rh`
- `conversations.use.it`

### 5.2 Chatbot Manager Service

Base path : `/api/v1`

| Méthode | Endpoint | Rôle |
|---|---|---|
| GET | `/health` | Santé du service. |
| GET | `/business-domains` | Liste des domaines métier. |
| POST | `/business-domains` | Création domaine métier. |
| GET | `/business-domains/{domain}` | Détail domaine. |
| PUT | `/business-domains/{domain}` | Mise à jour domaine. |
| GET | `/sensitivity-levels` | Liste niveaux de sensibilité. |
| POST | `/sensitivity-levels` | Création niveau. |
| GET | `/sensitivity-levels/{level}` | Détail niveau. |
| PUT | `/sensitivity-levels/{level}` | Mise à jour niveau. |
| GET | `/chatbots` | Liste chatbots. |
| POST | `/chatbots` | Création chatbot. |
| GET | `/chatbots/{chatbot}` | Détail chatbot. |
| PUT | `/chatbots/{chatbot}` | Mise à jour chatbot. |
| PATCH | `/chatbots/{chatbot}/status` | Changement de statut. |
| GET | `/chatbots/{chatbot}/roles` | Rôles autorisés. |
| PUT | `/chatbots/{chatbot}/roles` | Mise à jour des rôles autorisés. |
| GET | `/chatbots/{chatbot}/prompt-configs` | Configurations de prompt. |
| POST | `/chatbots/{chatbot}/prompt-configs` | Ajout d’une configuration. |

Éléments seedés :

- domaines : `rh`, `support-it` ;
- sensibilités : `faible`, `moyen`, `eleve` ;
- chatbots : `chatbot-rh`, `chatbot-support-it`.

### 5.3 Conversation Service

Base path : `/api/v1`

| Méthode | Endpoint | Rôle |
|---|---|---|
| GET | `/health` | Santé du service. |
| GET | `/conversations` | Liste des conversations. |
| POST | `/conversations` | Création conversation. |
| GET | `/conversations/{conversation}` | Détail conversation. |
| PATCH | `/conversations/{conversation}/status` | Changement de statut. |
| GET | `/conversations/{conversation}/messages` | Liste des messages. |
| POST | `/conversations/{conversation}/messages` | Ajout message utilisateur et réponse mockée. |

Sécurité spécifique :

- redaction des métadonnées sensibles via `SensitiveDataRedactor` ;
- tests unitaires sur la non-persistance des prompts bruts dans les métadonnées.

### 5.4 Audit Security Service

Base path : `/api/v1`

| Méthode | Endpoint | Rôle |
|---|---|---|
| GET | `/health` | Santé du service. |
| GET | `/incidents` | Liste incidents. |
| POST | `/incidents` | Création incident. |
| GET | `/incidents/{incident}` | Détail incident. |
| PATCH | `/incidents/{incident}/status` | Changement de statut. |
| GET | `/audit-logs` | Liste journaux d’audit. |
| POST | `/audit-logs` | Création journal d’audit. |
| GET | `/compliance-evidence` | Liste preuves conformité. |
| POST | `/compliance-evidence` | Création preuve conformité. |

Sécurité spécifique :

- redaction des champs sensibles dans les métadonnées d’audit ;
- empreinte `sha256` et longueur conservées à la place de la valeur brute ;
- génération de `integrity_hash` au moment de la création d’un audit log.

## 6. Architecture Kubernetes

Chemin : `infra/k8s`

### 6.1 Namespace et socle

La base Kustomize se trouve dans `infra/k8s/base` et déclare :

- namespace `securerag-hub` ;
- `ResourceQuota` ;
- `LimitRange` avec `ephemeral-storage` ;
- `NetworkPolicy` default deny ;
- NetworkPolicy DNS ;
- NetworkPolicies par service ;
- ServiceAccounts ;
- PDB pour les composants critiques ;
- HPA pour `portal-web` uniquement dans le périmètre officiel actuel ;
- rôle RBAC runtime read-only pour `audit-security-service`, avec token de ServiceAccount non monté automatiquement par défaut.

### 6.2 Workloads Kubernetes officiels actuels

Déclarés dans `infra/k8s/base/kustomization.yaml` :

| Workload | Type | Commentaire |
|---|---|---|
| `portal-web` | Deployment | Portail Laravel. |
| `auth-users` | Deployment | Service Laravel utilisateurs/RBAC. |
| `chatbot-manager` | Deployment | Service Laravel catalogue chatbots. |
| `conversation-service` | Deployment | Service Laravel conversations. |
| `audit-security-service` | Deployment | Service Laravel audit, événements sécurité et intégrité. |

Important : les anciens workloads Python/RAG (`api-gateway`, `llm-orchestrator`, `security-auditor`, `knowledge-hub`, `qdrant`, `ollama`) ne font plus partie du déploiement officiel tant que les sources applicatives absentes ne sont pas restaurées et revalidées.

### 6.3 Overlays

| Overlay | Chemin | Usage |
|---|---|---|
| Dev | `infra/k8s/overlays/dev` | Images locales `localhost:5001`, NodePort, pull policy `Always`. |
| Demo | `infra/k8s/overlays/demo` | Images locales tag `demo`, NodePort, pull policy `IfNotPresent`, périmètre Laravel-first. |
| Kyverno Audit | `infra/k8s/policies/kyverno` | Policies en audit. |
| Kyverno Enforce | `infra/k8s/policies/kyverno-enforce` | Préparation prudente de l’enforcement. |

### 6.4 Sécurité Kubernetes

Contrôles présents :

- `runAsNonRoot` sur la majorité des workloads applicatifs ;
- `allowPrivilegeEscalation: false` ;
- `capabilities.drop: ["ALL"]` ;
- `seccompProfile: RuntimeDefault` ;
- `automountServiceAccountToken: false` ;
- `readOnlyRootFilesystem: true` quand compatible ;
- CPU/mémoire/ephemeral-storage en `requests` et `limits` ;
- NetworkPolicies par flux attendu ;
- default deny ingress/egress ;
- annotation explicite des flux HTTP internes en clair.

Contrôles dépendants de l’environnement :

- HPA exploitable uniquement si `metrics-server` fonctionne ;
- Kyverno exploitable uniquement si le contrôleur est installé ;
- vérification Cosign admission exploitable uniquement si les images sont signées et le registre joignable.

## 7. CI/CD Jenkins

Jenkins est la source officielle de vérité CI/CD du projet.

Fichiers principaux :

| Fichier | Rôle |
|---|---|
| `Jenkinsfile` | Pipeline CI : checkout, préparation, installation dépendances, lint/tests, Semgrep, Gitleaks, Trivy. |
| `Jenkinsfile.cd` | Pipeline CD : vérification signatures, promotion digest, SBOM, gate supply chain, release evidence, déploiement kind, validation. |
| `infra/jenkins/docker-compose.yml` | Jenkins local reproductible. |
| `infra/jenkins/casc/jenkins.yaml` | Configuration Jenkins as Code. |
| `infra/jenkins/jobs/*.groovy` | Jobs Jenkins générés par Job DSL. |

Pipeline CI :

```text
Checkout
Prepare Workspace
Install CI Dependencies
Lint and Tests
Security Scans
Archive reports
```

Pipeline CD :

```text
Checkout
Prepare Workspace
Verify Release Candidate Signatures
Promote Verified Images by Digest
Generate SBOM
Assert Mandatory Supply Chain Evidence
Record Release Evidence
Collect Supply Chain Evidence
Deploy to kind
Post-deploy Validation
Build Support Pack
```

GitHub Actions :

- workflows présents dans `.github/workflows/` ;
- statut legacy ;
- déclenchement uniquement `workflow_dispatch` ;
- Jenkins reste prioritaire.

## 8. Supply chain et release

Scripts principaux :

| Script | Rôle |
|---|---|
| `scripts/release/generate-sbom.sh` | Génère les SBOM CycloneDX. |
| `scripts/release/sign-images.sh` | Signe les images avec Cosign. |
| `scripts/release/verify-signatures.sh` | Vérifie les signatures. |
| `scripts/release/promote-by-digest.sh` | Promeut les images par digest sans rebuild. |
| `scripts/release/promote-verified-images.sh` | Variante de promotion après vérification. |
| `scripts/release/assert-supply-chain-evidence.sh` | Gate obligatoire de preuves release. |
| `scripts/release/record-release-evidence.sh` | Produit les preuves release. |
| `scripts/release/generate-release-attestation.sh` | Produit l’attestation JSON/Markdown. |
| `scripts/release/collect-supply-chain-evidence.sh` | Consolide les preuves supply chain. |
| `scripts/release/run-supply-chain-execute.sh` | Orchestration complète sign/verify/promote/SBOM/evidence. |

Dépendances :

- Docker ;
- registry local ou distant ;
- Syft ;
- Cosign ;
- clés Cosign ou identité keyless ;
- connectivité registry ;
- images déjà construites et poussées.

État honnête :

- les scripts sont présents et structurés ;
- l’état TERMINÉ dépend de l’existence de preuves `PASS` par service ;
- en l’absence d’environnement complet, le statut reste `DÉPENDANT_DE_L_ENVIRONNEMENT` ou `PRÊT_NON_EXÉCUTÉ`.

## 9. SonarQube / SonarCloud

Fichier : `sonar-project.properties`

Portée actuelle :

- sources : `services-laravel`, `platform`, `scripts`, `infra` ;
- tests : tests Laravel métier et tests portail ;
- exclusions : vendor, node_modules, caches, artefacts, Python, storage, bootstrap cache, composer.lock ;
- version Python fixée à `3.11` pour éviter les warnings résiduels ;
- exclusions CPD sur boilerplate Laravel/Kubernetes et fichiers générés.

Dernière correction effectuée sur la duplication :

- factorisation des tests `AuthorizationSecurityTest.php` ;
- ajout du trait `services-laravel/shared-security/src/Testing/ServiceAuthorizationTestAssertions.php` ;
- validation locale ciblée `jscpd` : `0 clone` sur les tests concernés ;
- mise à jour réelle du dashboard Sonar dépend d’une nouvelle analyse Jenkins/Sonar.

## 10. Sécurité applicative Laravel

### 10.1 Autorisation des FormRequest

Le projet utilise `AuthorizesServiceRequest` pour éviter les `authorize(): true` non contrôlés.

Principe :

- refus par défaut si aucun token n’est configuré ;
- bypass local/test uniquement opt-in explicite ;
- support du header `X-SecureRAG-Service-Token` ;
- support du bearer token ;
- comparaison par `hash_equals`.

### 10.2 Policies

Présentes notamment pour :

- utilisateurs ;
- rôles ;
- chatbots ;
- domaines métier ;
- conversations ;
- incidents sécurité.

Les policies évitent les autorisations inconditionnelles sur les actions sensibles.

### 10.3 Redaction des données sensibles

`SensitiveDataRedactor` détecte :

- prompts ;
- messages ;
- corps de requête ;
- secrets ;
- mots de passe ;
- tokens ;
- clés API ;
- credentials.

À la place de la valeur brute, il conserve :

- `redacted: true` ;
- `sha256` ;
- `length`.

### 10.4 Audit trail

Le service `audit-security-service` maintient :

- incidents sécurité ;
- audit logs ;
- compliance evidence ;
- hash d’intégrité sur les logs d’audit.

## 11. Commandes de développement local

### 11.1 Prérequis recommandés

```bash
php -v
composer --version
node --version
npm --version
docker --version
kubectl version --client
kind --version
```

Pour les chemins supply chain :

```bash
syft version
cosign version
trivy --version
semgrep --version
```

### 11.2 Installation du portail Laravel

```bash
cd platform/portal-web
composer install
cp .env.example .env
php artisan key:generate
touch database/database.sqlite
php artisan migrate --force
npm install
npm run build
php artisan serve --host=127.0.0.1 --port=8082
```

Accès :

```text
http://127.0.0.1:8082
```

### 11.3 Lancement via Docker Compose du portail

```bash
cd platform
docker compose up --build
```

Accès :

```text
http://localhost:8081
http://localhost:8082
```

### 11.4 Installation des microservices Laravel

Auth Users :

```bash
cd services-laravel/auth-users-service
composer install
cp .env.example .env
php artisan key:generate
touch database/database.sqlite
php artisan migrate --seed
php artisan serve --host=127.0.0.1 --port=8091
```

Chatbot Manager :

```bash
cd services-laravel/chatbot-manager-service
composer install
cp .env.example .env
php artisan key:generate
touch database/database.sqlite
php artisan migrate --seed
php artisan serve --host=127.0.0.1 --port=8092
```

Conversation :

```bash
cd services-laravel/conversation-service
composer install
cp .env.example .env
php artisan key:generate
touch database/database.sqlite
php artisan migrate --seed
php artisan serve --host=127.0.0.1 --port=8093
```

Audit Security :

```bash
cd services-laravel/audit-security-service
composer install
cp .env.example .env
php artisan key:generate
touch database/database.sqlite
php artisan migrate --seed
php artisan serve --host=127.0.0.1 --port=8094
```

### 11.5 Tests Laravel

Tous les tests Laravel :

```bash
make laravel-test
```

Tests d’un service :

```bash
cd services-laravel/auth-users-service
php artisan test
```

### 11.6 Lint global non destructif

```bash
make lint
```

Ce target vérifie :

- syntaxe Bash ;
- configuration Docker Compose Jenkins ;
- rendu Kustomize des overlays `dev` et `demo` ;
- policies Kyverno ;
- scope HTTP clair interne ;
- resource guards Kubernetes.

### 11.7 Tests CI legacy Python

```bash
make test
```

Lecture honnête :

- `scripts/ci/run-tests.sh` cherche des tests Python sous `services` et `tests` ;
- si aucun test Python n’est présent, il produit `no-tests.txt` et quitte en succès ;
- la validation Laravel réelle passe par `make laravel-test`.

## 12. Développement Kubernetes local

### 12.1 Création du cluster kind

```bash
bash scripts/deploy/create-kind.sh
```

### 12.2 Initialisation des secrets

```bash
bash scripts/secrets/bootstrap-local-secrets.sh
bash scripts/secrets/create-dev-secrets.sh
```

### 12.3 Build et push d’images locales

```bash
REGISTRY_HOST=localhost:5001 IMAGE_TAG=dev bash scripts/deploy/build-local-images.sh
```

Point de vigilance actuel :

- ce script construit les composants par défaut de `services/` et `platform/portal-web` ;
- les services sous `services/` ont des Dockerfiles Python qui attendent `src/main.py` ;
- tant que les sources Python ne sont pas présentes, il faut limiter `COMPONENTS` ou rétablir un code runtime valide.

Exemple limité au portail :

```bash
COMPONENTS=platform/portal-web REGISTRY_HOST=localhost:5001 IMAGE_TAG=dev bash scripts/deploy/build-local-images.sh
```

### 12.4 Déploiement dev

```bash
REGISTRY_HOST=localhost:5001 IMAGE_PREFIX=securerag-hub IMAGE_TAG=dev \
KUSTOMIZE_OVERLAY=infra/k8s/overlays/dev \
bash scripts/deploy/deploy-kind.sh
```

### 12.5 Déploiement demo

```bash
REGISTRY_HOST=localhost:5001 IMAGE_PREFIX=securerag-hub IMAGE_TAG=demo \
KUSTOMIZE_OVERLAY=infra/k8s/overlays/demo \
bash scripts/deploy/deploy-kind.sh
```

### 12.6 Validation post-déploiement

```bash
bash scripts/validate/smoke-tests.sh
bash scripts/validate/security-smoke.sh
bash scripts/validate/e2e-functional-flow.sh
bash scripts/validate/rag-smoke.sh
bash scripts/validate/security-adversarial-advanced.sh
bash scripts/validate/generate-validation-report.sh
bash scripts/validate/collect-runtime-evidence.sh
```

Ou via Makefile :

```bash
make validate
```

## 13. Développement Jenkins local

### 13.1 Préparation

```bash
bash scripts/jenkins/bootstrap-local-credentials.sh
bash scripts/jenkins/bootstrap-local-kubeconfig.sh
docker compose -f infra/jenkins/docker-compose.yml up --build -d
bash scripts/jenkins/wait-for-jenkins.sh
```

### 13.2 Accès

```text
URL: http://localhost:8085
Utilisateur: admin
Mot de passe local par défaut: change-me-now
```

Ce mot de passe est uniquement acceptable en environnement local de démonstration. Il doit être remplacé dans tout environnement partagé.

### 13.3 Jobs

| Job | Rôle |
|---|---|
| `securerag-hub-ci` | CI : tests, lint, SAST, secrets, Trivy. |
| `securerag-hub-cd` | CD : verify, promote, SBOM, gate, deploy, validate, support pack. |

## 14. Étapes de développement du projet

Cette séquence est reconstituée depuis la structure du dépôt, les scripts, les runbooks et les artefacts. Elle décrit les étapes de construction du projet de manière exploitable.

### Étape 1 : cadrage du périmètre

Objectifs :

- définir SecureRAG Hub comme plateforme de chatbots métier sécurisés ;
- séparer plateforme applicative, runtime Kubernetes et chaîne DevSecOps ;
- choisir Jenkins comme CI/CD officielle ;
- conserver GitHub Actions comme legacy manuel.

Livrables :

- `README.md` ;
- `docs/architecture/*` ;
- `.github/workflows/README.md`.

### Étape 2 : structuration du dépôt

Objectifs :

- isoler `platform/` pour le portail ;
- isoler `services-laravel/` pour les microservices métier ;
- isoler `infra/` pour Kubernetes, kind et Jenkins ;
- isoler `scripts/` pour l’automatisation ;
- isoler `security/` pour les règles SAST/Trivy ;
- isoler `docs/` et `artifacts/` pour runbooks et preuves.

Livrables :

- arborescence actuelle du dépôt ;
- `Makefile` comme interface centrale.

### Étape 3 : développement du portail Laravel

Objectifs :

- créer une interface utilisateur/admin ;
- exposer les vues principales ;
- fournir une API de résumé ;
- permettre un mode fallback mock.

Livrables :

- `platform/portal-web/routes/web.php` ;
- `platform/portal-web/routes/api.php` ;
- `platform/portal-web/app/Http/Controllers/Portal/DashboardController.php` ;
- `platform/portal-web/app/Services/PortalBackendClient.php` ;
- `platform/portal-web/app/Support/DemoPortalData.php` ;
- vues Blade sous `resources/views`.

Validation :

```bash
cd platform/portal-web
php artisan test
```

### Étape 4 : développement du service Auth/RBAC

Objectifs :

- modéliser utilisateurs, rôles, permissions ;
- seed des rôles et permissions de démonstration ;
- fournir endpoints CRUD contrôlés.

Livrables :

- modèles `User`, `Role`, `Permission` ;
- migrations RBAC ;
- `RbacSeeder` ;
- controllers `UserController`, `RoleController`, `PermissionController` ;
- policies `UserPolicy`, `RolePolicy`.

Validation :

```bash
cd services-laravel/auth-users-service
php artisan test
```

### Étape 5 : développement du service Chatbot Manager

Objectifs :

- gérer le catalogue de chatbots ;
- gérer domaines métier et niveaux de sensibilité ;
- gérer accès par rôle ;
- versionner les configurations de prompt.

Livrables :

- modèles `BusinessDomain`, `SensitivityLevel`, `Chatbot`, `ChatbotPromptConfig`, `ChatbotAccessRule` ;
- migrations catalogue ;
- `ChatbotCatalogSeeder` ;
- controllers API v1 ;
- policies `ChatbotPolicy`, `BusinessDomainPolicy`.

Validation :

```bash
cd services-laravel/chatbot-manager-service
php artisan test
```

### Étape 6 : développement du service Conversation

Objectifs :

- persister conversations et messages ;
- fournir historique ;
- produire une réponse assistant déterministe pour la démo ;
- éviter la persistance brute de champs sensibles en métadonnées.

Livrables :

- modèles `Conversation`, `Message` ;
- service `ConversationService` ;
- redaction via `SensitiveDataRedactor` ;
- endpoints `/conversations` et `/messages`.

Validation :

```bash
cd services-laravel/conversation-service
php artisan test
```

### Étape 7 : développement du service Audit Security

Objectifs :

- gérer incidents sécurité ;
- journaliser événements d’audit ;
- stocker preuves de conformité ;
- garantir une forme d’intégrité des logs via hash.

Livrables :

- modèles `SecurityIncident`, `AuditLog`, `ComplianceEvidence` ;
- service `SecurityAuditService` ;
- seeders de démo ;
- tests de redaction et d’intégrité.

Validation :

```bash
cd services-laravel/audit-security-service
php artisan test
```

### Étape 8 : factorisation sécurité partagée

Objectifs :

- éviter la duplication de logique d’autorisation ;
- éviter la duplication de logique de redaction ;
- éviter la duplication de tests d’autorisation.

Livrables :

- `services-laravel/shared-security/src/Http/Requests/Concerns/AuthorizesServiceRequest.php` ;
- `services-laravel/shared-security/src/Support/SensitiveDataRedactor.php` ;
- `services-laravel/shared-security/src/Testing/ServiceAuthorizationTestAssertions.php`.

Validation :

```bash
make laravel-test
```

### Étape 9 : conteneurisation

Objectifs :

- fournir des Dockerfiles non-root ;
- préparer le portail Laravel en image ;
- préparer les services runtime.

Livrables :

- `platform/portal-web/Dockerfile` ;
- `services/*/Dockerfile` ;
- `services-laravel/*/Dockerfile`.

Point de vigilance :

- les Dockerfiles de `services/` attendent des sources Python absentes ;
- les Dockerfiles des services Laravel existent, mais ne sont pas encore tous dans le build/deploy officiel.

### Étape 10 : infrastructure Kubernetes

Objectifs :

- déployer la plateforme sur kind ;
- appliquer des politiques réseau ;
- définir ressources et limites ;
- prévoir HPA/PDB ;
- séparer overlays dev/demo.

Livrables :

- `infra/k8s/base` ;
- `infra/k8s/overlays/dev` ;
- `infra/k8s/overlays/demo` ;
- `infra/k8s/policies/kyverno` ;
- `infra/k8s/policies/kyverno-enforce`.

Validation :

```bash
kubectl kustomize infra/k8s/overlays/dev >/dev/null
kubectl kustomize infra/k8s/overlays/demo >/dev/null
make k8s-resource-guards
make k8s-cleartext-scope
```

### Étape 11 : CI Jenkins

Objectifs :

- automatiser tests et scans ;
- archiver rapports ;
- faire de Jenkins la source de vérité.

Livrables :

- `Jenkinsfile` ;
- `infra/jenkins/*` ;
- `scripts/ci/*`.

Validation :

```bash
docker compose -f infra/jenkins/docker-compose.yml config >/dev/null
```

### Étape 12 : CD, supply chain et preuves

Objectifs :

- vérifier les signatures ;
- promouvoir par digest ;
- générer SBOM ;
- rendre les preuves release obligatoires ;
- produire attestation et support pack.

Livrables :

- `Jenkinsfile.cd` ;
- `scripts/release/*` ;
- `scripts/cd/run-final-campaign.sh` ;
- `artifacts/release/*`.

Validation :

```bash
make supply-chain-evidence
make release-attestation
make support-pack
```

Pour exécution complète :

```bash
make supply-chain-execute
bash scripts/release/assert-supply-chain-evidence.sh
```

### Étape 13 : sécurité applicative et SAST

Objectifs :

- détecter les retours `authorize(): true` ;
- détecter les logs bruts ;
- détecter les protocoles HTTP non justifiés ;
- réduire les duplications Sonar.

Livrables :

- `security/semgrep/semgrep.yml` ;
- `sonar-project.properties` ;
- `services-laravel/shared-security/*`.

Validation :

```bash
semgrep scan --config security/semgrep/semgrep.yml --error
sonar-scanner
```

La commande `sonar-scanner` dépend de l’installation et de la configuration Sonar locales.

### Étape 14 : validation et artefacts soutenance

Objectifs :

- produire des preuves lisibles ;
- distinguer état réel, prêt non exécuté et dépendant de l’environnement ;
- produire un support pack.

Livrables :

- `scripts/validate/*` ;
- `docs/runbooks/*` ;
- `docs/security/*` ;
- `artifacts/*`.

Validation :

```bash
make final-proof
make final-summary
make security-posture
make support-pack
```

## 15. Commandes Makefile importantes

| Commande | Rôle |
|---|---|
| `make help` | Affiche les targets disponibles. |
| `make lint` | Validation syntaxe/scripts/Kustomize/sécurité K8s statique. |
| `make test` | Tests CI Python legacy et couverture si présents. |
| `make laravel-test` | Tests Laravel portail + services métier. |
| `make verify` | Vérification signatures images. |
| `make promote` | Promotion images vérifiées. |
| `make promote-digest` | Promotion par digest. |
| `make deploy` | Vérification puis déploiement kind. |
| `make validate` | Validation post-déploiement. |
| `make demo` | Déploiement overlay demo. |
| `make campaign` | Campagne verify/promote/deploy/validate. |
| `make final-campaign` | Campagne officielle + support pack. |
| `make release-evidence` | Rapport preuves release. |
| `make release-attestation` | Attestation release. |
| `make supply-chain-evidence` | Consolidation preuves supply chain. |
| `make supply-chain-execute` | Exécution complète supply chain. |
| `make observability-snapshot` | Snapshot observabilité K8s/Jenkins. |
| `make security-posture` | Rapport posture sécurité. |
| `make kyverno-install` | Installation Kyverno Audit. |
| `make kyverno-enforce` | Installation Kyverno Enforce. |
| `make metrics-install` | Installation metrics-server. |
| `make support-pack` | Archive support pack. |
| `make clean` | Suppression d’artefacts générés locaux. |

## 16. Documentation existante importante

### Architecture

| Fichier | Sujet |
|---|---|
| `docs/architecture/devsecops-target.md` | Cible DevSecOps. |
| `docs/architecture/jenkins-devsecops.md` | Architecture Jenkins. |
| `docs/architecture/laravel-platform-architecture.md` | Architecture Laravel. |
| `docs/architecture/securerag-deployment-target.md` | Cible de déploiement. |

### Runbooks

| Fichier | Sujet |
|---|---|
| `docs/runbooks/local-kind.md` | Cluster kind local. |
| `docs/runbooks/jenkins-setup.md` | Jenkins local. |
| `docs/runbooks/release-promotion.md` | Promotion release. |
| `docs/runbooks/final-campaign.md` | Campagne finale. |
| `docs/runbooks/demo-checklist.md` | Checklist soutenance. |
| `docs/runbooks/kyverno-install.md` | Installation Kyverno. |
| `docs/runbooks/metrics-server.md` | Installation metrics-server. |
| `docs/runbooks/troubleshooting.md` | Diagnostic incidents. |

### Sécurité

| Fichier | Sujet |
|---|---|
| `docs/security/security-status-source-of-truth.md` | Source de vérité sécurité. |
| `docs/security/control-matrix.md` | Matrice des contrôles. |
| `docs/security/policy-matrix.md` | Matrice Kyverno/policies. |
| `docs/security/k8s-laravel-service-integration-status.md` | Statut intégration Laravel/K8s. |
| `docs/security/secrets-strategy.md` | Stratégie secrets. |
| `docs/security/secrets-management-hardening.md` | Durcissement secrets. |

### Mémoire et soutenance

| Fichier | Sujet |
|---|---|
| `docs/soutenance/demo-5-7-minutes-expert.md` | Script de démo. |
| `docs/soutenance/tableau-taches-securerag-hub.md` | Tableau des tâches. |
| `docs/memoire/*` | Annexes, validation, références et éléments de mémoire. |

## 17. Artefacts de preuve

Répertoires principaux :

| Répertoire | Contenu |
|---|---|
| `artifacts/release` | Attestation, evidence release, supply chain evidence, manifest. |
| `artifacts/validation` | Rapports de validation post-déploiement. |
| `artifacts/security` | Rapports posture sécurité, cleartext scope, resource guards. |
| `artifacts/observability` | Snapshot observabilité. |
| `artifacts/application` | Preuve connectivité portail/services. |
| `artifacts/final` | Synthèses finales de soutenance. |
| `artifacts/jenkins` | Preuves Jenkins/webhook. |

Point de vigilance :

- `artifacts/final/global-project-status.md` et `artifacts/final/final-validation-summary.md` contiennent des marqueurs de conflit Git dans l’état consulté. Ces fichiers ne doivent pas être cités comme preuves propres tant qu’ils ne sont pas corrigés ou régénérés.

## 18. Validation recommandée avant soutenance

Validation statique non destructive :

```bash
make lint
make laravel-test
make k8s-cleartext-scope
make k8s-resource-guards
make security-posture
```

Validation Sonar :

```bash
sonar-scanner
```

Validation cluster si environnement prêt :

```bash
bash scripts/deploy/create-kind.sh
bash scripts/secrets/bootstrap-local-secrets.sh
bash scripts/secrets/create-dev-secrets.sh
make metrics-install
make kyverno-install
make cluster-security-proof
```

Validation supply chain si environnement prêt :

```bash
make supply-chain-execute
bash scripts/release/assert-supply-chain-evidence.sh
make release-attestation
make supply-chain-evidence
```

Validation finale :

```bash
make final-proof
make final-summary
make support-pack
```

## 19. Limites et incohérences à corriger

| Sujet | État | Impact | Correction recommandée |
|---|---|---|---|
| Dockerfiles Python sous `services/` sans sources `.py` | PARTIEL | Les builds runtime par défaut peuvent échouer. | Restaurer/remplacer les sources, ou retirer ces services du build officiel, ou basculer les manifests vers Laravel. |
| `conversation-service` Laravel absent du K8s officiel | PARTIEL | Service prêt côté code, non prouvé runtime. | Ajouter Deployment/Service/NetworkPolicy/probes/secrets, puis archiver preuve runtime. |
| `audit-security-service` Laravel absent du K8s officiel | PARTIEL | Audit Laravel prêt côté code, non prouvé runtime. | Ajouter manifests et preuve runtime. |
| Artefacts finaux avec marqueurs de conflit | PARTIEL | Preuves documentaires non propres. | Régénérer via scripts ou résoudre les conflits sans inventer de résultats. |
| Kyverno Audit/Enforce | DÉPENDANT_DE_L_ENVIRONNEMENT | Pas de preuve sans cluster actif. | Installer Kyverno puis archiver `clusterpolicies` et `policyreports`. |
| metrics-server/HPA | DÉPENDANT_DE_L_ENVIRONNEMENT | HPA non exploitable sans métriques. | Installer metrics-server puis archiver `kubectl top` et `kubectl get hpa`. |
| Supply chain complète | DÉPENDANT_DE_L_ENVIRONNEMENT | Pas de validation release sans Docker/registry/Syft/Cosign. | Exécuter `make supply-chain-execute` dans un environnement outillé. |
| Jenkins webhook réel | DÉPENDANT_DE_L_ENVIRONNEMENT | Preuve webhook dépend de l’exposition réseau. | Utiliser tunnel public ou Jenkins accessible par GitHub. |

## 20. Roadmap de consolidation

Priorité P0 :

1. nettoyer les artefacts avec marqueurs de conflit ;
2. clarifier officiellement le statut des services Python legacy ;
3. rendre le build Docker cohérent avec le code réellement présent ;
4. relancer Sonar/Jenkins après correction ;
5. régénérer les preuves finales propres.

Priorité P1 :

1. intégrer `conversation-service` Laravel dans Kubernetes ;
2. intégrer `audit-security-service` Laravel dans Kubernetes ;
3. ajouter NetworkPolicies dédiées pour ces deux services ;
4. ajouter probes et resource guards ;
5. ajouter preuves runtime dédiées.

Priorité P2 :

1. stabiliser Kyverno Enforce ;
2. renforcer secrets management avec une solution type External Secrets ou Vault ;
3. enrichir observabilité logs/métriques/traces ;
4. compléter les tests contractuels OpenAPI.

## 21. Guide rapide pour reprendre le développement

1. Vérifier l’état Git :

```bash
git status --short
```

2. Installer les dépendances Laravel :

```bash
for app in platform/portal-web services-laravel/auth-users-service services-laravel/chatbot-manager-service services-laravel/conversation-service services-laravel/audit-security-service; do
  (cd "$app" && composer install)
done
```

3. Regénérer les autoloads :

```bash
for app in services-laravel/auth-users-service services-laravel/chatbot-manager-service services-laravel/conversation-service services-laravel/audit-security-service; do
  (cd "$app" && composer dump-autoload --no-interaction)
done
```

4. Lancer les tests :

```bash
make laravel-test
```

5. Vérifier Kustomize et sécurité statique :

```bash
make lint
```

6. Corriger les artefacts conflictuels ou les régénérer :

```bash
make global-project-status
make final-summary
```

7. Préparer la preuve finale :

```bash
make devsecops-readiness
make security-posture
make support-pack
```

## 22. Conclusion

SecureRAG Hub est un projet déjà très avancé côté architecture DevSecOps, portail Laravel, microservices métier, scripts de release et documentation. Sa force est la présence d’une vraie démarche de preuve : Makefile, Jenkins, Kustomize, validations, artefacts, runbooks et matrices de sécurité.

La lecture technique actuelle impose toutefois de ne pas surdéclarer certains éléments :

- les microservices Laravel métier sont solides côté code/tests, mais pas tous intégrés au Kubernetes officiel ;
- les services runtime legacy sous `services/` ne sont pas build-ready si les sources Python restent absentes ;
- certaines preuves finales doivent être régénérées à cause de marqueurs de conflit Git ;
- la supply chain complète, Kyverno et metrics-server nécessitent un environnement d’exécution réel.

Avec ces points clarifiés et corrigés, le projet peut être présenté comme une plateforme SecureRAG Hub crédible, orientée sécurité, démontrable en mode `demo`, et prête à évoluer vers une intégration Kubernetes plus complète.
