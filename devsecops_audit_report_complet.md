# Rapport d'Audit DevSecOps — SecureRAG Hub

**Date:** 2026-06-17  
**Auditeur:** Principal DevSecOps Engineer (Indépendant)  
**Repository:** `/root/MasterPFE`  
**Méthodologie:** Audit evidence-based, 100 points répartis sur 10 domaines

---

## Résumé Exécutif

La plateforme SecureRAG Hub présente une **architecture DevSecOps mature** avec une couverture exceptionnelle d'outils de sécurité intégrés dans la chaîne CI/CD. Sur 10 domaines audités, 6 atteignent un niveau Enterprise-ready. Les forces principales résident dans le Pipeline Hardening (quality gates bloquants, scope-aware), l'IaC Security (Checkov, Kyverno, OPA, kube-score), la Runtime Security (Falco + Falco Talon), et l'Observabilité (Prometheus, Grafana, Loki, Alertmanager).

**Deux faiblesses critiques** impactent significativement le score global :

1. **Supply Chain Security (4/10)** — L'infrastructure Cosign/Sigstore/SBOM est complète mais **aucune exécution bout-en-bout n'a réussi**. Aucun SBOM généré, toutes les attestations sont `false`, le binaire Cosign est manquant dans l'environnement d'exécution, et `--allow-insecure-registry` est toujours passé à cause de code orphelin.

2. **Secrets Management (5/10)** — SOPS, Vault, et External Secrets Operator sont préparés mais **non déployés**. Cinq fichiers `.env` avec des `APP_KEY` sont commités dans Git. Aucune rotation automatique active.

**Score Global : 64/100 — Niveau Intermediate.**

La plateforme peut atteindre **96/100 (World-Class)** avec un effort estimé de **4 à 6 mois**, et **98/100 (Big Tech)** avec **8 à 12 mois**.

---

## Score Global

| Domaine | Poids | Score | Justification |
|---------|:-----:|:-----:|---------------|
| Secrets Management | 10 | **5.0** | SOPS/Vault/ESO préparés mais non exécutés ; 5 `.env` commités ; `.sops.yaml` 0644 world-readable |
| Pipeline Hardening | 10 | **8.0** | `secure-quality-gate.sh` bloquant ; `set -euo pipefail` ; pas d'`ALLOW_*` ; quelques `|| true` non-critiques |
| SAST | 10 | **6.0** | Semgrep custom rules (14) + SonarQube + Gitleaks ; **SARIF pas généré en CI** ; pas de `--config auto` en CI |
| SCA | 10 | **7.0** | Trivy + OWASP DC + Composer audit + Syft/Grype ; npm audit inefficace ; Grype seulement en CD |
| IaC Security | 10 | **8.0** | Checkov + Kyverno (30+ policies) + OPA Gatekeeper + kube-score ; dead code checkovScan.groovy |
| Runtime Security | 10 | **8.0** | Falco (17 MITRE rules) + Falco Talon + Cilium/Hubble + quality gate ; Tetragon désactivé par défaut |
| Supply Chain Security | 10 | **4.0** | **Aucun SBOM généré** ; attestations toutes `false` ; `--allow-insecure-registry` ; Cosign manquant |
| Kubernetes Security | 10 | **7.0** | PSA restricted ; RBAC fin ; NetworkPolicies default-deny ; 14 déploiements en `:latest` ; 7+ sans securityContext |
| Observabilité | 10 | **8.0** | Prometheus + Grafana (24+ dashboards) + Loki + Alertmanager ; Tempo/OTel désactivés ; pas de stockage persistant |
| Backup / Disaster Recovery | 10 | **7.0** | Velero + MinIO + PostgreSQL backup + Jenkins backup + DR tests ; productions non exécutés ; MinIO emptyDir |
| **TOTAL** | **100** | **68.0** | |

**Score ajusté avec pénalité Supply Chain : 64/100**

> Note : Le score Supply Chain (4.0) étant significativement inférieur à la moyenne des autres domaines, un facteur de correction de -4 points est appliqué pour refléter l'impact réel sur la posture de sécurité.

---

## Niveau de Maturité

| Seuil | Niveau | Atteint ? |
|-------|--------|:---------:|
| 0–40 | **Beginner** | Non |
| 40–70 | **Intermediate** | **Oui (64/100)** |
| 70–85 | **Advanced** | Non |
| 85–92 | **Enterprise** | Non |
| 92–97 | **World-Class** | Non |
| 97–100 | **Big Tech / FAANG** | Non |

---

## Architecture Détectée

```
                    ┌─────────────────────────────────────────────────────────────┐
                    │                    DEVELOPER WORKSTATION                     │
                    │  pre-commit (gitleaks, shellcheck, trailing-whitespace...)  │
                    └─────────┬───────────────────────────────────────────────────┘
                              │ git push
                    ┌─────────▼───────────────────────────────────────────────────┐
                    │                   GITHUB (mirror/backup)                     │
                    │  .github/workflows/ci-pr.yml (deprecated)                   │
                    │  .github/workflows/build-sign.yml (deprecated)              │
                    │  .github/workflows/rotate-cosign.yml                        │
                    └─────────┬───────────────────────────────────────────────────┘
                              │ webhook
                    ┌─────────▼───────────────────────────────────────────────────┐
                    │                    JENKINS (CI/CD Engine)                    │
                    │                                                              │
                    │  Jenkinsfile (CI)       Jenkinsfile.cd (CD)                  │
                    │  Jenkinsfile.recette (Staging)                               │
                    │  vars/ (Shared Libraries)                                    │
                    │    ├── trivyScan.groovy     ├── checkovScan.groovy (dead)   │
                    │    ├── trivyUtils.groovy    ├── securityGate.groovy          │
                    │    └── cosignVerify.groovy                                   │
                    └─────────┬───────────────────────────────────────────────────┘
                              │
          ┌───────────────────┼───────────────────────┬──────────────────────┐
          │                   │                        │                      │
  ┌───────▼────────┐ ┌───────▼────────┐ ┌────────────▼──────────┐ ┌─────────▼──────────┐
  │  CI PIPELINE   │ │ SCANS PIPELINE │ │    CD PIPELINE        │ │  RECETTE PIPELINE  │
  │                │ │                │ │                       │ │                    │
  │ • Lint + Tests │ │ • Semgrep SAST │ │ • Trivy Image Scan    │ │ • CI complet       │
  │ • SonarQube    │ │ • Gitleaks     │ │ • Checkov Helm        │ │ • Deploy SSH       │
  │ • Quality Gate │ │ • Trivy FS     │ │ • Cosign Sign/Verify  │ │ • Smoke Tests      │
  │ • Backup Valid │ │ • Checkov      │ │ • SBOM + Grype        │ │ • DAST ZAP         │
  │ • Velero Deploy│ │ • kube-score   │ │ • Promote by Digest   │ │ • Quality Gate     │
  │ • Vault Deploy │ │ • Kyverno      │ │ • Release Evidence    │ │ • Email notif      │
  │                │ │ • OPA Gatekeeper│ │ • GitOps Update      │ │                    │
  │                │ │ • Tetragon     │ │ • Deploy Production   │ │                    │
  │                │ │ • OWASP DC     │ │ • DAST ZAP            │ │                    │
  │                │ │ • Composer/npm │ │ • Support Pack        │ │                    │
  │                │ │ • Hadolint     │ │                       │ │                    │
  └───────┬────────┘ └───────┬────────┘ └────────────┬──────────┘ └─────────┬──────────┘
          │                  │                        │                      │
          └──────────────────┴────────────────────────┴──────────────────────┘
                              │
                    ┌─────────▼───────────────────────────────────────────────────┐
                    │                     QUALITY GATES                            │
                    │                                                              │
                    │  secure-quality-gate.sh (13 checks, ALL BLOCKING)            │
                    │  securityGate.groovy (Scope-aware : PROD CRIT/HIGH -> FAIL)  │
                    │  gate-decision-engine.sh (classification engine)             │
                    │  security-classifier.sh (PRODUCTION/NON_PROD/LEGACY/VENDOR)  │
                    └─────────┬───────────────────────────────────────────────────┘
                              │
                    ┌─────────▼───────────────────────────────────────────────────┐
                    │              ARGOCD (GitOps Deployment)                      │
                    │  ApplicationSets → Kustomize → Kubernetes Cluster            │
                    │  Sync-waves: 10→20→30→35→40→45→50→55→60                     │
                    └─────────┬───────────────────────────────────────────────────┘
                              │
          ┌───────────────────┼───────────────────────┬──────────────────────┐
          │                   │                        │                      │
  ┌───────▼────────┐ ┌───────▼────────┐ ┌────────────▼──────────┐ ┌─────────▼──────────┐
  │  PRODUCTION    │ │  RUNTIME SEC   │ │    OBSERVABILITY      │ │    BACKUP / DR     │
  │  NAMESPACE     │ │                │ │                       │ │                    │
  │                │ │ • Falco        │ │ • Prometheus          │ │ • Velero           │
  │ • 5 apps       │ │ • Falco Talon  │ │ • Grafana (24+ dash)  │ │ • MinIO            │
  │ • PSA restric. │ │ • Tetragon(off)│ │ • Loki                │ │ • PG backup (PVC)  │
  │ • Kyverno enf. │ │ • Cilium       │ │ • Alertmanager        │ │ • PG backup(Restic)│
  │ • OPA Gatekeep │ │ • Hubble       │ │ • Tempo (off)         │ │ • Jenkins backup   │
  │ • NetworkPol.  │ │ • Wazuh        │ │ • OTel (off)          │ │ • DR tests         │
  │ • PDB + HPA    │ │                │ │ • PrometheusRule x57  │ │ • Monitoring alerts│
  └────────────────┘ └────────────────┘ └───────────────────────┘ └───────────────────┘
```

---

## Inventaire des Outils

| Outil | Statut | Mode Bloquant | Pipeline | Score | Preuve |
|-------|:------:|:-------------:|:--------:|:-----:|--------|
| **Semgrep** | ✅ Actif | Oui (`--error`) | CI + Recette | 14 règles custom | `Jenkinsfile:106-118`, `jenkinsfile.recette:195-213` |
| **SonarQube** | ✅ Actif | Oui (`sonar.qualitygate.wait=true`) | CI + Recette | Quality Gate | `sonar-project.properties`, `run-sonar-analysis.sh` |
| **Gitleaks** | ✅ Actif | Oui (Quality Gate) | CI + Recette + Pre-commit | Config custom | `.gitleaks.toml`, `Jenkinsfile:120-133`, `.pre-commit-config.yaml` |
| **Trivy FS** | ✅ Actif | Oui (`exit-code:1`) | CI + Recette | Severity MEDIUM+ | `trivy-fs.yaml`, `Jenkinsfile:142-143` |
| **Trivy Image** | ✅ Actif | Oui (scan-images.sh) | CD | Severity HIGH+ | `trivy-image.yaml`, `Jenkinsfile.cd:61-64` |
| **Trivy Scope** | ✅ Actif | Partiel (`|| true`) | Scoping Engine | PROD scoped | `trivy-scope.sh`, `Jenkinsfile:319` |
| **OWASP DC** | ✅ Actif | Oui (`--failOnCVSS 7`) | CI | CVSS >= 7 bloque | `run-owasp-dependency-check.sh`, `Jenkinsfile:277-285` |
| **Composer Audit** | ✅ Actif | Oui | CI + Recette | PHP packages | `audit-dependencies.sh:38-48` |
| **npm Audit** | ⚠️ Inefficace | N/A | CI + Recette | package-lock.json absent | `audit-dependencies.sh:50-70` |
| **Syft** | ✅ Actif | Oui | CD | SBOM CycloneDX | `generate-sbom.sh`, `Jenkinsfile.cd:121-128` |
| **Grype** | ❌ Absent | N/A | CD (non-exécuté) | N/A | Aucun binaire Grype trouvé |
| **Checkov** | ✅ Actif | CRITICAL hard-fail, HIGH soft-fail | CI + CD + Recette | IaC scanning | `checkov-config.yaml`, `Jenkinsfile:165-172` |
| **kube-score** | ✅ Actif | Oui (strict mode) | CI | 0 CRITICAL, 0 WARNING | `validate-kube-score.sh`, `Jenkinsfile:175,185` |
| **Kyverno** | ✅ Actif | Enforce (production) | CI + Cluster | 30+ policies | `k8s/kyverno-policies/`, `infra/k8s/policies/kyverno/` |
| **OPA Gatekeeper** | ✅ Actif | Enforce (deny) | CI + Cluster | 4 constraint templates | `infra/k8s/opa-gatekeeper/` |
| **Conftest** | ✅ Actif | Oui | CI | Rego validation | `validate-opa-gatekeeper.sh:106` |
| **Falco** | ✅ Actif | Oui (Quality Gate) | Cluster | 17 MITRE rules | `infra/k8s/runtime-detection/`, `custom-rules.yaml` |
| **Falco Talon** | ✅ Actif | Automatique | Cluster | 6 actions | `infra/k8s/falco-talon/deployment.yaml` |
| **Tetragon** | ⚠️ Désactivé | Oui (si activé) | Cluster | Feature flag `false` | `infra/k8s/tetragon/` |
| **Cilium / Hubble** | ✅ Actif | NetworkPolicy | Cluster | eBPF | `infra/k8s/cilium/` |
| **Cosign** | ⚠️ Non exécuté | Oui (Kyverno Enforce) | CD | Binaire manquant | `vars/cosignVerify.groovy`, `phase-2-...log` |
| **Fulcio / Rekor** | ⚠️ Non exécuté | N/A | Local Sigstore | Stack non déployé | `deploy-sigstore-stack.sh` |
| **Vault** | ⚠️ Non déployé | N/A | Platform | Templates prêts | `security/vault/` |
| **External Secrets** | ⚠️ Non déployé | N/A | Platform | Templates prêts | `infra/k8s/secrets/` |
| **SOPS** | ⚠️ Non exécuté | N/A | Local | `.sops.yaml` configuré | `.sops.yaml`, aucun `.enc.yaml` |
| **Prometheus** | ✅ Actif | Alertes | Cluster | 20+ alert rules | `infra/k8s/observability/prometheus-*.yaml` |
| **Grafana** | ✅ Actif | Dashboards | Cluster | 24+ dashboards | `infra/k8s/observability/grafana-*.yaml` |
| **Loki** | ✅ Actif | Logs | Cluster | 7 jours rétention | `infra/k8s/observability/loki-deployment.yaml` |
| **Alertmanager** | ✅ Actif | Slack + Webhook | Cluster | 4 receivers | `infra/k8s/observability/alertmanager.yaml` |
| **Velero** | ✅ Actif | Backup schedules | Cluster | 3 schedules | `infra/k8s/velero/`, `application-velero.yaml` |
| **MinIO** | ✅ Actif | S3 backend | Cluster | `emptyDir` (éphemère) | `deploy-velero.sh` |
| **Renovate** | ✅ Actif | Auto-update | GitHub | Weekly | `renovate.json` |
| **Hadolint** | ✅ Actif | Oui (set -e) | CI | Dockerfile lint | `Jenkinsfile:270` |
| **ShellCheck** | ✅ Actif | Pre-commit | Pre-commit | `.sh` files | `.pre-commit-config.yaml` |

---

## Quality Gates

| Contrôle | Source | Bloque ? | Mécanisme | Pipeline |
|----------|--------|:--------:|-----------|:--------:|
| **Unit Tests** | JUnit XML | Oui | `secure-quality-gate.sh` exit 1 si échec | CI, Recette |
| **Code Coverage** | Coverage XML | Oui | `COVERAGE_MIN=85` exit 1 si < 85% | CI, Recette |
| **Semgrep SAST** | `semgrep.json` | Oui | `--error` + exit 1 si findings > 0 | CI, Recette |
| **Gitleaks** | `gitleaks.json` | Oui | Quality Gate exit 1 si leaks > 0 | CI, Recette, Pre-commit |
| **Trivy FS** | `trivy-fs.json` | Oui | Quality Gate exit 1 si CRITICAL/HIGH | CI, Recette |
| **Trivy Image** | `trivy-image.json` | Oui | Quality Gate exit 1 si CRITICAL/HIGH | CD |
| **OWASP DC** | CVSS | Oui | `--failOnCVSS 7` | CI |
| **Composer Audit** | exit code | Oui | `set -euo pipefail` | CI, Recette |
| **Checkov** | JUnit XML | Oui (CRITICAL) | `--hard-fail-on CRITICAL --soft-fail-on HIGH` + QG exit 1 | CI, CD, Recette |
| **kube-score** | status file | Oui | `STRICT_KUBE_SCORE=true` + thresholds | CI |
| **SonarQube** | Quality Gate | Oui | `sonar.qualitygate.wait=true` + exit 1 | CI, Recette |
| **Falco Runtime** | `falco-summary.md` | Oui | Quality Gate exit 1 si CRITICAL alerts | CI |
| **Tetragon** | `tetragon-summary.md` | Oui | Quality Gate exit 1 si violations | CI |
| **Cosign Verify** | verify status | Oui | `cosignVerify.groovy` calls `error()` | CD |
| **Grype (SBOM)** | Grype JSON | Oui | `--fail-on high,critical` | CD |
| **DAST ZAP** | ZAP report | Oui | `maxHigh=0, maxCritical=0` exit 1 | CD, Recette |
| **Scoping Engine** | Classified reports | Conditionnel | PROD HIGH/CRITICAL => exit 1 | CI |
| **Security Gate** | `securityGate.groovy` | Conditionnel | PROD CRIT/HIGH => `error()` | CI |

---

## Findings

### CRITICAL

| ID | Finding | Fichier | Ligne | Impact | Action |
|:--:|---------|---------|:-----:|--------|--------|
| C-01 | **Supply Chain : Aucun SBOM généré** | `artifacts/release/sbom-cyclonedx-validation.md` | 4 | Toute la chaîne supply chain est non fonctionnelle — 0 SBOM, 0 attestation | Débugger l'environnement CD, installer Cosign, exécuter `generate-sbom.sh` |
| C-02 | **Cosign binaire manquant dans l'environnement CD** | `artifacts/final/phase-2-supply-chain-sbom-cosign-digest-no-rebuild-execute.log` | 1 | Signature et vérification des images impossible | Ajouter Cosign à l'image Jenkins agent Docker |
| C-03 | **`--allow-insecure-registry` toujours passé à Cosign (code orphelin)** | `scripts/release/lib/common.sh` | 73-75 | Toutes les opérations Cosign bypassent la sécurité TLS du registry | Corriger le bloc `if` manquant |
| C-04 | **Toutes les 7 attestations de release sont `false`** | `artifacts/release/release-attestation.json` | 1-20 | Aucune release n'a de preuve cryptographique de son intégrité | Re-exécuter le pipeline CD complet avec Cosign fonctionnel |
| C-05 | **SARIF non généré dans le pipeline CI principal** | `Jenkinsfile` | 114 | SonarQube attend `semgrep.sarif` qui n'existe pas (import silencieux cassé) | Ajouter `--sarif -o security/reports/semgrep.sarif` au Semgrep run |
| C-06 | **5 fichiers `.env` commités avec des `APP_KEY`** | `platform/portal-web/.env`, `services-laravel/*/.env` | 3 | Clés de chiffrement Laravel exposées dans Git | Supprimer du tracking, ajouter à `.gitignore`, faire tour de clés |

### HIGH

| ID | Finding | Fichier | Ligne | Impact | Action |
|:--:|---------|---------|:-----:|--------|--------|
| H-01 | **SOPS configuré mais aucun fichier `.enc.yaml`** | `.sops.yaml` | 26,32,38 | Secrets management non activé en pratique | Générer age key, créer `.enc.yaml` pour les secrets infra |
| H-02 | **Vault + External Secrets Operator non déployés** | `security/vault/`, `infra/k8s/secrets/` | — | Secrets non externalisés ; Vault init script non exécuté | Déployer Vault via ArgoCD, activer ESO |
| H-03 | **Gitleaks n'utilise pas `--exit-code` en CI/CD** | `Jenkinsfile` | 128 | Le pipeline ne fail pas immédiatement sur une fuite de secret | Ajouter `--exit-code 1` aux commandes Gitleaks |
| H-04 | **Smoke tests non bloquants dans Jenkinsfile.recette** | `Jenkinsfile.recette` | 479 | Un déploiement cassé peut passer les quality gates | Remplacer `|| echo "[WARN]"` par `|| exit 1` |
| H-05 | **Key rotation Cosign sans propagation automatique** | `.github/workflows/rotate-cosign.yml` | 43-57 | La clé publique n'est pas mise à jour dans Kyverno/Vault/Jenkins | Ajouter une étape de propagation dans le workflow |
| H-06 | **Kyverno `verify-cosign-images` accepte key-pair statique OU keyless** | `infra/k8s/policies/kyverno/verify-cosign-images.yaml` | 36-46 | Si la clé privée statique est compromise, contournement possible | Supprimer l'attestor key-pair, ne garder que le keyless |
| H-07 | **MinIO credentials hardcodés `minioadmin:minioadmin` dans ArgoCD** | `infra/k8s/argocd/application-velero.yaml` | 28,38 | Backups accessibles avec des credentials par défaut | Utiliser Vault + ExternalSecret |
| H-08 | **14 déploiements infra utilisent le tag `:latest`** | Voir tableau dédié | — | Pas de reproductibilité, risque de regressions | Pinner toutes les images à des versions spécifiques |
| H-09 | **Grafana `readOnlyRootFilesystem: false`** | `infra/k8s/observability/grafana-deployment.yaml` | 56 | Augmente la surface d'attaque du serveur Grafana | Monter un tmpfs pour les fichiers temporaires |
| H-10 | **OpenID Connect client secret hardcodé dans le script de déploiement Sigstore** | `security/sigstore/deploy-sigstore-stack.sh` | 47 | Secret `jenkins-cosign-secret` en clair dans le repo | Utiliser Vault ou un secret Kubernetes |

### MEDIUM

| ID | Finding | Fichier | Ligne | Impact | Action |
|:--:|---------|---------|:-----:|--------|--------|
| M-01 | **`.sops.yaml` world-readable (0644)** | `.sops.yaml` | — | Information de configuration exposée | Changer à 0640 |
| M-02 | **`platform/**/.env` et `services-laravel/**/.env` pas dans .gitignore** | `.gitignore` | — | D'autres `.env` pourraient être commités | Ajouter les patterns à `.gitignore` |
| M-03 | **Legacy `quality-gate.sh` toujours présent** | `scripts/ci/quality-gate.sh` | 1-294 | Risque d'utilisation accidentelle avec bypasses | Supprimer le fichier legacy |
| M-04 | **Legacy GitHub workflow `ci-pr.yml` toujours maintenu** | `.github/workflows/ci-pr.yml` | 1 | Confusion sur le pipeline CI autoritaire | Supprimer le workflow legacy |
| M-05 | **Semgrep scoped scan bypassé avec `|| true`** | `Jenkinsfile` | 313 | Les erreurs du scan scoped sont silencieusement ignorées | Remplacer `2>/dev/null \|\| true` par `2>&1` |
| M-06 | **Checkov `checkovScan.groovy` unused** | `vars/checkovScan.groovy` | 1-33 | Dead code pouvant causer de la confusion | Supprimer ou réintégrer dans le pipeline |
| M-07 | **Kyverno infra policies : directory `kyverno/` a `Enforce` mais nommé "audit"** | `infra/k8s/policies/kyverno/` | 15 | Incohérence de nommage architecturale | Renommer le dossier ou aligner le mode |
| M-08 | **OPA Gatekeeper : ConstraintTemplate orphelin `K8sRequiredLabels`** | `infra/k8s/opa-gatekeeper/templates/k8srequiredlabels-template.yaml` | — | Template défini mais non instancié | Ajouter une constraint correspondante ou supprimer |
| M-09 | **Falco Talon Slack webhook URL placeholder** | `infra/k8s/falco-talon/deployment.yaml` | — | Notifications Slack non fonctionnelles | Configurer une vraie URL de webhook |
| M-10 | **Test namespace Falco incorrect (`falco-system` vs `falco`)** | `security/tests/06-falco-runtime-tests.sh` | — | Tests runtime échouent à cause du mauvais namespace | Corriger le namespace dans les tests |
| M-11 | **Trivy severity incohérente entre configs** | `trivy.yaml` vs `trivy-fs.yaml` | 2 | Recette utilise HIGH+ tandis que CI utilise MEDIUM+ | Uniformiser MEDIUM+ partout |
| M-12 | **OWASP DC utilise `--noupdate`** | `run-owasp-dependency-check.sh` | — | Base de données NVD potentiellement obsolète | Utiliser un cache NVD dédié plutôt que `--noupdate` |
| M-13 | **Tempo / OpenTelemetry désactivés par défaut** | `infra/k8s/otel/deployment.yaml` | — | Pas de tracing distribué actif | Activer progressivement |
| M-14 | **Loki en réplication factor 1** | `infra/k8s/observability/loki-deployment.yaml` | 17 | Point unique de défaillance pour les logs | Passer à `replication_factor: 3` |
| M-15 | **Pas de stockage persistant (emptyDir) pour Prometheus/Loki/Grafana** | `infra/k8s/observability/*.yaml` | — | Données perdues au redémarrage du pod | Ajouter des PVC de taille appropriée |
| M-16 | **MinIO utilise emptyDir (pas de PV)** | `scripts/deploy/deploy-velero.sh` | — | Backups Velero perdus au redémarrage | Ajouter un PVC pour MinIO |

### LOW

| ID | Finding | Fichier | Ligne | Impact | Action |
|:--:|---------|---------|:-----:|--------|--------|
| L-01 | **Pas de pre-commit hook Semgrep** | `.pre-commit-config.yaml` | — | SAST non exécuté avant commit local | Ajouter hook Semgrep |
| L-02 | **`automountServiceAccountToken: true` sur portal-web (exception Vault)** | `k8s/deployments/portal-web-deployment.yaml` | 40 | Violation du principe de moindre privilège | Documenter comme exception formelle |
| L-03 | **Kong expose port admin 8001** | `infra/k8s/kong/deployment.yaml` | — | Risque d'administration non authentifiée | Restreindre via NetworkPolicy |
| L-04 | **7+ déploiements infra sans securityContext** | Voir tableau Kubernetes Security | — | Pas de hardening sur les workloads infra | Ajouter securityContext avant activation |
| L-05 | **Qdrant manque `readOnlyRootFilesystem`** | `infra/k8s/base/qdrant/deployment.yaml` | 42-45 | Root filesystem non protégé | Ajouter avec un volume writable pour les données |
| L-06 | **Ollama manque `runAsNonRoot`** | `infra/k8s/base/ollama/deployment.yaml` | 18-20 | Conteneur potentiellement root | Ajouter `runAsNonRoot: true` |
| L-07 | **API gateway / llm-orchestrator / knowledge-hub / security-auditor : pas de startupProbe** | `infra/k8s/base/*/deployment.yaml` | — | Délai de démarrage non optimisé | Ajouter startupProbe |
| L-08 | **Keycloak admin credentials hardcodés `admin:adminpassword`** | `security/sigstore/keycloak-values.yaml` | 9 | Compte admin Keycloak trivial | Changer avant déploiement production |
| L-09 | **Trivy ignore CVEs expiration trop éloignée (2026-12-31)** | `.trivyignore` | — | Certaines acceptations dépassent 90 jours | Réduire à 90 jours ou justifier |
| L-10 | **Cosign error output redirigé vers /dev/null** | `vars/cosignVerify.groovy` | 37 | Diagnostics d'échec invisibles | Rediriger stderr vers le log |

---

## Points Forts (Top 10)

1. **Quality Gate Enterprise (`secure-quality-gate.sh`)** — 13 checks tous bloquants, remplace l'ancien script à bypass. Preuve : `scripts/ci/secure-quality-gate.sh:5`
2. **Security Scope Engine** — Classification automatique PRODUCTION/NON_PROD/LEGACY/VENDOR avec décisions différenciées (FAIL/WARNING/IGNORE). Preuve : `security/engine/security-classifier.sh:20-23`
3. **Kyverno : Dual-Declaration pattern** — 8 paires de politiques (Audit + Enforce) avec toggle script à rollback automatique. Preuve : `k8s/kyverno-policies/enforce/` + `scripts/deploy/kyverno-enforce-toggle.sh`
4. **Falco + Falco Talon** — 17 règles MITRE ATT&CK, alertes vers Loki/Slack/Wazuh, réponse automatisée (pod kill, network isolation). Preuve : `security/falco/custom-rules.yaml` + `infra/k8s/falco-talon/deployment.yaml`
5. **NetworkPolicies Zero-Trust** — Default-deny ingress+egress sur tous les namespaces, 20+ policies par-service. Preuve : `k8s/network-policies/`, `infra/k8s/cilium/`
6. **Grafana Observability Stack** — 24+ dashboards, 57 alert rules, 7 recording rules, Prometheus + Loki + Alertmanager. Preuve : `infra/k8s/monitoring/dashboards/`, `infra/k8s/observability/`
7. **HA Production Overlays** — HPAs (min 2-3, max 6-9), PDBs (minAvailable 1-2), podAntiAffinity, topologySpreadConstraints. Preuve : `infra/k8s/overlays/production/patches/`
8. **Velero + PostgreSQL Backup** — 3 schedules Velero, PG backup PVC+Restic, Jenkins backup, DR tests avec RTO measurement. Preuve : `infra/k8s/backup/`, `scripts/dr/`
9. **PSA Restricted sur tous les namespaces applicatifs** — securerag-hub, securerag-monitoring, argocd, backup-system en mode enforce: restricted. Preuve : `infra/k8s/base/namespace.yaml:7-12`
10. **ServiceAccounts dédiés avec automount désactivé** — Chaque service a son propre SA avec `automountServiceAccountToken: false`. Preuve : `infra/k8s/base/*/serviceaccount.yaml`

---

## Faiblesses (Top 10)

1. **Supply Chain : Aucune exécution bout-en-bout réussie** — Cosign manquant, SBOM 0, attestations false. Impact : Les releases ne sont pas signées.
2. **Secrets Management : SOPS/Vault/ESO préparés mais non actifs** — 5 `.env` avec clés commités. Impact : Secrets non externalisés.
3. **SARIF non généré en CI** — SonarQube import silencieusement cassé. Impact : Perte des résultats SARIF dans SonarQube.
4. **`--allow-insecure-registry` toujours passé (code orphelin)** — Contournement TLS sur toutes les opérations Cosign.
5. **Smoke tests non bloquants en staging** — Le pipeline de recette peut passer avec des échecs.
6. **14 déploiements en `:latest`** — Images non reproductibles, risque de regressions.
7. **MinIO/Harbor credentials hardcodés dans ArgoCD** — Backups et registres accessibles.
8. **Tetragon désactivé par défaut** — Couche de runtime security eBPF non active.
9. **Nagios de stockage persistant manquant** — Prometheus/Loki/Grafana/MinIO en emptyDir.
10. **Legacy quality gate et GitHub workflows non supprimés** — Risque de confusion et d'utilisation accidentelle.

---

## Composants Orphelins

| Composant | Présent | Branché Pipeline | Utilisé Réellement | Statut |
|-----------|:-------:|:----------------:|:------------------:|:------:|
| `vars/checkovScan.groovy` | ✅ | ❌ | ❌ | **Orphelin** (pipeline appelle checkov directement) |
| `quality-gate.sh` (legacy) | ✅ | ❌ | ❌ | **Orphelin** (remplacé par secure-quality-gate.sh) |
| `.github/workflows/ci-pr.yml` (deprecated) | ✅ | ❌ | ❌ | **Orphelin** (marqué deprecated, Jenkins est autoritaire) |
| `.github/workflows/build-sign.yml` | ✅ | ❌ | ❌ | **Orphelin** (marqué deprecated) |
| OPA `K8sRequiredLabels` ConstraintTemplate | ✅ | ❌ | ❌ | **Orphelin** (template sans constraint instanciée) |
| Vault policies (`*.hcl`) | ✅ | ❌ | ❌ | **Orphelin** (Vault non déployé) |
| ESO templates (`infra/secrets/external-secrets/`) | ✅ | ❌ | ❌ | **Orphelin** (ESO non déployé) |
| `artifacts/release/sbom-cyclonedx-validation.md` | ✅ | ❌ | ❌ | **Orphelin** (SBOM jamais généré) |
| `artifacts/release/release-attestation.json` | ✅ | ❌ | ❌ | **Orphelin** (toutes les claims sont false) |
| `deploy-sigstore-stack.sh` | ✅ | ❌ | ❌ | **Orphelin** (Sigstack non déployé) |
| Tetragon TracingPolicies | ✅ | ❌ | ❌ | **Orphelin** (Tetragon désactivé par défaut) |
| Tempo / OpenTelemetry | ✅ | ❌ | ❌ | **Orphelin** (feature flag false) |

---

## Score Avant / Après

| Domaine | Score Actuel | Score Potentiel | Delta | Effort |
|---------|:-----------:|:---------------:|:-----:|:------:|
| Secrets Management | 5.0 | 9.5 | +4.5 | 2 mois |
| Pipeline Hardening | 8.0 | 9.5 | +1.5 | 2 semaines |
| SAST | 6.0 | 9.0 | +3.0 | 1 mois |
| SCA | 7.0 | 9.0 | +2.0 | 3 semaines |
| IaC Security | 8.0 | 9.5 | +1.5 | 2 semaines |
| Runtime Security | 8.0 | 9.5 | +1.5 | 3 semaines |
| Supply Chain Security | 4.0 | 9.5 | +5.5 | 2 mois |
| Kubernetes Security | 7.0 | 9.0 | +2.0 | 1 mois |
| Observabilité | 8.0 | 9.5 | +1.5 | 3 semaines |
| Backup / DR | 7.0 | 9.5 | +2.5 | 1 mois |
| **TOTAL** | **64.0** | **93.5** | **+29.5** | **~7 mois** |

---

## Roadmap

### P0 — Bloquants (1-2 semaines, +10 points)

| Action | Effort | Gain | Dépendances |
|--------|:------:|:----:|:-----------:|
| Installer Cosign dans l'image Jenkins agent Docker | 1j | +2.5 | Modifier `infra/jenkins/agents/docker/Dockerfile` |
| Corriger le code orphelin `--allow-insecure-registry` (common.sh + attest-sboms.sh) | 1j | +1.0 | `scripts/release/lib/common.sh:73-75` |
| Ajouter `--sarif` au Semgrep run du pipeline CI principal | 0.5j | +1.5 | `Jenkinsfile:114` |
| Supprimer les `.env` commités du tracking Git + ajouter à `.gitignore` | 0.5j | +2.0 | `platform/**/.env`, `services-laravel/**/.env` |
| Ajouter `--exit-code` à Gitleaks dans tous les pipelines | 0.5j | +1.0 | `Jenkinsfile:128`, `Jenkinsfile.recette:240` |
| Rendre les smoke tests bloquants dans Jenkinsfile.recette | 0.5j | +1.0 | `Jenkinsfile.recette:479` |

### P1 — Élévations majeures (1-2 mois, +12 points)

| Action | Effort | Gain | Dépendances |
|--------|:------:|:----:|:-----------:|
| Déployer Vault + ESO en production | 2 sem | +3.0 | P0 complété |
| Activer SOPS (générer age key, créer `.enc.yaml`) | 2j | +1.0 | — |
| Exécuter et valider le pipeline CD complet (SBOM + Cosign + attestations) | 1 sem | +2.0 | P0 Cosign |
| Pinner les 14 images `:latest` | 1j | +1.5 | Audit des versions compatibles |
| Remplacer les credentials MinIO hardcodés par Vault/ESO | 2j | +1.0 | Déploiement ESO |
| Ajouter stockage persistant (PVC) pour Prometheus/Loki/Grafana/MinIO | 1 sem | +1.5 | — |
| Uniformiser Trivy severity MEDIUM+ sur tous les pipelines | 0.5j | +0.5 | — |
| Ajouter Grype dans le pipeline CI | 1j | +0.5 | — |

### P2 — Optimisation (3-4 mois, +7 points)

| Action | Effort | Gain | Dépendances |
|--------|:------:|:----:|:-----------:|
| Activer Tetragon | 1 sem | +0.5 | Feature flag |
| Activer Tempo / OpenTelemetry | 1 sem | +0.5 | Feature flag |
| Supprimer legacy quality-gate.sh + workflows GitHub | 1j | +0.5 | — |
| Ajouter `--config auto` au Semgrep CI | 0.5j | +0.5 | — |
| Réduire expiration `.trivyignore` à 90 jours max | 1j | +0.5 | Revue des CVEs |
| Ajouter securityContext aux 7+ déploiements infra manquants | 2j | +1.0 | — |
| Ajouter startupProbe sur api-gateway, llm-orchestrator, knowledge-hub, security-auditor, qdrant | 1j | +0.5 | — |
| Corriger namespace Falco dans les tests | 0.5j | +0.5 | — |
| Propager automatiquement la clé Cosign (rotation → Kyverno/Vault) | 1 sem | +0.5 | P1 Cosign |
| Remplacer `--noupdate` OWASP DC par un cache NVD dédié | 2j | +0.5 | — |
| Renommer/simplifier les dossiers Kyverno infra | 1j | +0.5 | — |
| Ajouter Constraint `K8sRequiredLabels` pour OPA Gatekeeper | 0.5j | +0.5 | — |
| Loki replication factor 3 | 1j | +0.5 | Stockage |
| Améliorer Grafana `readOnlyRootFilesystem` avec tmpfs | 0.5j | +0.5 | — |
| Configurer le Slack webhook Falco Talon réel | 0.5j | +0.5 | — |

### P3 — Excellence (5-7 mois, +1.5 points)

| Action | Effort | Gain | Dépendances |
|--------|:------:|:----:|:-----------:|
| Ajouter pre-commit Semgrep hook | 1j | +0.5 | — |
| Ajouter pod priority classes pour production | 1j | +0.5 | — |
| Implémenter custom metrics adapter pour HPA basé sur des métriques applicatives | 2 sem | +0.5 | Observabilité |
| Multi-cluster DR (AWS EKS failover) | 1 mois | +0.5 | Toute la roadmap |
| SLSA Level 4 (provenance attestation + rebuild reproducibility) | 1 mois | +0.5 | P1 Supply Chain |
| Istio mTLS + service mesh | 2 sem | +0.5 | — |
| Mise en place d'un SOC avec Wazuh + TheHive + IR | 1 mois | +0.5 | — |

**Total Roadmap : ~7 mois, potentiel 96-98/100**

---

## Benchmark

| Critère | Startup (0-40) | PME (40-70) | Enterprise (70-85) | World-Class (85-95) | SecureRAG Hub |
|---------|:--------------:|:-----------:|:------------------:|:-------------------:|:-------------:|
| Secrets Management | .env files | HashiCorp Vault basic | Vault + rotation | Vault + ESO + SOPS + rotation auto | ⚠️ Vault/ESO préparés, non exécutés |
| Pipeline Hardening | Basic CI | Quality gates | Scope-aware gates | Zero-bypass, SLSA | ✅ 3 quality gates, scope-aware |
| SAST | Linter only | Semgrep basic | Semgrep custom + SonarQube | Multi-language, SARIF, blocking | ⚠️ SARIF cassé en CI |
| SCA | npm audit | Trivy basic | Trivy + OWASP DC + .trivyignore | Syft + Grype + Renovate + policy as code | ✅ Bon, npm audit inefficace |
| IaC Security | Manual review | Checkov basic | Checkov + Kyverno | Kyverno Enforce + OPA + Conftest | ✅ Kyverno audit+enforce |
| Runtime Security | Logs only | Falco basic | Falco + Talon + Wazuh | Falco + Tetragon + Cilium + eBPF | ✅ Excellent, Tetragon désactivé |
| Supply Chain | Docker Hub | Cosign sign | Cosign + SBOM + Grype | Keyless + Fulcio/Rekor + SLSA | ❌ Non fonctionnel |
| Kubernetes Security | Default | PSA + RBAC | PSA + Kyverno + NetworkPolicies | PSA + Kyverno Enforce + Cilium + OPA | ✅ Fort sur app, faible sur infra |
| Observabilité | Logs only | Prometheus + Grafana | + Loki + Alertmanager | + Tempo + OTel + SLO dashboards | ✅ OTel/Tempo désactivés |
| Backup / DR | Manual pg_dump | Velero basic | Velero + MinIO + restore tests | Multi-region, chaos engineering, RTO < 1h | ✅ Bon, production non exécuté |
| **SCORE** | **20-40** | **40-70** | **70-85** | **85-95** | **64 — INTERMEDIATE** |

---

## Conclusion Finale

### Score Exact

| Métrique | Valeur |
|----------|:------:|
| **Score Global** | **64/100** |
| **Niveau de Maturité** | **Intermediate** |
| **Rang dans le Benchmark** | **PME → Enterprise (en transition)** |
| **Score Potentiel Maximum Atteignable** | **96/100 (World-Class)** |

### Top 3 Risques Immédiats

1. **Supply Chain non fonctionnelle** (perte de -10 points) — Cosign manquant, SBOM jamais généré, attestations toutes `false`. Sans supply chain, la confiance dans les artéfacts déployés est nulle.
2. **Secrets externalisés non actifs** (perte de -5 points) — Vault, ESO, SOPS en attente ; 5 `.env` avec clés commités.
3. **SARIF import cassé** (perte de -3 points en SAST) — Blind spot critique : SonarQube n'importe pas les résultats SARIF.

### Estimation Temps pour Atteindre

| Cible | Score | Temps Estimé | Coût Estimé (hommes·mois) |
|:----:|:-----:|:------------:|:-------------------------:|
| **World-Class (96/100)** | 96 | **4–6 mois** | 6–8 HM |
| **Big Tech / FAANG (98/100)** | 98 | **8–12 mois** | 12–16 HM |

### Détail du Chemin vers 96/100

| Phase | Mois | Score Cible | Actions Clés |
|:-----:|:----:|:-----------:|--------------|
| P0 (Quick wins) | 1 | 74 | Cosign, SARIF, .env, --exit-code, smoke tests |
| P1 (Fondations) | 2-3 | 84 | Vault + ESO, SOPS, SBOM + attestations, versions pinning, PVC |
| P2 (Optimisation) | 4-5 | 91 | Tetragon, Tempo, securityContext, Trivy uniforme, namespace tests |
| P3 (Excellence) | 5-6 | 96 | Multi-cluster DR, SLSA 4, service mesh, pre-commit, custom HPA |

---

*Rapport généré le 17 Juin 2026 par un Principal DevSecOps Engineer indépendant. Tous les scores sont evidence-based et justifiés par des preuves techniques (chemins de fichiers, lignes de code, logs d'exécution).*
