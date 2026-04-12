# SecureRAG Hub

SecureRAG Hub est une plateforme unifiee de chatbots metiers securises, concue comme un projet de type PFE Master DSIR et structuree autour d'une architecture microservices, d'une chaine DevSecOps, d'un deploiement Kubernetes local sur `kind` et d'un portail Laravel.

Ce depot contient :

- les microservices applicatifs ;
- le portail `portal-web` ;
- la couche DevSecOps complete ;
- le socle Kubernetes `base/overlay` ;
- le runtime local `kind` ;
- la chaine de confiance `verify -> promote -> deploy -> validate` ;
- la documentation technique et memoire associee.

## Objectifs du projet

- heberger plusieurs chatbots metiers securises ;
- exposer une plateforme web user/admin coherente ;
- industrialiser la construction, la verification, la signature et le deploiement des images ;
- demontrer une demarche DevSecOps reproductible localement ;
- produire des preuves reutilisables pour le memoire et la soutenance.

## Architecture d'ensemble

### Composants applicatifs
- `api-gateway`
- `auth-users`
- `chatbot-manager`
- `llm-orchestrator`
- `security-auditor`
- `knowledge-hub`
- `portal-web`
- `qdrant`
- `ollama`

### Plateforme et outillage
- `Docker` pour la construction des images
- `kind` pour le cluster local
- `Kustomize` pour les manifests `base/overlay`
- `Jenkins` comme source de verite CI/CD
- `Semgrep`, `Gitleaks`, `Trivy` pour les controles de securite
- `Syft` pour les SBOM
- `Cosign` pour la signature et la verification des images
- `Kyverno` pour les policies d'admission optionnelles

## Pipeline CI/CD de reference

Jenkins est la reference officielle.

### CI
- checkout
- lint et tests
- couverture
- Semgrep
- Gitleaks
- Trivy filesystem
- archivage des rapports

### CD
- verification du tag candidat
- promotion sans reconstruction
- promotion par digest traçable
- generation du SBOM
- production d'une preuve de release
- verification avant deploiement
- deploiement sur `kind`
- validation post-deploiement
- archivage des preuves et support pack

### Chaine de confiance

La chaine retenue est la suivante :

```text
verify -> promote -> deploy -> validate
```

Plus completement :

```text
build -> sbom -> sign -> verify -> promote -> deploy -> validate
```

Le pipeline CD ne doit pas reconstruire l'image a deployer.

## Scenario officiel de soutenance

Le scenario officiel recommande est le suivant :

- **mode** : `demo`
- **promotion** : `digest`
- **validation image** : `python:3.12-slim`
- **campagne** : `scripts/cd/run-final-campaign.sh`

Le mode `real` avec `Ollama` reste disponible, mais doit etre reserve a une machine prealablement stabilisee et a une demonstration preparee.

## Structure du depot

```text
services/                 Microservices applicatifs
platform/                 Portail Laravel et architecture applicative
infra/kind/               Cluster kind et registre local
infra/k8s/                Manifests Kubernetes base/overlays/policies
infra/jenkins/            Jenkins local reproductible
scripts/ci/               Tests et couverture
scripts/release/          SBOM, signature, verification, promotion
scripts/deploy/           Creation du cluster et deploiement verifie
scripts/validate/         Smoke tests, validation, collecte de preuves
scripts/secrets/          Bootstrap secrets locaux
scripts/jenkins/          Bootstrap et preuve Jenkins locale
security/                 Regles et conventions de securite
docs/                     Architecture, runbooks, memoire
```

## Demarrage rapide

### 1. Verifier les prerequis
```bash
docker --version
kind --version
kubectl version --client
```

### 2. Creer le cluster et le registre local
```bash
bash scripts/deploy/create-kind.sh
```

### 3. Creer les secrets locaux
```bash
bash scripts/secrets/bootstrap-local-secrets.sh
bash scripts/secrets/create-dev-secrets.sh
```

### 4. Construire les images locales
```bash
REGISTRY_HOST=localhost:5001 IMAGE_TAG=dev bash scripts/deploy/build-local-images.sh
```

Pour la voie reelle avec `Ollama`, il est recommande de precharger l'image avant le deploiement :
```bash
bash scripts/deploy/prepull-ollama.sh
```

### 5. Deployer sur le cluster
```bash
REGISTRY_HOST=localhost:5001 IMAGE_PREFIX=securerag-hub IMAGE_TAG=dev \
bash scripts/deploy/deploy-kind.sh
```

### 6. Lancer les validations
```bash
bash scripts/validate/smoke-tests.sh
bash scripts/validate/security-smoke.sh
bash scripts/validate/e2e-functional-flow.sh
bash scripts/validate/rag-smoke.sh
bash scripts/validate/security-adversarial-advanced.sh
bash scripts/validate/generate-validation-report.sh
bash scripts/validate/collect-runtime-evidence.sh
```

## Mode demo

Le mode `demo` remplace `Ollama` par un mock HTTP leger afin de fiabiliser une demonstration locale.

```bash
REGISTRY_HOST=localhost:5001 IMAGE_PREFIX=securerag-hub IMAGE_TAG=dev \
KUSTOMIZE_OVERLAY=infra/k8s/overlays/demo \
bash scripts/deploy/deploy-kind.sh
```

Utiliser ce mode lorsque :
- la machine locale est limitee en RAM ;
- le telechargement de l'image `ollama/ollama` est trop long ;
- une demonstration stable prime sur la fidelite du runtime LLM local.

## Mode reel avec Ollama

Le mode `dev` garde `Ollama` reel dans le cluster.

Avantages :
- runtime plus fidele a la cible ;
- meilleur alignement avec la chaine RAG reelle.

Limites connues :
- premier demarrage potentiellement lent ;
- image lourde ;
- dependance forte a la connectivite et aux ressources locales ;
- plus fragile qu'un mode `demo` pour une soutenance courte.

## Jenkins local

### Demarrage
```bash
bash scripts/jenkins/bootstrap-local-credentials.sh
bash scripts/jenkins/bootstrap-local-kubeconfig.sh
docker compose -f infra/jenkins/docker-compose.yml up --build -d
bash scripts/jenkins/wait-for-jenkins.sh
```

### Acces
- URL : `http://localhost:8085`
- utilisateur initial : `admin`
- mot de passe initial : `change-me-now`

### Jobs attendus
- `securerag-hub-ci`
- `securerag-hub-cd`

### Preuves Jenkins deja prevues
- `artifacts/jenkins/jobs.json`
- `artifacts/jenkins/login.html`

## Kubernetes et overlays

### Base
`infra/k8s/base/` contient :
- namespace
- services
- deployments/statefulset
- network policies
- quotas
- limit range
- PDB
- HPA

### Overlay `dev`
`infra/k8s/overlays/dev/` cible le runtime local standard avec :
- images locales `localhost:5001`
- `NodePort` pour `api-gateway`
- `NodePort` pour `portal-web`

### Overlay `demo`
`infra/k8s/overlays/demo/` conserve le meme socle mais remplace `Ollama` par un mock.

### Policies Kyverno
`infra/k8s/policies/kyverno/` contient :
- une policy d'audit de securite pod
- une policy de verification Cosign des images SecureRAG

Ces policies necessitent un moteur Kyverno installe dans le cluster.

### Addons de cluster
Le depot fournit aussi des addons installables a la demande :
- `infra/k8s/addons/kyverno/`
- `infra/k8s/addons/metrics-server/`

## Secrets, signatures et verification

### Secrets
- exemples : `security/secrets/.env.example`
- bootstrap local : `scripts/secrets/bootstrap-local-secrets.sh`
- secrets Kubernetes : `scripts/secrets/create-dev-secrets.sh`
- credentials Jenkins : voir `docs/runbooks/jenkins-setup.md`

### Release security
- SBOM : `scripts/release/generate-sbom.sh`
- signature : `scripts/release/sign-images.sh`
- verification : `scripts/release/verify-signatures.sh`
- promotion : `scripts/release/promote-verified-images.sh`
- promotion par digest : `scripts/release/promote-by-digest.sh`
- preuve de release : `scripts/release/record-release-evidence.sh`
- deploiement verifie : `scripts/deploy/verify-and-deploy-kind.sh`

## Commandes principales

Le `Makefile` racine fournit une interface simple :

```bash
make help
make lint
make test
make verify IMAGE_TAG=dev
make promote SOURCE_IMAGE_TAG=dev TARGET_IMAGE_TAG=release-local
make promote-digest SOURCE_IMAGE_TAG=dev TARGET_IMAGE_TAG=release-local
make deploy IMAGE_TAG=release-local
make validate
make demo IMAGE_TAG=dev
make campaign SOURCE_IMAGE_TAG=dev TARGET_IMAGE_TAG=release-local
make final-campaign OFFICIAL_SCENARIO=demo CAMPAIGN_MODE=dry-run
make release-evidence
make supply-chain-evidence
make final-proof
make final-summary
make support-pack
make kyverno-install
make kyverno-enforce
make metrics-install
```

## Campagne finale officielle

Le scenario officiel de soutenance est `demo`.

Commandes utiles :

```bash
OFFICIAL_SCENARIO=demo CAMPAIGN_MODE=dry-run make final-campaign
make final-proof
make final-summary
make supply-chain-evidence
make support-pack
```

Le mode `dry-run` prepare les preuves sans forcer la verification Cosign, la promotion ou le redeploiement. Le mode `execute` doit etre lance uniquement lorsque Docker, kind, kubectl, Cosign, Syft, les cles et le registre local sont disponibles et stabilises.

## Runbooks utiles

- [Jenkins setup](/Users/mohamedyassine/Desktop/PFE/Master/docs/runbooks/jenkins-setup.md)
- [Local kind](/Users/mohamedyassine/Desktop/PFE/Master/docs/runbooks/local-kind.md)
- [Release promotion](/Users/mohamedyassine/Desktop/PFE/Master/docs/runbooks/release-promotion.md)
- [Final campaign](/Users/mohamedyassine/Desktop/PFE/Master/docs/runbooks/final-campaign.md)
- [Demo checklist](/Users/mohamedyassine/Desktop/PFE/Master/docs/runbooks/demo-checklist.md)
- [Environment freeze](/Users/mohamedyassine/Desktop/PFE/Master/docs/runbooks/environment-freeze.md)
- [Troubleshooting](/Users/mohamedyassine/Desktop/PFE/Master/docs/runbooks/troubleshooting.md)
- [Final proof](/Users/mohamedyassine/Desktop/PFE/Master/docs/runbooks/final-proof.md)
- [Jenkins cloud fallback](/Users/mohamedyassine/Desktop/PFE/Master/docs/runbooks/jenkins-cloud-fallback.md)
- [Kyverno install](/Users/mohamedyassine/Desktop/PFE/Master/docs/runbooks/kyverno-install.md)
- [Metrics Server](/Users/mohamedyassine/Desktop/PFE/Master/docs/runbooks/metrics-server.md)
- [Jenkins recovery](/Users/mohamedyassine/Desktop/PFE/Master/docs/runbooks/jenkins-recovery.md)
- [Policy matrix](/Users/mohamedyassine/Desktop/PFE/Master/docs/security/policy-matrix.md)

## Gouvernance CI/CD

Jenkins est la source de verite officielle.

Les workflows encore presents dans [.github/workflows](/Users/mohamedyassine/Desktop/PFE/Master/.github/workflows) sont conserves comme workflows legacy :
- a titre d'historique ;
- pour une relance manuelle exceptionnelle ;
- sans declenchement automatique sur `push` ou `pull_request`.

Voir :
- [Legacy workflows README](/Users/mohamedyassine/Desktop/PFE/Master/.github/workflows/README.md)

## Gates CI -> CD

Le passage vers la CD n'est autorise que si :

- les tests passent ;
- les scans critiques sont traites ;
- les images existent dans le registre cible ;
- la verification Cosign passe ;
- la promotion produit un digest trace ;
- la checklist de demonstration est au vert.

## Limites actuelles

- les policies Kyverno sont fournies mais necessitent un moteur Kyverno installe pour etre appliquees reellement ;
- les HPA necessitent un `metrics-server` fonctionnel dans le cluster ;
- le mode `dev` avec `Ollama` reste plus fragile que le mode `demo` ;
- la preuve finale complete Jenkins CI + CD + deploy + validate depend de la disponibilite locale de Docker, `kind` et des credentials Cosign ;
- le deploiement par digest exige que les digests aient ete produits et traces pendant la promotion.

## Pistes futures

- installer Kyverno automatiquement dans le cluster de demonstration ;
- ajouter une verification de signature enforcee a l'admission ;
- renforcer la partie observabilite ;
- etendre les tests applicatifs et les preuves Jenkins consolidees ;
- ajouter une gestion plus avancee des secrets type Vault ou External Secrets.
