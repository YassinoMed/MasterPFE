# Kyverno Cosign Enforce Local Registry Blocker

- Generated at UTC: `2026-04-25T20:06:13Z`
- Namespace: `securerag-hub`
- Affected policy: `securerag-verify-cosign-images`
- Status: `DÉPENDANT_DE_L_ENVIRONNEMENT`

## Finding

The Kubernetes API is unreachable in the current environment, so Kyverno workload image references and `verifyImages` Enforce readiness cannot be proven.

## Decision

Treat local-registry Enforce readiness as environment-dependent until a reachable cluster context is available and the runtime proof can inspect live Deployment image references.
