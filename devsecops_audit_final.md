# Rapport d'audit DevSecOps — SecureRAG Hub

**Date :** 16 juin 2026
**Méthodologie :** Analyse exhaustive du dépôt (Jenkinsfiles, scripts, manifests K8s, Dockerfiles, configs, rapports, logs Jenkins). Zéro supposition.

---

## 1. TABLEAU D'ÉVALUATION

| Outil | Statut | Score | Preuve clé | Bloquant ? |
|---|---|---|---|---|
| SonarQube / SonarCloud | ⚠️ Partiel | 60% | `sonar-project.properties`, `RUN_SONAR=false` (`Jenkinsfile:17`) | ❌ |
| PHPUnit / Laravel Tests | ✅ Correct | 85% | 5 `phpunit.xml`, `run-tests.sh:32-53` | ✅ |
| Coverage Report | ⚠️ Partiel | 40% | `COVERAGE_MIN='0'` (`Jenkinsfile:59`) | ❌ |
| Composer Audit | ⚠️ Partiel | 55% | `exit 0` forcé (`audit-dependencies.sh:68`) | ❌ |
| npm audit | ⚠️ Partiel | 15% | 5/5 `PRÊT_NON_EXÉCUTÉ` (pas de `package-lock.json`) | ❌ |
| Trivy | ✅ Correct | 90% | 3 configs YAML, quality gates FS + image | ✅ |
| Gitleaks | ✅ Correct | 80% | `.gitleaks.toml`, pre-commit + CI | ✅ |
| Semgrep | ✅ Correct | 85% | 14 règles custom, `--error` flag | ✅ |
| Checkov | ⚠️ Partiel | 45% | 9/9 appels avec `\|\| true` | ❌ |
| Hadolint | ❌ Absent | 0% | Zéro occurrence | — |
| OWASP Dependency-Check | ❌ Absent | 0% | Zéro occurrence | — |
| OWASP ZAP | ✅ Correct | 75% | 4 configs, baseline + API scan | ✅ |
| Docker | ✅ Correct | 85% | 16 Dockerfiles, multi-stage, distroless | N/A |
| Kubernetes | ✅ Correct | 90% | 11 NetworkPolicies, PSS Restricted, RBAC | ✅ |
| Jenkins | ✅ Correct | 80% | 3 pipelines (14+18+15 stages), CASC | ✅ |
| Prometheus | ✅ Correct | 75% | 18 fichiers alertes, `observability-up` | N/A |
| Grafana | ✅ Correct | 75% | 3 datasources, dashboards custom | N/A |
| Cosign | ⚠️ Partiel | 60% | Keyless + attestation ; `cosign.key` commitée | ✅ |
| Falco | ✅ Correct | 75% | 14 règles MITRE, DaemonSet K8s | ⚠️ |
| Kyverno | ✅ Correct | 90% | 16 policies (audit+enforce), pre-flight CD | ✅ |
| Gatekeeper | ❌ Absent | 0% | Zéro occurrence (compensé Kyverno) | — |

---

## 2. QUALITY GATES — BLOQUENT-ELLES ?

| Gate | Bloquante ? | Condition de blocage |
|---|---|---|
| **Trivy FS** | ✅ Oui | CRITICAL>0 ou HIGH>3 → `error()` |
| **Trivy Image** | ✅ Oui | CRITICAL>0 ou HIGH>3 → `error()` |
| **Quality Gate agrégée** | ✅ Oui | Tout `required=true` FAIL → exit 1 |
| **Coverage** | ❌ Non | `COVERAGE_MIN=0` → jamais déclenché |
| **Sonar** | ⚠️ Conditionnelle | Si `RUN_SONAR=true` ET gate OK |
| **kube-score** | ✅ Oui | CRITICAL>seuil ou WARNING>seuil |
| **Kyverno static** | ⚠️ Conditionnelle | Si `REQUIRE_KYVERNO_CLI=true` |
| **Falco rules** | ✅ Oui | Règles invalides → exit 1 |
| **ZAP DAST** | ✅ Oui | High/Critical > 0 → `error()` |
| **Grype SBOM** | ✅ Oui | `--fail-on high,critical` |
| **Checkov** | ❌ Non | `\|\| true` → toujours succès |
| **Composer Audit** | ❌ Non | `exit 0` → toujours succès |
| **npm Audit** | ❌ Non | `exit 0` → toujours succès |

**4 gates neutralisées sur 13.**

---

## 3. STAGES JENKINS

| Pipeline | Stages | Vides | Simulés |
|---|---|---|---|
| Jenkinsfile (CI) | 14 | 0 | 0 |
| Jenkinsfile.cd (CD) | 18 | 0 | 0 |
| Jenkinsfile.recette | 15 | 0 | 0 |

---

## 4. OUTILS — RÉSULTATS EXPLOITÉS ?

| Outil | Résultat produit | Exploité ? |
|---|---|---|
| Checkov | `checkov-*.xml` (JUnit) | ❌ Archivé, jamais dans quality gate |
| Composer audit | `composer-audit-*.json` | ❌ Archivé, jamais parsé |
| npm audit | `npm-audit-*.json` | ❌ Archivé, jamais parsé (et jamais généré) |
| Sonar scanner | `sonar-analysis.md`, `sonar-quality-gate.json` | ⚠️ Parsé si `RUN_SONAR=true` |
| Trivy FS | `trivy-fs.json` | ✅ Parsé par quality gate Groovy + quality-gate.sh |
| Trivy Image | `trivy-image-*.json` | ✅ Parsé par quality gate Groovy |
| Semgrep | `semgrep.json` | ✅ Quality gate + SARIF (mismatch) |
| Gitleaks | `gitleaks.json` | ✅ Quality gate |
| ZAP | `zap-report.json` | ✅ parse-zap-report.groovy + zap-quality-gate.sh |
| Grype | `*.grype.json` | ✅ `--fail-on high,critical` |
| kube-score | `kube-score-*.txt` | ✅ Quality gate |
| Kyverno | `kyverno-apply.log` | ✅ Quality gate |

---

## 5. CONTRÔLES — CLASSIFICATION

| Contrôle | État |
|---|---|
| SAST (Semgrep) | ✅ Réellement appliqué |
| Secret scanning (Gitleaks) | ✅ Réellement appliqué (allowlist à corriger) |
| Trivy FS + Image | ✅ Réellement appliqué |
| IaC (Checkov) | ⚠️ Désactivé (non-bloquant) |
| SonarQube | ⚠️ Désactivé (`RUN_SONAR=false`) |
| Coverage | ⚠️ Désactivé (`COVERAGE_MIN=0`) |
| Composer/npm Audit | ⚠️ Désactivé (non-bloquant + npm inopérant) |
| DAST (ZAP) | ✅ Réellement appliqué |
| Supply chain (Cosign) | ✅ Appliqué (clé à retirer) |
| SBOM (Syft+Grype) | ✅ Réellement appliqué |
| K8s admission (Kyverno) | ✅ Réellement appliqué |
| Runtime (Falco) | ⚠️ Configuré seulement |
| Docker linting (Hadolint) | ❌ Absent |
| OWASP DC | ❌ Absent |
| Gatekeeper | ❌ Absent (compensé) |

---

## 6. SECRETS DANS LE DÉPÔT

| Fichier | Type | Risque |
|---|---|---|
| `infra/jenkins/secrets/cosign.key` | Clé privée Cosign chiffrée | Élevé |
| `infra/jenkins/secrets/cosign.password` | Mot de passe déchiffrement en clair | CRITIQUE |
| `infra/jenkins/secrets/recette-deploy-key` | Clé SSH root@63.250.59.72 | CRITIQUE |
| `infra/jenkins/secrets/sonar-token` | Token SonarQube | Élevé |
| `security/chromadb/chromadb-auth-config.yaml:19-23` | 3 tokens ChromaDB en clair | Élevé |
| `security/sigstore/keycloak-values.yaml:8-9` | `admin:adminpassword` | Élevé |

---

## 7. ÉCARTS P0 — CRITIQUES

| # | Écart | Fichier:Ligne |
|---|---|---|
| 1 | `COVERAGE_MIN='0'` → gate désactivée | `Jenkinsfile:59` |
| 2 | `RUN_SONAR=false` → jamais exécuté | `Jenkinsfile:17` |
| 3 | 9× Checkov avec `\|\| true` → jamais bloquant | `Jenkinsfile:307-310,317`, `Jenkinsfile.cd:456`, `Jenkinsfile.recette:240-243` |
| 4 | `exit 0` forcé → audit jamais bloquant | `scripts/ci/audit-dependencies.sh:68` |
| 5 | npm audit 5/5 inopérant | `dependency-audit-summary.md:8-16` |
| 6 | Clé privée Cosign commitée | `infra/jenkins/secrets/cosign.key` |
| 7 | Clé SSH recette commitée | `infra/jenkins/secrets/recette-deploy-key` |
| 8 | Allowlist Gitleaks trop permissive | `.gitleaks.toml:10` |

---

## 8. MATURITÉ GLOBALE

**Niveau : Avancé (3/4)**
**Note : 7/10**

---

## 9. PLAN P0 — CORRECTIONS IMMÉDIATES

| # | Fichier | Ligne | Correction |
|---|---|---|---|
| 1 | `Jenkinsfile` | 59 | `COVERAGE_MIN = '80'` |
| 2 | `Jenkinsfile` | 17 | `defaultValue: true` |
| 3 | `Jenkinsfile` | 307-310 | Supprimer `\|\| true`, mettre `--hard-fail-on HIGH` |
| 4 | `scripts/ci/audit-dependencies.sh` | 68 | `if (( failures )); then exit 1; fi` |
| 5 | 5 apps | — | `git add **/package-lock.json` |
| 6 | `infra/jenkins/secrets/` | — | `git rm --cached` + révoquer |
| 7 | `.gitleaks.toml` | 10 | Supprimer `infra/jenkins/secrets/` |
| 8 | `Jenkinsfile` | 178 | `--sarif --output security/reports/semgrep.sarif` |

---

## 10. CONDITIONS POUR 10/10

1. ✅ Zéro secret dans le dépôt (P0-6, P0-7)
2. ✅ Toutes les quality gates bloquantes (P0-1 à P0-5, P0-8)
3. ✅ Hadolint + OWASP DC intégrés
4. ✅ Couverture ≥ 80% vérifiée et bloquante
5. ✅ SonarQube exécuté à chaque build
6. ✅ SAST + DAST (full scan) + SCA complets et bloquants
7. ✅ Supply chain SLSA 3+
8. ✅ Runtime security active (Falco déployé, alertes vérifiées)
9. ✅ Observabilité déployée et vérifiée
10. ✅ Conformité multi-standards vérifiée
