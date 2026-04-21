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
| Supply chain | Provenance SLSA-style | `scripts/release/generate-provenance-statement.sh`, `artifacts/release/provenance.slsa.json` | PRÊT_NON_EXÉCUTÉ |
| CD | Déploiement d’artefacts vérifiés | `scripts/deploy/verify-and-deploy-kind.sh` | TERMINÉ |
| Kubernetes | Namespace dédié | `infra/k8s/base/namespace.yaml` | TERMINÉ |
| Kubernetes | NetworkPolicies | `infra/k8s/base/networkpolicy-*.yaml` | TERMINÉ |
| Kubernetes | SecurityContext minimal | manifests `Deployment` / `StatefulSet` | TERMINÉ |
| Kubernetes | ResourceQuota | `infra/k8s/base/resourcequota.yaml` | TERMINÉ |
| Kubernetes | LimitRange | `infra/k8s/base/limitrange.yaml` avec defaults CPU, mémoire et `ephemeral-storage` | TERMINÉ |
| Kubernetes | Resource guards | `scripts/validate/validate-k8s-resource-guards.sh` contrôle les overlays `dev`, `demo` et `production` | TERMINÉ |
| Kubernetes | Ultra hardening statique | `scripts/validate/validate-k8s-ultra-hardening.sh` contrôle PSA restricted, ServiceAccounts, probes, PDB, NetworkPolicies, hostPath, images et Kyverno | TERMINÉ |
| Kubernetes | Overlay production HA | `infra/k8s/overlays/production`, `scripts/validate/validate-production-ha.sh` | TERMINÉ statique |
| Kubernetes | Preuves runtime production | `scripts/validate/collect-production-runtime-evidence.sh`, `artifacts/validation/production-runtime-evidence.md` | DÉPENDANT_DE_L_ENVIRONNEMENT |
| Kubernetes | Sécurité runtime post-déploiement | `scripts/validate/validate-runtime-security-postdeploy.sh`, `artifacts/security/runtime-security-postdeploy.md` | DÉPENDANT_DE_L_ENVIRONNEMENT |
| Kubernetes | Validation Kyverno hors cluster | `scripts/ci/validate-kyverno-policies.sh`, `kyverno apply` si le CLI est disponible | PRÊT_NON_EXÉCUTÉ |
| Kubernetes | PodDisruptionBudget | manifests `*/pdb.yaml` sur composants critiques | TERMINÉ |
| Kubernetes | HorizontalPodAutoscaler | manifests `*/hpa.yaml`, `scripts/validate/validate-hpa-runtime.sh`, preuve `artifacts/validation/hpa-runtime-report.md` | DÉPENDANT_DE_L_ENVIRONNEMENT |
| Kubernetes | Admission policy (Audit) | `infra/k8s/policies/kyverno/*`; preuve via `cluster-security-addons.md` | DÉPENDANT_DE_L_ENVIRONNEMENT |
| Kubernetes | Admission policy (Enforce) | overlay unique `infra/k8s/policies/kyverno-enforce` | PRÊT_NON_EXÉCUTÉ |
| Kubernetes | Blocage Enforce registry locale | `artifacts/validation/kyverno-local-registry-enforce-blocker.md` documente le cas `localhost:5001` | DÉPENDANT_DE_L_ENVIRONNEMENT |
| Secrets | Jenkins credentials | `scripts/jenkins/bootstrap-local-credentials.sh`, `JENKINS_ADMIN_PASSWORD_FILE` | TERMINÉ |
| Secrets | Kubernetes secrets | `scripts/secrets/bootstrap-local-secrets.sh`, `scripts/secrets/create-dev-secrets.sh` | TERMINÉ |
| Secrets | Production DB secret | `scripts/secrets/create-production-db-secret.sh`, `artifacts/security/production-db-secret.md` | PRÊT_NON_EXÉCUTÉ |
| Secrets | SOPS/age option | `infra/secrets/sops`, `infra/secrets/production/*.template.yaml` | PRÊT_NON_EXÉCUTÉ |
| Secrets | External Secrets / Vault strategy | `docs/security/secrets-strategy.md` documente la trajectoire moderne sans la surdéclarer | PRÊT_NON_EXÉCUTÉ |
| Secrets | Secrets readiness report | `scripts/secrets/validate-secrets-management.sh`, `artifacts/security/secrets-management.md` | PRÊT_NON_EXÉCUTÉ |
| Runtime | Laravel workloads officiels | `portal-web`, `auth-users`, `chatbot-manager`, `conversation-service`, `audit-security-service` | TERMINÉ |
| Runtime | Dockerfiles production Laravel | `scripts/validate/validate-production-dockerfiles.sh`, `artifacts/security/production-dockerfiles.md` | TERMINÉ |
| Runtime | Image size evidence | `scripts/validate/collect-image-size-evidence.sh`, `artifacts/security/image-size-evidence.md` | DÉPENDANT_DE_L_ENVIRONNEMENT |
| Runtime | Services Python legacy | Exclus du build/deploy officiel car sources absentes | PRÊT_NON_EXÉCUTÉ |
| Résilience données | Readiness DB externe / backup / restore | `infra/k8s/overlays/production-external-db`, `scripts/data/backup-postgres.sh`, `scripts/data/restore-postgres.sh`, `docs/runbooks/data-resilience.md` | PRÊT_NON_EXÉCUTÉ |
| Validation | Smoke tests | `scripts/validate/*.sh` | TERMINÉ |
| Validation | Rapport final | `scripts/validate/generate-validation-report.sh` | TERMINÉ |
