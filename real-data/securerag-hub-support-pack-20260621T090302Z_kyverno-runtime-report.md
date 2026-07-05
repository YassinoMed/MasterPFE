# Kyverno Runtime Report - SecureRAG Hub

- Generated at UTC: `2026-06-21T09:02:23Z`
- Namespace: `securerag-hub`
- Supply chain attestation: `artifacts/release/release-attestation.json`
- Status: `PARTIEL`

| Component | Status | Evidence |
|---|---:|---|
| Kubernetes API | TERMINÉ | API server reachable |
| Kyverno CRDs | TERMINÉ | required CRDs are present |
| Kyverno namespace | TERMINÉ | namespace/kyverno exists |
| Kyverno deployments | TERMINÉ | all Kyverno deployments are ready |
| Kyverno Audit policies | TERMINÉ | all expected SecureRAG ClusterPolicies are present |
| Kyverno PolicyReports | PARTIEL | reports=34; pass=150; warn=0; fail_or_error=2 |
| Kyverno Enforce readiness | DÉPENDANT_DE_L_ENVIRONNEMENT | local registry references used by workloads are not reachable from Kyverno pods for verifyImages Enforce |
| Kyverno local registry Enforce blocker | DÉPENDANT_DE_L_ENVIRONNEMENT | localhost:5001/securerag-hub-audit-security-service:dev, localhost:5001/securerag-hub-auth-users:dev, localhost:5001/securerag-hub-chatbot-manager:dev, localhost:5001/securerag-hub-conversation-service:dev, localhost:5001/securerag-hub-portal-web:dev |

## Kubernetes context

```text
kind-securerag-dev
```

## Kyverno CRDs

```text
NAME                                  CREATED AT
clusterpolicies.kyverno.io            2026-06-21T09:00:46Z
policyreports.wgpolicyk8s.io          2026-06-21T09:00:47Z
clusterpolicyreports.wgpolicyk8s.io   2026-06-21T09:00:46Z
```

## Kyverno deployments

```text
NAME                            READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES                                                 SELECTOR
kyverno-admission-controller    1/1     1            1           97s   kyverno      reg.kyverno.io/kyverno/kyverno:v1.16.2                 app.kubernetes.io/component=admission-controller,app.kubernetes.io/instance=kyverno,app.kubernetes.io/part-of=kyverno
kyverno-background-controller   1/1     1            1           97s   controller   reg.kyverno.io/kyverno/background-controller:v1.16.2   app.kubernetes.io/component=background-controller,app.kubernetes.io/instance=kyverno,app.kubernetes.io/part-of=kyverno
kyverno-cleanup-controller      1/1     1            1           97s   controller   reg.kyverno.io/kyverno/cleanup-controller:v1.16.2      app.kubernetes.io/component=cleanup-controller,app.kubernetes.io/instance=kyverno,app.kubernetes.io/part-of=kyverno
kyverno-reports-controller      1/1     1            1           97s   controller   reg.kyverno.io/kyverno/reports-controller:v1.16.2      app.kubernetes.io/component=reports-controller,app.kubernetes.io/instance=kyverno,app.kubernetes.io/part-of=kyverno
```

## Kyverno pods

```text
NAME                                             READY   STATUS    RESTARTS   AGE   IP            NODE                   NOMINATED NODE   READINESS GATES
kyverno-admission-controller-7ff48568bf-gsk86    1/1     Running   0          97s   10.244.1.17   securerag-dev-worker   <none>           <none>
kyverno-background-controller-85999778c9-hgf5k   1/1     Running   0          97s   10.244.1.19   securerag-dev-worker   <none>           <none>
kyverno-cleanup-controller-7b74646946-q95xd      1/1     Running   0          97s   10.244.1.18   securerag-dev-worker   <none>           <none>
kyverno-reports-controller-86d8747f78-s489f      1/1     Running   0          97s   10.244.1.20   securerag-dev-worker   <none>           <none>
```

## Kyverno policies

```text
NAME                                   ADMISSION   BACKGROUND   READY   AGE   FAILURE POLICY   VALIDATE   MUTATE   GENERATE   VERIFY IMAGES   MESSAGE
securerag-audit-cleartext-env-values   true        true         True    36s                    1          0        0          0               Ready
securerag-require-pod-security         true        true         True    36s                    2          0        0          0               Ready
securerag-require-workload-controls    true        true         True    35s                    2          0        0          0               Ready
securerag-restrict-image-references    true        true         True    35s                    3          0        0          0               Ready
securerag-restrict-service-exposure    true        true         True    35s                    1          0        0          0               Ready
securerag-restrict-volume-types        true        true         True    35s                    1          0        0          0               Ready
securerag-verify-cosign-images         true        false        True    35s                    0          0        0          1               Ready
```

## Kyverno policy reports

```text
NAMESPACE       NAME                                                               KIND         NAME                                     PASS   FAIL   WARN   ERROR   SKIP   AGE
securerag-hub   policyreport.wgpolicyk8s.io/02177cb2-a975-43cf-b9cc-34095a19f9f6   Pod          portal-web-6ff6cd4545-swmh5              6      0      0      0       0      25s
securerag-hub   policyreport.wgpolicyk8s.io/0af2c865-3b0d-49a5-a7da-804ce361d6fc   Deployment   portal-web                               6      0      0      0       0      25s
securerag-hub   policyreport.wgpolicyk8s.io/0fe2bf13-3895-45a1-9c6c-a69487ef6a1f   Pod          auth-users-c4b94d64b-t6k79               6      0      0      0       0      25s
securerag-hub   policyreport.wgpolicyk8s.io/10830846-6264-4388-aafd-f1e94ec58b2e   Service      audit-security-service                   1      0      0      0       0      24s
securerag-hub   policyreport.wgpolicyk8s.io/10f26d7a-9da3-4ed5-9b82-cfe2edcd975d   ReplicaSet   conversation-service-64f99b44db          4      0      0      0       0      25s
securerag-hub   policyreport.wgpolicyk8s.io/1d20f675-dcad-44af-8df9-c109e1bd88ca   ReplicaSet   postgres-auth-867ddc6dc8                 4      0      0      0       0      25s
securerag-hub   policyreport.wgpolicyk8s.io/23d605ae-917e-4db5-aee5-de8763ef1892   Pod          conversation-service-64f99b44db-6n2vv    6      0      0      0       0      26s
securerag-hub   policyreport.wgpolicyk8s.io/25c40f4e-5780-4f17-b412-fae7b23694c9   ReplicaSet   portal-web-6ff6cd4545                    4      0      0      0       0      25s
securerag-hub   policyreport.wgpolicyk8s.io/2b96f891-7d77-432a-a657-2f4cf7a67833   Service      chatbot-manager                          1      0      0      0       0      24s
securerag-hub   policyreport.wgpolicyk8s.io/3bbde1fc-579f-4c67-9b3a-bfcf87521c1b   Pod          audit-security-service-b478dc875-b5s9d   6      0      0      0       0      25s
securerag-hub   policyreport.wgpolicyk8s.io/4209f692-729b-4575-a1cd-a95e38138066   Pod          audit-security-service-5fddbb654-n5ltk   6      0      0      0       0      26s
securerag-hub   policyreport.wgpolicyk8s.io/5b36bbc6-f77e-4689-94db-209c0e890d24   Service      auth-users                               1      0      0      0       0      24s
securerag-hub   policyreport.wgpolicyk8s.io/5f6a66e2-d4aa-4c42-98b6-13faaf3d6c6a   ReplicaSet   auth-users-c4b94d64b                     4      0      0      0       0      25s
securerag-hub   policyreport.wgpolicyk8s.io/609c3fc4-1423-4b8d-94f9-6caf8d95dedc   Pod          auth-users-799b8b5664-whwzb              6      0      0      0       0      25s
securerag-hub   policyreport.wgpolicyk8s.io/685da5a9-4050-42fa-b69f-263a00ebfcbc   ReplicaSet   audit-security-service-b478dc875         4      0      0      0       0      25s
securerag-hub   policyreport.wgpolicyk8s.io/766e969b-569f-407e-a6ae-a067c015f512   Pod          chatbot-manager-779b7cc44b-bskxh         6      0      0      0       0      26s
securerag-hub   policyreport.wgpolicyk8s.io/7f8a19b2-19ee-4239-9aab-d77c8429e96d   Service      postgres-auth                            0      1      0      0       0      24s
securerag-hub   policyreport.wgpolicyk8s.io/815a6cf6-65d1-41a3-9c66-b0e3257ac10b   Deployment   auth-users                               6      0      0      0       0      25s
securerag-hub   policyreport.wgpolicyk8s.io/819080ea-ed29-482c-b6da-9fce980be1ea   ReplicaSet   chatbot-manager-779b7cc44b               4      0      0      0       0      25s
securerag-hub   policyreport.wgpolicyk8s.io/823cb9df-09d9-409a-b559-9a017d2b039e   Service      portal-web                               1      0      0      0       0      24s
securerag-hub   policyreport.wgpolicyk8s.io/84f8448f-378d-4597-9353-c6213983f615   Pod          chatbot-manager-976899cb8-jprbg          6      0      0      0       0      25s
securerag-hub   policyreport.wgpolicyk8s.io/868ed9d4-86e1-4b4d-a066-23e3fc1c45af   Service      conversation-service                     1      0      0      0       0      24s
securerag-hub   policyreport.wgpolicyk8s.io/8f63f457-7089-4f26-969c-86663c792739   Pod          postgres-auth-867ddc6dc8-w9xgr           5      1      0      0       0      26s
securerag-hub   policyreport.wgpolicyk8s.io/92fc148d-803c-4129-a59e-070e1605f256   ReplicaSet   conversation-service-778479dbbf          4      0      0      0       0      25s
securerag-hub   policyreport.wgpolicyk8s.io/9628a5b1-1536-434b-9b79-da5bc5bf96bb   Deployment   chatbot-manager                          6      0      0      0       0      25s
securerag-hub   policyreport.wgpolicyk8s.io/9bd25686-b67e-43a7-8b3b-7d9f702956d0   Deployment   audit-security-service                   6      0      0      0       0      25s
securerag-hub   policyreport.wgpolicyk8s.io/a53b69a9-54f7-416e-ba4b-702605a564ca   Deployment   postgres-auth                            6      0      0      0       0      25s
securerag-hub   policyreport.wgpolicyk8s.io/af637b0d-f110-4122-8983-4ce3bbaed2c0   Pod          portal-web-68d97f97f-2sjcd               6      0      0      0       0      25s
securerag-hub   policyreport.wgpolicyk8s.io/b3f4cb53-6c92-499d-a2b3-901fe2b3a82f   ReplicaSet   chatbot-manager-976899cb8                4      0      0      0       0      25s
securerag-hub   policyreport.wgpolicyk8s.io/c4ac0686-47c1-443c-8a88-ec1714ddaea3   ReplicaSet   audit-security-service-5fddbb654         4      0      0      0       0      25s
securerag-hub   policyreport.wgpolicyk8s.io/d9707dd8-805d-4f50-a777-82ee2269df80   ReplicaSet   auth-users-799b8b5664                    4      0      0      0       0      25s
securerag-hub   policyreport.wgpolicyk8s.io/db5d9e32-aae8-4dde-805f-bcfc8f026cc0   Pod          conversation-service-778479dbbf-wwfcx    6      0      0      0       0      25s
securerag-hub   policyreport.wgpolicyk8s.io/f50b3b4a-7035-46ba-9337-488f1ee6a07c   ReplicaSet   portal-web-68d97f97f                     4      0      0      0       0      25s
securerag-hub   policyreport.wgpolicyk8s.io/fa6b373e-acf4-4955-b39c-e6af826a73bf   Deployment   conversation-service                     6      0      0      0       0      25s
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

## Failing PolicyReport results

```text
Service/postgres-auth: securerag-restrict-service-exposure/allow-nodeport-only-for-portal-web :: Only portal-web may use NodePort in the local demo overlay; LoadBalancer is forbidden.
Pod/postgres-auth-867ddc6dc8-w9xgr: securerag-restrict-image-references/restrict-registries :: validation failure: validation error: Runtime images must come from localhost:5001 or ghcr.io. rule restrict-registries[0] failed at path /image/ rule restrict-registries[1] fai...
```

## Enforce rule

`Enforce` must not be enabled automatically. It is acceptable only when:

- Kyverno CRDs, deployments and SecureRAG Audit policies are present.
- PolicyReports exist and contain no `fail` or `error` result.
- The supply-chain release attestation is `COMPLETE_PROVEN`.
- The deployed images are the same digests that were signed, verified and promoted.
- No loopback image registry reference such as `localhost:5001` is used by the workload images targeted by `verifyImages`.
