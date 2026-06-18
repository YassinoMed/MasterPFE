# 🔍 Audit Sécurité Indépendant — SecureRAG Hub

**Date :** Juin 2026  
**Méthode :** Evidence-based (grep, find, inspection fichiers). Aucune supposition. Zéro crédit pour fonctionnalités non branchées.  
**Auditeur :** Principal DevSecOps Engineer (indépendant)

---

## Score final

| Catégorie | Note /10 |
|-----------|:--------:|
| Secrets Management | 1.5 |
| Pipeline Hardening | 7.0 |
| SAST | 9.0 |
| SCA | 6.0 |
| IaC Security | 6.0 |
| Runtime Security | 5.0 |
| Supply Chain | 7.5 |
| Kubernetes Security | 7.5 |
| Observabilité | 8.5 |
| Backup & DR | 1.0 |
| **MOYENNE** | **59 / 100** |

## Niveau de maturité

```
0-40  : Débutant
40-70 : Intermédiaire   ← 59/100
70-85 : Avancé
85-92 : Enterprise
92-97 : World-Class
98-100: Big Tech / FAANG
```

**Niveau : INTERMÉDIAIRE (59/100)**

---

## 1. Tableau détaillé des outils

| Catégorie | Outil | Statut réel | Preuve (fichier:ligne) | Note |
|-----------|-------|-------------|------------------------|:----:|
| **Secrets** | Vault | ❌ Manifests présents, non déployé (0 pipeline stage) | `infra/k8s/vault/` (6 fichiers) | 0/10 |
| | External Secrets Operator | ❌ Manifests présents, non déployé (0 pipeline stage) | `infra/k8s/secrets/eso-*.yaml` (5 fichiers) | 0/10 |
| | SOPS + age | ⚠️ Config présent, clés placeholder | `.sops.yaml:31-32` (age keys factices) | 3/10 |
| | Rotation automatique | ❌ CronJob présent, non branché pipeline | `infra/k8s/jobs/secret-rotation-cronjob.yaml` | 0/10 |
| | Secrets en clair | ❌ 11 fichiers credentials en clair + perms 777 | `infra/jenkins/secrets/` | 0/10 |
| **Pipeline** | ||| **7/10** |
| | `\|\| true` | ✅ 0 CI / 1 CD (kubectl annotate) / 2 Recette (sysctl, iptables) | `Jenkinsfile.cd:212`, `Jenkinsfile.recette:371-372` | |
| | `ALLOW_*` flags | ⚠️ Retiré pipeline CD, présent dans scripts | `scripts/release/scan-images.sh:19` | |
| | `secure-quality-gate.sh` | ✅ Utilisé dans CI + Recette | `Jenkinsfile:323`, `Jenkinsfile.recette:312` | |
| **SAST** | ||| **9/10** |
| | Semgrep | ✅ 14 règles custom, `--error`, QG parse | `Jenkinsfile:109`, `security/semgrep/semgrep.yml` | |
| | Gitleaks | ✅ Pre-commit + CI + QG | `Jenkinsfile:123`, `.gitleaks.toml`, `.pre-commit-config.yaml` | |
| | SonarQube | ✅ QG wait, SARIF import | `sonar-project.properties:20,31` | |
| **SCA** | ||| **6/10** |
| | Composer Audit | ✅ Bloquant dans CI | `Jenkinsfile:258` | |
| | npm audit | ✅ Bloquant dans CI | `scripts/ci/audit-dependencies.sh:59-60` | |
| | Trivy | ✅ `exit-code:1` | `security/trivy/trivy*.yaml` | |
| | OWASP Dependency-Check | ✅ Dans Jenkinsfile | `Jenkinsfile:272-277` | |
| **IaC** | ||| **6/10** |
| | Checkov | ⚠️ `\|\| true` retiré, --soft-fail HIGH, **non parsé QG** | `Jenkinsfile:160-163` | |
| | kube-score | ✅ Bloquant CRITICAL=0 | `scripts/ci/validate-kube-score.sh:155-159` | |
| | Kyverno | ✅ **7/7 Enforce** + CI validation | `infra/k8s/policies/kyverno/*.yaml` | |
| | OPA Gatekeeper | ✅ Dans Jenkinsfile + constraints Rego | `Jenkinsfile:194`, `infra/k8s/opa-gatekeeper/` | |
| **Runtime** | ||| **5/10** |
| | Falco | ✅ DaemonSet + 13 rules MITRE, ❌ **hors QG** | `infra/k8s/runtime-detection/daemonset.yaml` | |
| | Cilium | ✅ Activé (`"true"`) + 5 NetworkPolicies | `infra/k8s/cilium/daemonset.yaml` | |
| | Tetragon | ✅ 3 TracingPolicies + CI | `infra/k8s/tetragon/tracing-policy-*.yaml`, `Jenkinsfile:203` | |
| | Hubble | ✅ Relay + UI déployés | `infra/k8s/cilium/daemonset.yaml:52-104` | |
| **Supply Chain** | ||| **7.5/10** |
| | Cosign Sign | ✅ CD stage, `FAIL_FAST=true` | `Jenkinsfile.cd:88-101` | |
| | Cosign Verify | ✅ CD stage, QG vérifie | `Jenkinsfile.cd:103-115`, `secure-quality-gate.sh:210-219` | |
| | SBOM CycloneDX | ✅ Script existant | `scripts/release/generate-sbom.sh` | |
| | Syft | ✅ Utilisé dans SBOM | `scripts/release/generate-sbom.sh:60-69` | |
| | Grype | ✅ CD stage | `Jenkinsfile.cd:128` | |
| | Kyverno verify | ✅ **Enforce** | `infra/k8s/policies/kyverno/verify-cosign-images.yaml` | |
| **K8s** | ||| **7.5/10** |
| | PSA restricted | ✅ `pod-security.kubernetes.io/enforce: restricted` | `infra/k8s/base/namespace.yaml:7` | |
| | NetworkPolicies | ✅ default-deny + allow-dns + allow-db + allow-harbor | `infra/k8s/network-policies/` | |
| | RBAC | ✅ Aucun cluster-admin, SAs dédiés, verbes spécifiques | `infra/k8s/base/rbac-runtime-readonly.yaml` | |
| | allowPrivilegeEscalation=false | ✅ Partout | `infra/k8s/base/*/deployment.yaml` | |
| | runAsNonRoot=true | ✅ Partout | `infra/k8s/base/*/deployment.yaml` | |
| | :latest tags | ❌ 11+ manifests | `backstage, spiffe, aiops, kong, tetragon, opencost, data-platform, falco-talon, otel, coraza, ml-platform` | |
| | Feature flags désactivés | ❌ 10+ `"false"` | `backstage, spiffe, aiops, multi-cluster, istio, dr, staging` | |
| **Observabilité** | ||| **8.5/10** |
| | Prometheus | ✅ Déployé + 5 rule files + RBAC | `infra/k8s/observability/prometheus-*.yaml` | |
| | Grafana | ✅ Déployé + 10 dashboards | `infra/k8s/observability/grafana-*.yaml` | |
| | Alertes sécurité | ✅ Oui (10+ alert files) | `infra/k8s/monitoring/security-alerts.yaml` | |
| | Dashboards sécurité | ✅ Oui (Falco, K8s audit, security-overview) | `infra/k8s/monitoring/dashboards/` | |
| **Backup** | ||| **1/10** |
| | Velero | ❌ Manifests présents, non déployé | `infra/k8s/velero/` | |
| | MinIO | ❌ Non déployé | — | |
| | Tests restauration | ❌ Aucun | — | |

---

## 2. Points forts

- ✅ **SAST complet** : Semgrep (14 règles custom) + Gitleaks (pre-commit + CI) + SonarQube (QG wait). Tous bloquants.
- ✅ **Pipeline mature** : 23 stages CI réels, 7 agents K8s spécialisés, aucun stage vide.
- ✅ **Kyverno tout en Enforce** : 7 politiques couvrant pod-security, images, volumes, cosign, services, cleartext, workloads.
- ✅ **K8s Pod Security** : PSA restricted sur 4 namespaces, NetworkPolicies (default-deny egress), RBAC restrictif, `runAsNonRoot=true` et `allowPrivilegeEscalation=false` partout.
- ✅ **Observabilité** : Prometheus + Grafana + Alertmanager + 10 dashboards + 10+ alert rules.
- ✅ **Supply chain** : Cosign keyless + SBOM CycloneDX + Syft + Grype + Kyverno Enforce verify.

---

## 3. Faiblesses restantes

- 🔴 **11 credentials en clair** sur disque (cosign.key, github-token, sonar-token, gmail-app-password, jenkins-admin-password, kubeconfig, recette-deploy-key, recette-deploy-key.pub, cosign.pub, cosign.password, gmail-user)
- 🔴 **Vault non déployé** : 6 manifests K8s créés mais 0 référence dans les pipelines
- 🔴 **ESO non déployé** : 5 manifests ExternalSecret créés mais 0 référence dans les pipelines
- 🟠 **Velero non déployé** : manifests orphelins, 0 pipeline stage
- 🟠 **Checkov non vérifié dans le QG** : JUnit XML produits mais `secure-quality-gate.sh` ne les parse pas
- 🟠 **Falco hors QG** : alertes runtime vont vers Slack/Wazuh mais ne bloquent pas le pipeline
- 🟠 **:latest tags** dans 11+ manifests K8s
- 🟠 **WAZUH_PASSWORD hardcodé** (`infra/wazuh/wazuh-exporter/docker-compose.exporter.yml:19`)
- 🟡 **10+ feature flags désactivés** (backstage, spiffe, aiops, istio, multi-cluster, dr, staging)
- 🟡 **COSIGN_ALLOW_INSECURE_REGISTRY** présent dans 10+ scripts
- 🟡 **.trivyignore** avec 14 CVEs acceptés sans justifications documentées

---

## 4. Findings classifiés

### 🔴 CRITICAL (7)

| ID | Finding | Fichier | Ligne | Détail |
|:--:|---------|---------|:-----:|--------|
| C1 | 11 credentials en clair | `infra/jenkins/secrets/` | — | cosign.key, github-token, sonar-token, gmail-app-password, gmail-user, jenkins-admin-password, kubeconfig, recette-deploy-key, recette-deploy-key.pub, cosign.pub, cosign.password |
| C2 | Permissions 777 | `infra/jenkins/secrets/` | `stat` | Le dossier secrets est accessible mondialement |
| C3 | WAZUH_PASSWORD hardcodé | `infra/wazuh/wazuh-exporter/docker-compose.exporter.yml` | 19 | Mot de passe en clair dans un fichier versionné |
| C4 | Vault non déployé | `infra/k8s/vault/` (6 fichiers) | — | StatefulSet, PVC, Service, ConfigMap, RBAC, SA créés mais non appliqués |
| C5 | ESO non déployé | `infra/k8s/secrets/` (5 fichiers) | — | ClusterSecretStore + 3 ExternalSecrets créés mais non appliqués |
| C6 | Velero non déployé | `infra/k8s/velero/velero.yaml` | — | Schedules BackupStorageLocation créés mais non appliqués |
| C7 | Rotation CronJob non branchée | `infra/k8s/jobs/secret-rotation-cronjob.yaml` | — | CronJob + RBAC créés mais non appliqués |

### 🟠 HIGH (6)

| ID | Finding | Fichier | Ligne | Détail |
|:--:|---------|---------|:-----:|--------|
| H1 | Checkov non parsé par le QG | `scripts/ci/secure-quality-gate.sh` | — | `grep checkov secure-quality-gate.sh` → vide |
| H2 | Falco non intégré au QG | `scripts/ci/secure-quality-gate.sh` | — | `grep falco secure-quality-gate.sh` → vide |
| H3 | :latest tags (11+ manifests) | Voir section K8s | multiple | backstage, spiffe, aiops, kong, tetragon, opencost, data-platform, falco-talon, otel, coraza, ml-platform |
| H4 | COSIGN_ALLOW_INSECURE_REGISTRY | Scripts release | 10+ | `grep -rn "COSIGN_ALLOW_INSECURE" scripts/release/` → 10+ résultats |
| H5 | .trivyignore 14 CVEs | `.trivyignore` | 5-20 | Aucune justification documentée |
| H6 | ALLOW_IMAGE_VULNERABILITIES | `scripts/release/scan-images.sh` | 19 | Flag présent dans le script malgré retrait du pipeline |

### 🟡 MEDIUM (8)

| ID | Finding | Détail |
|:--:|---------|--------|
| M1 | 10+ feature flags `"false"` | backstage, spiffe, aiops, multi-cluster, istio, staging, dr |
| M2 | COSIGN_EXPERIMENTAL=1 | Keyless mode mais flag expérimental |
| M3 | .env.example avec secrets | JWT_SECRET, POSTGRES_PASSWORD placeholders |
| M4 | Aucun dashboard Trivy/Checkov/Semgrep | Observabilité des scans manquante |
| M5 | Aucun test de restauration | Velero non déployé, aucun DR test |
| M6 | SOPS age keys placeholders | `.sops.yaml` avec clés factices |
| M7 | Pas de backup Jenkins | Aucune sauvegarde automatique de la config Jenkins |
| M8 | Aucun ServiceMonitor pour apps métier | Prometheus scrape manuel uniquement |

---

## 5. Quality Gates — Vérification détaillée

| Quality Gate | Bloque ? | Mécanisme | Code |
|-------------|:--------:|-----------|:----:|
| Coverage | ✅ OUI | `exit 1` si < seuil | `collect-coverage.sh:229` |
| Semgrep | ✅ OUI | `--error` flag + QG parse `semgrep.json` | `Jenkinsfile:109`, `secure-quality-gate.sh:130-139` |
| Gitleaks | ✅ OUI | QG parse `gitleaks.json`, `exit 1` si leaks > 0 | `secure-quality-gate.sh:142-156` |
| Trivy FS | ✅ OUI | QG parse `trivy-fs.json`, `exit 1` si CRITICAL > 0 | `secure-quality-gate.sh:159-169` |
| Trivy Image | ⚠️ PARTIEL | `exit-code:1` mais `ALLOW_MISSING_IMAGES` script | `security/trivy/trivy-image.yaml`, `scan-images.sh:18` |
| SonarQube | ✅ OUI | `sonar.qualitygate.wait=true` + QG verify | `sonar-project.properties:20` |
| kube-score | ✅ OUI | `exit 1` si CRITICAL/WARNING > seuil | `validate-kube-score.sh:155-159` |
| Kyverno | ✅ OUI | Enforce mode + `exit 1` si échec | `validate-kyverno-policies.sh:80-82` |
| Checkov | ❌ NON | `\|\| true` retiré mais QG ignore JUnit | `grep checkov secure-quality-gate.sh` → vide |
| Cosign | ✅ OUI | QG vérifie sign + verify | `secure-quality-gate.sh:210-219` |
| ZAP | ⚠️ PARTIEL | `\|\| true` retiré, exécuté seulement CD/Recette | `Jenkinsfile.cd:236`, `Jenkinsfile.recette:527` |
| Hadolint | ✅ OUI | Stage CI, JUnit publié | `Jenkinsfile:262-269` |
| OWASP DC | ✅ OUI | Stage CI, blocage HIGH/CRITICAL | `Jenkinsfile:272-277` |
| OPA Gatekeeper | ✅ OUI | Stage CI, conftest | `Jenkinsfile:194-201` |
| Tetragon | ✅ OUI | Stage CI, validation YAML | `Jenkinsfile:203-210` |
| Falco | ❌ NON | DaemonSet déployé, **pas dans le QG** | `grep falco secure-quality-gate.sh` → vide |

---

## 6. Preuves exactes

### Secrets Management
```bash
# 11 credentials en clair
ls -la infra/jenkins/secrets/ | grep -v .gitignore | wc -l  # → 11

# Permissions 777
stat -c "%a %n" infra/jenkins/secrets/  # → 777 infra/jenkins/secrets/

# WAZUH_PASSWORD hardcodé
grep -n "WAZUH_PASSWORD" infra/wazuh/wazuh-exporter/docker-compose.exporter.yml
# → 19:      - WAZUH_PASSWORD=SecretPassword

# Vault non déployé (0 pipeline stage)
grep -rn "vault\|initialize-vault" Jenkinsfile Jenkinsfile.cd Jenkinsfile.recette | wc -l
# → 0

# ESO non déployé (0 pipeline stage)
grep -rn "external-secrets\|eso-cluster" Jenkinsfile Jenkinsfile.cd Jenkinsfile.recette | wc -l
# → 0
```

### Pipeline Hardening
```bash
# || true remnants
grep -n '|| true' Jenkinsfile  # → 0
grep -n '|| true' Jenkinsfile.cd  # → 1 (kubectl annotate)
grep -n '|| true' Jenkinsfile.recette  # → 2 (sysctl, iptables)

# ALLOW_IMAGE_VULNERABILITIES retiré du pipeline CD
grep "ALLOW_IMAGE_VULNERABILITIES" Jenkinsfile.cd  # → 0

# secure-quality-gate.sh utilisé
grep -n "secure-quality-gate" Jenkinsfile  # → 323
grep -n "secure-quality-gate" Jenkinsfile.recette  # → 312
```

### SAST
```bash
# Semgrep —error flag
grep "semgrep.*--error" Jenkinsfile  # → 109

# SonarQube quality gate wait
grep "qualitygate" sonar-project.properties  # → 20

# Gitleaks pre-commit
grep -A2 "gitleaks" .pre-commit-config.yaml  # → présent
```

### SCA
```bash
# Trivy exit-code:1
grep "exit-code" security/trivy/*.yaml  # → trois fois exit-code: 1

# OWASP DC dans Jenkinsfile
grep "run-owasp-dependency-check" Jenkinsfile  # → 277
```

### IaC Security
```bash
# Kyverno Enforce (7/7)
grep "validationFailureAction" infra/k8s/policies/kyverno/*.yaml
# → Tous "Enforce"

# OPA Gatekeeper dans Jenkinsfile
grep "validate-opa-gatekeeper" Jenkinsfile  # → 199

# Checkov non parsé par QG
grep -n "checkov\|Checkov" scripts/ci/secure-quality-gate.sh  # → vide
```

### Runtime Security
```bash
# Falco hors QG
grep -n "falco\|Falco" scripts/ci/secure-quality-gate.sh  # → vide

# Cilium activé
grep "enable-cilium" infra/k8s/cilium/daemonset.yaml  # → "true"

# Tetragon dans Jenkinsfile
grep "validate-tetragon" Jenkinsfile  # → 203
```

### Supply Chain
```bash
# Cosign Enforce
grep "validationFailureAction" infra/k8s/policies/kyverno/verify-cosign-images.yaml
# → Enforce

# Cosign dans QG
grep "cosign\|Cosign" scripts/ci/secure-quality-gate.sh  # → 210-219
```

### K8s Security
```bash
# PSA restricted
grep "pod-security.kubernetes.io/enforce" infra/k8s/base/namespace.yaml  # → restricted

# Feature flags désactivés
grep -rn "enable-.*false" infra/k8s/ --include='*.yaml' | wc -l  # → 10+
```

### Observabilité
```bash
# Dashboard count
ls infra/k8s/monitoring/dashboards/*.json | wc -l  # → 10
```

### Backup
```bash
# Velero non déployé
grep -rn "velero" Jenkinsfile Jenkinsfile.cd Jenkinsfile.recette | wc -l  # → 0
```

---

## 7. Estimation avant/après

| Métrique | Audit Juin 2026 | Potentiel post-corrections P0 |
|----------|:---------------:|:----------------------------:|
| Secrets Management | 1.5/10 | 8/10 (Vault + ESO déployés) |
| Pipeline Hardening | 7/10 | 9/10 |
| SAST | 9/10 | 9/10 |
| SCA | 6/10 | 8/10 |
| IaC Security | 6/10 | 9/10 (Checkov parsé dans QG) |
| Runtime Security | 5/10 | 8/10 (Falco dans QG) |
| Supply Chain | 7.5/10 | 9/10 |
| K8s Security | 7.5/10 | 9/10 (latest tags + flags) |
| Observabilité | 8.5/10 | 9.5/10 |
| Backup & DR | 1/10 | 8/10 (Velero déployé) |
| **SCORE GLOBAL** | **59/100** | **~86/100** |

---

## 8. Top 20 améliorations restantes

| # | Priorité | Action | Fichier | Effort |
|:-:|:--------:|--------|---------|:------:|
| 1 | 🔴 P0 | Déployer Vault | `kubectl apply -k infra/k8s/vault/` + `bash scripts/secrets/initialize-vault.sh` | 2h |
| 2 | 🔴 P0 | Déployer ESO | `helm install external-secrets` + `kubectl apply -f infra/k8s/secrets/eso-*.yaml` | 1h |
| 3 | 🔴 P0 | Supprimer les 11 fichiers secrets | `rm -rf infra/jenkins/secrets/*` (garder .gitignore) | 5min |
| 4 | 🔴 P0 | Fixer permissions 777→700 | `chmod 700 infra/jenkins/secrets/` | 1min |
| 5 | 🔴 P0 | Remplacer WAZUH_PASSWORD | Variable d'environnement ou vault | 30min |
| 6 | 🟠 P1 | Intégrer Checkov dans le QG | Ajouter parsing JUnit dans `secure-quality-gate.sh` | 1h |
| 7 | 🟠 P1 | Intégrer Falco dans le QG | Parser `custom-rules.yaml` violations | 1h |
| 8 | 🟠 P1 | Épingler les 11+ tags :latest | Remplacer par versions SHA256 | 2h |
| 9 | 🟠 P1 | Supprimer COSIGN_ALLOW_INSECURE_REGISTRY | Nettoyer 10+ scripts | 1h |
| 10 | 🟠 P1 | Documenter .trivyignore | Ajouter justifications CVE par CVE | 30min |
| 11 | 🟠 P1 | Déployer Velero | `kubectl apply -k infra/k8s/velero/` + config MinIO | 2h |
| 12 | 🟡 P2 | Activer feature flags | backstage, spiffe, aiops, istio | 2h |
| 13 | 🟡 P2 | Ajouter dashboards scan | Trivy, Checkov, Semgrep, Gitleaks | 2h |
| 14 | 🟡 P2 | Générer clés SOPS | `bash scripts/secrets/bootstrap-sops-age.sh` | 30min |
| 15 | 🟡 P2 | Activer rotation CronJob | `kubectl apply -f infra/k8s/jobs/secret-rotation-cronjob.yaml` | 30min |
| 16 | 🟡 P2 | Ajouter stage Velero CI | Vérification hebdomadaire des backups | 1h |
| 17 | 🟡 P2 | Ajouter ServiceMonitors apps | Prometheus scrape auto pour chaque service | 2h |
| 18 | 🟡 P2 | Remplacer COSIGN_EXPERIMENTAL | Keyless stable via Fulcio dédié | 2h |
| 19 | 🟡 P2 | Ajouter stage backup Jenkins | Sauvegarde automatique JENKINS_HOME | 1h |
| 20 | 🟡 P3 | Tests restauration Velero | Script automatisé de DR test | 3h |

---

## 9. Conclusion

> **Verbatim :** *"Une architecture Enterprise avec une exécution Intermédiaire. Les fondations sont solides. L'écart entre les manifests et leur déploiement réel est le facteur limitant principal."*

### Forces réelles
- **Pipeline CI/CD** : 23 stages, 7 agents K8s spécialisés, 14 outils de sécurité intégrés
- **SAST** : Semgrep + Gitleaks + SonarQube — tous bloquants et bien configurés
- **Kyverno** : 7 politiques en **Enforce** (pod-security, images, volumes, cosign, services)
- **K8s Security** : PSA restricted, NetworkPolicies, RBAC restrictif, runAsNonRoot partout

### Faiblesses réelles
- **11 credentials en clair** sur disque avec permissions 777
- **Vault + ESO non déployés** (manifests créés mais inactifs)
- **Checkov + Falco ignorés par le quality gate**
- **Velero non déployé** (zéro backup)
- **11+ tags :latest** et **10+ feature flags désactivés**

### Prochain pas critique
Les **5 P0** (déployer Vault + ESO, supprimer credentials en clair, fixer permissions, remplacer WAZUH_PASSWORD) doivent être traités immédiatement. Une fois ces correctifs appliqués, le score passerait de **59/100** (Intermédiaire) à environ **86/100** (Enterprise).
