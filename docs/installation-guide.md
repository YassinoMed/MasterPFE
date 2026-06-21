# Guide d'installation — SecureRAG Hub (Laravel)

> Runtime officiel : **Laravel** (voir
> [ADR-001](architecture/decision-001-laravel-as-official-runtime.md)).

## Prérequis

| Outil | Version min | Vérification |
|-------|:-----------:|--------------|
| Docker | 24.0 | `docker --version` |
| Docker Compose | v2.20 | `docker compose version` |
| PHP | 8.2 | `php --version` |
| Composer | 2.6 | `composer --version` |
| Node.js | 18 | `node --version` |
| kubectl | 1.28 | `kubectl version --client` |
| kustomize | 5.0 | `kustomize version` |
| kind (optionnel K8s local) | 0.20 | `kind --version` |

## 1. Installation locale (mode développeur)

### a) Clone + bootstrap

```bash
git clone https://github.com/YassinoMed/MasterPFE.git
cd MasterPFE
cp .env.example .env
```

### b) Build + démarrage stack Laravel via Docker Compose

```bash
# Docker Compose officiel pour la plateforme Laravel :
cd platform
docker compose up -d --build

# Vérifier l'état
docker compose ps
docker compose logs portal-web --tail 30
```

### c) Migrations + key generation

```bash
docker compose exec portal-web php artisan key:generate
docker compose exec portal-web php artisan migrate --force
docker compose exec portal-web php artisan db:seed --force  # données démo
```

### d) Accès UI

```
http://localhost:8000
```

Credentials de démo (à changer ; non commités) — voir `platform/portal-web/database/seeders/`.

## 2. Tests

### a) Tests unitaires + intégration Laravel

```bash
# Par service
cd services-laravel/auth-users-service && composer install && ./vendor/bin/phpunit
cd ../chatbot-manager-service && composer install && ./vendor/bin/phpunit
# ...

# Suite globale via Makefile
cd ../..
make test
```

### b) Coverage

```bash
make test  # génère .coverage-artifacts/coverage.xml
bash scripts/ci/collect-coverage.sh
cat artifacts/security/quality-gate-summary.md
```

### c) Lint

```bash
make lint  # PHPStan + black + isort + flake8 + shellcheck (si dispo)
```

## 3. Pipeline CI/CD Jenkins

### a) Démarrer Jenkins local (mode CASC + GitHub webhook)

```bash
cd infra/jenkins
docker compose up -d
# Jenkins accessible sur http://localhost:8080
# Credentials initiaux dans infra/jenkins/secrets/ (jamais commités)
```

### b) Déclencher un build CI

Push sur GitHub → webhook → Jenkins lance le pipeline `Jenkinsfile`.

Sinon manuellement :

```bash
make jenkins-live-proofs   # déclenche un build + collecte la preuve
```

### c) Vérifier le résultat

- `artifacts/security/quality-gate-summary.md` (verdict consolidé)
- `artifacts/security/kube-score-report.md`
- `artifacts/security/kyverno-policy-validation.md`

## 4. Déploiement Kubernetes (kind local)

### a) Créer le cluster

```bash
kind create cluster --config infra/kind/kind-dev.yaml
```

### b) Installer Argo CD + Kyverno + observabilité

```bash
make kyverno-install
make argocd-bootstrap
make observability-up
```

### c) Déployer SecureRAG via Argo CD

```bash
kubectl -n argocd get applications
argocd app sync securerag-demo --auth-token "$ARGOCD_TOKEN"
```

### d) Vérifier l'état

```bash
kubectl -n securerag-hub get pods,svc,networkpolicy
kubectl -n securerag-hub logs deploy/portal-web --tail 30
make production-runtime-evidence
```

## 5. Démonstration sécurité

### a) Quality Gate

```bash
make quality-gate
cat artifacts/security/quality-gate-summary.md
```

### b) Pod Security audit

```bash
make audit-pod-security
make audit-networkpolicies
```

### c) Tests admission Kyverno (sur cluster)

```bash
make kyverno-fixtures  # nécessite cluster + Kyverno
cat artifacts/security/kyverno-fixtures-tests.md
```

### d) Bascule Audit → Enforce séquencée

```bash
DRY_RUN=true make kyverno-enforce-sequenced  # diff sans changement
make kyverno-enforce-sequenced               # bascule effective
```

### e) Chaos pod-delete

```bash
make chaos-pod-delete   # supprime un pod, prouve self-heal + HTTP up
cat artifacts/validation/chaos-pod-delete-*.md
```

### f) Restore drill PostgreSQL

```bash
make restore-drill
```

### g) Rotation secret drill

```bash
make secret-rotation-drill
```

## 6. Désinstallation / cleanup

```bash
# Stack Docker
cd platform && docker compose down -v

# kind
kind delete cluster --name securerag-dev

# Argo CD reset (ne supprime PAS Argo lui-même)
make argocd-down
```

## Variables d'environnement

Voir `.env.example` à la racine pour la liste complète et les
placeholders. **Aucun secret réel ne doit être commit dans `.env`.**

| Variable critique | Description |
|-------------------|-------------|
| `AUTH_JWT_SECRET` | Signing key Sanctum, ≥ 32 chars, généré via `php artisan key:generate` |
| `AUTH_DATABASE_URL` | DSN Postgres (`postgresql://user:pass@host:5432/db`) |
| `VECTORSTORE_QDRANT_URL` | Endpoint Qdrant interne ClusterIP |
| `LLM_OLLAMA_URL` | Endpoint Ollama interne |
| `LLM_USE_MOCK` | `true` en CI / tests, `false` en production |
| `AUDITOR_BLOCK_THRESHOLD` | Score pour décider BLOCKED (défaut 70) |

## Dépannage

| Symptôme | Cause probable | Fix |
|----------|----------------|-----|
| `Could not resolve host: postgres` dans logs Laravel | Service PG pas démarré | `docker compose up -d postgres` |
| `JWT signature mismatch` | `JWT_SECRET` différent entre services | Aligner via `.env` ou SOPS |
| `Pod CrashLoopBackOff portal-web` | Migration DB échouée | `kubectl exec ... php artisan migrate` |
| `kubectl apply --dry-run` refuse `:dev` | Kyverno `restrict-image-references` actif | Builder + pin digest via `pin-overlay-digests.sh` |
| Coverage non détectée par Quality Gate | Format `coverage-summary.txt` différent | Vérifier que `coverage.xml` ou format `coverage py` est produit |
