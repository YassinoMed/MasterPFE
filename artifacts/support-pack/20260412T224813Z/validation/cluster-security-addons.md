# Cluster Security Addons Validation

- Generated at: `2026-04-12T22:48:11Z`
- Namespace: `securerag-hub`

| Component | Status | Evidence |
|---|---:|---|
| metrics-server | PARTIAL | Metrics APIService not detected |
| HPA | OK | HPA objects are present |
| Kyverno | PARTIAL | Kyverno CRD not detected |
| Kyverno policies | PARTIAL | ClusterPolicy resources unavailable or Kyverno not installed |

## Kubernetes context

```text
kind-securerag-dev
```

## Metrics APIService

```text
Error from server (NotFound): apiservices.apiregistration.k8s.io "v1beta1.metrics.k8s.io" not found
```

## Metrics server pods

```text
No resources found in kube-system namespace.
```

## Node metrics

```text
error: Metrics API not available
```

## SecureRAG pod metrics

```text
error: Metrics API not available
```

## HPA status

```text
NAME          REFERENCE                TARGETS              MINPODS   MAXPODS   REPLICAS   AGE
api-gateway   Deployment/api-gateway   cpu: <unknown>/70%   1         3         1          2d4h
portal-web    Deployment/portal-web    cpu: <unknown>/70%   1         3         1          2d4h
```

## Kyverno pods

```text
No resources found in kyverno namespace.
```

## Kyverno policies

```text
error: the server doesn't have a resource type "clusterpolicy"
```

## Kyverno policy reports

```text
error: the server doesn't have a resource type "policyreport"
```
