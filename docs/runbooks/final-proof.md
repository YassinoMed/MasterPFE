# Final Reference Campaign — SecureRAG Hub

## Objectif
Consolider une campagne de reference unique pour la chaine :

`verify -> promote -> deploy -> validate`

Ce document ne pretend pas qu'un run a ete execute si aucune preuve n'existe. Il distingue :

- les preuves deja presentes dans le depot ;
- les commandes exactes a rejouer pour constituer une preuve complete de soutenance ;
- les ecarts entre mode `dev` reel et mode `demo`.

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
- `artifacts/validation/portal-web-describe.txt`

## Extensions de cluster preparees

Le depot permet maintenant d'activer explicitement :

- `Kyverno` via `bash scripts/deploy/install-kyverno.sh`
- `metrics-server` via `bash scripts/deploy/install-metrics-server.sh`

Ces composants ne sont pas couplés de force a l'overlay principal. Ils peuvent donc etre installes seulement si l'environnement local le permet.

### Etat observe sur le cluster courant

Lors de la consolidation finale du depot :

- `metrics-server` a ete installe avec succes ;
- `kubectl top nodes` et `kubectl top pods -n securerag-hub` repondent ;
- les `HPA` de `api-gateway` et `portal-web` exposent des valeurs CPU reelles ;
- `Kyverno` a ete installe avec succes ;
- les policies `securerag-require-pod-security` et `securerag-verify-cosign-images` sont presentes et `Ready` en mode `Audit`.

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
bash scripts/validate/rag-smoke.sh
bash scripts/validate/security-adversarial-advanced.sh
bash scripts/validate/generate-validation-report.sh
bash scripts/validate/collect-runtime-evidence.sh
```

## Variante demo

Utiliser cette variante si `Ollama` est trop lourd ou instable sur la machine locale :

```bash
REGISTRY_HOST=localhost:5001 \
IMAGE_PREFIX=securerag-hub \
IMAGE_TAG=dev \
KUSTOMIZE_OVERLAY=infra/k8s/overlays/demo \
bash scripts/deploy/deploy-kind.sh
```

Dans ce mode :
- le reste de la plateforme reste deployee normalement ;
- `Ollama` est remplace par un mock HTTP ;
- la demonstration fonctionnelle et la validation de la chaine applicative restent possibles ;
- il faut annoncer explicitement en soutenance que le moteur LLM local est simule pour raisons de stabilite runtime.

## Variante reelle avec Ollama

Le mode `dev` garde le composant `Ollama` reel. Il est plus fidele au runtime cible mais depend fortement :

- de la connectivite reseau ;
- du telechargement de l'image ;
- de la capacite memoire locale ;
- du temps de premier demarrage.

Ce mode est preferable si la machine locale est suffisamment stable et que l'image `ollama/ollama` est deja disponible.

Avant un deploiement en mode reel, il est recommande d'executer :

```bash
bash scripts/deploy/prepull-ollama.sh
```

## Artefacts a conserver pour la soutenance

- `artifacts/release/verify-summary.txt`
- `artifacts/release/promotion-summary.txt`
- `artifacts/release/promotion-by-digest-summary.txt`
- `artifacts/release/promotion-digests.txt`
- `artifacts/release/release-evidence.md`
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

- la stabilite complete d'un run `Ollama` reel
- l'execution d'un vrai job Jenkins CD complet si Docker Desktop ou le cluster local ne sont pas disponibles au moment du run
- la presence effective d'images deja signees dans la registry locale au moment du lancement de la campagne complete

Au moment de la consolidation finale :

- le cluster local dispose bien du CRD `clusterpolicies.kyverno.io` ;
- `metrics-server` est disponible ;
- la campagne unifiee a ete produite en `dry-run` pour ne pas pretendre a une promotion reelle sans revalidation explicite des images signees presentes dans la registry locale.
