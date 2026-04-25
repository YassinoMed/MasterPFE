# SecureRAG Hub Expert Production Readiness

This runbook upgrades the existing production-like proof into an expert,
operable platform without replacing Jenkins.

## Authority model

| Layer | Authority |
|---|---|
| CI, scan, SBOM, sign, attest | Jenkins |
| Deployment intent | Git digest files |
| Cluster sync | Argo CD |
| Admission control | Kyverno Audit, then Enforce |
| Secrets | SOPS/age first, External Secrets or Vault later |
| Observability | Prometheus, Grafana, Loki, Alertmanager |

## Safe execution order

1. `make cluster-registry-setup`
2. push/promote/sign images with `REGISTRY_HOST=127.0.0.1:5002`
3. `make cluster-registry-proof`
4. `make gitops-update-digests`
5. install Argo CD and apply `infra/gitops/argocd/securerag-hub-application.yaml`
6. keep Kyverno in Audit until registry, signatures and digest deployment are proven
7. run `APPLY_ENFORCE=true make kyverno-enforce-proof`
8. operate SOPS/age and archive the secret rotation proof
9. install the observability stack and archive the four SRE reports
10. regenerate the final support pack

## Non-negotiable gates

- Do not mark Enforce as complete without a positive signed digest admission
  and a negative rejection proof.
- Do not commit plaintext secrets.
- Do not enable destructive chaos or node drain checks without explicit flags.
- Keep `localhost:5001` only for demo and local fallback.
