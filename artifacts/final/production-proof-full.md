# Production Proof Full - SecureRAG Hub

- Generated at UTC: `2026-04-20T04:51:36Z`
- RUN_CLUSTER_MUTATIONS: `false`

| Step | Status | Evidence |
|---|---:|---|
| production-cluster-clean | DÉPENDANT_DE_L_ENVIRONNEMENT | `artifacts/final/production-proof-production-cluster-clean.log`, `artifacts/validation/production-cluster-clean.md` |
| hpa-runtime-readonly | DÉPENDANT_DE_L_ENVIRONNEMENT | `artifacts/final/production-proof-hpa-runtime-readonly.log`, `artifacts/validation/hpa-runtime-report.md` |
| kyverno-runtime-proof | DÉPENDANT_DE_L_ENVIRONNEMENT | `artifacts/final/production-proof-kyverno-runtime-proof.log`, `artifacts/validation/kyverno-runtime-report.md` |
| kyverno-enforce-readiness | DÉPENDANT_DE_L_ENVIRONNEMENT | `artifacts/final/production-proof-kyverno-enforce-readiness.log`, `artifacts/validation/kyverno-enforce-readiness.md` |
| production-runtime-evidence | DÉPENDANT_DE_L_ENVIRONNEMENT | `artifacts/final/production-proof-production-runtime-evidence.log`, `artifacts/validation/production-runtime-evidence.md` |
| ha-chaos-lite-readonly | DÉPENDANT_DE_L_ENVIRONNEMENT | `artifacts/final/production-proof-ha-chaos-lite-readonly.log`, `artifacts/validation/ha-chaos-lite-report.md` |
| observability-snapshot | TERMINÉ | `artifacts/final/production-proof-observability-snapshot.log`, `artifacts/observability/observability-snapshot.md` |
| security-posture | DÉPENDANT_DE_L_ENVIRONNEMENT | `artifacts/final/production-proof-security-posture.log`, `artifacts/security/security-posture-report.md` |
| support-pack | TERMINÉ | `artifacts/final/production-proof-support-pack.log`, `artifacts/support-pack` |

## Reading guide

- Default mode avoids cluster mutations.
- Set `RUN_CLUSTER_MUTATIONS=true` to install/repair metrics-server and install Kyverno Audit.
- Pod deletion, rollout restart and node drain remain controlled by `validate-ha-chaos-lite.sh` variables.
