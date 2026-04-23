# Kyverno Runtime Report - SecureRAG Hub

- Generated at UTC: `2026-04-22T17:41:11Z`
- Namespace: `securerag-hub`
- Supply chain attestation: `artifacts/release/release-attestation.json`

| Component | Status | Evidence |
|---|---:|---|
| Kubernetes API | TERMINÉ | API server reachable |
| Kyverno CRDs | TERMINÉ | required CRDs are present |
| Kyverno namespace | TERMINÉ | namespace/kyverno exists |
| Kyverno deployments | DÉPENDANT_DE_L_ENVIRONNEMENT | not ready: kyverno-admission-controller=1/1/1,kyverno-background-controller=1/1/1 kyverno-cleanup-controller=1/1/1,kyverno-reports-controller=1/1/1 |
| Kyverno Audit policies | TERMINÉ | all expected SecureRAG ClusterPolicies are present |
| Kyverno PolicyReports | TERMINÉ | reports=31; pass=136; warn=0; fail_or_error=5 |
| Kyverno Enforce readiness | DÉPENDANT_DE_L_ENVIRONNEMENT | local registry references used by workloads are not reachable from Kyverno pods for verifyImages Enforce |
| Kyverno local registry Enforce blocker | DÉPENDANT_DE_L_ENVIRONNEMENT | localhost:5001/securerag-hub-audit-security-service:production, localhost:5001/securerag-hub-auth-users:production, localhost:5001/securerag-hub-chatbot-manager:production, localhost:5001/securerag-hub-conversation-service:production, localhost:5001/securerag-hub-portal-web:production |

## Kubernetes context

```text
kind-securerag-prod
```

## Kyverno CRDs

```text
NAME                                  CREATED AT
clusterpolicies.kyverno.io            2026-04-22T14:53:49Z
policyreports.wgpolicyk8s.io          2026-04-22T14:53:49Z
clusterpolicyreports.wgpolicyk8s.io   2026-04-22T14:53:49Z
```

## Kyverno deployments

```text
NAME                            READY   UP-TO-DATE   AVAILABLE   AGE    CONTAINERS   IMAGES                                                 SELECTOR
kyverno-admission-controller    1/1     1            1           167m   kyverno      reg.kyverno.io/kyverno/kyverno:v1.16.2                 app.kubernetes.io/component=admission-controller,app.kubernetes.io/instance=kyverno,app.kubernetes.io/part-of=kyverno
kyverno-background-controller   1/1     1            1           167m   controller   reg.kyverno.io/kyverno/background-controller:v1.16.2   app.kubernetes.io/component=background-controller,app.kubernetes.io/instance=kyverno,app.kubernetes.io/part-of=kyverno
kyverno-cleanup-controller      1/1     1            1           167m   controller   reg.kyverno.io/kyverno/cleanup-controller:v1.16.2      app.kubernetes.io/component=cleanup-controller,app.kubernetes.io/instance=kyverno,app.kubernetes.io/part-of=kyverno
kyverno-reports-controller      1/1     1            1           167m   controller   reg.kyverno.io/kyverno/reports-controller:v1.16.2      app.kubernetes.io/component=reports-controller,app.kubernetes.io/instance=kyverno,app.kubernetes.io/part-of=kyverno
```

## Kyverno pods

```text
NAME                                             READY   STATUS    RESTARTS   AGE    IP            NODE                     NOMINATED NODE   READINESS GATES
kyverno-admission-controller-7ff48568bf-6jjtd    1/1     Running   0          167m   10.244.3.9    securerag-prod-worker3   <none>           <none>
kyverno-background-controller-85999778c9-mhxk2   1/1     Running   0          167m   10.244.2.9    securerag-prod-worker    <none>           <none>
kyverno-cleanup-controller-7b74646946-6rjjg      1/1     Running   0          167m   10.244.3.10   securerag-prod-worker3   <none>           <none>
kyverno-reports-controller-86d8747f78-n6f4z      1/1     Running   0          167m   10.244.2.10   securerag-prod-worker    <none>           <none>
```

## Kyverno policies

```text
NAME                                   ADMISSION   BACKGROUND   READY   AGE    FAILURE POLICY   VALIDATE   MUTATE   GENERATE   VERIFY IMAGES   MESSAGE
securerag-audit-cleartext-env-values   true        true         True    166m                    1          0        0          0               Ready
securerag-require-pod-security         true        true         True    166m                    2          0        0          0               Ready
securerag-require-workload-controls    true        true         True    166m                    2          0        0          0               Ready
securerag-restrict-image-references    true        true         True    166m                    3          0        0          0               Ready
securerag-restrict-service-exposure    true        true         True    166m                    1          0        0          0               Ready
securerag-restrict-volume-types        true        true         True    166m                    1          0        0          0               Ready
securerag-verify-cosign-images         true        false        True    166m                    0          0        0          1               Ready
```

## Kyverno policy reports

```text
NAMESPACE       NAME                                                               KIND         NAME                                      PASS   FAIL   WARN   ERROR   SKIP   AGE
securerag-hub   policyreport.wgpolicyk8s.io/03f73506-96ab-4300-8730-4d821bfe7eb2   Deployment   conversation-service                      5      1      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/08aec842-a907-42e6-8aa3-826491530446   ReplicaSet   auth-users-58df94bcb8                     4      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/08ed2f51-b714-41cd-82dc-17e93fb40b84   Pod          auth-users-58df94bcb8-2cbgb               6      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/10d2332e-d6f2-4d32-ba9c-4294d8f71275   Pod          portal-web-6859f8c7b7-kjdgj               6      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/1965aabc-b568-4845-bb12-dd5a04c6761f   ReplicaSet   portal-web-676676cbdf                     4      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/1ec40370-ef54-4025-9ecb-12d4d4de86eb   ReplicaSet   audit-security-service-568984ff67         4      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/1f4cfed8-f22c-49d5-9035-e3d7ecdb3795   Pod          conversation-service-6c9f48ff84-tk7zx     6      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/216004af-8d94-443c-bcd3-3aa436e568f1   ReplicaSet   conversation-service-749bb7fc99           4      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/44561ac1-9616-4527-b1ba-4f9d20f0a90f   Deployment   portal-web                                5      1      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/56bee8be-968d-4b51-b213-e9dac6f53c96   ReplicaSet   portal-web-6859f8c7b7                     4      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/6378e464-7319-45a5-bf23-f96f224c0cbc   Pod          chatbot-manager-659cdc7cdc-db6dr          6      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/65edc1f5-fb8a-4779-b942-bf7b2d350297   Pod          audit-security-service-568984ff67-mmgg7   6      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/6fc3a056-f3d6-4a7d-8485-f71252fd5a06   Pod          portal-web-6859f8c7b7-k64rs               6      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/7598095a-54b1-4f13-8b84-670356654408   ReplicaSet   audit-security-service-b6b5b766d          4      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/7bd50a1d-c515-4224-bb58-e8c285938307   Deployment   auth-users                                5      1      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/7de21b8d-7b2d-452d-89c1-227d45b7cac6   Pod          audit-security-service-568984ff67-pjtzt   6      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/89783974-2085-42f0-a2d5-b8a1001be76f   Deployment   chatbot-manager                           5      1      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/9eba446d-e217-403b-9ae4-8354f139fd3f   Pod          portal-web-6859f8c7b7-lwthj               6      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/a923338c-173d-4cb6-b2e0-308dc4c3596d   Pod          conversation-service-6c9f48ff84-z8qhh     6      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/adc5e9bf-b5dc-454f-a1b2-659f56800259   Service      audit-security-service                    1      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/af7a79fb-4fae-4c5c-99c4-c48f6f75c9d7   ReplicaSet   conversation-service-6c9f48ff84           4      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/b259dc35-8405-47f8-9dd7-a9f46cb1ffa5   Service      conversation-service                      1      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/b30550fa-4323-49f7-991b-7b2bc4a2645b   Pod          auth-users-58df94bcb8-ncghs               6      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/c817afc3-0cf7-4167-867e-79c0cef7559f   ReplicaSet   chatbot-manager-5fcdb45757                4      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/cb2ea73e-d98e-4e97-bf27-57d3aab7356d   Service      portal-web                                1      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/d218a986-d8d3-42ff-b2c9-af62855acc89   Deployment   audit-security-service                    5      1      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/d47a51cf-e4d5-413b-911e-7a97dc540695   Service      auth-users                                1      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/de9d6614-8d80-4b4f-a848-1a9c67bc5889   ReplicaSet   auth-users-697479f954                     4      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/e85d1e13-5f5d-4f88-ba41-93b2cc3d8fe5   Service      chatbot-manager                           1      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/ef190e8b-9559-4fb8-a1de-fc3f4e49aabd   Pod          chatbot-manager-659cdc7cdc-25cgq          6      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/f6641f60-9055-4222-a9f1-9f2a9c93fa0c   ReplicaSet   chatbot-manager-659cdc7cdc                4      0      0      0       0      166m
```

## SecureRAG deployment images

```text
audit-security-service	localhost:5001/securerag-hub-audit-security-service:production 
auth-users	localhost:5001/securerag-hub-auth-users:production 
chatbot-manager	localhost:5001/securerag-hub-chatbot-manager:production 
conversation-service	localhost:5001/securerag-hub-conversation-service:production 
portal-web	localhost:5001/securerag-hub-portal-web:production 
```

## Enforce rule

`Enforce` must not be enabled automatically. It is acceptable only when:

- Kyverno CRDs, deployments and SecureRAG Audit policies are present.
- PolicyReports exist and contain no `fail` or `error` result.
- The supply-chain release attestation is `COMPLETE_PROVEN`.
- The deployed images are the same digests that were signed, verified and promoted.
- No loopback image registry reference such as `localhost:5001` is used by the workload images targeted by `verifyImages`.
