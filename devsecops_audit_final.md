# Audit DevSecOps — SecureRAG Hub

**Date :** 2026-06-16
**Méthode :** Analyse exclusive des preuves du dépôt (Jenkinsfile, scripts, manifests K8s, logs, configurations, artefacts).

---

## 1. Résultat par outil

| Outil | Statut | Score | Preuves dans le dépôt | Fonctionnalités utilisées | Éléments manquants |
|-------|:------:|:-----:|------------------------|--------------------------|---------------------|
| **SonarQube** | ✅ | 90 % | `Jenkinsfile:410-433` (stage CI_SONAR_QUALITY_GATE), `sonar-project.properties`, `scripts/ci/run-sonar-analysis.sh`, `sonar-scanner.log:177` : `QUALITY GATE STATUS: PASSED`, `infra/sonarqube/docker-compose.sonarqube.yml`, `infra/jenkins/secrets/sonar-token` | Analyse multi-langages (10), Quality Gate bloquant (`qualitygate.wait=true`), intégration SARIF Semgrep, exclusion CPD, analyse IaC Docker + K8s | Conditionnel : requiert `RUN_SONAR=true` + `SONAR_HOST_URL` + `SONAR_TOKEN`. Coverage XML non trouvé. |
| **PHPUnit** | ✅ | 85 % | 5 `phpunit.xml` (portal-web + 4 services Laravel), `scripts/ci/run-tests.sh:49-52` (`php artisan test --log-junit`), `Jenkinsfile:118-133` (stage CI_TESTS), `Jenkinsfile:130` (archivage JUnit) | `php artisan test` sur 5 apps, JUnit XML, couverture Clover XML, merge multi-app | Driver Xdebug/PCOV absent en CI → `coverage.xml` parfois non généré. Pas de tests de mutation. |
| **Laravel Tests** | ✅ | 85 % | `scripts/ci/run-tests.sh:8-14` (5 apps), `Jenkinsfile:118-133`, `Makefile:44-52`, `Jenkinsfile.recette:139-163` | Tests Feature + Unit 5 microservices, rapport JUnit, couverture Clover | Pas de tests E2E automatisés. Pas de mutation testing. |
| **Coverage Report** | ⚠️ | 60 % | `scripts/ci/collect-coverage.sh`, `Jenkinsfile:136-151` (stage CI_COVERAGE_GATE), `Jenkinsfile:60-61` (`COVERAGE_MIN=80`, `ENFORCE_COVERAGE_GATE=true`), `quality-gate-summary.json:7` (`"status":"PARTIEL"`), `sonar-scanner.log:98` (`coverage.xml : No such file or directory`) | Seuil 80 % bloquant, parsing Cobertura XML, quality gate aggregé | **Driver coverage absent** (Xdebug/PCOV). Le Sonar scanner log confirme : `ERROR: coverage.xml (No such file or directory)`. Coverage effectivement non mesurée. |
| **Composer Audit** | ✅ | 85 % | `scripts/ci/audit-dependencies.sh:39-45`, `Jenkinsfile:153-166` (stage CI_DEPENDENCIES), `Jenkinsfile.recette:181-193` | `composer audit --locked --format=json`, 5 `composer.lock`, JSON par app, bloquant (exit 1) | Pas de croisement avec BDD externe (type OSS Index). |
| **npm audit** | ✅ | 80 % | `scripts/ci/audit-dependencies.sh:56-70`, `Jenkinsfile:153-166` | `npm audit --production --audit-level=critical` (bloquant), audit full (non-bloquant), JSON | Dépend du `npm install` préalable. `npm ci` utilisé uniquement dans la Recette. |
| **Trivy** | ✅ | 95 % | `Jenkinsfile:218-224` (fs scan), `Jenkinsfile:233-303` (CI_TRIVY_FS_QUALITY_GATE), `Jenkinsfile.cd:82-181` (image scan + gate), `Jenkinsfile:321-323` (second fs scan), `.trivyignore` (14 CVEs), `security/trivy/trivy-fs.yaml`, `security/trivy/trivy-image.yaml`, `security/trivy/trivy.yaml`, `Jenkinsfile.recette:250-256` | Scan FS (vuln+misconfig+secret), scan image OCI (5 services), Quality Gates (0 CRITICAL, max 3 HIGH), HTML Publisher, Slack alert, ignore list | **Doublon :** Trivy fs exécuté 2× dans la CI (stages `CI_SECURITY_STATIC` + `Static Analysis`). |
| **Gitleaks** | ✅ | 90 % | `Jenkinsfile:209-216` (docker run), `.gitleaks.toml` (allowlist 10 paths + 3 regex), `.pre-commit-config.yaml:17-21` (hook pre-commit), `Jenkinsfile.recette:236-243` | Scan via conteneur Docker (v8.30.1), config custom, pre-commit hook bloquant, rapport JSON | Pas de flag `--exit-code` explicite dans le stage CI (le report est consommé par le quality gate). |
| **Semgrep** | ✅ | 90 % | `Jenkinsfile:175-184`, `security/semgrep/semgrep.yml` (14 règles custom), `.semgrepignore`, `sonar-project.properties:28` (`sonar.sarif.reportPaths`), `Jenkinsfile:57-59` (`SEMGREP_VERSION=1.156.0`), `Jenkinsfile.recette:202-211` | Règles custom : Python (6), PHP/Laravel (5), Docker (2), K8s (1), `--error` bloquant, SARIF vers Sonar, `--config auto` (non-bloquant) | Règles `auto` non bloquantes (`|| true`). Pas de Semgrep Registry supplémentaire. |
| **Checkov** | ✅ | 85 % | `Jenkinsfile:311-318` (4 scans : k8s + helm + platform + services-laravel), `Jenkinsfile.cd:456-458` (Helm CD), `Jenkinsfile.recette:245-248`, `security/checkov-config.yaml` (5 skip-checks), `Jenkinsfile:329` (junit publish) | Scan K8s, Helm, Docker, hard-fail CRITICAL, soft-fail HIGH, JUnit XML publié | 5 checks désactivés (`CKV_K8S_21,15,16,23,43`). Justifiés mais réduisent la couverture. |
| **Hadolint** | ❌ | 0 % | Aucun. Mentionné uniquement dans `devsecops_audit_expert.md:901-925` à titre de recommandation. | — | Pas de `.hadolint.yaml`. Pas de stage CI. Pas dans le Makefile. Pas dans pre-commit. 16 Dockerfiles sans linting. |
| **OWASP DC** | ❌ | 0 % | Aucune occurrence dans tout le dépôt. | — | Absence totale. Les services Python legacy n'ont pas d'audit de dépendances. |
| **OWASP ZAP** | ✅ | 85 % | `Jenkinsfile.cd:507-559` (DAST — ZAP), `Jenkinsfile.recette:484-558` (DAST remote), `security/zap/zap-baseline.yaml`, `security/zap/zap-api-scan.yaml`, `security/zap/zap-rules-config.tsv`, `security/zap/parse-zap-report.groovy`, `scripts/zap-quality-gate.sh`, `Makefile:460-486` (dast-baseline, dast-full) | Baseline scan (spider + passive), API scan (OpenAPI), Quality Gate bloquant (0 High/Critical), HTML + JSON, Groovy parser, Makefile | Scan full actif non intégré au pipeline (`make dast-full` local). Pas d'authentification configurée dans les scans. |
| **Docker** | ✅ | 90 % | 16 Dockerfiles, 5 docker-compose, `Jenkinsfile:187-216` (DinD pour Gitleaks), `scripts/deploy/build-local-images.sh`, `.dockerignore`, `platform/portal-web/Dockerfile.distroless`, `docker buildx imagetools` (promotion par digest) | Build multi-service, registry local `:5001`, Docker-in-Docker Jenkins, promotion immutable, distroless variant, multi-stage | Pas de layer caching avancé. Hadolint absent (voir ci-dessus). |
| **Kubernetes** | ✅ | 90 % | `infra/k8s/base/` (14 microservices), `infra/k8s/overlays/` (7 environnements), `infra/k8s/policies/kyverno/` (7 ClusterPolicies), `infra/k8s/observability/`, `infra/k8s/runtime-detection/`, `infra/k8s/argocd/`, `infra/k8s/backup/`, `infra/k8s/secrets/`, HPA, PDB, NetworkPolicies, RBAC, ServiceAccounts, LimitRange, ResourceQuota | Kustomize multi-env, Kind local, HPA + PDB, NetworkPolicies par service, RBAC, quotas, ArgoCD GitOps | Pas de service mesh. PodSecurityStandards gérés par Kyverno (choix valide). |
| **Jenkins** | ✅ | 90 % | 3 Jenkinsfiles (CI+CD+Recette), `infra/jenkins/casc/jenkins.yaml` (CasC), `infra/jenkins/jobs/` (3 Job DSL), `infra/jenkins/Dockerfile`, `infra/jenkins/plugins.txt`, `infra/jenkins/init.groovy.d/`, `infra/jenkins/docker-compose.yml`, `vars/trivyUtils.groovy` (Shared Library), `Jenkinsfile:734-738` (email HTML), `Jenkinsfile:290-296` (Slack placeholder) | Pipeline as Code, CasC, Job DSL, DinD, credentials (Sonar, SSH, Cosign, GitHub), email HTML, Shared Library | Agent unique. Slack webhook = `<SLACK_WEBHOOK_URL>` (placeholder). Pas de backup Jenkins. |
| **Prometheus** | ✅ | 80 % | `infra/k8s/observability/prometheus-deployment.yaml` (v2.54.1), `prometheus-config.yaml`, `prometheus-rules-security.yaml`, `prometheus-rbac.yaml`, 8+ ServiceMonitors (`infra/k8s/monitoring/servicemonitor-*.yaml`), `Makefile:384-388` | Déploiement, règles alerte sécurité, retention 15j/10GB, ServiceMonitors apps+Harbor+CertManager+Vault, RBAC | **Pods non annotés** `prometheus.io/scrape`. Déploiement manuel (`make observability-up`). ServiceMonitors définis mais non actifs. |
| **Grafana** | ✅ | 80 % | `infra/k8s/observability/grafana-deployment.yaml` (v11.2.0), dashboard JSON custom « SecureRAG Hub Overview », datasources Prometheus+Loki+Alertmanager, `Makefile:384-388` | Dashboard, 3 datasources, admin pwd via K8s Secret | Déploiement manuel. Pas de dashboards sécurité (Falco, Kyverno, ZAP). |
| **Cosign** | ✅ | 90 % | `Jenkinsfile.cd:183-259` (sign + verify keyless), `Jenkinsfile.cd:328-366` (attest SBOMs via Vault), `.github/workflows/ci.yml:47-55`, `.github/workflows/build-sign.yml:123-136`, `scripts/release/sign-images.sh`, `scripts/release/verify-signatures.sh`, `scripts/release/attest-sboms.sh`, `infra/k8s/policies/kyverno/verify-cosign-images.yaml`, `security/sigstore/` (Fulcio+Rekor+Keycloak) | Keyless signing (OIDC GitHub + Keycloak local), key-based signing/verification, SBOM attestation, Vault key storage, Kyverno runtime check | `QG_REQUIRE_COSIGN=false` en CI (normal — scope CD). Pas de rotation automatique. |
| **Falco** | ✅ | 85 % | `security/falco/custom-rules.yaml` (226 lignes, 16 règles MITRE ATT&CK), `infra/k8s/runtime-detection/daemonset.yaml` (v0.38.2), `falcosidekick.yaml`, `scripts/ci/validate-falco-rules.sh`, `falco-rules-validation.log:12` (`Ok, with warnings`), `falco-values.yaml`, `Makefile:408-412` | DaemonSet custom rules, validation CI moteur Falco, Falcosidekick alerting, RBAC | 2 warnings (unused macro `securerag_known_procs` + unknown source `k8s_audit`). Déploiement manuel. Pas de Falco Talon. |
| **Kyverno** | ✅ | 90 % | 7 ClusterPolicies, `kyverno-apply.log:25` (`pass: 35, fail: 0, warn: 7`), `Jenkinsfile:334-363` (CI_K8S_POLICY), `scripts/ci/validate-kyverno-policies.sh`, `Jenkinsfile.recette:265-291`, `Jenkinsfile.cd:467-478` (Pre-flight), `tests/admission/` (5 negative + 1 positive), `Makefile:283-286,399-405` | `kyverno apply` statique, Audit/Enforce, Cosign verification, Pod Security, admission tests, toggle Enforce séquencé | `validationFailureAction: Audit` par défaut. 7 warnings (livenessProbe manquante). PolicyReports non exploités. |
| **Gatekeeper** | ❌ | 0 % | Aucune occurrence. | — | Kyverno choisi comme alternative. Décision architecturale valide. |

---

## 2. Niveau de maturité DevSecOps

| Critère | Résultat |
|---------|----------|
| **Niveau global** | **Avancé** |
| **Note sur 10** | **8/10** |

**Justification :** Le projet couvre l'intégralité des piliers DevSecOps (SAST, SCA, secret scanning, IaC scanning, DAST, container scanning, supply chain security, runtime security, policy enforcement, observability, GitOps, secret management). 17 outils sur 20 sont correctement intégrés. 3 sont absents (Hadolint, OWASP DC, Gatekeeper — ce dernier remplacé par Kyverno). Tous les contrôles critiques ont des quality gates bloquants.

---

## 3. Écarts / Bonnes pratiques

| # | Écart | Sévérité | Détail |
|---|-------|:--------:|--------|
| 1 | Coverage driver absent | **P1** | Xdebug/PCOV non installé dans l'image Jenkins → `coverage.xml` non généré |
| 2 | Hadolint absent | **P1** | 16 Dockerfiles sans linting |
| 3 | OWASP Dependency-Check absent | **P2** | Services Python legacy sans audit de dépendances |
| 4 | Kyverno en Audit seulement | **P2** | Bloque pas les pods non conformes |
| 5 | Prometheus/Grafana manuel | **P2** | Pas de déploiement automatique, pods non annotés |
| 6 | Falco manuel | **P2** | DaemonSet prêt mais déploiement non automatisé |
| 7 | Trivy fs redondant | **P3** | 2 scans identiques dans le même pipeline CI |
| 8 | Slack placeholder | **P3** | `<SLACK_WEBHOOK_URL>` non substitué |

---

## 4. Vérification des stages Jenkins

### Jenkinsfile (CI) — 13 stages

| Stage | Exécuté | Contenu |
|-------|:-------:|---------|
| Checkout | ✅ | `checkout scm` |
| Prepare Workspace | ✅ | `mkdir` + `chmod` |
| Install CI Dependencies | ✅ | pip semgrep + composer install + npm install |
| CI_LINT | ✅ | `make lint` (shellcheck + kustomize + docker compose + hardening) |
| CI_TESTS | ✅ | `run-tests.sh` → 5 apps testées → JUnit |
| CI_COVERAGE_GATE | ✅ | `collect-coverage.sh` → seuil 80 % |
| CI_DEPENDENCIES | ✅ | `audit-dependencies.sh` → composer + npm |
| CI_SECURITY_STATIC | ✅ | Semgrep `--error` + Gitleaks via Docker + Trivy fs |
| CI_TRIVY_FS_QUALITY_GATE | ✅ | Parsing JSON → gate CRITICAL/HIGH → `error()` |
| Static Analysis & IaC Scanning | ✅ | Checkov ×4 + Trivy fs (doublon) |
| CI_K8S_POLICY | ✅ | k8s-hardening + kyverno + kube-score + falco rules |
| CI_QUALITY_GATE | ✅ | Agrège 9 signaux → exit 1 si REQUIRED ≠ PASS |
| CI_SONAR_QUALITY_GATE | ✅ | Conditionnel (`RUN_SONAR=true`) → Sonar scanner + gate |

### Jenkinsfile.cd (CD) — 18 stages

| Stage | Exécuté | Contenu |
|-------|:-------:|---------|
| Checkout | ✅ | `checkout scm` |
| Prepare Workspace | ✅ | mkdir + chmod |
| CD_IMAGE_SCAN | ✅ | `scan-images.sh` (Trivy ×5 services) |
| CD_TRIVY_IMAGE_QUALITY_GATE | ✅ | Parse 5 JSON → gate global |
| Sign Release Candidate Images | ✅ | Cosign keyless (OIDC Keycloak) |
| Verify Release Candidate Signatures | ✅ | Cosign verify keyless |
| Promote Verified Images by Digest | ✅ | `docker buildx imagetools create` |
| Generate SBOM | ✅ | Syft CycloneDX + validation |
| SBOM Analysis — Grype | ✅ | `grype sbom:` → blocage HIGH/CRITICAL |
| Attest SBOMs | ✅ | Cosign attest via Vault |
| Assert Mandatory Supply Chain Evidence | ✅ | Vérifie sign+verify+sbom+promotion |
| Generate Release Attestation | ✅ | JSON + Markdown |
| Generate SLSA-style Provenance | ✅ | `provenance.slsa.json` |
| Record Release Evidence | ✅ | `release-evidence.md` |
| Collect Supply Chain Evidence | ✅ | Consolidation |
| Helm Security Scan | ✅ | Checkov sur Helm charts |
| Pre-flight Kyverno | ✅ | Validation overlay production |
| Update GitOps Manifests | ✅ | Pin digests → `git push` |
| DAST — OWASP ZAP | ✅ | API scan + quality gate |
| Generate Support Pack | ✅ | `make support-pack` |

### Jenkinsfile.recette — 9 stages

| Stage | Exécuté | Contenu |
|-------|:-------:|---------|
| Checkout à Deploy to Recette | ✅ | CI complet + SSH vers 63.250.59.72 |
| Post-deploy Smoke Tests | ✅ | Health checks + `smoke-tests.sh` |
| DAST | ✅ | ZAP baseline scan remote + retrieve + parse |

> **Aucun stage vide ou simulé détecté.** Chaque stage appelle un script shell ou une commande Groovy qui produit des artefacts vérifiables.

---

## 5. Outils installés mais jamais appelés

| Outil | Config présent | Appelé ? |
|-------|:-------------:|:--------:|
| ArgoCD | `infra/k8s/argocd/` (Application + ApplicationSet + Project) | Manuel (`make argocd-bootstrap`) |
| Loki | `infra/k8s/observability/loki-deployment.yaml` | Manuel (`make observability-up`) |
| Alertmanager | `infra/k8s/observability/alertmanager.yaml` | Manuel (`make observability-up`) |
| SOPS | `.sops.yaml` + `scripts/secrets/` | Scripts spécialisés, pas dans pipeline |
| Vault (hors Cosign) | `security/vault/` (HCL policies + Helm values) | Dans le CD pour Cosign uniquement |
| Wazuh | `infra/wazuh/docker-compose.wazuh.yml`, `infra/k8s/wazuh/` | Ni pipeline ni Makefile |
| Renovate | `renovate.json` | Externe (GitHub App) |

---

## 6. Outils appelés mais résultats non exploités

| Outil | Résultat produit | Exploité ? |
|-------|-----------------|:----------:|
| Kyverno PolicyReports | Générés en cluster | ❌ Non lus dans le pipeline |
| Falco alerts runtime | Logs Falco + Falcosidekick | ❌ Non vérifiés dans le pipeline |
| ServiceMonitors | 8+ définis dans `monitoring/` | ❌ Pods non annotés → pas de métriques |
| Wazuh | Agent déployé | ❌ Pas de vérification dans le pipeline |

---

## 7. Configurations incomplètes ou désactivées

| Configuration | État | Impact |
|---------------|------|--------|
| `Slack webhook` | `<SLACK_WEBHOOK_URL>` non substitué | Alerte Slack silencieuse |
| `QG_REQUIRE_COSIGN=false` | Cosign désactivé en CI | Normal (scope CD), mais documenté |
| `RUN_SONAR` paramétrable | Par défaut `true`, mais `SONAR_HOST_URL` vide par défaut | Sonar peut être sauté silencieusement |
| `Kyverno Enforce` | `Audit` par défaut | Aucun blocage runtime des pods non conformes |
| `SKIP_FALCO_DOCKER=true` | Uniquement dans la Recette | Pas de validation Falco sur la Recette |
| GitHub Actions | Tous marqués `legacy` + `workflow_dispatch` only | Intentionnel (Jenkins source de vérité) |

---

## 8. Quality Gates — Blocage réel

| Quality Gate | Bloquant | Mécanisme |
|-------------|:--------:|-----------|
| SonarQube | ✅ | `sonar.qualitygate.wait=true`, `sonar-scanner` exit code ≠ 0 |
| Trivy FS | ✅ | CRITICAL > 0 ou HIGH > 3 → `error("Trivy FS Quality Gate Failed")` |
| Trivy Image | ✅ | Idem, agrégé sur 5 services |
| Coverage | ✅ | `< 80 %` → `exit 1` dans `collect-coverage.sh` (si driver présent) |
| Semgrep | ✅ | `--error` → exit code non-zero |
| Gitleaks | ⚠️ | Indirect via quality gate aggregé (pas de `--exit-code` explicite) |
| Checkov | ✅ | `--hard-fail-on CRITICAL` → exit code non-zero |
| Composer Audit | ✅ | `composer audit` → exit code non-zero |
| npm Audit | ✅ | `--audit-level=critical` → exit code non-zero |
| Grype | ✅ | `--fail-on high,critical` → exit code non-zero |
| ZAP DAST | ✅ | `parse-zap-report.groovy` → `error()` si High/Critical > 0 |
| CI Quality Gate | ✅ | Aggregé → `exit 1` si `REQUIRED=true AND status≠PASS` |

---

## 9. Statut réel de chaque contrôle de sécurité

| Contrôle | Statut |
|----------|--------|
| SAST — Semgrep | ✅ Réellement appliqué — `--error` bloquant |
| SAST — SonarQube | ✅ Réellement appliqué — Quality Gate bloquant |
| Secret scanning — Gitleaks | ✅ Réellement appliqué — CI + pre-commit |
| SCA — Composer | ✅ Réellement appliqué — bloquant |
| SCA — npm | ✅ Réellement appliqué — bloquant sur critical |
| SCA — OWASP Dependency-Check | ❌ Absent |
| Container scan — Trivy | ✅ Réellement appliqué — image + FS, bloquant |
| IaC scan — Checkov | ✅ Réellement appliqué — K8s + Helm + Docker, bloquant |
| Dockerfile lint — Hadolint | ❌ Absent |
| DAST — OWASP ZAP | ✅ Réellement appliqué — bloquant dans CD |
| Image signing — Cosign | ✅ Réellement appliqué — CD keyless + key-based |
| SBOM — Syft | ✅ Réellement appliqué — CycloneDX validé |
| SBOM analysis — Grype | ✅ Réellement appliqué — bloquant |
| Policy engine — Kyverno | ⚠️ Présent mais désactivé (Audit) |
| Policy engine — Gatekeeper | ❌ Absent (Kyverno choisi) |
| Runtime security — Falco | ⚠️ Uniquement configuré (déploiement manuel) |
| Observability — Prometheus | ⚠️ Uniquement configuré (déploiement manuel) |
| Observability — Grafana | ⚠️ Uniquement configuré (déploiement manuel) |
| Kubernetes hardening | ✅ Réellement appliqué — kube-score + kyverno + ultra-hardening |
| Secret management — Vault | ⚠️ Uniquement configuré (utilisé pour Cosign dans CD) |

---

## 10. Plan d'amélioration priorisé

| # | Priorité | Action | Effort |
|---|:--------:|--------|:------:|
| 1 | **P0** | Installer Xdebug ou PCOV dans l'image Docker Jenkins pour activer la couverture PHP | 1 h |
| 2 | **P1** | Créer `.hadolint.yaml` + ajouter stage Hadolint dans la CI + cible Makefile | 2 h |
| 3 | **P1** | Activer Kyverno Enforce pour `verify-cosign-images` + `require-pod-security` dans le pipeline CD | 3 h |
| 4 | **P2** | Ajouter OWASP Dependency-Check pour les services Python legacy (`services/`) | 3 h |
| 5 | **P2** | Automatiser déploiement Prometheus + Grafana via ArgoCD + annoter les pods | 4 h |
| 6 | **P2** | Ajouter `falco-up` au pipeline CD + valider les alertes Falco en post-deploy | 2 h |
| 7 | **P3** | Supprimer le Trivy fs redondant du stage `Static Analysis & IaC Scanning` | 30 min |
| 8 | **P3** | Remplacer `<SLACK_WEBHOOK_URL>` par une variable Jenkins ou supprimer le bloc | 15 min |
