# SecureRAG Hub Deployment Target

## Objectif

Ce document applique la logique du diagramme de deploiement au projet SecureRAG Hub tel qu'il existe dans ce depot.
Il aligne :

- la chaine DevSecOps Jenkins separee en CI et CD
- le registre d'images OCI
- le cluster local `kind`
- le portail User/Admin Laravel
- les microservices Laravel métier et sécurité
- les anciens dossiers Python/RAG conservés hors périmètre officiel tant que leurs sources applicatives sont absentes

## Diagramme source

- source PlantUML : `docs/architecture/securerag-deployment-target.puml`

## Principes retenus

- la CI/CD reste separee du runtime local
- les images sont scannees, inventoriees et signees avant promotion
- le deploiement local vers `kind` se fait via `Kustomize` et scripts `scripts/deploy/*`
- l'entree HTTP de démonstration est portée par le `Service portal-web`
- le portail Laravel est explicite dans l'architecture
- les services Laravel `conversation-service` et `audit-security-service` remplacent le périmètre runtime legacy pour la démonstration officielle

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

- `auth-users`
- `chatbot-manager`
- `conversation-service`
- `audit-security-service`
- `portal-web`

Le diagramme distingue volontairement :

- l'entree HTTP locale exposee en `NodePort` pour les environnements `dev` et `demo`
- le `Service portal-web`
- les pods Laravel métier internes

Cette separation est plus juste qu'un bloc unique `Ingress / API Gateway Service`.

## Positionnement du portail Laravel

Le portail Laravel est actuellement intégré au déploiement `kind` officiel via `infra/k8s/base/portal-web`.

Cela permet de presenter une architecture realiste :

- backend securise et distribue dans Kubernetes
- interface User/Admin separee, maintenable et extensible
- preuve de déploiement à produire par `scripts/validate/collect-runtime-evidence.sh` lorsque le cluster est actif

## Mode de deploiement retenu

Le diagramme precise aussi le mode de CD local :

- `Jenkins` avec un pipeline CI dedie et un pipeline CD dedie
- `agent Jenkins self-hosted` ou scripts locaux pour le deploiement `kind`

Cette precision est importante pour rester coherent avec la contrainte "pas de cloud payant" et avec l'execution reelle du projet.
