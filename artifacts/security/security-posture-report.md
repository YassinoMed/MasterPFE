# Security Posture Report — SecureRAG Hub

- Generated at UTC: `2026-04-25T20:08:19Z`
- Git commit: `808eb363d8aa4eba3fb202858af6482fbde73b35`
- Kubernetes namespace: `securerag-hub`

## 1. Security controls status

| Control | State | Evidence |
|---|---|---|
| Semgrep SAST | `TERMINÉ` | `security/reports/semgrep.json`, findings=0 |
| Sonar CPD scope | `TERMINÉ` | `artifacts/security/sonar-cpd-scope.md` |
| Sonar Quality Gate | `PRÊT_NON_EXÉCUTÉ` | `security/reports/sonar-analysis.md` |
| Gitleaks secret scan | `PRÊT_NON_EXÉCUTÉ` | `security/reports/gitleaks.json`, findings=n/a |
| Trivy filesystem scan | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `security/reports/trivy-fs.json`, vulnerabilities=n/a |
| Trivy image scan | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `artifacts/release/image-scan-summary.txt` |
| SBOM Syft | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `artifacts/release/sbom-summary.txt`, sbom_count=0, expected=5 |
| SBOM Cosign attestation | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `artifacts/release/attest-summary.txt` |
| Cosign sign | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `artifacts/release/sign-summary.txt` |
| Cosign verify | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `artifacts/release/verify-summary.txt` |
| Digest promotion | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `artifacts/release/promotion-digests.txt` |
| Release attestation | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `artifacts/release/release-attestation.json` |
| SLSA-style provenance | `PRÊT_NON_EXÉCUTÉ` | `artifacts/release/provenance.slsa.md` |
| Kubernetes ultra hardening static | `TERMINÉ` | `artifacts/security/k8s-ultra-hardening.md` |
| Official scope / legacy exclusion | `TERMINÉ` | `artifacts/final/official-scope-report.md` |
| Runtime security post-deployment | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `artifacts/security/runtime-security-postdeploy.md` |
| Kubernetes production HA static | `TERMINÉ` | `artifacts/security/production-ha-readiness.md` |
| Production runtime evidence | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `artifacts/validation/production-runtime-evidence.md` |
| Runtime image rollout proof | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `artifacts/validation/runtime-image-rollout-proof.md` |
| Jenkins webhook/API proof | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `artifacts/validation/jenkins-webhook-proof.md` |
| Jenkins CI push proof | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `artifacts/validation/jenkins-ci-push-proof.md` |
| Kyverno Enforce admission proof | `PRÊT_NON_EXÉCUTÉ` | `artifacts/validation/kyverno-enforce-proof.md` |
| GitOps Argo CD sync | `PRÊT_NON_EXÉCUTÉ` | `artifacts/gitops/argocd-sync.md` |
| Runtime detection audit | `PRÊT_NON_EXÉCUTÉ` | `artifacts/security/runtime-detection-proof.md` |
| Observability SLO summary | `PRÊT_NON_EXÉCUTÉ` | `artifacts/observability/slo-summary.md` |
| Production data resilience | `PRÊT_NON_EXÉCUTÉ` | `artifacts/security/production-data-resilience.md` |
| Production Dockerfiles | `TERMINÉ` | `artifacts/security/production-dockerfiles.md` |
| Image size evidence | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `artifacts/security/image-size-evidence.md` |
| Secrets management | `PRÊT_NON_EXÉCUTÉ` | `artifacts/security/secrets-management.md` |
| Production readiness campaign | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `artifacts/final/production-readiness-final.md` |
| Kyverno policy CLI validation | `PRÊT_NON_EXÉCUTÉ` | `artifacts/security/kyverno-policy-validation.md` |
| Metrics Server runtime | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `kubectl top pods -n securerag-hub` |
| Kyverno runtime | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `kubectl get clusterpolicies` |
| Kyverno reports | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `kubectl get policyreports -A` |
| Application workloads | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `kubectl get pods -n securerag-hub` |

## 2. Honest interpretation

- `TERMINÉ` means all expected evidence rows are proven, or the runtime command succeeds in the current environment.
- `PARTIEL` means a control was executed or partially evidenced, but the resulting evidence is incomplete, failed, skipped or inconsistent.
- `PRÊT_NON_EXÉCUTÉ` means the repository-side control is ready but has not been replayed in the final evidence environment.
- `DÉPENDANT_DE_L_ENVIRONNEMENT` means the control needs an active Docker/kind/Kubernetes/Jenkins/Cosign/Syft/Kyverno runtime.

## 3. Security-ready reading

SecureRAG Hub is security-ready for a defended Laravel demo when SAST, Sonar scope validation, secret scanning, filesystem scanning, Laravel authorization tests, Kubernetes render checks, and final proof scripts pass. It becomes supply-chain-ready only after Trivy image scanning, SBOM generation, SBOM attestation, Cosign signing, Cosign verification and digest promotion evidence are regenerated in the target environment for the official service set.
