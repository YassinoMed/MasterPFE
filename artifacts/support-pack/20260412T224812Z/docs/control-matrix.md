# Control Matrix — SecureRAG Hub

| Domaine | Contrôle | Implémentation actuelle | État |
|---|---|---|---|
| CI | Lint et tests | `scripts/ci/run-tests.sh`, `scripts/ci/collect-coverage.sh` | OK |
| CI | SAST | `security/semgrep/semgrep.yml` | OK |
| CI | Détection de secrets | `.gitleaks.toml` | OK |
| CI | Scan filesystem | `security/trivy/trivy.yaml` | OK |
| Supply chain | SBOM | `scripts/release/generate-sbom.sh` | OK |
| Supply chain | Signature d’images | `scripts/release/sign-images.sh` | OK |
| Supply chain | Vérification de signature | `scripts/release/verify-signatures.sh` | OK |
| Supply chain | Promotion sans rebuild | `scripts/release/promote-verified-images.sh` | OK |
| CD | Déploiement d’artefacts vérifiés | `scripts/deploy/verify-and-deploy-kind.sh` | OK |
| Kubernetes | Namespace dédié | `infra/k8s/base/namespace.yaml` | OK |
| Kubernetes | NetworkPolicies | `infra/k8s/base/networkpolicy-*.yaml` | OK |
| Kubernetes | SecurityContext minimal | manifests `Deployment` / `StatefulSet` | OK |
| Kubernetes | ResourceQuota | `infra/k8s/base/resourcequota.yaml` | OK |
| Kubernetes | LimitRange | `infra/k8s/base/limitrange.yaml` | OK |
| Kubernetes | PodDisruptionBudget | manifests `*/pdb.yaml` sur composants critiques | OK |
| Kubernetes | HorizontalPodAutoscaler | manifests `*/hpa.yaml` + `metrics-server` actif sur le cluster de démo | OK |
| Kubernetes | Admission policy (Audit) | `infra/k8s/policies/kyverno/*` + Kyverno installé sur le cluster de démo | OK |
| Kubernetes | Admission policy (Enforce) | overlay `infra/k8s/policies/kyverno/overlays/enforce` | PARTIEL |
| Secrets | Jenkins credentials | runbook Jenkins | PARTIEL |
| Secrets | Kubernetes secrets | `secretRef` + script local à utiliser | PARTIEL |
| Validation | Smoke tests | `scripts/validate/*.sh` | OK |
| Validation | Rapport final | `scripts/validate/generate-validation-report.sh` | OK |
