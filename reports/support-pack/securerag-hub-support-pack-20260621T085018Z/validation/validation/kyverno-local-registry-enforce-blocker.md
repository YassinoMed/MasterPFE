# Kyverno Cosign Enforce Local Registry Blocker

- Generated at UTC: `2026-06-21T08:50:15Z`
- Namespace: `securerag-hub`
- Registry reference used by workloads: `localhost:5001/securerag-hub-audit-security-service:dev, localhost:5001/securerag-hub-auth-users:dev, localhost:5001/securerag-hub-chatbot-manager:dev, localhost:5001/securerag-hub-conversation-service:dev, localhost:5001/securerag-hub-portal-web:dev`
- Affected policy: `securerag-verify-cosign-images`
- Status: `DÉPENDANT_DE_L_ENVIRONNEMENT`

## Finding

Kyverno admission runs inside the cluster. For workload images referenced with `localhost` or another loopback address, `verifyImages` Enforce cannot reach the same registry endpoint that is reachable from the host.

## Decision

Keep `securerag-verify-cosign-images` in Audit for the local kind registry, and keep host-side Cosign verification and digest deploy as the blocking release gate.
