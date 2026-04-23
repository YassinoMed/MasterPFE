# Kyverno Cosign Enforce Local Registry Blocker

- Generated at UTC: `2026-04-23T14:28:27Z`
- Namespace: `securerag-hub`
- Registry reference used by workloads: `localhost:5001/securerag-hub-audit-security-service:production, localhost:5001/securerag-hub-auth-users:production, localhost:5001/securerag-hub-chatbot-manager:production, localhost:5001/securerag-hub-conversation-service:production, localhost:5001/securerag-hub-portal-web:production`
- Affected policy: `securerag-verify-cosign-images`
- Status: `DÉPENDANT_DE_L_ENVIRONNEMENT`

## Finding

Kyverno admission runs inside the cluster. For workload images referenced with `localhost` or another loopback address, `verifyImages` Enforce cannot reach the same registry endpoint that is reachable from the host.

## Decision

Keep `securerag-verify-cosign-images` in Audit for the local kind registry, and keep host-side Cosign verification and digest deploy as the blocking release gate.
