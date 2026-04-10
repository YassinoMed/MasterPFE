# SecureRAG Hub Deployment Target

## Objectif

Ce document applique la logique du diagramme de deploiement au projet SecureRAG Hub tel qu'il existe dans ce depot.
Il aligne :

- la chaine DevSecOps Jenkins separee en CI et CD
- le registre d'images OCI
- le cluster local `kind`
- les microservices Python du socle RAG/securite
- le portail User/Admin en Laravel

## Diagramme source

- source PlantUML : `docs/architecture/securerag-deployment-target.puml`

## Principes retenus

- la CI/CD reste separee du runtime local
- les images sont scannees, inventoriees et signees avant promotion
- le deploiement local vers `kind` se fait via `Kustomize` et scripts `scripts/deploy/*`
- l'entree HTTP du cluster est separee du `Service api-gateway`
- le portail Laravel est explicite dans l'architecture
- les integrations IA restent consommees via les services `llm-orchestrator`, `security-auditor` et `knowledge-hub`

## Lecture du diagramme

### 1. Zone GitHub / DevSecOps

Le monorepo contient les sources applicatives, les manifests Kubernetes, les fichiers `Jenkinsfile` et `Jenkinsfile.cd`, ainsi que les scripts d'exploitation locale.
La chaine DevSecOps produit :

- des rapports de securite
- un SBOM CycloneDX
- des images OCI signees

Ces artefacts sont publies dans un registre OCI local ou distant.

### 2. Zone machine locale / VM

Cette zone represente le poste de demonstration ou la VM locale :

- le portail Laravel User/Admin
- les scripts de creation du cluster
- les scripts de deploiement et validation

Le portail web consomme l'entree HTTP du cluster et centralise l'experience utilisateur et administrative.

### 3. Zone cluster kind

Le cluster `kind` heberge le namespace `securerag-hub` et les workloads SecureRAG Hub :

- `api-gateway`
- `auth-users`
- `chatbot-manager`
- `llm-orchestrator`
- `security-auditor`
- `knowledge-hub`
- `qdrant`
- `ollama`

Le diagramme distingue volontairement :

- l'entree HTTP locale exposee en `NodePort` pour l'environnement `dev`
- le `Service api-gateway`
- le `Pod api-gateway`

Cette separation est plus juste qu'un bloc unique `Ingress / API Gateway Service`.

## Positionnement du portail Laravel

Le portail Laravel est actuellement bootstrappe en local dans `platform/portal-web`.
Il n'est pas encore deploye dans `kind`, mais il fait deja partie de l'architecture cible de la plateforme.

Cela permet de presenter une architecture realiste :

- backend securise et distribue dans Kubernetes
- interface User/Admin separee, maintenable et extensible

## Mode de deploiement retenu

Le diagramme precise aussi le mode de CD local :

- `Jenkins` avec un pipeline CI dedie et un pipeline CD dedie
- `agent Jenkins self-hosted` ou scripts locaux pour le deploiement `kind`

Cette precision est importante pour rester coherent avec la contrainte "pas de cloud payant" et avec l'execution reelle du projet.
