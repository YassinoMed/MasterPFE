# Security Posture Report — SecureRAG Hub

- Generated at UTC: `2026-04-14T23:38:08Z`
- Git commit: `ea2440c357444b99b40c8334381b61455d9a752b`
- Kubernetes namespace: `securerag-hub`

## 1. Security controls status

| Control | State | Evidence |
|---|---|---|
| Semgrep SAST | `TERMINÉ` | `security/reports/semgrep.json`, findings=0 |
| Gitleaks secret scan | `PARTIEL` | `security/reports/gitleaks.json`, findings=n/a |
| Trivy filesystem scan | `PARTIEL` | `security/reports/trivy-fs.json`, vulnerabilities=n/a |
| SBOM Syft | `PARTIEL` | `artifacts/release/sbom-summary.txt`, sbom_count=0 |
| Cosign sign | `PARTIEL` | `artifacts/release/sign-summary.txt` |
| Cosign verify | `PARTIEL` | `artifacts/release/verify-summary.txt` |
| Digest promotion | `PARTIEL` | `artifacts/release/promotion-digests.txt` |
| Release attestation | `TERMINÉ` | `artifacts/release/release-attestation.json` |
| Metrics Server runtime | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `kubectl top pods -n securerag-hub` |
| Kyverno runtime | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `kubectl get clusterpolicies` |
| Kyverno reports | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `kubectl get policyreports -A` |
| Application workloads | `DÉPENDANT_DE_L_ENVIRONNEMENT` | `kubectl get pods -n securerag-hub` |

## 2. Honest interpretation

- `TERMINÉ` means the evidence file exists locally or the runtime command succeeds in the current environment.
- `PARTIEL` means the control is scripted/configured but the expected evidence file is not present yet.
- `DÉPENDANT_DE_L_ENVIRONNEMENT` means the control needs an active Docker/kind/Kubernetes/Jenkins/Cosign/Syft/Kyverno runtime.

## 3. Security-ready reading

SecureRAG Hub is security-ready for a defended demo when SAST, secret scanning, filesystem scanning, Laravel authorization tests, Kubernetes render checks, and final proof scripts pass. It becomes supply-chain-ready only after SBOM, Cosign signing, Cosign verification and digest promotion evidence are regenerated in the target environment.
