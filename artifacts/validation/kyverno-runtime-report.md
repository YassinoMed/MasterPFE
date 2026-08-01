# Kyverno Runtime Report - SecureRAG Hub

- Generated at UTC: `2026-07-31T18:26:37Z`
- Namespace: `securerag-hub`
- Supply chain attestation: `artifacts/release/release-attestation.json`
- Status: `DÉPENDANT_DE_L_ENVIRONNEMENT`

| Component | Status | Evidence |
|---|---:|---|
| Kubernetes API | TERMINÉ | API server reachable |
| Kyverno CRDs | TERMINÉ | required CRDs are present |
| Kyverno namespace | TERMINÉ | namespace/kyverno exists |
| Kyverno deployments | PARTIEL | not ready: kyverno-admission-controller=0/0/0,kyverno-background-controller=0/0/0 kyverno-cleanup-controller=0/0/0,kyverno-reports-controller=0/0/0 |
| Kyverno Audit policies | PRÊT_NON_EXÉCUTÉ | missing policies: securerag-require-pod-security |
| Kyverno PolicyReports | PARTIEL | reports=56; pass=225; warn=0; fail_or_error=3 |
| Kyverno Enforce readiness | DÉPENDANT_DE_L_ENVIRONNEMENT | local registry references used by workloads are not reachable from Kyverno pods for verifyImages Enforce |
| Kyverno local registry Enforce blocker | DÉPENDANT_DE_L_ENVIRONNEMENT | localhost:5001/postgres:16-alpine, localhost:5001/securerag-hub-audit-security-service:demo, localhost:5001/securerag-hub-auth-users:demo, localhost:5001/securerag-hub-chatbot-manager:demo, localhost:5001/securerag-hub-conversation-service:demo, localhost:5001/securerag-hub-portal-web:demo |

## Kubernetes context

```text
kind-securerag-dev
```

## Kyverno CRDs

```text
NAME                                  CREATED AT
clusterpolicies.kyverno.io            2026-06-24T11:03:20Z
policyreports.wgpolicyk8s.io          2026-06-24T11:03:20Z
clusterpolicyreports.wgpolicyk8s.io   2026-06-24T11:03:19Z
```

## Kyverno deployments

```text
NAME                            READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS               IMAGES                                                       SELECTOR
kyverno-admission-controller    0/0     0            0           37d   registry-proxy,kyverno   alpine/socat:latest,reg.kyverno.io/kyverno/kyverno:v1.16.2   app.kubernetes.io/component=admission-controller,app.kubernetes.io/instance=kyverno,app.kubernetes.io/part-of=kyverno
kyverno-background-controller   0/0     0            0           37d   controller               reg.kyverno.io/kyverno/background-controller:v1.16.2         app.kubernetes.io/component=background-controller,app.kubernetes.io/instance=kyverno,app.kubernetes.io/part-of=kyverno
kyverno-cleanup-controller      0/0     0            0           37d   controller               reg.kyverno.io/kyverno/cleanup-controller:v1.16.2            app.kubernetes.io/component=cleanup-controller,app.kubernetes.io/instance=kyverno,app.kubernetes.io/part-of=kyverno
kyverno-reports-controller      0/0     0            0           37d   controller               reg.kyverno.io/kyverno/reports-controller:v1.16.2            app.kubernetes.io/component=reports-controller,app.kubernetes.io/instance=kyverno,app.kubernetes.io/part-of=kyverno
```

## Kyverno pods

```text
No resources found in kyverno namespace.
```

## Kyverno policies

```text
NAME                                       ADMISSION   BACKGROUND   READY   AGE   FAILURE POLICY   VALIDATE   MUTATE   GENERATE   VERIFY IMAGES   MESSAGE
securerag-audit-cleartext-env-values       true        true         False   37d                    1          0        0          0               Not Ready
securerag-disallow-host-network            true        true         False   36d                    1          0        0          0               Not Ready
securerag-disallow-root-containers         true        true         False   36d                    1          0        0          0               Not Ready
securerag-require-workload-controls        true        true         False   37d                    2          0        0          0               Not Ready
securerag-restrict-image-references        true        true         False   37d                    3          0        0          0               Not Ready
securerag-restrict-service-exposure        true        true         False   37d                    1          0        0          0               Not Ready
securerag-restrict-volume-types            true        true         False   37d                    1          0        0          0               Not Ready
securerag-verify-cosign-images             true        false        True    20d                    0          0        0          1               Ready
securerag-verify-image-signature-keyless   true        false        False   13d                    0          0        0          1               Not Ready
```

## Kyverno policy reports

```text
NAMESPACE       NAME                                                               KIND         NAME                                PASS   FAIL   WARN   ERROR   SKIP   AGE
securerag-hub   policyreport.wgpolicyk8s.io/0350047a-d79c-41e2-8adb-53417a3cbd0a   Service      postgres-auth                       0      1      0      0       0      36d
securerag-hub   policyreport.wgpolicyk8s.io/07560cd6-0890-43e8-b7e1-76b5197e7549   ReplicaSet   auth-users-74ff9d7df7               4      0      0      0       0      20d
securerag-hub   policyreport.wgpolicyk8s.io/10185b5a-7130-48e7-8e39-d853f2a14cec   ReplicaSet   auth-users-8f47d4955                4      0      0      0       0      14d
securerag-hub   policyreport.wgpolicyk8s.io/160a30d1-951f-4b2d-86b1-cfaa9afcd886   ReplicaSet   portal-web-77bdb897d7               4      0      0      0       0      20d
securerag-hub   policyreport.wgpolicyk8s.io/17bbd7fd-4bca-48c2-bb5c-571f1e86c965   ReplicaSet   chatbot-manager-6f559d96db          4      0      0      0       0      20d
securerag-hub   policyreport.wgpolicyk8s.io/192a2894-7a70-4373-b9fd-ce59b17650f6   Deployment   postgres-auth                       6      0      0      0       0      36d
securerag-hub   policyreport.wgpolicyk8s.io/1c8ffea2-619b-40c8-979b-2f9d15105166   ReplicaSet   conversation-service-694d9d678d     4      0      0      0       0      36d
securerag-hub   policyreport.wgpolicyk8s.io/20b53e71-8d84-4ef8-a6a6-306560e75636   ReplicaSet   portal-web-7f59d969c                4      0      0      0       0      20d
securerag-hub   policyreport.wgpolicyk8s.io/20c00360-74ac-4fe7-bd4f-d85faa23d0c5   ReplicaSet   portal-web-599f478c6c               4      0      0      0       0      20d
securerag-hub   policyreport.wgpolicyk8s.io/217ae067-d472-473a-a9bc-a8a50b78a7e9   Service      chatbot-manager                     1      0      0      0       0      36d
securerag-hub   policyreport.wgpolicyk8s.io/2189daa1-9ef7-47bd-9f75-6c59c2ad74fd   ReplicaSet   portal-web-84bd8bb87c               4      0      0      0       0      20d
securerag-hub   policyreport.wgpolicyk8s.io/248bf76a-c1f5-4ba7-9a6b-49bfbf38301b   Deployment   conversation-service                8      0      0      0       0      36d
securerag-hub   policyreport.wgpolicyk8s.io/323b7c2c-3d44-4546-be50-d0d721e881d2   ReplicaSet   chatbot-manager-7747c5c74c          4      0      0      0       0      36d
securerag-hub   policyreport.wgpolicyk8s.io/38d24002-41e2-4e47-8cde-c2cad01dfa47   ReplicaSet   chatbot-manager-7586fb94f6          4      0      0      0       0      20d
securerag-hub   policyreport.wgpolicyk8s.io/4326e73c-2baf-4cbf-a5b0-73a1b7c14372   ReplicaSet   portal-web-5c9c9c5d66               3      1      0      0       0      20d
securerag-hub   policyreport.wgpolicyk8s.io/447727d8-eb69-4e19-941b-87c4fc0ab0cc   ReplicaSet   auth-users-557c884c45               4      0      0      0       0      20d
securerag-hub   policyreport.wgpolicyk8s.io/4ab0f761-1403-4963-a4b3-008823a81898   Service      auth-users                          1      0      0      0       0      36d
securerag-hub   policyreport.wgpolicyk8s.io/4b27aa40-3665-49ca-b772-c2a4d0c3a89e   ReplicaSet   audit-security-service-5dc8b86497   4      0      0      0       0      20d
securerag-hub   policyreport.wgpolicyk8s.io/58cfc763-ed9c-41f1-8458-8bbd746078ed   ReplicaSet   conversation-service-55b9dcbc4      4      0      0      0       0      36d
securerag-hub   policyreport.wgpolicyk8s.io/61ee4927-985f-42de-bb9f-5c790cab03b6   Service      portal-web                          1      0      0      0       0      36d
securerag-hub   policyreport.wgpolicyk8s.io/63862f14-20ca-4349-887d-63551f58c0be   ReplicaSet   chatbot-manager-6495b5556           4      0      0      0       0      20d
securerag-hub   policyreport.wgpolicyk8s.io/6b2da2d0-eee5-40ae-b046-c4a71026ad8c   ReplicaSet   chatbot-manager-58d8fdb94f          4      0      0      0       0      36d
securerag-hub   policyreport.wgpolicyk8s.io/734ac693-75f4-4b15-a24a-f7d8813a3379   ReplicaSet   conversation-service-6bc4c7dbc6     4      0      0      0       0      36d
securerag-hub   policyreport.wgpolicyk8s.io/73f729dd-1d38-427f-bf7f-bcf80824ecda   Service      audit-security-service              1      0      0      0       0      36d
securerag-hub   policyreport.wgpolicyk8s.io/74cdeb19-fc0d-4da2-b3d7-b77c2f079177   ReplicaSet   chatbot-manager-5c868487d8          4      0      0      0       0      20d
securerag-hub   policyreport.wgpolicyk8s.io/77975d08-ebb1-40c3-94bd-10f19a083438   ReplicaSet   conversation-service-7678f59b49     4      0      0      0       0      20d
securerag-hub   policyreport.wgpolicyk8s.io/79260f4d-dbc3-48a3-8a95-32c06b39788c   ReplicaSet   chatbot-manager-6d6958b667          4      0      0      0       0      36d
securerag-hub   policyreport.wgpolicyk8s.io/7d79e610-c6c7-4bb7-b4ca-3c661f741fdd   Deployment   portal-web                          8      0      0      0       0      36d
securerag-hub   policyreport.wgpolicyk8s.io/86918803-8195-4a6a-b539-09a07e5c99db   Deployment   chatbot-manager                     8      0      0      0       0      36d
securerag-hub   policyreport.wgpolicyk8s.io/87138f5d-d854-410d-b852-913fcfd252ff   ReplicaSet   chatbot-manager-5b9d9fd58           4      0      0      0       0      20d
securerag-hub   policyreport.wgpolicyk8s.io/881ec9ad-a48c-498d-9c16-2acfc7870b9b   ReplicaSet   portal-web-588b497f88               3      1      0      0       0      20d
securerag-hub   policyreport.wgpolicyk8s.io/88ccebff-15de-443a-900f-6d86db2f951f   ReplicaSet   audit-security-service-85976dc85b   4      0      0      0       0      36d
securerag-hub   policyreport.wgpolicyk8s.io/8c655d04-cb54-4b54-9e72-8f9aab94cc8e   ReplicaSet   audit-security-service-78c49d959f   4      0      0      0       0      20d
securerag-hub   policyreport.wgpolicyk8s.io/9136f5fc-616b-4c76-8079-c94699dd682a   ReplicaSet   chatbot-manager-79b79d59c4          4      0      0      0       0      36d
securerag-hub   policyreport.wgpolicyk8s.io/9dddcbf3-d260-4413-8b18-9492bb9818f0   ReplicaSet   portal-web-5967644c8                4      0      0      0       0      20d
securerag-hub   policyreport.wgpolicyk8s.io/b12793b7-4529-421f-bd0a-b11bb98c9df2   ReplicaSet   postgres-auth-fbf55db78             4      0      0      0       0      36d
securerag-hub   policyreport.wgpolicyk8s.io/b4615b5f-f987-4994-a369-f80edf553bc1   ReplicaSet   conversation-service-75f6978f87     4      0      0      0       0      20d
securerag-hub   policyreport.wgpolicyk8s.io/b71a80f7-25bb-463f-9b65-5eb41e913f04   ReplicaSet   audit-security-service-585f5dc795   4      0      0      0       0      36d
securerag-hub   policyreport.wgpolicyk8s.io/b89623d5-e5f1-4ccb-9775-d2190af5af3c   ReplicaSet   conversation-service-6fb95765f5     4      0      0      0       0      20d
securerag-hub   policyreport.wgpolicyk8s.io/ba1b7c01-8628-4a6a-ab3d-421745dc17ee   ReplicaSet   audit-security-service-bdc97f8f6    4      0      0      0       0      36d
securerag-hub   policyreport.wgpolicyk8s.io/becdfea9-e978-4596-b866-e592e11c75f0   Service      conversation-service                1      0      0      0       0      36d
securerag-hub   policyreport.wgpolicyk8s.io/c7884863-99d7-417e-972a-ed9de3a16975   ReplicaSet   conversation-service-5cf55dcc7f     4      0      0      0       0      20d
securerag-hub   policyreport.wgpolicyk8s.io/c84ad9d8-6fde-4a67-838e-82757d29b3f4   ReplicaSet   postgres-auth-867ddc6dc8            4      0      0      0       0      36d
securerag-hub   policyreport.wgpolicyk8s.io/ccc92b8b-e3c8-4fd0-8b74-64ac3d81d5ec   Deployment   auth-users                          8      0      0      0       0      20d
securerag-hub   policyreport.wgpolicyk8s.io/cec81aa5-7bae-4abe-853c-3683962471a7   ReplicaSet   audit-security-service-68c6959445   4      0      0      0       0      20d
securerag-hub   policyreport.wgpolicyk8s.io/d3939ec7-56f3-4ee5-8309-806bb5235471   ReplicaSet   audit-security-service-6c79b48cc7   4      0      0      0       0      20d
securerag-hub   policyreport.wgpolicyk8s.io/d9e5a673-5769-4105-b455-579bd2e9b7b5   ReplicaSet   conversation-service-7875d66875     4      0      0      0       0      20d
securerag-hub   policyreport.wgpolicyk8s.io/de6e0f1e-b407-42d4-98ba-97defcfa8be1   ReplicaSet   portal-web-548bf768cc               4      0      0      0       0      20d
securerag-hub   policyreport.wgpolicyk8s.io/e654cd9d-f6e0-478f-8a56-11ea90800c46   ReplicaSet   conversation-service-748d585b85     4      0      0      0       0      20d
securerag-hub   policyreport.wgpolicyk8s.io/e7006b96-1463-44f8-a100-08f52004c3cf   Deployment   audit-security-service              8      0      0      0       0      36d
securerag-hub   policyreport.wgpolicyk8s.io/e8b0d0a0-8eba-49ad-9e42-0b5ce9d2b194   ReplicaSet   audit-security-service-667b7997b4   4      0      0      0       0      36d
securerag-hub   policyreport.wgpolicyk8s.io/e970ecc4-7caf-49dc-aaeb-c3b1643d6415   ReplicaSet   postgres-auth-b66fb7bb6             4      0      0      0       0      36d
securerag-hub   policyreport.wgpolicyk8s.io/f2a8e7c2-4d4e-4357-b4f3-53ca3253ffb9   ReplicaSet   chatbot-manager-648b486f4f          4      0      0      0       0      20d
securerag-hub   policyreport.wgpolicyk8s.io/f499c55c-544c-403a-8eb8-a7352a2cff7d   ReplicaSet   audit-security-service-7466d4686c   4      0      0      0       0      20d
securerag-hub   policyreport.wgpolicyk8s.io/fa986290-6783-4c5c-96a1-10a344820a90   ReplicaSet   audit-security-service-6d858c9c5c   4      0      0      0       0      20d
securerag-hub   policyreport.wgpolicyk8s.io/fe97b470-c794-452d-9b69-c83387bd069e   ReplicaSet   conversation-service-5ffc5d5ff6     4      0      0      0       0      36d
```

## SecureRAG deployment images

```text
audit-security-service	localhost:5001/securerag-hub-audit-security-service:demo 
auth-users	localhost:5001/securerag-hub-auth-users:demo 
chatbot-manager	localhost:5001/securerag-hub-chatbot-manager:demo 
conversation-service	localhost:5001/securerag-hub-conversation-service:demo 
portal-web	localhost:5001/securerag-hub-portal-web:demo 
postgres-auth	localhost:5001/postgres:16-alpine 
```

## Failing PolicyReport results

```text
Service/postgres-auth: securerag-restrict-service-exposure/allow-nodeport-only-for-portal-web :: Only portal-web may use NodePort in the local demo overlay; LoadBalancer is forbidden.
ReplicaSet/portal-web-5c9c9c5d66: securerag-disallow-root-containers/autogen-check-run-as-non-root :: validation error: Pods must run as non-root (runAsNonRoot: true). rule autogen-check-run-as-non-root failed at path /spec/template/spec/containers/0/securityContext/runAsNonRoot/
ReplicaSet/portal-web-588b497f88: securerag-disallow-root-containers/autogen-check-run-as-non-root :: validation error: Pods must run as non-root (runAsNonRoot: true). rule autogen-check-run-as-non-root failed at path /spec/template/spec/containers/0/securityContext/runAsNonRoot/
```

## Enforce rule

`Enforce` must not be enabled automatically. It is acceptable only when:

- Kyverno CRDs, deployments and SecureRAG Audit policies are present.
- PolicyReports exist and contain no `fail` or `error` result.
- The supply-chain release attestation is `COMPLETE_PROVEN`.
- The deployed images are the same digests that were signed, verified and promoted.
- No loopback image registry reference such as `localhost:5001` is used by the workload images targeted by `verifyImages`.
