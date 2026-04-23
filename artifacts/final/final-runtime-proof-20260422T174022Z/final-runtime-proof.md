# Final Runtime Proof - SecureRAG Hub

- Generated at UTC: `2026-04-22T17:40:22Z`
- Namespace: `securerag-hub`
- Registry: `localhost:5001`
- Image prefix: `securerag-hub`
- Image tag: `dev`
- Digest record file: `artifacts/release/promotion-digests.txt`
- Require digest deploy: `false`
- RUN_METRICS_REFRESH: `true`
- RUN_KYVERNO_REFRESH: `true`
- STRICT_FINAL_RUNTIME: `false`

## Results

| Block | Task | Status | Evidence | Note |
|---|---|---:|---|---|
| Preflight | Kubernetes context | TERMINÉ | `artifacts/final/final-runtime-proof-20260422T174022Z/snapshots/preflight-kubernetes-context.txt` | Snapshot archive |
| Preflight | Nodes | TERMINÉ | `artifacts/final/final-runtime-proof-20260422T174022Z/snapshots/preflight-nodes.txt` | Snapshot archive |
| Preflight | Workloads | TERMINÉ | `artifacts/final/final-runtime-proof-20260422T174022Z/snapshots/preflight-workloads.txt` | Snapshot archive |
| Bloc A | Runtime imageID proof | PARTIEL | `artifacts/final/final-runtime-proof-20260422T174022Z/logs/bloc-a-runtime-imageid-proof.log` | Voir le log |
| Bloc A | Runtime imageIDs | TERMINÉ | `artifacts/final/final-runtime-proof-20260422T174022Z/snapshots/bloc-a-runtime-imageids.txt` | Snapshot archive |
| Bloc A | metrics-server install repair | TERMINÉ | `artifacts/final/final-runtime-proof-20260422T174022Z/logs/bloc-a-metrics-server-install-repair.log` | Commande terminee |
| Bloc A | HPA convergence without unknown | TERMINÉ | `artifacts/final/final-runtime-proof-20260422T174022Z/logs/bloc-a-hpa-convergence-without-unknown.log` | Commande terminee |
| Bloc A | Strict HPA runtime report | TERMINÉ | `artifacts/final/final-runtime-proof-20260422T174022Z/logs/bloc-a-strict-hpa-runtime-report.log` | Commande terminee |
| Bloc A | kubectl top nodes | TERMINÉ | `artifacts/final/final-runtime-proof-20260422T174022Z/snapshots/bloc-a-kubectl-top-nodes.txt` | Snapshot archive |
| Bloc A | kubectl top pods | TERMINÉ | `artifacts/final/final-runtime-proof-20260422T174022Z/snapshots/bloc-a-kubectl-top-pods.txt` | Snapshot archive |
| Bloc A | HPA wide | TERMINÉ | `artifacts/final/final-runtime-proof-20260422T174022Z/snapshots/bloc-a-hpa-wide.txt` | Snapshot archive |
| Bloc A | Kyverno Audit install with webhook retry | TERMINÉ | `artifacts/final/final-runtime-proof-20260422T174022Z/logs/bloc-a-kyverno-audit-install-with-webhook-retry.log` | Commande terminee |
| Bloc A | Kyverno PolicyReports ready | TERMINÉ | `artifacts/final/final-runtime-proof-20260422T174022Z/logs/bloc-a-kyverno-policyreports-ready.log` | Commande terminee |
| Bloc A | Strict Kyverno runtime report | TERMINÉ | `artifacts/final/final-runtime-proof-20260422T174022Z/logs/bloc-a-strict-kyverno-runtime-report.log` | Commande terminee |
| Bloc A | Kyverno Enforce readiness report | TERMINÉ | `artifacts/final/final-runtime-proof-20260422T174022Z/logs/bloc-a-kyverno-enforce-readiness-report.log` | Commande terminee |
| Bloc A | Kyverno pods | TERMINÉ | `artifacts/final/final-runtime-proof-20260422T174022Z/snapshots/bloc-a-kyverno-pods.txt` | Snapshot archive |
| Bloc A | Kyverno policies reports | TERMINÉ | `artifacts/final/final-runtime-proof-20260422T174022Z/snapshots/bloc-a-kyverno-policies-reports.txt` | Snapshot archive |
| Bloc A | Production runtime evidence | TERMINÉ | `artifacts/final/final-runtime-proof-20260422T174022Z/logs/bloc-a-production-runtime-evidence.log` | Commande terminee |
| Bloc A | Runtime security post-deploy | TERMINÉ | `artifacts/final/final-runtime-proof-20260422T174022Z/logs/bloc-a-runtime-security-post-deploy.log` | Commande terminee |
| Bloc A | Observability snapshot | TERMINÉ | `artifacts/final/final-runtime-proof-20260422T174022Z/logs/bloc-a-observability-snapshot.log` | Commande terminee |
| Bloc A | Security posture refresh | TERMINÉ | `artifacts/final/final-runtime-proof-20260422T174022Z/logs/bloc-a-security-posture-refresh.log` | Commande terminee |
| Bloc A | Final source of truth refresh | TERMINÉ | `artifacts/final/final-runtime-proof-20260422T174022Z/logs/bloc-a-final-source-of-truth-refresh.log` | Commande terminee |
| Bloc A | Final validation summary refresh | TERMINÉ | `artifacts/final/final-runtime-proof-20260422T174022Z/logs/bloc-a-final-validation-summary-refresh.log` | Commande terminee |
| Bloc A | Support pack refresh | TERMINÉ | `artifacts/final/final-runtime-proof-20260422T174022Z/logs/bloc-a-support-pack-refresh.log` | Commande terminee |

## Key artifacts

- Runtime image proof: `artifacts/validation/runtime-image-rollout-proof.md`
- HPA runtime proof: `artifacts/validation/hpa-runtime-report.md`
- Kyverno runtime proof: `artifacts/validation/kyverno-runtime-report.md`
- Kyverno Enforce readiness: `artifacts/validation/kyverno-enforce-readiness.md`
- Runtime security post-deploy: `artifacts/security/runtime-security-postdeploy.md`
- Kyverno local registry blocker: `artifacts/validation/kyverno-local-registry-enforce-blocker.md`
- Production runtime evidence: `artifacts/validation/production-runtime-evidence.md`
- Observability snapshot: `artifacts/observability/observability-snapshot.md`
- Final validation summary: `artifacts/final/final-validation-summary.md`
- Support pack root: `artifacts/support-pack/`

## Honest reading

- `TERMINÉ` means the evidence was generated in this run.
- `PARTIEL` means the command ran but found an incomplete runtime state.
- `PRÊT_NON_EXÉCUTÉ` means an optional mutation was intentionally skipped.
- `DÉPENDANT_DE_L_ENVIRONNEMENT` remains possible only when the cluster or tools are unavailable.
