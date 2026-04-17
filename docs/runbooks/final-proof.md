# Final Reference Campaign — SecureRAG Hub

## Objectif
Consolider une campagne de reference unique pour la chaine :

`verify -> promote -> deploy -> validate`

Ce document ne pretend pas qu'un run a ete execute si aucune preuve n'existe. Il distingue :

- les preuves deja presentes dans le depot ;
- les commandes exactes a rejouer pour constituer une preuve complete de soutenance ;
- les ecarts entre preuves préparées et preuves runtime réellement exécutées.

## Preuves deja presentes dans le depot

### Jenkins local
- `artifacts/jenkins/jobs.json`
- `artifacts/jenkins/login.html`

Ces artefacts prouvent qu'une instance Jenkins locale a ete demarree et que les jobs seedes sont visibles.

### Validation post-deploiement
- `artifacts/validation/validation-summary.md`
- `artifacts/validation/e2e-functional-flow.txt`
- `artifacts/validation/rag-smoke.txt`
- `artifacts/validation/security-adversarial.txt`
- `artifacts/validation/k8s-get-all.txt`
- `artifacts/validation/k8s-pods.txt`
- `artifacts/validation/k8s-pvc.txt`
- `artifacts/validation/k8s-networkpolicy.txt`

Ces artefacts correspondent a une campagne deja executee localement sur `kind`.

### Observations consolidees lors de la finalisation DevSecOps

Les verifications suivantes ont ete relancees et observees sur le depot finalise :

- `docker compose -f infra/jenkins/docker-compose.yml config` : OK
- `kubectl kustomize infra/k8s/overlays/dev` : OK
- `kubectl kustomize infra/k8s/overlays/demo` : OK
- `kubectl kustomize infra/k8s/policies/kyverno` : OK
- `make lint` : OK
- `kubectl apply -k infra/k8s/overlays/dev` : applique avec succes pour `ResourceQuota`, `LimitRange`, `PDB` et `HPA`
- `bash scripts/validate/collect-runtime-evidence.sh` : OK

Les artefacts rafraichis associes sont :

- `artifacts/validation/k8s-pdb.txt`
- `artifacts/validation/k8s-hpa.txt`
- `artifacts/validation/k8s-resourcequota.txt`
- `artifacts/validation/k8s-limitrange.txt`
- `artifacts/security/k8s-ultra-hardening.md`
- `artifacts/validation/portal-web-describe.txt`

## Extensions de cluster preparees

Le depot permet maintenant d'activer explicitement :

- `Kyverno` via `bash scripts/deploy/install-kyverno.sh`
- `metrics-server` via `bash scripts/deploy/install-metrics-server.sh`

Ces composants ne sont pas couplés de force a l'overlay principal. Ils peuvent donc etre installes seulement si l'environnement local le permet.

### État à ne pas surdéclarer

Ne déclarer `metrics-server`, `kubectl top`, les HPA runtime ou Kyverno comme `TERMINÉ` que si les commandes suivantes répondent dans le cluster cible :

```bash
kubectl top nodes
kubectl top pods -n securerag-hub
kubectl get hpa -n securerag-hub
kubectl get clusterpolicy
kubectl get policyreport,clusterpolicyreport -A
```

Sans ces sorties archivées, l’état est `DÉPENDANT_DE_L_ENVIRONNEMENT`.

## Campagne de reference a rejouer

### 1. Bootstrap local
```bash
bash scripts/secrets/bootstrap-local-secrets.sh
bash scripts/secrets/create-dev-secrets.sh
bash scripts/jenkins/bootstrap-local-credentials.sh
bash scripts/jenkins/bootstrap-local-kubeconfig.sh
docker compose -f infra/jenkins/docker-compose.yml up --build -d
bash scripts/jenkins/wait-for-jenkins.sh
```

### Variante unifiee

La campagne complete peut etre rejouee par :

```bash
make campaign SOURCE_IMAGE_TAG=dev TARGET_IMAGE_TAG=release-local
```

ou directement :

```bash
REGISTRY_HOST=localhost:5001 IMAGE_PREFIX=securerag-hub \
SOURCE_IMAGE_TAG=dev TARGET_IMAGE_TAG=release-local \
bash scripts/validate/run-reference-campaign.sh
```

La voie officielle de finalisation avec support pack est :

```bash
OFFICIAL_SCENARIO=demo CAMPAIGN_MODE=dry-run \
bash scripts/cd/run-final-campaign.sh
```

Puis, pour une execution reelle :

```bash
OFFICIAL_SCENARIO=demo CAMPAIGN_MODE=execute \
COSIGN_PUBLIC_KEY=/absolute/path/to/cosign.pub \
bash scripts/cd/run-final-campaign.sh
```

### 2. Verification du tag candidat
```bash
REGISTRY_HOST=localhost:5001 \
IMAGE_PREFIX=securerag-hub \
IMAGE_TAG=dev \
COSIGN_PUBLIC_KEY=/absolute/path/to/cosign.pub \
bash scripts/release/verify-signatures.sh
```

### 3. Promotion sans reconstruction
```bash
REGISTRY_HOST=localhost:5001 \
IMAGE_PREFIX=securerag-hub \
SOURCE_IMAGE_TAG=dev \
TARGET_IMAGE_TAG=release-local \
COSIGN_PUBLIC_KEY=/absolute/path/to/cosign.pub \
bash scripts/release/promote-verified-images.sh
```

Version recommandee par digest :
```bash
REGISTRY_HOST=localhost:5001 \
IMAGE_PREFIX=securerag-hub \
SOURCE_IMAGE_TAG=dev \
TARGET_IMAGE_TAG=release-local \
COSIGN_PUBLIC_KEY=/absolute/path/to/cosign.pub \
bash scripts/release/promote-by-digest.sh
```

### 4. Deploiement verifie
```bash
REGISTRY_HOST=localhost:5001 \
IMAGE_PREFIX=securerag-hub \
IMAGE_TAG=release-local \
COSIGN_PUBLIC_KEY=/absolute/path/to/cosign.pub \
RUN_POSTDEPLOY_VALIDATION=false \
bash scripts/deploy/verify-and-deploy-kind.sh
```

### 5. Validation et collecte de preuves
```bash
bash scripts/validate/smoke-tests.sh
bash scripts/validate/security-smoke.sh
bash scripts/validate/e2e-functional-flow.sh
bash scripts/validate/security-adversarial-advanced.sh
bash scripts/validate/generate-validation-report.sh
bash scripts/validate/collect-runtime-evidence.sh
```

## Variante demo

Utiliser cette variante pour la soutenance :

```bash
REGISTRY_HOST=localhost:5001 \
IMAGE_PREFIX=securerag-hub \
IMAGE_TAG=dev \
KUSTOMIZE_OVERLAY=infra/k8s/overlays/demo \
bash scripts/deploy/deploy-kind.sh
```

Dans ce mode :
- le runtime officiel Laravel est déployé ;
- les services legacy Python/RAG restent exclus ;
- la validation de la chaîne applicative et sécurité reste possible.

## Variante legacy RAG/Ollama

Le scénario legacy RAG/Ollama n'est pas un scénario officiel tant que les sources Python applicatives ne sont pas restaurées. `scripts/validate/rag-smoke.sh` documente cette exclusion et sort en succès avec un statut `PRÊT_NON_EXÉCUTÉ` sauf si `ENABLE_LEGACY_RAG_VALIDATION=true` est explicitement fourni dans un environnement restauré.

## Artefacts a conserver pour la soutenance

- `artifacts/release/verify-summary.txt`
- `artifacts/release/image-scan-summary.txt`
- `artifacts/release/promotion-summary.txt`
- `artifacts/release/promotion-by-digest-summary.txt`
- `artifacts/release/promotion-digests.txt`
- `artifacts/release/release-evidence.md`
- `artifacts/release/attest-summary.txt`
- `artifacts/release/release-attestation.json`
- `artifacts/sbom/*`
- `artifacts/validation/validation-summary.md`
- `artifacts/validation/k8s-get-all.txt`
- `artifacts/validation/k8s-pods.txt`
- `artifacts/validation/k8s-pdb.txt`
- `artifacts/validation/k8s-hpa.txt`
- `artifacts/validation/k8s-resourcequota.txt`
- `artifacts/validation/k8s-limitrange.txt`
- `artifacts/jenkins/jobs.json`
- `artifacts/support-pack/<timestamp>/`

## Ce qui est reellement verifiable

- la verification et la promotion d'images peuvent etre verifiees par les rapports `artifacts/release/*`
- le deploiement `kind` peut etre verifie par `kubectl get ...` et les fichiers de preuve
- le mode `demo` est entierement rejouable localement

## Ce qui depend de l'environnement

- l'execution d'un vrai job Jenkins CD complet si Docker Desktop ou le cluster local ne sont pas disponibles au moment du run
- la presence effective d'images deja signees dans la registry locale au moment du lancement de la campagne complete

Au moment de la consolidation finale :

- la campagne unifiée peut être produite en `dry-run` pour ne pas prétendre à une promotion réelle sans revalidation explicite des images signées présentes dans la registry locale ;
- Kyverno et metrics-server restent `DÉPENDANT_DE_L_ENVIRONNEMENT` tant que les preuves runtime ci-dessus ne sont pas archivées.
- le durcissement K8s statique peut être déclaré `TERMINÉ` uniquement si `bash scripts/validate/validate-k8s-ultra-hardening.sh` passe sur les overlays `dev`, `demo`, `kyverno` et `kyverno-enforce`.
