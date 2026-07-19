# Security Posture Report — SecureRAG Hub

- Generated at UTC: `2026-07-18T13:30:01Z`
- Git commit: `d40fb6193d0ed5431c3cab7cf35860344f2cdf7f`
- Kubernetes namespace: `securerag-hub`

## 1. Security controls status

| Control | State | Evidence |
|---|---|---|
| Semgrep SAST | `PRÊT_NON_EXÉCUTÉ` | `security/reports/semgrep.json`, findings=n/a |
| Sonar CPD scope | `TERMINÉ` | `artifacts/security/sonar-cpd-scope.md` |
| Sonar Quality Gate | `FAIL` | `security/reports/sonar-analysis.md` |
| Gitleaks secret scan | `PRÊT_NON_EXÉCUTÉ` | `security/reports/gitleaks.json`, findings=n/a |
| Trivy filesystem scan | `TERMINÉ` | `security/reports/trivy-fs.json`, vulnerabilities=0 |
| Trivy image scan | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `artifacts/release/image-scan-summary.txt` |
| SBOM Syft | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `artifacts/release/sbom-summary.txt`, sbom_count=0, expected=5 |
| SBOM Cosign attestation | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `artifacts/release/attest-summary.txt` |
| Cosign sign | `PARTIEL` | `artifacts/release/sign-summary.txt` |
| Cosign verify | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `artifacts/release/verify-summary.txt` |
| Digest promotion | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `artifacts/release/promotion-digests.txt` |
| Release attestation | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `artifacts/release/release-attestation.json` |
| SLSA-style provenance | `PRÊT_NON_EXÉCUTÉ` | `artifacts/release/provenance.slsa.md` |
| Kubernetes ultra hardening static | `TERMINÉ` | `artifacts/security/k8s-ultra-hardening.md` |
| Runtime security post-deployment | `PARTIEL` | `artifacts/security/runtime-security-postdeploy.md` |
| Kubernetes production HA static | `TERMINÉ` | `artifacts/security/production-ha-readiness.md` |
| Production runtime evidence | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `artifacts/validation/production-runtime-evidence.md` |
| Runtime image rollout proof | `PARTIEL` | `artifacts/validation/runtime-image-rollout-proof.md` |
| Jenkins webhook proof | `PARTIEL` | `artifacts/jenkins/github-webhook-validation.md` |
| Jenkins CI push proof | `TERMINÉ` | `artifacts/jenkins/ci-push-trigger-proof.md` |
| Kyverno Enforce local registry blocker | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `artifacts/validation/kyverno-local-registry-enforce-blocker.md` |
| Production data resilience | `FAIL` | `artifacts/security/production-data-resilience.md` |
| Production Dockerfiles | `TERMINÉ` | `artifacts/security/production-dockerfiles.md` |
| Image size evidence | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `artifacts/security/image-size-evidence.md` |
| Secrets management | `PRÊT_NON_EXÉCUTÉ` | `artifacts/security/secrets-management.md` |
| Production readiness campaign | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `artifacts/final/production-readiness-final.md` |
| Kyverno policy CLI validation | `FAIL` | `artifacts/security/kyverno-policy-validation.md` |
| Metrics Server runtime | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `kubectl top pods -n securerag-hub` |
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
