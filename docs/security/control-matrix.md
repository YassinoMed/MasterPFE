# Control Matrix — SecureRAG Hub

| Domaine | Contrôle | Implémentation actuelle | État |
|---|---|---|---|
| CI | Lint et tests | `scripts/ci/run-tests.sh`, `scripts/ci/collect-coverage.sh` | TERMINÉ |
| CI | SAST | `security/semgrep/semgrep.yml`, `sonar-project.properties` | PRÊT_NON_EXÉCUTÉ |
| CI | Détection de secrets | `.gitleaks.toml` | TERMINÉ |
| CI | Scan filesystem | `security/trivy/trivy.yaml` | TERMINÉ |
| Supply chain | SBOM | `scripts/release/generate-sbom.sh` + `artifacts/sbom/sbom-index.txt` | DÉPENDANT_DE_L_ENVIRONNEMENT |
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
| Kubernetes | PodDisruptionBudget | manifests `*/pdb.yaml` sur composants critiques | TERMINÉ |
| Kubernetes | HorizontalPodAutoscaler | manifests `*/hpa.yaml`; exploitation dépend de `metrics-server` runtime | DÉPENDANT_DE_L_ENVIRONNEMENT |
| Kubernetes | Admission policy (Audit) | `infra/k8s/policies/kyverno/*`; preuve via `cluster-security-addons.md` | DÉPENDANT_DE_L_ENVIRONNEMENT |
| Kubernetes | Admission policy (Enforce) | overlays `infra/k8s/policies/kyverno-enforce` et `infra/k8s/policies/kyverno/overlays/enforce` | PRÊT_NON_EXÉCUTÉ |
| Secrets | Jenkins credentials | runbook Jenkins | PARTIEL |
| Secrets | Kubernetes secrets | `secretRef` + script local à utiliser | PARTIEL |
| Validation | Smoke tests | `scripts/validate/*.sh` | TERMINÉ |
| Validation | Rapport final | `scripts/validate/generate-validation-report.sh` | TERMINÉ |
