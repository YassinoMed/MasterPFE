# Cluster Security Addons Validation

- Generated at: `2026-04-12T22:11:47Z`
- Namespace: `securerag-hub`

| Component | Status | Evidence |
|---|---:|---|
| Kubernetes API | PARTIAL | API server unreachable from this environment |
| metrics-server | PARTIAL | Cannot validate without a reachable cluster |
| HPA | PARTIAL | Cannot validate without a reachable cluster |
| Kyverno | PARTIAL | Cannot validate without a reachable cluster |

## Diagnostic

```text
kubectl is installed, but the Kubernetes API is not reachable.
Context: kind-securerag-dev
Action: start kind or export a valid kubeconfig, then rerun make cluster-security-proof.
```
