# Rapport d'audit DevSecOps — SecureRAG Hub

**Date :** 16 juin 2026
**Périmètre :** Ensemble du dépôt `/root/MasterPFE`
**Méthodologie :** Analyse statique des Jenkinsfiles, manifests Kubernetes, Dockerfiles, scripts CI/CD, configurations de sécurité, logs et artefacts

---

## Tableau d'évaluation global

### Légende

| Icône | Signification |
|---|---|
| ✅ | Utilisé correctement — l'outil est intégré, exécuté dans le pipeline, et ses résultats sont exploités |
| ⚠️ | Utilisé partiellement — l'outil est présent (configuré, scripté) mais soit désactivé, soit non-bloquant, soit résultats ignorés |
| ❌ | Non utilisé — aucune trace de l'outil dans le dépôt |

---

### CATÉGORIE 1 — Analyse de code (SAST)

| Outil | Statut | Score | Exécuté dans le pipeline ? | Bloquant ? | Constat principal | Action prioritaire |
|---|---|---|---|---|---|---|
| **Semgrep** | ✅ | 85 % | Oui — `Jenkinsfile:175-179` | Oui (`--error`) | 14 règles custom (Python, Dockerfile, K8s, PHP), venv dédié, SARIF exporté vers Sonar | Ajouter règles `p/default` et JS/TS |
| **SonarQube** | ⚠️ | 60 % | Non par défaut — `RUN_SONAR=false` | Conditionnel | Tout est prêt (config, token, docker-compose) mais jamais exécuté. Rapport confirme `PRÊT_NON_EXÉCUTÉ` | Passer `RUN_SONAR=true` par défaut |

### CATÉGORIE 2 — Tests et couverture

| Outil | Statut | Score | Exécuté dans le pipeline ? | Bloquant ? | Constat principal | Action prioritaire |
|---|---|---|---|---|---|---|
| **PHPUnit / Laravel Tests** | ✅ | 85 % | Oui — Stage `CI_TESTS` | Oui (failures=blocage) | 5 apps testées, JUnit XML publié, détection Xdebug/PCOV | Exécution parallèle multi-apps |
| **Coverage Report** | ⚠️ | 40 % | Oui — Stage `CI_COVERAGE_GATE` | Non (`COVERAGE_MIN=0`) | Parsing Cobertura fonctionnel mais seuil à 0 % rend la gate inefficace | Mettre `COVERAGE_MIN=70` |

### CATÉGORIE 3 — Audit des dépendances

| Outil | Statut | Score | Exécuté dans le pipeline ? | Bloquant ? | Constat principal | Action prioritaire |
|---|---|---|---|---|---|---|
| **Composer Audit** | ⚠️ | 55 % | Oui — Stage `CI_DEPENDENCIES` | Non (`exit 0` forcé) | `composer audit --locked` exécuté, JSON archivé mais script toujours `exit 0` | Remplacer `exit 0` par condition sur seuil |
| **npm audit** | ⚠️ | 55 % | Oui — Stage `CI_DEPENDENCIES` | Non (`exit 0` forcé) | `npm audit --json` exécuté, JSON archivé, mêmes limitations + API dépréciée | Migrer vers `npm audit signatures`, rendre bloquant |
| **OWASP Dependency-Check** | ❌ | 0 % | Non | — | Zéro occurrence dans le dépôt. Partiellement compensé par Trivy | Intégrer OWASP DC ou justifier l'absence |

### CATÉGORIE 4 — Scan de vulnérabilités et secrets

| Outil | Statut | Score | Exécuté dans le pipeline ? | Bloquant ? | Constat principal | Action prioritaire |
|---|---|---|---|---|---|---|
| **Trivy** | ✅ | 90 % | Oui — CI (FS+IaC) + CD (images) | Oui — CRITICAL>0 ou HIGH>3 | 3 fichiers config, quality gates CI+CD, parsing Groovy, Slack, Grype SBOMs | Justifier les 14 CVE du `.trivyignore` |
| **Gitleaks** | ✅ | 80 % | Oui — CI + pre-commit hook | Oui (via quality gate) | Image Docker pinnée par digest, `.gitleaks.toml`, pre-commit, quality gate | Supprimer `infra/jenkins/secrets/` de l'allowlist |
| **Checkov** | ⚠️ | 50 % | Oui — 4 scans CI + 1 scan CD | Non (`\|\| true` partout) | Scan K8s, Helm, Docker (platform+services). JUnit publié mais jamais bloquant | Supprimer `\|\| true`, ajouter seuil |
| **Hadolint** | ❌ | 0 % | Non | — | 16 Dockerfiles sans aucune validation de bonnes pratiques | Intégrer Hadolint dans `make lint` |

### CATÉGORIE 5 — Tests dynamiques (DAST)

| Outil | Statut | Score | Exécuté dans le pipeline ? | Bloquant ? | Constat principal | Action prioritaire |
|---|---|---|---|---|---|---|
| **OWASP ZAP** | ✅ | 80 % | Oui — CD (API scan) + Recette (baseline) | Oui — High/Critical > 0 | Baseline + API scan, 4 fichiers config, quality gate Groovy + bash, Makefile | Ajouter full scan hebdomadaire |

### CATÉGORIE 6 — Conteneurisation et orchestration

| Outil | Statut | Score | Exécuté dans le pipeline ? | Bloquant ? | Constat principal | Action prioritaire |
|---|---|---|---|---|---|---|
| **Docker** | ✅ | 85 % | Oui — 16 Dockerfiles, builds CI/CD | N/A | Multi-stage, distroless, docker-compose x4, `.dockerignore` | Isoler DinD (Kaniko/Buildah) |
| **Kubernetes** | ✅ | 90 % | Oui — kube-score, Kyverno, pre-flight | Oui — kube-score seuils | Kustomize 4 overlays, 11 NetworkPolicies, zero-trust, PSS Restricted, Audit Policy | Tests conformité CIS K8s |

### CATÉGORIE 7 — CI/CD

| Outil | Statut | Score | Exécuté dans le pipeline ? | Bloquant ? | Constat principal | Action prioritaire |
|---|---|---|---|---|---|---|
| **Jenkins** | ✅ | 85 % | Oui — 3 pipelines (14+18+15 stages) | Oui — quality gate agrégée | Pipelines complets, CASC, shared library, notifications Email+Slack+GitHub | Supprimer montage socket Docker |

### CATÉGORIE 8 — Supply chain (chaîne logistique logicielle)

| Outil | Statut | Score | Exécuté dans le pipeline ? | Bloquant ? | Constat principal | Action prioritaire |
|---|---|---|---|---|---|---|
| **Cosign** | ⚠️ | 65 % | Oui — CD (Sign+Verify+Attest) | Oui | Keyless (Fulcio+Rekor+Keycloak) + clé privée (commitée !), attestation SBOM via Vault | **URGENT** : supprimer `cosign.key` du dépôt |

### CATÉGORIE 9 — Sécurité runtime et admission

| Outil | Statut | Score | Exécuté dans le pipeline ? | Bloquant ? | Constat principal | Action prioritaire |
|---|---|---|---|---|---|---|
| **Kyverno** | ✅ | 90 % | Oui — CI (validate) + CD (pre-flight) | Oui (si CLI présent) | 16 policies (audit+enforce), keyless verify, fixtures, toggle enforce/audit | PolicyReport automatisé en CI |
| **Falco** | ✅ | 80 % | Partiel — validation règles en CI | Non (exit 77 accepté) | 15 règles MITRE ATT&CK, DaemonSet, Falcosidekick, validation via conteneur engine | Déploiement effectif + simulation d'attaque |
| **Gatekeeper** | ❌ | 0 % | Non | — | Zéro occurrence. Compensé par Kyverno (même finalité d'admission control) | Non prioritaire si Kyverno opérationnel |

### CATÉGORIE 10 — Observabilité

| Outil | Statut | Score | Exécuté dans le pipeline ? | Bloquant ? | Constat principal | Action prioritaire |
|---|---|---|---|---|---|---|
| **Prometheus** | ✅ | 80 % | Non — manifests statiques | N/A | Config complète (62 lignes), 18 fichiers d'alertes sécurité, Alertmanager, `observability-up` | Déploiement effectif + ServiceMonitor |
| **Grafana** | ✅ | 80 % | Non — manifests statiques | N/A | 3 datasources, dashboards custom (SLO, K8s audit), PSS Restricted | Déploiement effectif + sidecar provisioning |

---

### Synthèse des scores

```
Trivy         ██████████████████░ 90 %
Kyverno       ██████████████████░ 90 %
Kubernetes    ██████████████████░ 90 %
PHPUnit       █████████████████░░ 85 %
Semgrep       █████████████████░░ 85 %
Docker        █████████████████░░ 85 %
Jenkins       █████████████████░░ 85 %
Gitleaks      ████████████████░░░ 80 %
OWASP ZAP     ████████████████░░░ 80 %
Prometheus    ████████████████░░░ 80 %
Grafana       ████████████████░░░ 80 %
Falco         ████████████████░░░ 80 %
Cosign        █████████████░░░░░░ 65 %
SonarQube     ████████████░░░░░░░ 60 %
Composer Audit███████████░░░░░░░░ 55 %
npm audit     ███████████░░░░░░░░ 55 %
Checkov       ██████████░░░░░░░░░ 50 %
Coverage      ████████░░░░░░░░░░░ 40 %
────────────────────────────────────
Hadolint      ░░░░░░░░░░░░░░░░░░░░  0 %
OWASP DC      ░░░░░░░░░░░░░░░░░░░░  0 %
Gatekeeper    ░░░░░░░░░░░░░░░░░░░░  0 %
────────────────────────────────────
MOYENNE       68 % (outils présents : 76 % hors absents)
```

---

## Niveau global de maturité DevSecOps

### **Avancé** (niveau 3/4)

Le projet SecureRAG Hub implémente la quasi-totalité des pratiques DevSecOps modernes sur l'ensemble du cycle SDLC : SAST, secrets scanning, container scanning, IaC scanning, supply chain security (SBOM + signature + attestation), DAST, runtime security, admission control, observability, et gestion des secrets.

### Note : **7.5 / 10**

---

## Écarts par rapport aux bonnes pratiques DevSecOps

### Écarts critiques (P0)
1. **Clés privées dans le dépôt** — `infra/jenkins/secrets/cosign.key` est commitée et délibérément exclue de Gitleaks (`.gitleaks.toml:19`)
2. **Quality gates désactivées** — `COVERAGE_MIN=0` (couverture jamais bloquante), `RUN_SONAR=false` (analyse Sonar jamais exécutée par défaut)
3. **Checkov non-bloquant** — tous les appels utilisent `|| true`, les vulnérabilités IaC sont détectées mais jamais bloquantes

### Écarts importants (P1)
4. **Credentials hardcodés** — `keycloak-values.yaml:adminPassword="adminpassword"`, `chromadb-auth-config.yaml` contient des tokens en clair
5. **Composer/npm audit non-bloquants** — `audit-dependencies.sh` fait `exit 0` même en cas d'échec
6. **Absence de Hadolint** — 16 Dockerfiles sans linting de bonnes pratiques
7. **Absence d'OWASP Dependency-Check** — pas de scan NVD pour les dépendances (partiellement compensé par Trivy)
8. **Docker socket monté dans Jenkins** — surface d'attaque DinD non isolée

### Écarts modérés (P2)
9. **SonarQube désactivé par défaut** — configuré mais `RUN_SONAR=false` par défaut
10. **Pas de full scan ZAP** — seuls baseline et API scan sont automatisés, pas de full active scan
11. **Trivy config K8s non dédié** — le scan `trivy config` pour les manifests K8s n'est pas isolé
12. **Pas de GitHub Actions** — dépendance exclusive à Jenkins (pas de redondance CI)

---

## Vérification des stages Jenkins

### Jenkinsfile (CI) — 13 stages définis, TOUS exécutent du code réel :

| Stage | Exécution réelle | Code effectif |
|---|---|---|
| Checkout | ✅ Oui | `checkout scm` |
| Prepare Workspace | ✅ Oui | `mkdir`, `chmod` |
| Install CI Dependencies | ✅ Oui | venv + composer + npm |
| CI_LINT | ✅ Oui | `make lint` (bash -n, kustomize, docker compose config) |
| CI_TESTS | ✅ Oui | `run-tests.sh` (php artisan test x5) |
| CI_COVERAGE_GATE | ✅ Oui | `collect-coverage.sh` (mais seuil=0) |
| CI_DEPENDENCIES | ✅ Oui | `audit-dependencies.sh` (non-bloquant) |
| CI_SECURITY_STATIC | ✅ Oui | Semgrep + Gitleaks + Trivy FS |
| CI_TRIVY_FS_QUALITY_GATE | ✅ Oui | Parsing + seuil CRITICAL/HIGH |
| Static Analysis & IaC Scanning | ✅ Oui | Checkov + Trivy IaC |
| CI_K8S_POLICY | ✅ Oui | k8s-hardening + Kyverno + kube-score + Falco |
| CI_QUALITY_GATE | ✅ Oui (conditionnel) | Agrége les signaux |
| CI_SONAR_SCOPE_READY / CI_SONAR_QUALITY_GATE | ⚠️ Conditionnel | Sonar activé uniquement si `RUN_SONAR=true` |

### Jenkinsfile (CD) — 18 stages, tous exécutent du code réel

### Jenkinsfile.recette — 15 stages, tous exécutent du code réel

**Aucun stage vide ou simulé détecté.**

---

## Outils installés mais jamais appelés

| Outil | Preuve d'installation | Appelé dans pipeline ? |
|---|---|---|
| **Syft** (SBOM generation) | Installé dans `infra/jenkins/Dockerfile:78` | ✅ Oui — `scripts/release/generate-sbom.sh` appelé dans CD |
| **Grype** (vuln scanning) | Référencé dans `Jenkinsfile.cd:312` | ✅ Oui — stage "SBOM Analysis — Grype" |
| **Sonar Scanner** | Installé dans `infra/jenkins/Dockerfile:86` | ⚠️ Seulement si `RUN_SONAR=true` |
| **kube-score** | Installé dans `infra/jenkins/Dockerfile:84` | ✅ Oui — `validate-kube-score.sh` |
| **Checkov** | Installé dans `infra/jenkins/Dockerfile:86-88` | ✅ Oui — mais avec `\|\| true` |
| **Falco** (CLI) | Pas installé, validation via conteneur | ✅ Oui — `validate-falco-rules.sh` |

---

## Outils appelés mais résultats non exploités

| Outil | Résultat produit | Exploité ? |
|---|---|---|
| **Checkov** | `checkov-*.xml` (JUnit) | ❌ Archivé mais jamais analysé dans une quality gate |
| **Composer audit** | `composer-audit-*.json` | ❌ Archivé mais jamais parsé ; non-bloquant |
| **npm audit** | `npm-audit-*.json` | ❌ Archivé mais jamais parsé ; non-bloquant |
| **Sonar Scanner** (quand exécuté) | `sonar-analysis.md`, `sonar-quality-gate.json` | ⚠️ Parsé dans quality-gate.sh mais uniquement si `RUN_SONAR=true` |

---

## Configurations incomplètes ou désactivées

| Configuration | État | Détail |
|---|---|---|
| `COVERAGE_MIN=0` | Désactivée de facto | Seuil à 0% = jamais bloquant |
| `RUN_SONAR=false` | Désactivée par défaut | SonarQube jamais exécuté en CI standard |
| `ENFORCE_QUALITY_GATE=true` | Activée | Mais les signaux entrants sont affaiblis (coverage=0, checkov non-bloquant) |
| `REQUIRE_KYVERNO_CLI=false` | Non-bloquant par défaut | Absence de Kyverno CLI ne bloque pas |
| `SKIP_FALCO_DOCKER=true` (recette) | Désactivé en recette | Validation Falco sautée si Docker absent |
| `.gitleaks.toml:infra/jenkins/secrets/` | Allowlist trop large | Secrets légitimes ignorés |
| `zap-baseline.yaml` (recette) | Fichier non monté | Le `-autorun` référence un chemin dans le conteneur sans montage explicite |

---

## Quality Gates — bloquent-elles réellement ?

| Quality Gate | Emplacement | Bloquante ? | Condition de blocage |
|---|---|---|---|
| Trivy FS | `Jenkinsfile:228-298` | ✅ Oui | CRITICAL > 0 OU HIGH > 3 → `error()` |
| Trivy Image | `Jenkinsfile.cd:100-181` | ✅ Oui | CRITICAL > 0 OU HIGH > 3 → `error()` |
| Quality Gate agrégée | `scripts/ci/quality-gate.sh` | ✅ Oui | Tout check `required=true` en FAIL → exit 1 |
| Coverage Gate | `Jenkinsfile:136-151` | ❌ Non | `COVERAGE_MIN=0` → jamais déclenchée |
| Sonar Quality Gate | `scripts/ci/run-sonar-analysis.sh` | ⚠️ Conditionnelle | Seulement si `RUN_SONAR=true` et `SONAR_QUALITY_GATE_WAIT=true` |
| kube-score | `scripts/ci/validate-kube-score.sh` | ✅ Oui | CRITICAL > seuil OU WARNING > seuil → exit 1 |
| Kyverno static | `scripts/ci/validate-kyverno-policies.sh` | ⚠️ Conditionnelle | Seulement si `REQUIRE_KYVERNO_CLI=true` |
| Falco rules | `scripts/ci/validate-falco-rules.sh` | ✅ Oui | Exit 1 si règles invalides (exit 77 = skip accepté) |
| ZAP DAST | `parse-zap-report.groovy` / `zap-quality-gate.sh` | ✅ Oui | High/Critical > 0 → `error()` |
| Grype SBOM | `Jenkinsfile.cd:302-326` | ✅ Oui | `--fail-on high,critical` → exit 1 |
| Checkov | `Jenkinsfile:307-313` | ❌ Non | `\|\| true` systématique |
| Composer Audit | `scripts/ci/audit-dependencies.sh` | ❌ Non | `exit 0` systématique |
| npm Audit | `scripts/ci/audit-dependencies.sh` | ❌ Non | `exit 0` systématique |

---

## Classification détaillée des contrôles de sécurité

| Contrôle | Réellement appliqué | Uniquement configuré | Présent mais désactivé | Absent |
|---|---|---|---|---|
| **SAST (Semgrep)** | ✅ | — | — | — |
| **Secret scanning (Gitleaks)** | ✅ (mais allowlist) | — | — | — |
| **FS Vulnerability (Trivy)** | ✅ | — | — | — |
| **Image Scanning (Trivy)** | ✅ | — | — | — |
| **IaC Scanning (Checkov)** | — | — | ✅ (non-bloquant) | — |
| **SonarQube SAST** | — | — | ✅ (RUN_SONAR=false) | — |
| **Coverage enforcement** | — | — | ✅ (COVERAGE_MIN=0) | — |
| **Dependency audit (Composer)** | — | — | ✅ (non-bloquant) | — |
| **Dependency audit (npm)** | — | — | ✅ (non-bloquant) | — |
| **DAST (ZAP)** | ✅ | — | — | — |
| **Supply chain (Cosign)** | ✅ | — | — | — |
| **SBOM (Syft + Grype)** | ✅ | — | — | — |
| **K8s admission (Kyverno)** | ✅ | — | — | — |
| **Runtime detection (Falco)** | — | ✅ | — | — |
| **Docker linting (Hadolint)** | — | — | — | ❌ |
| **OWASP Dependency-Check** | — | — | — | ❌ |
| **Gatekeeper** | — | — | — | ❌ (compensé Kyverno) |
| **Network policies** | ✅ (11 polices) | — | — | — |
| **Secret management (SOPS/Vault)** | ✅ (SOPS) | ✅ (Vault configuré) | — | — |

---

## Plan d'amélioration priorisé

### P0 — Immédiat (sécurité critique)

| Action | Effort | Impact |
|---|---|---|
| 1. Supprimer `cosign.key` et `cosign.password` du dépôt, révoquer la clé, utiliser EXCLUSIVEMENT le flux keyless (Fulcio + Rekor) | 1h | Suppression d'une fuite de clé privée |
| 2. Mettre `COVERAGE_MIN=70` et s'assurer que les tests couvrent au moins ce seuil | 2h | Réactivation de la quality gate coverage |
| 3. Supprimer `\|\| true` des appels Checkov, ajouter un seuil tolérable (ex: max 0 failures HIGH) | 1h | Checkov devient bloquant |
| 4. Rendre `composer audit` et `npm audit` bloquants avec seuils (ex: max 0 CRITICAL) | 1h | Audit dépendances devient bloquant |
| 5. Activer `RUN_SONAR=true` par défaut OU documenter pourquoi il est désactivé | 30min | SAST avancé activé |

### P1 — Court terme (1-2 semaines)

| Action | Effort | Impact |
|---|---|---|
| 6. Intégrer Hadolint dans le pipeline CI pour les 16 Dockerfiles | 2h | Linting Dockerfile automatisé |
| 7. Intégrer OWASP Dependency-Check ou migrer `npm audit` vers `npm audit signatures` | 3h | Scan NVD dédié |
| 8. Hardcoder les credentials Keycloak/ChromaDB en variables d'environnement ou secrets K8s | 2h | Suppression des secrets en clair |
| 9. Ajouter un stage full scan ZAP (actif) hebdomadaire | 3h | DAST approfondi |
| 10. Ajouter un scan `trivy config` dédié pour les manifests K8s | 1h | Séparation vulnérabilités vs misconfigurations |

### P2 — Moyen terme (1 mois)

| Action | Effort | Impact |
|---|---|---|
| 11. Remplacer le montage socket Docker par Kaniko ou Buildah dans Jenkins | 4h | Isolation du build |
| 12. Déployer effectivement Falco et vérifier les alertes remontées | 4h | Runtime security active |
| 13. Déployer Prometheus + Grafana et valider les dashboards | 3h | Observabilité effective |
| 14. Ajouter des tests d'intégration Kyverno (apply + audit sur cluster éphémère) | 4h | Validation runtime des politiques |
| 15. Documenter les CVE supprimées dans `.trivyignore` avec justification et date de revue | 1h | Traçabilité des exceptions |
| 16. Ajouter GitHub Actions en redondance du pipeline Jenkins | 6h | Résilience CI |
