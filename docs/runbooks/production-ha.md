# Production HA Runbook - SecureRAG Hub

## Objectif

Faire evoluer SecureRAG Hub du mode `demo` vers un overlay `production` qui conserve le perimetre Laravel officiel tout en ajoutant les controles de haute disponibilite attendus pour une quasi pre-production.

## Perimetre

Sont couverts :
- `portal-web`
- `auth-users`
- `chatbot-manager`
- `conversation-service`
- `audit-security-service`

Sont exclus de ce runbook :
- composants IA, RAG, LLM, Ollama, Qdrant et embeddings ;
- services legacy Python sans sources applicatives exploitables.

## Architecture production appliquee

| Controle | Implementation | Etat |
|---|---|---:|
| Overlay dedie | `infra/k8s/overlays/production` | TERMINÉ |
| Replicas critiques | `portal-web=3`, autres services officiels `=2` | TERMINÉ |
| Rolling update | `maxUnavailable=0`, `maxSurge=1`, `minReadySeconds=10` | TERMINÉ |
| Anti-affinity | preference sur `kubernetes.io/hostname` par service | TERMINÉ |
| Topology spread | contrainte par service sur `kubernetes.io/hostname` | TERMINÉ |
| PDB | `portal-web minAvailable=2`, autres `minAvailable=1` | TERMINÉ |
| HPA | HPA CPU+memoire pour les 5 services officiels | TERMINÉ statique |
| Exposition portail | `Service/portal-web` en `NodePort` `30081` dans l'overlay production | TERMINÉ statique |
| Cluster propre | validation officielle sans workloads legacy | PRÊT_NON_EXÉCUTÉ |
| metrics-server | addon et script d'installation existants | DÉPENDANT_DE_L_ENVIRONNEMENT |
| Preuve runtime HA | `validate-cluster-security-addons.sh`, `kubectl get hpa`, `kubectl top` | DÉPENDANT_DE_L_ENVIRONNEMENT |

## Cluster production propre

Pour une campagne production-like, utiliser un cluster separe du mode demo :

```bash
bash scripts/deploy/recreate-production-kind.sh
```

Si le cluster `securerag-prod` existe deja, la recreation est destructive et doit etre confirmee explicitement :

```bash
CONFIRM_DESTROY=YES bash scripts/deploy/recreate-production-kind.sh
```

Le nettoyage des anciens workloads runtime se fait en deux temps :

```bash
make production-cleanup-plan
CONFIRM_CLEANUP=YES make production-cleanup
```

La preuve attendue est generee par :

```bash
make production-cluster-clean-proof
```

Voir aussi `docs/runbooks/production-cluster-clean.md`.

## Validation non destructive

```bash
kubectl kustomize infra/k8s/overlays/production >/tmp/securerag-production.yaml
bash scripts/validate/validate-production-ha.sh
bash scripts/validate/validate-production-cluster-clean.sh
bash scripts/validate/validate-k8s-resource-guards.sh
bash scripts/validate/validate-k8s-ultra-hardening.sh
make production-runtime-evidence
make production-ha
```

Preuves attendues :
- `artifacts/security/production-ha-readiness.md`
- `artifacts/validation/production-cluster-clean.md`
- `artifacts/security/k8s-resource-guards.md`
- `artifacts/security/k8s-ultra-hardening.md`
- `artifacts/validation/production-runtime-evidence.md`

## Deploiement production-like sur kind

Action mutative : applique des ressources Kubernetes dans le cluster courant.

```bash
REGISTRY_HOST=localhost:5001 \
IMAGE_PREFIX=securerag-hub \
IMAGE_TAG=production \
KUSTOMIZE_OVERLAY=infra/k8s/overlays/production \
bash scripts/deploy/deploy-kind.sh
```

Pour un deploiement supply-chain avec verification Cosign avant application :

```bash
REGISTRY_HOST=localhost:5001 \
IMAGE_PREFIX=securerag-hub \
IMAGE_TAG=production \
KUSTOMIZE_OVERLAY=infra/k8s/overlays/production \
COSIGN_PUBLIC_KEY=/absolute/path/to/cosign.pub \
bash scripts/deploy/verify-and-deploy-kind.sh
```

## metrics-server et HPA

Action mutative : installe ou met a jour `metrics-server`.

```bash
bash scripts/deploy/install-metrics-server.sh
kubectl get hpa -n securerag-hub
kubectl top pods -n securerag-hub
bash scripts/validate/validate-hpa-runtime.sh
bash scripts/validate/validate-cluster-security-addons.sh
bash scripts/validate/collect-production-runtime-evidence.sh
```

Resultat attendu :
- les HPA affichent des valeurs CPU/memoire au lieu de `<unknown>` ;
- `hpa-runtime-report.md` classe chaque HPA officiel en `TERMINÉ` ;
- `cluster-security-addons.md` classe `metrics-server` et `HPA` en `TERMINÉ`.

## Exposition officielle du portail

L'overlay production rend `portal-web` en `NodePort` `30081`. Avec le cluster `infra/kind/kind-production.yaml`, le mapping host attendu est `localhost:8081`.

```bash
kubectl get svc portal-web -n securerag-hub -o wide
curl -fsS http://localhost:8081/health
```

Cette exposition remplace les conteneurs de forward ad hoc. Si `localhost:8081` ne repond pas, verifier d'abord le type de Service puis les mappings kind avant d'ajouter un contournement.

## Test de resilience

Actions mutatives : redemarrent ou evacuent des pods.

```bash
kubectl rollout restart deployment/portal-web -n securerag-hub
kubectl rollout status deployment/portal-web -n securerag-hub --timeout=180s
kubectl get pods -n securerag-hub -o wide
```

Preuve recommandee apres rebuild d'images ou redeploiement par digest :

```bash
REGISTRY_HOST=localhost:5001 \
IMAGE_PREFIX=securerag-hub \
IMAGE_TAG=production \
REPORT_FILE=artifacts/validation/runtime-image-rollout-proof.md \
bash scripts/validate/validate-runtime-image-rollout.sh
```

Cette preuve compare les images declarees dans les Deployments, les pods Ready et les `imageID` reels des conteneurs. Si `DEPLOY_STARTED_AT` est fourni par `deploy-kind.sh`, les pods doivent aussi etre plus recents que l'action de deploiement, ce qui evite le faux positif `deployment unchanged`.

Drain d'un noeud, uniquement sur cluster multi-noeud :

```bash
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
kubectl get pods -n securerag-hub -o wide
kubectl uncordon <node>
```

## Limites honnetes

- Sur un cluster `kind` mono-noeud, l'anti-affinity et le topology spread restent des intentions de scheduling, pas une tolerance reelle a la perte d'un noeud.
- Les volumes applicatifs actuels sont principalement `emptyDir` pour le runtime Laravel demo. La resilience donnees production exige une strategie externe : base de donnees managee, sauvegarde, restauration testee et stockage persistant.
- Une vraie HA production demande au moins trois noeuds workers, metrics-server actif, registry disponible, images signees et preuves runtime archivees.

## Formulation soutenance

SecureRAG Hub dispose maintenant d'un overlay production separe du mode demo. Cet overlay ajoute replicas, PDB coherents, rolling updates sans indisponibilite volontaire, anti-affinity, topology spread et HPA pour tous les services Laravel officiels. Les preuves statiques sont terminees ; les preuves runtime restent dependantes d'un cluster actif avec metrics-server.
