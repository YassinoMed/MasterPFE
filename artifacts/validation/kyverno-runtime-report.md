# Kyverno Runtime Report - SecureRAG Hub

- Generated at UTC: `2026-07-05T11:59:21Z`
- Namespace: `securerag-hub`
- Supply chain attestation: `artifacts/release/release-attestation.json`
- Status: `PRÊT_NON_EXÉCUTÉ`

| Component | Status | Evidence |
|---|---:|---|
| Kubernetes API | TERMINÉ | API server reachable |
| Kyverno CRDs | TERMINÉ | required CRDs are present |
| Kyverno namespace | TERMINÉ | namespace/kyverno exists |
| Kyverno deployments | TERMINÉ | all Kyverno deployments are ready |
| Kyverno Audit policies | PRÊT_NON_EXÉCUTÉ | missing policies: securerag-require-pod-security securerag-verify-cosign-images |
| Kyverno PolicyReports | PARTIEL | reports=80; pass=333; warn=0; fail_or_error=1 |
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
NAME                            READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES                                                 SELECTOR
kyverno-admission-controller    1/1     1            1           11d   kyverno      reg.kyverno.io/kyverno/kyverno:v1.16.2                 app.kubernetes.io/component=admission-controller,app.kubernetes.io/instance=kyverno,app.kubernetes.io/part-of=kyverno
kyverno-background-controller   1/1     1            1           11d   controller   reg.kyverno.io/kyverno/background-controller:v1.16.2   app.kubernetes.io/component=background-controller,app.kubernetes.io/instance=kyverno,app.kubernetes.io/part-of=kyverno
kyverno-cleanup-controller      1/1     1            1           11d   controller   reg.kyverno.io/kyverno/cleanup-controller:v1.16.2      app.kubernetes.io/component=cleanup-controller,app.kubernetes.io/instance=kyverno,app.kubernetes.io/part-of=kyverno
kyverno-reports-controller      1/1     1            1           11d   controller   reg.kyverno.io/kyverno/reports-controller:v1.16.2      app.kubernetes.io/component=reports-controller,app.kubernetes.io/instance=kyverno,app.kubernetes.io/part-of=kyverno
```

## Kyverno pods

```text
NAME                                             READY   STATUS    RESTARTS   AGE   IP            NODE                   NOMINATED NODE   READINESS GATES
kyverno-admission-controller-7ff48568bf-rfmrc    1/1     Running   0          10d   10.244.1.79   securerag-dev-worker   <none>           <none>
kyverno-background-controller-85999778c9-njbsr   1/1     Running   0          10d   10.244.1.80   securerag-dev-worker   <none>           <none>
kyverno-cleanup-controller-7b74646946-4zh7c      1/1     Running   0          10d   10.244.1.81   securerag-dev-worker   <none>           <none>
kyverno-reports-controller-86d8747f78-r7rbq      1/1     Running   0          10d   10.244.1.82   securerag-dev-worker   <none>           <none>
```

## Kyverno policies

```text
NAME                                   ADMISSION   BACKGROUND   READY   AGE   FAILURE POLICY   VALIDATE   MUTATE   GENERATE   VERIFY IMAGES   MESSAGE
securerag-audit-cleartext-env-values   true        true         True    11d                    1          0        0          0               Ready
securerag-disallow-host-network        true        true         True    10d                    1          0        0          0               Ready
securerag-disallow-root-containers     true        true         True    10d                    1          0        0          0               Ready
securerag-require-workload-controls    true        true         True    11d                    2          0        0          0               Ready
securerag-restrict-image-references    true        true         True    11d                    3          0        0          0               Ready
securerag-restrict-service-exposure    true        true         True    11d                    1          0        0          0               Ready
securerag-restrict-volume-types        true        true         True    11d                    1          0        0          0               Ready
```

## Kyverno policy reports

```text
NAMESPACE       NAME                                                               KIND         NAME                                      PASS   FAIL   WARN   ERROR   SKIP   AGE
securerag-hub   policyreport.wgpolicyk8s.io/00cc2b6a-4bb1-42e5-8168-968224464e95   ReplicaSet   chatbot-manager-5d4d486988                4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/0350047a-d79c-41e2-8adb-53417a3cbd0a   Service      postgres-auth                             0      1      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/08e83326-b742-4aa7-a1a1-71fa22e9189e   ReplicaSet   portal-web-866b8bb877                     4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/0b416629-d206-4163-82d5-4d9824bf8ac1   ReplicaSet   portal-web-6bb4d89c8f                     4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/0c0c955d-404b-47b5-bf37-9090c460f555   ReplicaSet   audit-security-service-86d97db989         4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/12204801-9ee8-4dfb-ada6-2a9c529c23fb   ReplicaSet   auth-users-596cb4b6b6                     4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/1385e566-6651-42c0-a36b-81adeaf5336f   ReplicaSet   conversation-service-7798c4d9f5           4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/13e42b35-f56d-4837-b241-56b211cf1b9c   ReplicaSet   portal-web-859c78db95                     4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/16c2ab2b-3766-4556-810a-35608f6fcf93   ReplicaSet   conversation-service-85fbdc56b5           4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/1828129f-c548-4e1a-9fd8-1968c6497ce3   ReplicaSet   portal-web-74fb75ffd                      4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/192a2894-7a70-4373-b9fd-ce59b17650f6   Deployment   postgres-auth                             6      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/1c8ffea2-619b-40c8-979b-2f9d15105166   ReplicaSet   conversation-service-694d9d678d           4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/217ae067-d472-473a-a9bc-a8a50b78a7e9   Service      chatbot-manager                           1      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/248bf76a-c1f5-4ba7-9a6b-49bfbf38301b   Deployment   conversation-service                      6      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/323b7c2c-3d44-4546-be50-d0d721e881d2   ReplicaSet   chatbot-manager-7747c5c74c                4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/35481288-e675-4b9f-90e9-53fead45294e   ReplicaSet   portal-web-78477ccc9c                     4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/3613ca90-70cb-472b-957b-73072c41e688   ReplicaSet   auth-users-685bb744b8                     4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/375f5251-dfff-4fe9-8ef1-21f96a40dea5   ReplicaSet   auth-users-6876975497                     4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/3ba104f9-1547-4471-ba3f-57ddb3cfc6dd   Pod          auth-users-8678978685-bfl4l               6      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/4641faa8-fc63-42a2-8b5d-6faa2a5380f8   Pod          auth-users-8678978685-zrn25               6      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/4ab0f761-1403-4963-a4b3-008823a81898   Service      auth-users                                1      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/4e68b0d4-e351-434c-8ea4-8eb1515bcb8d   ReplicaSet   portal-web-6c8ffb98f9                     4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/4faf700b-68a3-4466-8e7e-f1adc35490ab   ReplicaSet   portal-web-8468c5c66d                     4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/52b56f5b-0e0d-403c-9d56-a69eef91112c   Pod          portal-web-859c78db95-v9vwx               6      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/53293784-7dbf-49b2-95b0-5f64cc75b9f3   ReplicaSet   auth-users-9886bf44b                      4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/58cfc763-ed9c-41f1-8458-8bbd746078ed   ReplicaSet   conversation-service-55b9dcbc4            4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/5c65dd19-6870-43f9-b97d-5817df3eb505   ReplicaSet   chatbot-manager-56dd8f9bb4                4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/5e126487-24ef-4962-8446-cd0a4a489336   ReplicaSet   audit-security-service-5d454744b7         4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/5f41f368-c5f2-41cb-af4d-50cf408293cf   ReplicaSet   auth-users-8547b5bfb                      4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/60d0dd9c-838f-4f01-b734-35a5611d6da8   ReplicaSet   conversation-service-74cdcf4fdc           4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/61ee4927-985f-42de-bb9f-5c790cab03b6   Service      portal-web                                1      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/64aa6bea-0f14-4590-a1c6-49ac464eb5e8   ReplicaSet   portal-web-57546c8c47                     4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/64bdf0e9-739e-4263-878d-87a2e21c2aee   ReplicaSet   conversation-service-76b5577fd5           4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/69be49bb-dfff-4dfe-a521-9e5f9e3aeb2a   ReplicaSet   auth-users-6d79d66cc5                     4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/6b2da2d0-eee5-40ae-b046-c4a71026ad8c   ReplicaSet   chatbot-manager-58d8fdb94f                4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/734ac693-75f4-4b15-a24a-f7d8813a3379   ReplicaSet   conversation-service-6bc4c7dbc6           4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/73f729dd-1d38-427f-bf7f-bcf80824ecda   Service      audit-security-service                    1      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/7510739a-77b7-4514-ac4c-010f85c17519   Pod          portal-web-859c78db95-8xxmr               6      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/79260f4d-dbc3-48a3-8a95-32c06b39788c   ReplicaSet   chatbot-manager-6d6958b667                4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/7d79e610-c6c7-4bb7-b4ca-3c661f741fdd   Deployment   portal-web                                6      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/7fa10287-ae13-4774-a32b-87e6b04ce261   Pod          auth-users-8678978685-l7968               6      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/7fc9830f-d2ab-4cb4-9c8f-eba9e66a8c35   ReplicaSet   conversation-service-588cc88f95           4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/86918803-8195-4a6a-b539-09a07e5c99db   Deployment   chatbot-manager                           6      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/88ccebff-15de-443a-900f-6d86db2f951f   ReplicaSet   audit-security-service-85976dc85b         4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/8ab93505-b633-4327-8978-7c655e409452   Deployment   auth-users                                6      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/9136f5fc-616b-4c76-8079-c94699dd682a   ReplicaSet   chatbot-manager-79b79d59c4                4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/9854ef6c-e8e8-41c4-a3f0-1cef3d64a6e6   ReplicaSet   auth-users-8678978685                     4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/9ac123c7-f854-4258-b571-1b7aababe55b   ReplicaSet   auth-users-698f76867b                     4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/a0bc7dcc-b366-44ed-a914-c1b5496377d3   ReplicaSet   chatbot-manager-7475b9fd9d                4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/a447d2ca-0a1c-4294-9bae-aa84bcd56632   Pod          audit-security-service-667b7997b4-j5m7r   6      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/a6c80d01-971f-49dd-b2d7-6d108bd38626   ReplicaSet   chatbot-manager-54b9bb64f8                4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/aa07470f-8bcf-4ec1-a7eb-958e66c59aff   ReplicaSet   conversation-service-6f6bfff485           4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/abbe03ff-6f5c-453c-8f16-3de4311f5334   Pod          postgres-auth-fbf55db78-kwlh4             6      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/ae9245f6-cda5-4522-a67a-47baddc81a7a   ReplicaSet   audit-security-service-7b97f5476c         4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/b12793b7-4529-421f-bd0a-b11bb98c9df2   ReplicaSet   postgres-auth-fbf55db78                   4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/b31b5a7b-13ce-4b0a-bb90-44b88161877c   ReplicaSet   portal-web-5c55fb5dcb                     4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/b71a80f7-25bb-463f-9b65-5eb41e913f04   ReplicaSet   audit-security-service-585f5dc795         4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/b9971807-6241-4d22-a7c9-0726ee47e43d   ReplicaSet   portal-web-5898f9c5cd                     4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/ba1b7c01-8628-4a6a-ab3d-421745dc17ee   ReplicaSet   audit-security-service-bdc97f8f6          4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/bbee43a3-9ba9-4563-b225-75d37da10561   ReplicaSet   audit-security-service-5dbc7b5bbf         4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/becdfea9-e978-4596-b866-e592e11c75f0   Service      conversation-service                      1      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/bfbd47cc-8a7a-46b9-b0fb-efb5096dcfa8   ReplicaSet   audit-security-service-864b876b69         4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/c0bdd4b3-210e-493d-af31-4d10ded1169e   ReplicaSet   portal-web-6454587c5c                     4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/c47699e2-5876-4efe-858c-a35a99c5b8da   Pod          chatbot-manager-79b79d59c4-lvgtp          6      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/c4f9d1c8-3e32-4ecd-8f29-8d45b265fdaf   ReplicaSet   audit-security-service-6c44bb459c         4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/c84ad9d8-6fde-4a67-838e-82757d29b3f4   ReplicaSet   postgres-auth-867ddc6dc8                  4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/ca9e7d72-f6e8-428e-b2f1-bb9f1369e06d   ReplicaSet   chatbot-manager-67f57c8786                4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/cb0365b4-3c7d-4627-8abd-294bf062e269   ReplicaSet   auth-users-dbddb9b59                      4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/d8ef9f97-a5ff-4ca0-b347-639dcdd1713a   ReplicaSet   chatbot-manager-774676768b                4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/db461878-686e-474f-ac03-397278f85e68   ReplicaSet   audit-security-service-76777d56f5         4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/dbae8caf-1898-49d7-9e65-7a27bb48140c   ReplicaSet   conversation-service-5899b48485           4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/dbba59f9-8e92-4141-bf16-49514ca603c4   ReplicaSet   auth-users-7f7667b546                     4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/dd44f3e8-634c-4fc8-a53b-47e4b23abfa6   ReplicaSet   auth-users-5ff9cd9948                     4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/e7006b96-1463-44f8-a100-08f52004c3cf   Deployment   audit-security-service                    6      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/e8b0d0a0-8eba-49ad-9e42-0b5ce9d2b194   ReplicaSet   audit-security-service-667b7997b4         4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/e970ecc4-7caf-49dc-aaeb-c3b1643d6415   ReplicaSet   postgres-auth-b66fb7bb6                   4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/f690b794-27e2-4400-b110-8c0daec819ff   Pod          conversation-service-6bc4c7dbc6-pq7xf     6      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/f7285256-3e13-413b-bccd-2361322efa5f   ReplicaSet   chatbot-manager-794979876                 4      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/fbae4d42-9c57-4a86-a159-21152e9635f9   Pod          portal-web-859c78db95-z68jt               6      0      0      0       0      10d
securerag-hub   policyreport.wgpolicyk8s.io/fe97b470-c794-452d-9b69-c83387bd069e   ReplicaSet   conversation-service-5ffc5d5ff6           4      0      0      0       0      10d
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
```

## Enforce rule

`Enforce` must not be enabled automatically. It is acceptable only when:

- Kyverno CRDs, deployments and SecureRAG Audit policies are present.
- PolicyReports exist and contain no `fail` or `error` result.
- The supply-chain release attestation is `COMPLETE_PROVEN`.
- The deployed images are the same digests that were signed, verified and promoted.
- No loopback image registry reference such as `localhost:5001` is used by the workload images targeted by `verifyImages`.
