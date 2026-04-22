# SecureRAG Hub - High-Level Improvements Roadmap

## Baseline

SecureRAG Hub already has a strong DevSecOps repository baseline:

- `TERMINÉ` cote depot: la chaine est concue, automatisee, versionnee et documentee.
- `DÉPENDANT_DE_L_ENVIRONNEMENT`: la preuve runtime finale, la release finale, Kyverno live, la DB externe et Jenkins live.
- `PRÊT_NON_EXÉCUTÉ`: la modernisation secrets type SOPS/ESO/Vault.
- `PARTIEL`: la demonstration live tant que le cluster cible n'est pas proprement rejoue.

The next step is not to add random tooling. The goal is to close the environment-dependent gaps and move the platform from `production-like` to a more credible cloud-grade operating model.

## Strategic target

At high level, the project should evolve along five major axes:

1. Move from local-kind constraints to a cluster-reachable runtime platform.
2. Make the supply chain enforceable end to end, not only provable from the host.
3. Upgrade runtime security from hardening-only to hardening plus detection.
4. Modernize secret delivery and data resilience.
5. Strengthen observability, rollback safety and platform governance.

## Prioritized roadmap

| Priority | Improvement | Why it matters | Concrete target | Honest status today | Recommended next move |
|---|---|---|---|---|---|
| P0 | Replace loopback registry with cluster-reachable registry | Unblocks Kyverno Enforce, cleaner release proofs, better cloud realism | Harbor, GHCR, GitLab Registry, ECR/GAR/ACR | `DÉPENDANT_DE_L_ENVIRONNEMENT` | Expose a real registry endpoint reachable from nodes and Kyverno pods |
| P0 | Replay final release on a healthy target cluster | Converts repository readiness into runtime proof | Healthy Kubernetes cluster, replayed final campaign | `PARTIEL` | Recreate or stabilize the target cluster, then rerun final runtime and release proofs |
| P0 | Enforce immutable release promotion across environments | Makes the release path auditable and reproducible | `dev -> staging -> production` by digest only | `TERMINÉ` cote depot | Add a staging promotion gate and archive evidence for each promotion step |
| P0 | Move PostgreSQL to an external runtime | Removes local SQLite/runtime shortcuts and improves operational credibility | Managed PostgreSQL or dedicated VM/service | `DÉPENDANT_DE_L_ENVIRONNEMENT` | Deploy `production-external-db`, create secret, run backup and restore proof |
| P1 | Introduce modern secret delivery | Reduces manual secret handling and improves rotation/auditability | SOPS/age for Git-encrypted secrets or ESO/Vault in runtime | `PRÊT_NON_EXÉCUTÉ` | Choose one target pattern and implement it end to end |
| P1 | Add full observability stack | Turns proofs into continuous operations | Prometheus, Grafana, Alertmanager, Loki | `PARTIEL` | Start with Prometheus + Grafana + basic alerts, then add Loki |
| P1 | Add runtime threat detection | Goes beyond preventive hardening | Falco or Tetragon | `PRÊT_NON_EXÉCUTÉ` | Deploy in Audit-style mode first, then tune rules on key namespaces |
| P1 | Upgrade rollout strategy | Reduces release risk | Canary or blue/green via Argo Rollouts | `PRÊT_NON_EXÉCUTÉ` | Keep current rolling update, then introduce canary for `portal-web` first |
| P2 | Adopt GitOps | Improves drift control and auditability | Argo CD or Flux | `PRÊT_NON_EXÉCUTÉ` | Start with read-only sync on overlays, then promote by PR |
| P2 | Strengthen compliance mapping | Makes the project stronger for audit and soutenance | NIST SSDF, CIS Kubernetes, OWASP ASVS mapping | `PARTIEL` | Extend the control matrix with explicit proof references and residual risks |
| P2 | Formalize SRE operating model | Shifts from deployment to sustained operations | SLOs, error budgets, incident drills, recovery exercises | `PARTIEL` | Add service-level indicators and one tested incident exercise |

## Recommended execution order

### P0 - close the structural blockers

- Stabilize or recreate the target cluster.
- Replace `localhost:5001` with a registry reachable from the cluster.
- Replay the full final release campaign on that cluster.
- Externalize PostgreSQL and run backup/restore proof.

### P1 - modernize operations

- Choose and operate a modern secret-delivery approach.
- Add Prometheus, Grafana and Alertmanager.
- Introduce runtime threat detection.
- Add progressive delivery for the most exposed workload.

### P2 - scale the platform model

- Move to GitOps for environment reconciliation.
- Expand the control matrix into a compliance view.
- Formalize SRE indicators, drills and governance.

## Executive summary

If only three high-level improvements can be implemented, the strongest sequence is:

1. real registry + healthy runtime cluster;
2. external PostgreSQL + tested backup/restore;
3. modern secrets + observability stack.

That sequence closes the most important credibility gaps without undoing the strong work already completed in the repository.
