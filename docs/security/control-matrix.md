# Control Matrix — SecureRAG Hub

| Domaine | Contrôle | Implémentation actuelle | État |
|---|---|---|---|
| CI | Tests Laravel | `scripts/ci/run-tests.sh`, rapports `.coverage-artifacts/junit-*.xml` | TERMINÉ |
| CI | Audit dépendances | `scripts/ci/audit-dependencies.sh`, Composer audit, npm audit si lockfile présent | TERMINÉ |
| CI | SAST | `security/semgrep/semgrep.yml`, `sonar-project.properties` | PRÊT_NON_EXÉCUTÉ |
| CI | Sonar CPD scope | `scripts/ci/validate-sonar-cpd-scope.sh`, `sonar.cpd.exclusions` | TERMINÉ |
| CI | Sonar Quality Gate | `scripts/ci/run-sonar-analysis.sh`, `security/reports/sonar-analysis.md` | DÉPENDANT_DE_L_ENVIRONNEMENT |
| CI | Détection de secrets | `.gitleaks.toml` | TERMINÉ |
| CI | Scan filesystem | `security/trivy/trivy.yaml` | TERMINÉ |
| Supply chain | Scan images | `scripts/release/scan-images.sh`, `artifacts/release/image-scan-summary.txt` | DÉPENDANT_DE_L_ENVIRONNEMENT |
| Supply chain | SBOM | `scripts/release/generate-sbom.sh` + `artifacts/sbom/sbom-index.txt` | DÉPENDANT_DE_L_ENVIRONNEMENT |
| Supply chain | Attestation SBOM | `scripts/release/attest-sboms.sh`, `artifacts/release/attest-summary.txt` | DÉPENDANT_DE_L_ENVIRONNEMENT |
| Supply chain | Signature d’images | `scripts/release/sign-images.sh` + Cosign key/keyless identity | DÉPENDANT_DE_L_ENVIRONNEMENT |
| Supply chain | Vérification de signature | `scripts/release/verify-signatures.sh` + Cosign public key/identity | DÉPENDANT_DE_L_ENVIRONNEMENT |
| Supply chain | Promotion sans rebuild | `scripts/release/promote-by-digest.sh` + `promotion-digests.txt` | DÉPENDANT_DE_L_ENVIRONNEMENT |
| Supply chain | Gate release obligatoire | `scripts/release/assert-supply-chain-evidence.sh` | PRÊT_NON_EXÉCUTÉ |
| CD | Déploiement d’artefacts vérifiés | `scripts/deploy/verify-and-deploy-kind.sh` | TERMINÉ |
| Kubernetes | Namespace dédié | `infra/k8s/base/namespace.yaml` | TERMINÉ |
| Kubernetes | NetworkPolicies | `infra/k8s/base/networkpolicy-*.yaml` | TERMINÉ |
| Kubernetes | SecurityContext minimal | manifests `Deployment` / `StatefulSet` | TERMINÉ |
| Kubernetes | ResourceQuota | `infra/k8s/base/resourcequota.yaml` | TERMINÉ |
| Kubernetes | LimitRange | `infra/k8s/base/limitrange.yaml` avec defaults CPU, mémoire et `ephemeral-storage` | TERMINÉ |
| Kubernetes | Resource guards | `scripts/validate/validate-k8s-resource-guards.sh` contrôle les overlays `dev` et `demo` | TERMINÉ |
| Kubernetes | Ultra hardening statique | `scripts/validate/validate-k8s-ultra-hardening.sh` contrôle PSA restricted, ServiceAccounts, probes, PDB, NetworkPolicies, hostPath, images et Kyverno | TERMINÉ |
| Kubernetes | Validation Kyverno hors cluster | `scripts/ci/validate-kyverno-policies.sh`, `kyverno apply` si le CLI est disponible | PRÊT_NON_EXÉCUTÉ |
| Kubernetes | PodDisruptionBudget | manifests `*/pdb.yaml` sur composants critiques | TERMINÉ |
| Kubernetes | HorizontalPodAutoscaler | manifests `*/hpa.yaml`; exploitation dépend de `metrics-server` runtime | DÉPENDANT_DE_L_ENVIRONNEMENT |
| Kubernetes | Admission policy (Audit) | `infra/k8s/policies/kyverno/*`; preuve via `cluster-security-addons.md` | DÉPENDANT_DE_L_ENVIRONNEMENT |
| Kubernetes | Admission policy (Enforce) | overlay unique `infra/k8s/policies/kyverno-enforce` | PRÊT_NON_EXÉCUTÉ |
| Secrets | Jenkins credentials | `scripts/jenkins/bootstrap-local-credentials.sh`, `JENKINS_ADMIN_PASSWORD_FILE` | TERMINÉ |
| Secrets | Kubernetes secrets | `scripts/secrets/bootstrap-local-secrets.sh`, `scripts/secrets/create-dev-secrets.sh` | TERMINÉ |
| Runtime | Laravel workloads officiels | `portal-web`, `auth-users`, `chatbot-manager`, `conversation-service`, `audit-security-service` | TERMINÉ |
| Runtime | Services Python legacy | Exclus du build/deploy officiel car sources absentes | PARTIEL |
| Validation | Smoke tests | `scripts/validate/*.sh` | TERMINÉ |
| Validation | Rapport final | `scripts/validate/generate-validation-report.sh` | TERMINÉ |
