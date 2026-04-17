# Production Readiness Final Campaign - SecureRAG Hub

- Generated at UTC: `2026-04-17T06:27:11Z`
- Namespace: `securerag-hub`
- Overlay: `infra/k8s/overlays/production`
- RUN_MUTATING: `false`

| Bloc | Task | Status | Evidence |
|---|---|---:|---|
| A | Render production overlay | TERMINÉ | /tmp/securerag-production-campaign.yaml |
| A | Static HA validation | TERMINÉ | artifacts/security/production-ha-readiness.md |
| A | Deploy production overlay | PRÊT_NON_EXÉCUTÉ | Set RUN_DEPLOY_PRODUCTION=true |
| A | Collect production runtime evidence | DÉPENDANT_DE_L_ENVIRONNEMENT | artifacts/validation/production-runtime-evidence.md |
| A | Rollout restart proof | PRÊT_NON_EXÉCUTÉ | Set RUN_ROLLOUT_RESTART=true |
| A | Node drain proof | PRÊT_NON_EXÉCUTÉ | Set RUN_NODE_DRAIN=true only on a disposable multi-node cluster |
| B | Install metrics-server | PRÊT_NON_EXÉCUTÉ | Set RUN_INSTALL_METRICS=true |
| B | Validate HPA and metrics runtime | DÉPENDANT_DE_L_ENVIRONNEMENT | artifacts/validation/cluster-security-addons.md |
| C | Install Kyverno Audit | PRÊT_NON_EXÉCUTÉ | Set RUN_INSTALL_KYVERNO_AUDIT=true |
| C | Kyverno policy static validation | TERMINÉ | artifacts/security/kyverno-policy-validation.md |
| D | Supply chain execute | PRÊT_NON_EXÉCUTÉ | Set RUN_SUPPLY_CHAIN=true; current attestation is factual only |
| E | Data resilience readiness | PARTIEL | artifacts/security/production-data-resilience.md |
| F | Observability snapshot | TERMINÉ | artifacts/observability/observability-snapshot.md |
| F | Support pack | TERMINÉ | artifacts/support-pack/production-readiness-20260417T062712Z |

## Reading guide

- `TERMINÉ` means the control executed successfully or the static validation passed.
- `PARTIEL` means implementation exists but proof is incomplete or failed.
- `PRÊT_NON_EXÉCUTÉ` means the step is ready but intentionally not executed in this run.
- `DÉPENDANT_DE_L_ENVIRONNEMENT` means Docker, kind, kubectl, registry, Trivy, Syft, Cosign, Kyverno, metrics-server or a reachable cluster is required.
