# Observability Snapshot - SecureRAG Hub

- Generated at: `2026-04-17T06:27:12Z`
- Namespace: `securerag-hub`
- Jenkins URL: `http://localhost:8085`

## Scope

This report captures runtime observability evidence without mutating the cluster. It complements, but does not replace, a full Prometheus/Grafana/Loki stack.

## Kubernetes runtime

```text
kubectl is installed, but the Kubernetes API is not reachable from this environment.
Context: kind-securerag-dev
Diagnostic: start kind or export a valid kubeconfig, then rerun make observability-snapshot.
```

## Jenkins login endpoint

```text
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
curl: (7) Failed to connect to localhost port 8085 after 0 ms: Couldn't connect to server
```

## Reading guide

- If `kubectl top` fails, metrics-server is not ready or not installed.
- If HPA targets are `<unknown>`, metrics-server is not feeding resource metrics.
- If Kyverno policy reports are absent, Kyverno is not installed or policies have not generated reports yet.
- For the official demo, this snapshot is enough for a factual runtime proof. Prometheus/Grafana/Loki remain an optional expert extension.
