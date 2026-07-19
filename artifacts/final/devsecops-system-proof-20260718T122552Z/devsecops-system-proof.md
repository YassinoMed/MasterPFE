# SecureRAG Hub - DevSecOps System Proof

- Generated at UTC: `2026-07-18T12:25:53Z`
- Namespace: `securerag-hub`
- Registry: `localhost:5001`
- Image prefix: `securerag-hub`
- Image tag: `dev`
- Source image tag: `dev`
- Target image tag: `release-local`
- Kustomize overlay: `infra/k8s/overlays/dev`
- Portal health URL: `http://127.0.0.1:8081/health`
- STRICT: `false`

## Execution results

| Bloc | Test | Etat | Preuve | Note |
|---|---|---:|---|---|
| Preflight | Outils locaux | TERMINÉ | `artifacts/final/devsecops-system-proof-20260718T122552Z/snapshots/preflight-tools.txt` | Les outils manquants rendent certains blocs dependants de l'environnement |
| Preflight | Docker info | TERMINÉ | `artifacts/final/devsecops-system-proof-20260718T122552Z/snapshots/preflight-docker-info.txt` | Snapshot archive |
| Preflight | Disk memory | TERMINÉ | `artifacts/final/devsecops-system-proof-20260718T122552Z/snapshots/preflight-disk-memory.txt` | Snapshot archive |
| Kubernetes | Current context | TERMINÉ | `artifacts/final/devsecops-system-proof-20260718T122552Z/snapshots/kubernetes-current-context.txt` | Snapshot archive |
| Kubernetes | Nodes | TERMINÉ | `artifacts/final/devsecops-system-proof-20260718T122552Z/snapshots/kubernetes-nodes.txt` | Snapshot archive |
| Kubernetes | Workloads | TERMINÉ | `artifacts/final/devsecops-system-proof-20260718T122552Z/snapshots/kubernetes-workloads.txt` | Snapshot archive |
| Kubernetes | Events | TERMINÉ | `artifacts/final/devsecops-system-proof-20260718T122552Z/snapshots/kubernetes-events.txt` | Snapshot archive |
| Bloc A | Runtime imageID rollout proof | TERMINÉ | `artifacts/final/devsecops-system-proof-20260718T122552Z/logs/bloc-a-runtime-imageid-rollout-proof.log` | Commande terminee |
| Bloc A | Runtime imageIDs | TERMINÉ | `artifacts/final/devsecops-system-proof-20260718T122552Z/snapshots/bloc-a-runtime-imageids.txt` | Snapshot archive |
| Bloc B | metrics-server install or repair | PARTIEL | `artifacts/final/devsecops-system-proof-20260718T122552Z/logs/bloc-b-metrics-server-install-or-repair.log` | Voir le log |
| Bloc B | kubectl top nodes | PARTIEL | `artifacts/final/devsecops-system-proof-20260718T122552Z/snapshots/bloc-b-kubectl-top-nodes.txt` | Snapshot incomplet |
| Bloc B | kubectl top pods | PARTIEL | `artifacts/final/devsecops-system-proof-20260718T122552Z/snapshots/bloc-b-kubectl-top-pods.txt` | Snapshot incomplet |
| Bloc B | HPA without unknown | PARTIEL | `artifacts/final/devsecops-system-proof-20260718T122552Z/logs/bloc-b-hpa-without-unknown.log` | Voir le log |
| Bloc B | HPA runtime report | PARTIEL | `artifacts/final/devsecops-system-proof-20260718T122552Z/logs/bloc-b-hpa-runtime-report.log` | Voir le log |
| Bloc D | Kyverno pods | TERMINÉ | `artifacts/final/devsecops-system-proof-20260718T122552Z/snapshots/bloc-d-kyverno-pods.txt` | Snapshot archive |
| Bloc D | Kyverno policies | TERMINÉ | `artifacts/final/devsecops-system-proof-20260718T122552Z/snapshots/bloc-d-kyverno-policies.txt` | Snapshot archive |
| Bloc D | Kyverno CRDs | TERMINÉ | `artifacts/final/devsecops-system-proof-20260718T122552Z/snapshots/bloc-d-kyverno-crds.txt` | Snapshot archive |
| Bloc D | Kyverno runtime report | TERMINÉ | `artifacts/final/devsecops-system-proof-20260718T122552Z/logs/bloc-d-kyverno-runtime-report.log` | Commande terminee |
| Bloc D | Kyverno enforce readiness | TERMINÉ | `artifacts/final/devsecops-system-proof-20260718T122552Z/logs/bloc-d-kyverno-enforce-readiness.log` | Commande terminee |
| Bloc D | PolicyReports present | TERMINÉ | `artifacts/final/devsecops-system-proof-20260718T122552Z/logs/bloc-d-policyreports-present.log` | Commande terminee |
| Bloc C | Supply chain execute | DÉPENDANT_DE_L_ENVIRONNEMENT | `artifacts/final/devsecops-system-proof-20260718T122552Z/devsecops-system-proof.md` | Docker/Trivy/Syft/Cosign ou cles Cosign manquants |
| Bloc C | Supply chain evidence consolidation | TERMINÉ | `artifacts/final/devsecops-system-proof-20260718T122552Z/logs/bloc-c-supply-chain-evidence-consolidation.log` | Commande terminee |
| Bloc C | Release attestation from available evidence | TERMINÉ | `artifacts/final/devsecops-system-proof-20260718T122552Z/logs/bloc-c-release-attestation-from-available-evidence.log` | Commande terminee |
| Bloc C | Release provenance from available evidence | TERMINÉ | `artifacts/final/devsecops-system-proof-20260718T122552Z/logs/bloc-c-release-provenance-from-available-evidence.log` | Commande terminee |
| Bloc C | No-rebuild digest deploy | PRÊT_NON_EXÉCUTÉ | `artifacts/final/devsecops-system-proof-20260718T122552Z/devsecops-system-proof.md` | Digest record absent: artifacts/release/promotion-digests.txt |
| Bloc E | Production external DB readiness | TERMINÉ | `artifacts/final/devsecops-system-proof-20260718T122552Z/logs/bloc-e-production-external-db-readiness.log` | Commande terminee |
| Bloc E | Production data resilience readiness | TERMINÉ | `artifacts/final/devsecops-system-proof-20260718T122552Z/logs/bloc-e-production-data-resilience-readiness.log` | Commande terminee |
| Bloc E | PostgreSQL backup restore proof | DÉPENDANT_DE_L_ENVIRONNEMENT | `artifacts/final/devsecops-system-proof-20260718T122552Z/devsecops-system-proof.md` | DB_HOST/DB_PORT/DB_DATABASE/DB_USERNAME/DB_PASSWORD non definis |
| Bloc F | Production Dockerfiles | TERMINÉ | `artifacts/final/devsecops-system-proof-20260718T122552Z/logs/bloc-f-production-dockerfiles.log` | Commande terminee |
| Bloc F | Image size evidence | TERMINÉ | `artifacts/final/devsecops-system-proof-20260718T122552Z/logs/bloc-f-image-size-evidence.log` | Commande terminee |
| Bloc F | Secrets management | TERMINÉ | `artifacts/final/devsecops-system-proof-20260718T122552Z/logs/bloc-f-secrets-management.log` | Commande terminee |
| Bloc F | Security posture | TERMINÉ | `artifacts/final/devsecops-system-proof-20260718T122552Z/logs/bloc-f-security-posture.log` | Commande terminee |
| Bloc G | Production proof full | TERMINÉ | `artifacts/final/devsecops-system-proof-20260718T122552Z/logs/bloc-g-production-proof-full.log` | Commande terminee |
| Bloc G | Final source of truth | TERMINÉ | `artifacts/final/devsecops-system-proof-20260718T122552Z/logs/bloc-g-final-source-of-truth.log` | Commande terminee |
| Bloc G | Final validation summary | TERMINÉ | `artifacts/final/devsecops-system-proof-20260718T122552Z/logs/bloc-g-final-validation-summary.log` | Commande terminee |
| Bloc G | Support pack | TERMINÉ | `artifacts/final/devsecops-system-proof-20260718T122552Z/logs/bloc-g-support-pack.log` | Commande terminee |

## Key evidence paths

- Runtime image proof: `artifacts/validation/runtime-image-rollout-proof.md`
- HPA runtime proof: `artifacts/validation/hpa-runtime-report.md`
- Kyverno runtime proof: `artifacts/validation/kyverno-runtime-report.md`
- Kyverno Enforce readiness: `artifacts/validation/kyverno-enforce-readiness.md`
- Supply chain evidence: `artifacts/release/supply-chain-evidence.md`
- Release attestation: `artifacts/release/release-attestation.md`
- Provenance: `artifacts/release/provenance.slsa.md`
- Data resilience: `artifacts/security/production-data-resilience.md`
- External DB readiness: `artifacts/security/production-external-db-readiness.md`
- External Secrets runtime: `artifacts/security/external-secrets-runtime.md`
- Final production status: `artifacts/final/production-final-status.md`
- Final release status: `artifacts/final/release-final-status.md`
- Final security status: `artifacts/final/security-final-status.md`
- Evidence manifest: `artifacts/final/devsecops-system-proof-20260718T122552Z/evidence-manifest.txt`

## Honest reading

- `TERMINÉ` means proven in this run.
- `PARTIEL` means the check ran but found a gap or transient readiness issue.
- `PRÊT_NON_EXÉCUTÉ` means the script intentionally skipped the step.
- `DÉPENDANT_DE_L_ENVIRONNEMENT` means a required external dependency was absent.
