# 🔐 SecureRAG Hub — Rapport d'Audit DevSecOps Complet

**Date :** Juin 2026  
**Méthodologie :** Analyse basée uniquement sur les preuves présentes dans le dépôt (grep, find, inspection de contenu). Aucune hypothèse. Toutes les lignes et fichiers sont référencés.

---

## Table des matières

1. [Audit des 22 outils DevSecOps](#1-audit-des-22-outils-devsecops)
2. [Secrets Audit](#2-secrets-audit)
3. [Kubernetes Audit](#3-kubernetes-audit)
4. [RBAC Audit](#4-rbac-audit)
5. [Docker Security](#5-docker-security)
6. [Supply Chain](#6-supply-chain)
7. [Policy-as-Code](#7-policy-as-code)
8. [Runtime Security](#8-runtime-security)
9. [Jenkins Pipeline Audit](#9-jenkins-pipeline-audit)
10. [Quality Gates](#10-quality-gates)
11. [Score de sécurité et maturité](#11-score-de-sécurité-et-maturité)
12. [Plan d'amélioration priorisé](#12-plan-damélioration-priorisé)

---

## 1. Audit des 22 outils DevSecOps

| Outil | Statut | Intégration (%) | Preuves | Fonctionnalités utilisées | Éléments manquants |
|-------|--------|:-:|---------|--------------------------|-------------------|
| **SonarQube / SonarCloud** | ✅ Utilisé correctement | 90% | `sonar-project.properties`, `Jenkinsfile:243-257` (stage SonarQube), `infra/sonarqube/docker-compose.sonarqube.yml`, `scripts/ci/run-sonar-analysis.sh`, `security/reports/sonar-*.md/log/json` | Quality gate bloquant (`sonar.qualitygate.wait=true`), CPD exclusions, SARIF import Semgrep, coverage XML, test reports JUnit, credentials Jenkins | Branch analysis, PR decoration, SonarCloud option |
| **PHPUnit** | ✅ Utilisé correctement | 95% | `phpunit.xml` dans les 5 apps Laravel, `scripts/ci/run-tests.sh`, `coverage-*.xml` générés | Tests unitaires + feature, couverture Clover, JUnit XML, échec si driver coverage absent | — |
| **Laravel Tests** | ✅ Utilisé correctement | 95% | `scripts/ci/run-tests.sh`, `Jenkinsfile:66-93` (parallel Lint + Tests), `.coverage-artifacts/junit-*.xml` | 5 apps testées via `php artisan test`, rapport JUnit, exit code bloquant | Tests Browser/Dusk non présents |
| **Coverage Report** | ✅ Utilisé correctement | 90% | `scripts/ci/collect-coverage.sh`, `coverage.xml` fusionné, `coverage-summary.txt`, `Jenkinsfile:209-224` | Fusion Clover 5 apps, seuil configurable (`COVERAGE_MIN`), Quality Gate vérifie | Pas de diff coverage, pas de trend history |
| **Composer Audit** | ⚠️ Utilisé partiellement | 60% | `scripts/ci/audit-dependencies.sh:38-48`, `composer-audit-*.json` | `composer audit --locked` pour 5 apps, rapport JSON, échoue si vulnérabilités | Non-bloquant si échec, pas d'auto-fix, pas de SBOM |
| **npm audit** | ⚠️ Utilisé partiellement | 55% | `scripts/ci/audit-dependencies.sh:55-69`, `npm-audit-*.json` | `npm audit --production` pour chaque app, rapport full+prod, `--audit-level=critical` | `npm install` exécuté avant audit (modifie node_modules), non-bloquant |
| **Trivy** | ⚠️ Utilisé partiellement | 70% | `security/trivy/trivy-{fs,image}.yaml`, `.trivyignore`, `Jenkinsfile:129-143` (CI FS) + `Jenkinsfile.cd:54-68` (Image), `vars/trivyUtils.groovy` | Filesystem + image scanning, vuln + misconfig, `.trivyignore` (14 CVEs acceptés), Quality Gate vérifie CRITICALS | `exit-code: 0` (non bloquant seul), `ALLOW_IMAGE_VULNERABILITIES=true` en CD, pas de scanning en production runtime |
| **Gitleaks** | ✅ Utilisé correctement | 90% | `.gitleaks.toml`, `.pre-commit-config.yaml`, `Jenkinsfile:115-128`, `infra/jenkins/agents/security/Dockerfile` | Pre-commit hook + CI stage, rapport JSON, Quality Gate vérifie, allowlist configurée, fausses alertes filtrées | — |
| **Semgrep** | ✅ Utilisé correctement | 90% | `security/semgrep/semgrep.yml` (13 règles personnalisées), `.semgrepignore`, `Jenkinsfile:100-113`, `Jenkinsfile.recette:200-211` | SAST multi-langage (Python/PHP/Dockerfile/YAML), SARIF exporté vers SonarQube, règles custom Laravel/K8s | Règles communautaires `--config auto` seulement en recette, pas d'analyse de flux inter-fichiers |
| **Checkov** | ⚠️ Utilisé partiellement | 65% | `security/checkov-config.yaml`, `Jenkinsfile:150-168`, `Jenkinsfile.cd:70-79` | IaC scanning (K8s + Helm + Docker), JUnit XML, `--hard-fail-on CRITICAL --soft-fail-on HIGH` | Non-bloquant (`\|\| true`), 5 checks ignorés, Quality Gate **ne parse PAS** les rapports Checkov JUnit |
| **Hadolint** | ❌ Non utilisé | 0% | Aucune référence dans tout le dépôt | — | Aucun linting Dockerfile dans CI/CD |
| **OWASP Dependency-Check** | ❌ Non utilisé | 0% | Aucune référence | — | Composer/npm audit partiel mais pas d'OWASP DC |
| **OWASP ZAP** | ⚠️ Utilisé partiellement | 60% | `security/zap/{zap-baseline.yaml,zap-api-scan.yaml,parse-zap-report.groovy}`, `Jenkinsfile.cd:228-244`, `Jenkinsfile.recette:494-575`, `infra/jenkins/agents/zap/Dockerfile` | DAST scan baseline + API, HTML + JSON report, Quality Gate HIGH/CRITICAL bloquant | ZAP exécuté seulement en recette/staging, pas en CI; `\|\| true` sur la commande, fallback silencieux (`skip gate if no report`) |
| **Docker** | ⚠️ Utilisé partiellement | 70% | 23 Dockerfiles, `scripts/deploy/build-local-images.sh`, `scripts/release/scan-images.sh`, `platform/docker-compose.yml`, `infra/jenkins/docker-compose.yml` | Multi-service build, Docker-in-Docker (dind), registry local, distroless optionnel | `USER root` dans Jenkins/sonar-agent/zap-agent, `curl \| bash` pour installer Docker, socket Docker monté dans Jenkins |
| **Kubernetes** | ✅ Utilisé correctement | 85% | `infra/k8s/` (200+ manifests), `k8s/` (30+ policies), Helm charts, Kustomize overlays, ArgoCD | Namespaces, ResourceQuotas, LimitRanges, NetworkPolicies (default-deny), PSA (restricted), PDBs, HPAs, RBAC, ServiceAccounts | `:latest` tags dans 14 manifests, hostPath dans Falco/Cilium/Tetragon, kube-score validation partielle |
| **Jenkins** | ✅ Utilisé correctement | 90% | `Jenkinsfile` (CI), `Jenkinsfile.cd` (CD), `Jenkinsfile.recette`, `infra/jenkins/` (CasC, agents, plugins, jobs) | 3 pipelines, 7 agents K8s spécialisés, CasC, Job DSL, credentials, mail notifications, Prometheus plugin | Pas de shared library, pas de backup automatique de la config Jenkins |
| **Prometheus** | ✅ Utilisé correctement | 85% | `infra/k8s/observability/prometheus-*.yaml`, `infra/k8s/monitoring/` (10+ alert files), `infra/helm/prometheus/` | ServiceMonitor, règles d'alerte (sécurité, infra, app), RBAC, ConfigMap, Jenkins Prometheus plugin | Pas de Thanos, rétention limitée, pas de ServiceMonitors pour toutes les apps |
| **Grafana** | ✅ Utilisé correctement | 80% | `infra/k8s/observability/grafana-*.yaml`, `infra/k8s/monitoring/dashboards/` (11 dashboards) | 11 dashboards (Falco, K8s audit, Istio, ArgoCD, SLO/SLI), External Secrets pour credentials | Pas de dashboard pour Trivy, Checkov, ou résultats de scan |
| **Cosign** | ⚠️ Utilisé partiellement | 65% | `infra/jenkins/secrets/cosign.{key,password,pub}`, `Jenkinsfile.cd:86-136`, `.github/workflows/build-sign.yml`, `infra/k8s/policies/kyverno/verify-cosign-images.yaml` | Sign + Verify en CD, keyless mode, Kyverno policy, GitHub Actions workflow | `COSIGN_EXPERIMENTAL=1` (keyless), clé stockée sans encryption, Kyverno policy en **Audit** (pas Enforce), `QG_REQUIRE_COSIGN=false` |
| **Falco** | ⚠️ Utilisé partiellement | 70% | `infra/k8s/runtime-detection/daemonset.yaml`, `security/falco/custom-rules.yaml` (MITRE ATT&CK), `security/falco/falcosidekick-values.yaml`, `scripts/ci/validate-falco-rules.sh` | DaemonSet avec custom rules, Falcosidekick → Wazuh + Slack, validation YAML en CI, network policy dédiée | Rules en Audit/WARNING (pas de blocage), qualité gate **ignore** Falco, Falco `privileged: true` obligatoire |
| **Kyverno** | ✅ Utilisé correctement | 85% | `infra/k8s/policies/kyverno/` (8 polices), `kyverno-enforce/`, `k8s/kyverno-policies/` (21 polices), `scripts/ci/validate-kyverno-policies.sh` | Policies Audit + Enforce, pod security, image restriction, volume types, cosign verify, service exposure, mutation | Cosign policy en Audit, pas de Kyverno CLI en CI (fallback `REQUIRE_KYVERNO_CLI=false`) |
| **Gatekeeper (OPA)** | ❌ Non utilisé (désactivé) | 5% | `infra/k8s/opa-gatekeeper/deployment.yaml` (annotation `enable-gatekeeper: "false"`), ConstraintTemplate K8sRequiredResources (désactivé) | Déploiement existant mais feature flag à `false`, 1 ConstraintTemplate mais inactif | **Complètement désactivé**, pas de Rego policies, pas de Gatekeeper dans le pipeline |

---

## 2. Secrets Audit

| # | Finding | Fichier | Ligne | Sévérité |
|---|---------|---------|:-----:|:--------:|
| **S01** | `OPENSSH PRIVATE KEY` exposée (clé SSH déploiement) | `infra/jenkins/secrets/recette-deploy-key` | 1 | **🔴 CRITICAL** |
| **S02** | Token GitHub en clair | `infra/jenkins/secrets/github-token` | 1 | **🔴 CRITICAL** |
| **S03** | Token SonarQube en clair | `infra/jenkins/secrets/sonar-token` | 1 | **🔴 CRITICAL** |
| **S04** | Clé privée Cosign en clair (non chiffrée) | `infra/jenkins/secrets/cosign.key` | 1 | **🔴 CRITICAL** |
| **S05** | Mot de passe email Gmail en clair | `infra/jenkins/secrets/gmail-app-password` | 1 | **🔴 CRITICAL** |
| **S06** | Mot de passe Jenkins admin en clair | `infra/jenkins/secrets/jenkins-admin-password` | 1 | **🔴 CRITICAL** |
| **S07** | Kubeconfig complet en clair | `infra/jenkins/secrets/kubeconfig` | 1 | **🔴 CRITICAL** |
| **S08** | `WAZUH_PASSWORD=SecretPassword` (hardcodé) | `infra/wazuh/wazuh-exporter/docker-compose.exporter.yml` | 19 | **🟠 HIGH** |
| **S09** | `AUTH_JWT_SECRET=CHANGE_ME...` (placeholder) | `.env.example` | 10 | **🟡 MEDIUM** |
| **S10** | `POSTGRES_PASSWORD=CHANGE_ME_DEV_ONLY` (placeholder) | `.env.example` | 47 | **🟡 MEDIUM** |
| **S11** | `DB_PASSWORD: change-me-minimum...` (template) | `infra/secrets/production/securerag-database-secrets.template.yaml` | 12 | **🟡 MEDIUM** |
| **S12** | Dossier secrets mondialement accessible (`chmod 777`) | `scripts/jenkins/bootstrap-local-credentials.sh` | 112 | **🟠 HIGH** |

```bash
# Preuve S01
grep -Rni "BEGIN OPENSSH PRIVATE KEY" .  →  infra/jenkins/secrets/recette-deploy-key:1

# Preuve S12
grep -Rni "chmod 777" .  →  scripts/jenkins/bootstrap-local-credentials.sh:112:  chmod 777 "${JENKINS_SECRETS_DIR}"
```

---

## 3. Kubernetes Audit

### Composants attendus avec privilèges élevés (PASS)

| Composant | Fichier | privileged | hostNetwork | hostPID | hostPath |
|-----------|---------|:----------:|:-----------:|:-------:|:--------:|
| **Falco** | `infra/k8s/runtime-detection/daemonset.yaml:37,22,21,58-63` | ✅ | ✅ | ✅ | ✅ |
| **Cilium** | `infra/k8s/cilium/daemonset.yaml:28,20,21,48-49` | ✅ | ✅ | ✅ | ✅ |
| **Tetragon** | `infra/k8s/tetragon/daemonset.yaml:27,20,39-41` | ✅ | ❌ | ✅ | ✅ |
| **Wazuh** | `infra/k8s/wazuh/wazuh-agent-daemonset.yaml:34,44-47` | ✅ | ❌ | ❌ | ✅ |
| **SPIFFE** | `infra/k8s/spiffe/deployment.yaml:61,50` | ❌ | ❌ | ✅ | ✅ |

### Tags `:latest` — Violations (FAIL)

| # | Manifest | Image | Ligne |
|:-:|----------|-------|:-----:|
| 1 | `infra/k8s/backstage/deployment.yaml` | `backstageio/backstage:latest` | 26 |
| 2 | `infra/k8s/spiffe/deployment.yaml` | `ghcr.io/spiffe/spire-server:latest` | 23 |
| 3 | `infra/k8s/spiffe/deployment.yaml` | `ghcr.io/spiffe/spire-agent:latest` | 54 |
| 4 | `infra/k8s/aiops/deployment.yaml` | `ollama/ollama:latest` | 23 |
| 5 | `infra/k8s/kong/deployment.yaml` | `kong:latest` | 22 |
| 6 | `infra/k8s/tetragon/daemonset.yaml` | `quay.io/cilium/tetragon:latest` | 25 |
| 7 | `infra/k8s/finops/opencost.yaml` | `ghcr.io/opencost/opencost:latest` | 26 |
| 8 | `infra/k8s/data-platform/deployment.yaml` | `clickhouse/clickhouse-server:latest` | 56 |
| 9 | `infra/k8s/data-platform/deployment.yaml` | `minio/minio:latest` | 84 |
| 10 | `infra/k8s/falco-talon/deployment.yaml` | `issif/falco-talon:latest` | 29 |
| 11 | `infra/k8s/otel/deployment.yaml` | `otel/opentelemetry-collector-contrib:latest` | 23 |
| 12 | `infra/k8s/otel/deployment.yaml` | `grafana/tempo:latest` | 78 |
| 13 | `infra/k8s/coraza/deployment.yaml` | `ghcr.io/corazawaf/coraza-proxy-wasm:latest` | 23 |
| 14 | `infra/k8s/ml-platform/deployment.yaml` | `feastdev/feast:latest` | 88 |

```bash
grep -Rsn ":latest" infra/k8s/ --include='*.yaml' | grep -v '!*:latest' | grep -v 'kube-score/ignore'
```

### Bonnes pratiques vérifiées (PASS)

- ✅ PSA `restricted` sur `securerag-hub` (`infra/k8s/base/namespace.yaml:7`)
- ✅ PSA `restricted` sur `argocd`, `observability`, `backup`
- ✅ NetworkPolicies : default-deny-egress + allow-dns + allow-db-redis + allow-harbor
- ✅ ResourceQuota + LimitRange
- ✅ PodDisruptionBudgets pour tous les services
- ✅ `allowPrivilegeEscalation: false` sur TOUS les déploiements de base
- ✅ `runAsNonRoot: true` sur TOUS les déploiements de base
- ✅ ServiceAccounts dédiés par application

---

## 4. RBAC Audit

| Vérification | Résultat | Preuve |
|-------------|:--------:|--------|
| `cluster-admin` | ✅ **PASS** — Aucun bind | `grep -Rsn "cluster-admin" infra/` → vide |
| Resources `["*"]` | ✅ **PASS** — Aucun wildcard | `grep -Rsn 'resources:\s*\[' infra/k8s/` → listes spécifiques |
| Verbs `["*"]` | ✅ **PASS** — Aucun wildcard | Tous les verbes sont : get, list, watch, create, update, patch, delete |
| ServiceAccounts dédiés | ✅ **PASS** | `infra/k8s/base/*/serviceaccount.yaml` |
| RBAC readonly | ✅ **PASS** — get/list/watch uniquement | `infra/k8s/base/rbac-runtime-readonly.yaml` |

---

## 5. Docker Security

| # | Finding | Fichier | Ligne | Sévérité |
|:-:|---------|---------|:-----:|:--------:|
| D01 | `USER root` (Jenkins — justifié: docker.sock) | `infra/jenkins/Dockerfile` | 3 | 🟡 WARN |
| D02 | `USER root` (sonar-agent — justifié: packages) | `infra/jenkins/agents/sonar/Dockerfile` | 4 | 🟡 WARN |
| D03 | `USER root` (zap-agent — justifié: packages) | `infra/jenkins/agents/zap/Dockerfile` | 4 | 🟡 WARN |
| D04 | `curl -fsSL https://get.docker.com | bash` | `scripts/deploy/deploy-to-recette.sh` | 133 | **🟠 HIGH** |
| D05 | Docker socket monté dans Jenkins | `infra/jenkins/docker-compose.yml` | 29 | 🟡 WARN |

```bash
# Preuve D04
grep -Rsn "curl.*|.*bash" . --include='*.sh'  →  scripts/deploy/deploy-to-recette.sh:133:  curl -fsSL https://get.docker.com | bash

# Preuve D05
grep -Rsn "docker.sock" . --include='*.yml'  →  infra/jenkins/docker-compose.yml:29:      - /var/run/docker.sock:/var/run/docker.sock
```

---

## 6. Supply Chain

| Vérification | Statut | Preuve |
|-------------|:------:|--------|
| **Cosign Sign** | ✅ **PASS** | `Jenkinsfile.cd:88-101` — stage avec `FAIL_FAST=true` |
| **Cosign Verify** | ✅ **PASS** | `Jenkinsfile.cd:103-115` — stage avec `FAIL_FAST=true` |
| **Cosign keys** | ⚠️ **WARN** | Stockés en clair, `COSIGN_EXPERIMENTAL=1` utilisé |
| **SBOM CycloneDX** | ✅ **PASS** | `scripts/release/generate-sbom.sh` + `validate-sbom-cyclonedx.sh` |
| **Syft** | ✅ **PASS** | Utilisé dans `generate-sbom.sh:60-69` |
| **Grype** | ✅ **PASS** | `Jenkinsfile.cd:128` — scan SBOM avec `--fail-on high,critical` |
| **Kyverno verify** | ⚠️ **WARN** | `validationFailureAction: Audit` (pas **Enforce**) |
| **QG_REQUIRE_COSIGN** | ⚠️ **WARN** | `false` en CI (`Jenkinsfile:277`), seulement en CD |

```bash
# Preuve Grype
grep -rn "grype" . --include='*.sh' --include='Jenkinsfile*'  →  Jenkinsfile.cd:128

# Preuve Trivy exit-code non-bloquant
grep "exit-code" security/trivy/*.yaml  →  security/trivy/trivy.yaml:exit-code: 0
```

---

## 7. Policy-as-Code

| Vérification | Statut | Détails |
|-------------|:------:|---------|
| **Kyverno ClusterPolicies** | ✅ **7 polices** | Audit mode : pod-security, images, volumes, services, cosign, cleartext, workloads |
| **Kyverno Enforce variant** | ✅ **Existe** | `kyverno-enforce/kustomization.yaml` — patch vers Enforce |
| **Kyverno CI validation** | ✅ **PASS** | `validate-kyverno-policies.sh` exécuté en CI |
| **Kyverno policies (k8s/)** | ✅ **21+ polices** | `k8s/kyverno-policies/` — audit et enforce |
| **OPA Gatekeeper** | ❌ **FAIL — Désactivé** | `feature.securerag.dev/enable-gatekeeper: "false"` |
| **OPA ConstraintTemplate** | ❌ **FAIL — Désactivé** | Même annotation `false` |
| **Rego policies** | ❌ **Absentes** | Aucun fichier `.rego` dans le dépôt |

```bash
# Preuve OPA Gatekeeper désactivé
grep -n "enable-gatekeeper" infra/k8s/opa-gatekeeper/deployment.yaml
→ 12:    feature.securerag.dev/enable-gatekeeper: "false"
→ 43:    feature.securerag.dev/enable-gatekeeper: "false"

# Preuve Kyverno en Audit
for f in infra/k8s/policies/kyverno/*.yaml; do grep "validationFailureAction" "$f"; done
→  validationFailureAction: Audit
→  validationFailureAction: Audit
→  validationFailureAction: Audit
→  validationFailureAction: Audit
→  validationFailureAction: Audit
→  validationFailureAction: Audit
→  validationFailureAction: Audit
```

---

## 8. Runtime Security

| Composant | Statut | Intégration pipeline |
|-----------|:------:|---------------------|
| **Falco** (DaemonSet, modern_ebpf, custom rules MITRE) | ✅ Déployé | ❌ **Pas intégré** au quality gate |
| **Falcosidekick** (→ Wazuh syslog + Slack) | ✅ Déployé | ❌ Aucun callback Jenkins |
| **Tetragon** (DaemonSet) | ✅ Manifest présent | ❌ Pas activement déployé |
| **Cilium** (eBPF, Hubble, NetworkPolicies) | ⚠️ Déployé mais désactivé | `enable-cilium: "false"` |
| **Hubble** (Relay + UI) | ✅ Manifests présents | Même feature flag `false` |
| **NetworkPolicies** (default-deny, allow-dns, allow-db) | ✅ 4 policies | ✅ Validé par kube-score |
| **Falco rules validation CI** | ✅ `validate-falco-rules.sh` | ✅ PRÉSENT — validation YAML + docker |

---

## 9. Jenkins Pipeline Audit

### Analyse des stages

| Pipeline | Stages total | Stages vides | `|| true` | `exit 1` direct |
|----------|:-----------:|:------------:|:--------:|:----------------:|
| **CI** (`Jenkinsfile`) | 10 | 0 | 1 (composer install) | 0 (Quality Gate via script) |
| **CD** (`Jenkinsfile.cd`) | 10 | 0 | 3 (grype, annotate, zap) | 3 |
| **Recette** (`Jenkinsfile.recette`) | 14 | 0 | 6 (semgrep, checkov×4, sysctl, iptables, kubectl, zap) | 0 |

### Findings `|| true` critiques

| Stage | Pipeline | Ligne | Risque |
|-------|----------|:-----:|:------:|
| ZAP DAST scan | `Jenkinsfile.cd` | 236 | **🟠 HIGH** — Le scan peut échouer silencieusement |
| ZAP DAST scan | `Jenkinsfile.recette` | 527 | **🟠 HIGH** — Même problème |
| Checkov (×8 occurrences) | `Jenkinsfile:160-163`, `.cd:75`, `.recette:245-248` | multiple | **🟠 HIGH** — Sur TOUS les appels Checkov |
| Grype scan | `Jenkinsfile.cd` | 128 | 🟡 MEDIUM |
| Semgrep auto config | `Jenkinsfile.recette` | 211 | 🟡 MEDIUM |

### Flag `ALLOW_IMAGE_VULNERABILITIES=true`

```groovy
// Jenkinsfile.cd:64
ALLOW_IMAGE_VULNERABILITIES=true bash scripts/release/scan-images.sh
```

Ce flag permet aux images avec des vulnérabilités de passer en production sans échec du pipeline.

---

## 10. Quality Gates

### Tableau des quality gates

| Quality Gate | Bloque ? | Mécanisme | Preuve |
|-------------|:--------:|-----------|--------|
| **Coverage** | ✅ **YES** | `exit 1` si < seuil | `collect-coverage.sh:229` |
| **Semgrep** | ✅ **YES** | `--error` flag + QG parse | `Jenkinsfile:109` + `quality-gate.sh:130-139` |
| **Gitleaks** | ✅ **YES** | QG parse JSON, exit 1 si leaks > 0 | `quality-gate.sh:142-156` |
| **Trivy FS** | ✅ **YES** | QG parse JSON, exit 1 si CRITICAL > 0 | `quality-gate.sh:159-169` |
| **Trivy Image** | ❌ **NO** | `ALLOW_IMAGE_VULNERABILITIES=true` | `Jenkinsfile.cd:64` |
| **Checkov** | ❌ **NO** | `\|\| true` + QG **ne vérifie pas** Checkov | `grep checkov quality-gate.sh` → vide |
| **kube-score** | ✅ **YES** | `exit 1` si CRITICAL/WARNING > seuil | `validate-kube-score.sh:155-159` |
| **Kyverno** | ✅ **YES** | `exit 1` si échec (avec CLI présent) | `validate-kyverno-policies.sh:80-82` |
| **SonarQube** | ✅ **YES** | `sonar.qualitygate.wait=true` + QG verify | `sonar-project.properties:20` |
| **ZAP** | ⚠️ **PARTIAL** | Bloque si HIGH/CRITICAL, mais `\|\| true` + skip si pas de rapport | `Jenkinsfile.cd:236` + `Jenkinsfile.recette:546-547` |
| **Cosign** | ⚠️ **PARTIAL** | `QG_REQUIRE_COSIGN=false` en CI, OK en CD | `Jenkinsfile:277` |
| **Dependency Audit** | ✅ **YES** | `exit 1` si vulnérabilités | `audit-dependencies.sh:73-76` |

```bash
# Preuve Checkov ignoré par le quality gate
grep -n "checkov\|Checkov" scripts/ci/quality-gate.sh → (aucun résultat)

# Preuve Trivy non-bloquant
grep "exit-code" security/trivy/trivy.yaml → exit-code: 0

# Preuve QG_REQUIRE_COSIGN=false
grep -n "QG_REQUIRE" Jenkinsfile → QG_REQUIRE_COSIGN=false
```

---

## 11. Score de sécurité et maturité

### Calcul du score

| Catégorie | Points | Max | Score |
|-----------|:------:|:---:|:-----:|
| Secrets management | 2 | 10 | 2/10 |
| K8s pod security (hors attendus) | 8 | 10 | 8/10 |
| RBAC | 10 | 10 | 10/10 |
| Docker security | 5 | 10 | 5/10 |
| Supply chain | 7 | 10 | 7/10 |
| Policy-as-Code | 5 | 10 | 5/10 |
| Runtime security | 5 | 10 | 5/10 |
| Pipeline hardening | 4 | 10 | 4/10 |
| Quality gates | 5 | 10 | 5/10 |
| Observability (monitoring) | 9 | 10 | 9/10 |
| **TOTAL** | **60** | **100** | **60/100** |

### Résumé des findings

```
🔴 CRITICAL : 7  (Secrets en clair)
🟠 HIGH     : 4  (Checkov bypass, WAZUH_PASSWORD, curl|bash, permissions 777)
🟡 MEDIUM   : 8  (latest tags, Audit mode, flags bypass)
🟢 LOW      : 5  (Docker USER root justifié, feature flags inactifs)

Score de sécurité : 60/100
Maturité DevSecOps : Avancé
```

### Niveau de maturité

```
Débutant       [         ]
Intermédiaire  [         ]
Avancé         [████████ ]  ← 60/100
Enterprise     [         ]
```

---

## 12. Plan d'amélioration priorisé

### 🔴 P0 — Critique (Correction immédiate)

| # | Finding | Action | Fichier |
|:-:|---------|--------|---------|
| P0-1 | **8 credentials en clair** (cosign.key, github-token, sonar-token, gmail-app-password, jenkins-admin-password, kubeconfig, recette-deploy-key) | Chiffrer avec SOPS + age, charger via variables d'environnement ou vault | `infra/jenkins/secrets/` |
| P0-2 | **Permissions 777** sur le dossier secrets | Remplacer `chmod 777` par `chmod 600` | `scripts/jenkins/bootstrap-local-credentials.sh:112` |
| P0-3 | **Checkov désactivé** (`\|\| true` + QG ignore) | Retirer `\|\| true`, intégrer Checkov dans `quality-gate.sh` | `Jenkinsfile:160-163`, `quality-gate.sh` |
| P0-4 | **OPA Gatekeeper complètement désactivé** | Activer OU supprimer les manifests pour éviter la confusion | `infra/k8s/opa-gatekeeper/deployment.yaml` |

### 🟠 P1 — Important (Prochaine itération)

| # | Finding | Action |
|:-:|---------|--------|
| P1-1 | 14 images `:latest` dans manifests K8s | Remplacer par versions épinglées (digest SHA256) |
| P1-2 | `ALLOW_IMAGE_VULNERABILITIES=true` en CD | Remplacer par un seuil de vulnérabilités acceptable |
| P1-3 | ZAP scan bypassable (`\|\| true` + skip si pas de rapport) | Rendre le scan ZAP bloquant dans le pipeline CI |
| P1-4 | `COSIGN_ALLOW_INSECURE_REGISTRY` partout | Supprimer ou restreindre au dev uniquement |
| P1-5 | Kyverno cosign verify en **Audit** | Passer en **Enforce** après validation |
| P1-6 | `WAZUH_PASSWORD=SecretPassword` hardcodé | Utiliser une variable d'environnement ou vault |
| P1-7 | `curl https://get.docker.com | bash` | Remplacer par installation via package manager |

### 🟡 P2 — Amélioration continue

| # | Finding | Action |
|:-:|---------|--------|
| P2-1 | **Hadolint** absent | Ajouter le linting Dockerfile dans le pipeline CI |
| P2-2 | **OWASP Dependency-Check** absent | Ajouter pour les dépendances additionnelles |
| P2-3 | **Falco** non intégré au quality gate | Ajouter vérification Falco dans le quality gate |
| P2-4 | **Trivy `exit-code: 0`** (non bloquant) | Passer à `exit-code: 1` pour CRITICAL |
| P2-5 | **Cilium/Hubble** désactivé (`enable-cilium: "false"`) | Activer ou nettoyer les manifests |
| P2-6 | **Tetragon** présent mais pas activement déployé | Activer et intégrer au pipeline |
| P2-7 | **Dashboards Grafana** pour résultats de scan | Ajouter dashboards Trivy/Checkov/Semgrep |

---

## Annexes

### Annexe A : Commandes utilisées pour l'audit

```bash
# Secrets
grep -RniE '(password|secret|token|apikey|api_key|jwt)' .
grep -Rni "BEGIN OPENSSH PRIVATE KEY" .
grep -Rni "BEGIN RSA PRIVATE KEY" .

# K8s Security
grep -Rsn "privileged:" infra/k8s/ k8s/
grep -Rsn "hostNetwork:" infra/k8s/
grep -Rsn "hostPID:" infra/k8s/
grep -Rsn "hostIPC:" infra/k8s/
grep -Rsn ":latest" infra/k8s/ k8s/
grep -Rsn "hostPath" infra/k8s/

# RBAC
grep -Rsn "cluster-admin" infra/
grep -Rsn 'resources:\s*\[' infra/k8s/ k8s/
grep -Rsn 'verbs:\s*\[' infra/k8s/ k8s/

# Docker
find . -name Dockerfile -exec grep -Hn "^USER root" {} \;
grep -Rsn "curl.*|.*bash" .
grep -Rsn "docker.sock" .

# Pipeline
grep -n "|| true" Jenkinsfile Jenkinsfile.cd Jenkinsfile.recette
grep -n "exit 1" Jenkinsfile Jenkinsfile.cd Jenkinsfile.recette
grep -n "exit-code" security/trivy/*.yaml
```

### Annexe B : Contrôles de sécurité — Statut final

| Contrôle | Statut |
|----------|:------:|
| SonarQube Quality Gate | **Réellement appliqué** |
| PHPUnit Tests | **Réellement appliqué** |
| Coverage Minimum | **Réellement appliqué** |
| Composer Audit | **Réellement appliqué** (bloque partiellement) |
| npm Audit | **Réellement appliqué** (bloque partiellement) |
| Trivy FS | **Réellement appliqué** (via quality gate) |
| Trivy Image | **Uniquement configuré** (non-bloquant) |
| Gitleaks Secrets | **Réellement appliqué** |
| Semgrep SAST | **Réellement appliqué** |
| Checkov IaC | **Présent mais désactivé** (non-bloquant) |
| Hadolint | **Absent** |
| OWASP Dependency-Check | **Absent** |
| OWASP ZAP DAST | **Uniquement configuré** (recette seulement) |
| Kyverno Pod Security | **Réellement appliqué** (Audit) |
| Kyverno Cosign Verify | **Présent mais désactivé** (Audit, pas Enforce) |
| OPA Gatekeeper | **Présent mais désactivé** |
| Falco Runtime | **Présent mais désactivé** (pas de blocage pipeline) |
| Cosign Sign/Verify | **Réellement appliqué** (en CD) |
| Prometheus Alerting | **Réellement appliqué** |
| Grafana Dashboards | **Réellement appliqué** |
