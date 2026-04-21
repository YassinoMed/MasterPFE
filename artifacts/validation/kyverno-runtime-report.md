# Kyverno Runtime Report - SecureRAG Hub

- Generated at UTC: `2026-04-21T18:59:26Z`
- Namespace: `securerag-hub`
- Supply chain attestation: `artifacts/release/release-attestation.json`

| Component | Status | Evidence |
|---|---:|---|
| Kubernetes API | DÉPENDANT_DE_L_ENVIRONNEMENT | API server unreachable |

## Diagnostic

Start kind or export a valid kubeconfig, install Kyverno Audit, then rerun:

```bash
make kyverno-runtime-proof
```
