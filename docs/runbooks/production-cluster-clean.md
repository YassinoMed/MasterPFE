# Production Cluster Clean Runbook - SecureRAG Hub

## Objectif

Prouver que le runtime production-like de SecureRAG Hub est limite aux workloads Laravel officiels, expose le portail par un Service Kubernetes officiel, et ne depend pas de workloads legacy parasites.

## Perimetre officiel

| Workload | Source | Etat attendu |
|---|---|---:|
| `portal-web` | `platform/portal-web` | TERMINÉ |
| `auth-users` | `services-laravel/auth-users-service` | TERMINÉ |
| `chatbot-manager` | `services-laravel/chatbot-manager-service` | TERMINÉ |
| `conversation-service` | `services-laravel/conversation-service` | TERMINÉ |
| `audit-security-service` | `services-laravel/audit-security-service` | TERMINÉ |

Les workloads legacy sous `services/` et les anciens dossiers Kubernetes correspondants ne font pas partie du runtime production officiel. Ils ne doivent pas apparaitre dans l'overlay `production` ni dans le namespace production apres nettoyage.

Le dossier `infra/k8s/overlays/legacy/` contient uniquement un marqueur documentaire. Il n'expose pas de `kustomization.yaml` deployable afin d'eviter toute reintegration implicite dans les preuves production.

## Actions non destructives

Validation statique de l'overlay production :

```bash
STATIC_ONLY=true bash scripts/validate/validate-production-cluster-clean.sh
```

Inventaire runtime sans suppression :

```bash
bash scripts/deploy/cleanup-nonproduction-workloads.sh
```

Preuve cluster clean si un cluster est actif :

```bash
bash scripts/validate/validate-production-cluster-clean.sh
```

Preuve attendue :

```text
artifacts/validation/production-cluster-clean.md
```

## Creation d'un cluster production-like propre

Action mutative et potentiellement destructive si le cluster existe deja.

```bash
bash scripts/deploy/recreate-production-kind.sh
```

Si le cluster `securerag-prod` existe deja et doit etre recree :

```bash
CONFIRM_DESTROY=YES bash scripts/deploy/recreate-production-kind.sh
```

Dependances :
- Docker actif
- `kind`
- `kubectl`
- registre local `localhost:5001`

## Deploiement production

Action mutative : applique l'overlay `production` dans le cluster courant.

```bash
REGISTRY_HOST=localhost:5001 \
IMAGE_PREFIX=securerag-hub \
IMAGE_TAG=production \
KUSTOMIZE_OVERLAY=infra/k8s/overlays/production \
bash scripts/deploy/deploy-kind.sh
```

Le portail est expose officiellement par `Service/portal-web` en `NodePort` `30081`. Avec `infra/kind/kind-production.yaml`, l'acces attendu depuis l'hote est :

```bash
curl -fsS http://localhost:8081/health
```

## Nettoyage des workloads non production

Action mutative : supprime les objets legacy du namespace `securerag-hub`.

```bash
CONFIRM_CLEANUP=YES make production-cleanup
```

Les PVC legacy sont conserves par defaut. Leur suppression est destructive pour les donnees locales :

```bash
CONFIRM_CLEANUP=YES DELETE_STATEFUL_LEGACY=true \
make production-cleanup
```

## Lecture honnete

| Controle | Etat |
|---|---:|
| Overlay production limite aux workloads officiels | TERMINÉ |
| Service officiel `portal-web` en NodePort `30081` | TERMINÉ statique |
| Cluster multi-noeuds production-like | PRÊT_NON_EXÉCUTÉ tant que le script n'a pas ete lance |
| Preuve runtime workloads Ready | DÉPENDANT_DE_L_ENVIRONNEMENT |
| Nettoyage legacy runtime | DÉPENDANT_DE_L_ENVIRONNEMENT si aucun cluster actif |

## Diagnostic si echec

| Symptome | Commande | Cause probable |
|---|---|---|
| `kind` introuvable | `kind version` | outil non installe |
| `kubectl` ne repond pas | `kubectl cluster-info` | contexte absent ou cluster arrete |
| `localhost:8081/health` ne repond pas | `kubectl get svc portal-web -n securerag-hub -o wide` | overlay non applique ou mauvais cluster |
| workloads legacy presents | `bash scripts/deploy/cleanup-nonproduction-workloads.sh` | ancien namespace non nettoye |
| noeuds non Ready | `kubectl describe node <node>` | cluster kind instable, Docker resources insuffisantes |
