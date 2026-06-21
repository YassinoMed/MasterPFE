# Security Posture Report — SecureRAG Hub

- Generated at UTC: `2026-06-17T21:51:07Z`
- Git commit: `5029fb224ddc6e06f65049dabc838c592d962971`
- Kubernetes namespace: `securerag-hub`

## 1. Security controls status

| Control | State | Evidence |
|---|---|---|
| Semgrep SAST | `TERMINÉ` | `security/reports/semgrep.json`, findings=0 |
| Sonar CPD scope | `TERMINÉ` | `artifacts/security/sonar-cpd-scope.md` |
| Sonar Quality Gate | `TERMINÉ` | `security/reports/sonar-analysis.md` |
| Gitleaks secret scan | `TERMINÉ` | `security/reports/gitleaks.json`, findings=0 |
| Trivy filesystem scan | `TERMINÉ` | `security/reports/trivy-fs.json`, vulnerabilities=84 |
| Trivy image scan | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `artifacts/release/image-scan-summary.txt` |
| SBOM Syft | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `artifacts/release/sbom-summary.txt`, sbom_count=0, expected=5 |
| SBOM Cosign attestation | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `artifacts/release/attest-summary.txt` |
| Cosign sign | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `artifacts/release/sign-summary.txt` |
| Cosign verify | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `artifacts/release/verify-summary.txt` |
| Digest promotion | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `artifacts/release/promotion-digests.txt` |
| Release attestation | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `artifacts/release/release-attestation.json` |
| SLSA-style provenance | `PRÊT_NON_EXÉCUTÉ` | `artifacts/release/provenance.slsa.md` |
| Kubernetes ultra hardening static | `TERMINÉ` | `artifacts/security/k8s-ultra-hardening.md` |
| Runtime security post-deployment | `PARTIEL` | `artifacts/security/runtime-security-postdeploy.md` |
| Kubernetes production HA static | `TERMINÉ` | `artifacts/security/production-ha-readiness.md` |
| Production runtime evidence | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `artifacts/validation/production-runtime-evidence.md` |
| Runtime image rollout proof | `PARTIEL` | `artifacts/validation/runtime-image-rollout-proof.md` |
| Jenkins webhook proof | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `artifacts/jenkins/github-webhook-validation.md` |
| Jenkins CI push proof | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `artifacts/jenkins/ci-push-trigger-proof.md` |
| Kyverno Enforce local registry blocker | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `artifacts/validation/kyverno-local-registry-enforce-blocker.md` |
| Production data resilience | `PRÊT_NON_EXÉCUTÉ` | `artifacts/security/production-data-resilience.md` |
| Production Dockerfiles | `TERMINÉ` | `artifacts/security/production-dockerfiles.md` |
| Image size evidence | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `artifacts/security/image-size-evidence.md` |
| Secrets management | `PRÊT_NON_EXÉCUTÉ` | `artifacts/security/secrets-management.md` |
| Production readiness campaign | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `artifacts/final/production-readiness-final.md` |
| Kyverno policy CLI validation | `FAIL` | `artifacts/security/kyverno-policy-validation.md` |
| Metrics Server runtime | `TERMINÉ` | `kubectl top pods -n securerag-hub` |
| Kyverno runtime | `TERMINÉ` | `kubectl get clusterpolicies` |
| Kyverno reports | `TERMINÉ` | `kubectl get policyreports -A` |
| Application workloads | `TERMINÉ` | `kubectl get pods -n securerag-hub` |

## 2. Honest interpretation

- `TERMINÉ` means all expected evidence rows are proven, or the runtime command succeeds in the current environment.
- `PARTIEL` means a control was executed or partially evidenced, but the resulting evidence is incomplete, failed, skipped or inconsistent.
- `PRÊT_NON_EXÉCUTÉ` means the repository-side control is ready but has not been replayed in the final evidence environment.
- `DÉPENDANT_DE_L_ENVIRONNEMENT` means the control needs an active Docker/kind/Kubernetes/Jenkins/Cosign/Syft/Kyverno runtime.

## 3. Security-ready reading

SecureRAG Hub is security-ready for a defended Laravel demo when SAST, Sonar scope validation, secret scanning, filesystem scanning, Laravel authorization tests, Kubernetes render checks, and final proof scripts pass. It becomes supply-chain-ready only after Trivy image scanning, SBOM generation, SBOM attestation, Cosign signing, Cosign verification and digest promotion evidence are regenerated in the target environment for the official service set.
