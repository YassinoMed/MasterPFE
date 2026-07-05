# Kyverno Runtime Report - SecureRAG Hub

- Generated at UTC: `2026-06-21T08:50:14Z`
- Namespace: `securerag-hub`
- Supply chain attestation: `artifacts/release/release-attestation.json`
- Status: `DÉPENDANT_DE_L_ENVIRONNEMENT`

| Component | Status | Evidence |
|---|---:|---|
| Kubernetes API | TERMINÉ | API server reachable |
| Kyverno CRDs | DÉPENDANT_DE_L_ENVIRONNEMENT | missing: clusterpolicies.kyverno.io policyreports.wgpolicyk8s.io clusterpolicyreports.wgpolicyk8s.io |
| Kyverno namespace | DÉPENDANT_DE_L_ENVIRONNEMENT | namespace/kyverno missing |
| Kyverno deployments | DÉPENDANT_DE_L_ENVIRONNEMENT | no Kyverno deployments returned |
| Kyverno Audit policies | PRÊT_NON_EXÉCUTÉ | missing policies: securerag-audit-cleartext-env-values securerag-require-pod-security securerag-require-workload-controls securerag-restrict-image-references securerag-restrict-service-exposure securerag-restrict-volume-types securerag-verify-cosign-images |
| Kyverno PolicyReports | PRÊT_NON_EXÉCUTÉ | no PolicyReport returned yet; wait for Kyverno reports controller or generate workload events |
| Kyverno Enforce readiness | DÉPENDANT_DE_L_ENVIRONNEMENT | local registry references used by workloads are not reachable from Kyverno pods for verifyImages Enforce |
| Kyverno local registry Enforce blocker | DÉPENDANT_DE_L_ENVIRONNEMENT | localhost:5001/securerag-hub-audit-security-service:dev, localhost:5001/securerag-hub-auth-users:dev, localhost:5001/securerag-hub-chatbot-manager:dev, localhost:5001/securerag-hub-conversation-service:dev, localhost:5001/securerag-hub-portal-web:dev |

## Kubernetes context

```text
kind-securerag-dev
```

## Kyverno CRDs

```text
Error from server (NotFound): customresourcedefinitions.apiextensions.k8s.io "clusterpolicies.kyverno.io" not found
Error from server (NotFound): customresourcedefinitions.apiextensions.k8s.io "policyreports.wgpolicyk8s.io" not found
Error from server (NotFound): customresourcedefinitions.apiextensions.k8s.io "clusterpolicyreports.wgpolicyk8s.io" not found
```

## Kyverno deployments

```text
No resources found in kyverno namespace.
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

## SecureRAG deployment images

```text
audit-security-service	localhost:5001/securerag-hub-audit-security-service:dev 
auth-users	localhost:5001/securerag-hub-auth-users:dev 
chatbot-manager	localhost:5001/securerag-hub-chatbot-manager:dev 
conversation-service	localhost:5001/securerag-hub-conversation-service:dev 
portal-web	localhost:5001/securerag-hub-portal-web:dev 
postgres-auth	postgres:16-alpine 
```

## Enforce rule

`Enforce` must not be enabled automatically. It is acceptable only when:

- Kyverno CRDs, deployments and SecureRAG Audit policies are present.
- PolicyReports exist and contain no `fail` or `error` result.
- The supply-chain release attestation is `COMPLETE_PROVEN`.
- The deployed images are the same digests that were signed, verified and promoted.
- No loopback image registry reference such as `localhost:5001` is used by the workload images targeted by `verifyImages`.
