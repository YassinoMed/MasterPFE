# Security Posture Report — SecureRAG Hub

- Generated at UTC: `2026-04-17T06:18:31Z`
- Git commit: `7a030e6bf014787eabf6b4d5415713629f9aa019`
- Kubernetes namespace: `securerag-hub`

## 1. Security controls status

| Control | State | Evidence |
|---|---|---|
| Semgrep SAST | `TERMINÉ` | `security/reports/semgrep.json`, findings=0 |
| Sonar CPD scope | `TERMINÉ` | `artifacts/security/sonar-cpd-scope.md` |
| Sonar Quality Gate | `PRÊT_NON_EXÉCUTÉ` | `security/reports/sonar-analysis.md` |
| Gitleaks secret scan | `PARTIEL` | `security/reports/gitleaks.json`, findings=n/a |
| Trivy filesystem scan | `PARTIEL` | `security/reports/trivy-fs.json`, vulnerabilities=n/a |
| Trivy image scan | `PARTIEL` | `artifacts/release/image-scan-summary.txt` |
| SBOM Syft | `PARTIEL` | `artifacts/release/sbom-summary.txt`, sbom_count=0, expected=5 |
| SBOM Cosign attestation | `PARTIEL` | `artifacts/release/attest-summary.txt` |
| Cosign sign | `PARTIEL` | `artifacts/release/sign-summary.txt` |
| Cosign verify | `PARTIEL` | `artifacts/release/verify-summary.txt` |
| Digest promotion | `PARTIEL` | `artifacts/release/promotion-digests.txt` |
| Release attestation | `PARTIEL` | `artifacts/release/release-attestation.json` |
| Kubernetes ultra hardening static | `TERMINÉ` | `artifacts/security/k8s-ultra-hardening.md` |
| Kubernetes production HA static | `TERMINÉ` | `artifacts/security/production-ha-readiness.md` |
| Production runtime evidence | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `artifacts/validation/production-runtime-evidence.md` |
| Kyverno policy CLI validation | `PRÊT_NON_EXÉCUTÉ` | `artifacts/security/kyverno-policy-validation.md` |
| Metrics Server runtime | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `kubectl top pods -n securerag-hub` |
| Kyverno runtime | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `kubectl get clusterpolicies` |
| Kyverno reports | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `kubectl get policyreports -A` |
| Application workloads | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `kubectl get pods -n securerag-hub` |

## 2. Honest interpretation

- `TERMINÉ` means all expected evidence rows are proven, or the runtime command succeeds in the current environment.
- `PARTIEL` means the control is scripted/configured but the expected evidence is missing, incomplete, failed, skipped or partial.
- `DÉPENDANT_DE_L_ENVIRONNEMENT` means the control needs an active Docker/kind/Kubernetes/Jenkins/Cosign/Syft/Kyverno runtime.

## 3. Security-ready reading

SecureRAG Hub is security-ready for a defended Laravel demo when SAST, Sonar scope validation, secret scanning, filesystem scanning, Laravel authorization tests, Kubernetes render checks, and final proof scripts pass. It becomes supply-chain-ready only after Trivy image scanning, SBOM generation, SBOM attestation, Cosign signing, Cosign verification and digest promotion evidence are regenerated in the target environment for the official service set.
