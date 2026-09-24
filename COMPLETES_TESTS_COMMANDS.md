# SecureRAG Hub — Référence des commandes de tests

> Index complet des commandes de tests et de validation de la chaîne DevSecOps.
> Exécution depuis la racine du projet, sauf mention contraire.

## 1. Suite locale `/make`

| Commande | Description | Durée estimée |
|---|---|---|
| `make lint` | Valide scripts bash, Kustomize overlays, Dockerfiles, JPm | ~30 s |
| `make test` | PHPUnit 5 apps + merge coverage XML (gate ≥ 95 %) | ~5 min |
| `make laravel-test` | `php artisan test` sur les 5 services Laravel | ~3 min |
| `make sonar-analysis` | SonarQube analyse (si SONAR_TOKEN défini) | ~2 min |
| `make kyverno-policy-check` | Validation statique des policies Kyverno | ~1 min |
| `make security-scan` | Semgrep + Gitleaks + Trivy FS | ~2-3 min |
| `make devsecops-expert-audit` | audit-pod-security + audit-networkpolicies + quality-gate | ~1 min |
| `make quality-gate` | Auriche consolidé des signaux CI | ~10 s |
| `make sbom` | Génération SBOM CycloneDX pour 5 images | ~1 min |
| `make sbom-validate` | Valide le format SBOM JSON | ~5 s |
| `make sign` | `cosign sign` key-pair dev (avec keys/security/) | ~30 s |
| `make verify` | `cosign verify` signatures 5 images | ~30 s |
| `make promote-digest` | Promeut dev → release-local avec digest locked | ~10 s |
| `make supply-chain-execute` | Chaîne SBOM→sign→verify→attestation complète | ~2 min |
| `make deploy` | Applique l'overlay Kustomize sur kind | ~2 min |
| `make final-proof` | Gates finaux obligatoires (supply-chain, support pack) | ~30 s |
| `make devsecops-readiness` | Rapport général de readiness | ~5 s |

## 2. Tests par service Laravel

```bash
(cd platform/portal-web && php artisan test)
(cd services-laravel/auth-users-service && php artisan test)
(cd services-laravel/chatbot-manager-service && php artisan test)
(cd services-laravel/conversation-service && php artisan test)
(cd services-laravel/audit-security-service && php artisan test)
```

Ou tous ensemble :

```bash
for app in platform/portal-web services-laravel/*-service; do
  (cd "$app" && php artisan test)
done
```

## 3. Tests Kubernetes runtime (post-deploy)

| Commande | Vérification |
|---|---|
| `bash scripts/validate/smoke-tests.sh` | Endpoints /health des 5 services |
| `bash scripts/validate/security-smoke.sh` | .env, /storage, /admin protégé |
| `bash scripts/validate/e2e-functional-flow.sh` | Flux utilisateur bout-en-bout |
| `bash scripts/validate/security-adversarial-advanced.sh` | Fuzzing LLM (/api/v1/audit-logs 403) |
| `bash scripts/validate/validate-runtime-security-postdeploy.sh` | PSS, seccomp, HPA, PDB runtime |
| `bash scripts/validate/validate-k8s-ultra-hardening.sh` | Durcissement pod et NS |
| `bash scripts/validate/validate-k8s-resource-guards.sh` | CPU/memory limits + probes |
| `bash scripts/validate/validate-k8s-cleartext-scope.sh` | Aucun flux HTTP externe non justifié |
| `bash scripts/validate/validate-portal-service-connectivity.sh` | portail ↔ API backend |

## 4. Validation production / HA

| Commande | Contenu |
|---|---|
| `make production-ha` | PDB, anti-affinity, rolling update settings |
| `bash scripts/validate/validate-production-dockerfiles.sh` | Durcissement Dockerfile par service |
| `bash scripts/validate/validate-production-data-resilience.sh` | Backup/restore PostgreSQL |
| `bash scripts/validate/validate-production-external-db-readiness.sh` | Clés externes (Vault/ESO) |
| `make backup-test-cycle` | Full cycle backup & restore |
| `bash scripts/validate/validate-cluster-enterprise-health.sh` | Health-check cluster complet |

## 5. Tests de benchmarks (performance)

| Commande | Description |
|---|---|
| `make benchmark-k6` | smoke + load + stress (via k6 pod dans le cluster) |
| `bash scripts/performance/run-k6-tests.sh smoke` | smoke ari (1 VU × 30s) |
| `bash scripts/performance/run-k6-tests.sh load` | load (0→25→50 VUs) sans ult |
| `bash scripts/performance/run-k6-tests.sh stress` | stress >50 VUs |
| `bash scripts/performance/run-k6-tests.sh load stress` | Both séquentiels |
| `make benchmark-report` | Table consolidée des derniers résultats |

## 6. Tests sécurité (wrapper script)

| Commande | Scan |
|---|---|
| `bash scripts/ci/run-owasp-zap-dast.sh` | OWASP ZAP DAST (~15 min) |
| `bash scripts/ci/run-owasp-dependency-check.sh` | OWASP Dependency-Check (composer/npm) |
| `bash scripts/security/run-kube-bench.sh` | CIS Kubernetes Benchmark |
| `bash scripts/ci/run-mlsecops-scans.sh` | Scan ML-spécifiquedes images AI |
| `bash scripts/ci/run-sast-scan.sh` | Semgrep SAST (variante) |

## 7. Gitleaks — scans secrets

```bash
# Exécution locale (si le binaire est installé)
gitleaks detect --config .gitleaks.toml --source . --report-format json \
  --report-path security/reports/gitleaks.json

# Via Docker (pas besoin de binaire local)
docker run --rm -v "$PWD:/repo" -w /repo ghcr.io/gitleaks/gitleaks:v8.30.1 dir /repo \
  --config .gitleaks.toml --report-format json --report-path security/reports/gitleaks.json
```

## 8. Semgrep — SAST PHP

```bash
semgrep scan --config security/semgrep/semgrep.yml --json \
  -o security/reports/semgrep.json
```

## 9. Trivy — SCA

```bash
trivy fs --config security/trivy/trivy.yaml --ignorefile .trivyignore \
  --format json --output security/reports/trivy-fs.json .
```

## 10. SonarQube

```bash
bash scripts/ci/run-sonar-analysis.sh
# Démarre/arrête l'infra Sonar locale :
make sonarqube-up
make sonarqube-down
```

## 11. Cosign — signature images

```bash
# Signer (mode key-pair dev)
COSIGN_KEY=security/keys/cosign.key \
COSIGN_PASSWORD="$(cat security/keys/cosign.password.txt)" \
make sign

# Vérifier
COSIGN_PUBLIC_KEY=security/keys/cosign.pub make verify
```

## 12. Pipeline bout-en-bout (clé)

```bash
# Chaîne complète (ci + cd + validate)
make ci && make cd && make validate

# Supply chain dédiée (SBOM→sign→verify→promote)
COSIGN_KEY=security/keys/cosign.key \
COSIGN_PUBLIC_KEY=security/keys/cosign.pub \
COSIGN_PASSWORD="$(cat security/keys/cosign.password.txt)" \
make supply-chain-execute

# Final proof (gate obligatoire)
COSIGN_KEY=security/keys/cosign.key make final-proof
```

## 13. Vérification pipelines Jenkins

| Commande | Description |
|---|---|
| `make jenkins-webhook-proof` | Prouve que Jenkins a été déclenché par le dernier push |
| `make jenkins-ci-push-proof` | Prouve que Jenkins consomme le dernier commit GitHub |
| `bash scripts/jenkins/run-live-proofs.sh` | Les deux |

## 14. Exécution de tous les tests (cheat-sheet)

```bash
# Batterie minimale utile (démi)
make lint && make test && make quality-gate

# Production-level validation
make ci && make cd && make validate && make final-proof

# Rapport final
make devsecops-readiness
```

## 15. Dépendances attendues

| Outil | Version | Installation |
|---|---|---|
| `php` | 8.4 | apt `php-cli` / mise |
| `composer` | 2.x | composer install |
| `kubectl` | 1.33+ | distribuer / homebrew |
| `kind` | 0.31+ | distro / homebrew |
| `cosign` | 2.x | sigstore |
| `yq` | 4.x | `sudo apt install yq` (Go binary) |
| `jq` | 1.x | `sudo apt install jq` |
| `helm` | 3.x | distribuer |

---

**Fichier généré le 23/09/2026.** Associer à `deroulement.md` pour l'explication textuelle du flux.
