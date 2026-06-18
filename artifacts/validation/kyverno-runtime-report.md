# Kyverno Runtime Report - SecureRAG Hub

- Generated at UTC: `2026-06-18T12:52:03Z`
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
| Kyverno PolicyReports | PARTIEL | reports=74; pass=299; warn=0; fail_or_error=1 |
| Kyverno Enforce readiness | DÉPENDANT_DE_L_ENVIRONNEMENT | local registry references used by workloads are not reachable from Kyverno pods for verifyImages Enforce |
| Kyverno local registry Enforce blocker | DÉPENDANT_DE_L_ENVIRONNEMENT | localhost:5001/securerag-hub-audit-security-service:demo, localhost:5001/securerag-hub-auth-users:demo, localhost:5001/securerag-hub-chatbot-manager:demo, localhost:5001/securerag-hub-conversation-service:demo, localhost:5001/securerag-hub-portal-web:demo |

## Kubernetes context

```text
kind-securerag-dev
```

## Kyverno CRDs

```text
NAME                                  CREATED AT
clusterpolicies.kyverno.io            2026-06-16T08:41:21Z
policyreports.wgpolicyk8s.io          2026-06-16T08:41:22Z
clusterpolicyreports.wgpolicyk8s.io   2026-06-16T08:41:21Z
```

## Kyverno deployments

```text
NAME                            READY   UP-TO-DATE   AVAILABLE   AGE    CONTAINERS   IMAGES                                                 SELECTOR
kyverno-admission-controller    1/1     1            1           2d4h   kyverno      reg.kyverno.io/kyverno/kyverno:v1.16.2                 app.kubernetes.io/component=admission-controller,app.kubernetes.io/instance=kyverno,app.kubernetes.io/part-of=kyverno
kyverno-background-controller   1/1     1            1           2d4h   controller   reg.kyverno.io/kyverno/background-controller:v1.16.2   app.kubernetes.io/component=background-controller,app.kubernetes.io/instance=kyverno,app.kubernetes.io/part-of=kyverno
kyverno-cleanup-controller      1/1     1            1           2d4h   controller   reg.kyverno.io/kyverno/cleanup-controller:v1.16.2      app.kubernetes.io/component=cleanup-controller,app.kubernetes.io/instance=kyverno,app.kubernetes.io/part-of=kyverno
kyverno-reports-controller      1/1     1            1           2d4h   controller   reg.kyverno.io/kyverno/reports-controller:v1.16.2      app.kubernetes.io/component=reports-controller,app.kubernetes.io/instance=kyverno,app.kubernetes.io/part-of=kyverno
```

## Kyverno pods

```text
NAME                                             READY   STATUS    RESTARTS   AGE    IP           NODE                   NOMINATED NODE   READINESS GATES
kyverno-admission-controller-7ff48568bf-jz6gw    1/1     Running   0          2d4h   10.244.1.2   securerag-dev-worker   <none>           <none>
kyverno-background-controller-85999778c9-rq67h   1/1     Running   0          2d4h   10.244.1.3   securerag-dev-worker   <none>           <none>
kyverno-cleanup-controller-7b74646946-fm5jq      1/1     Running   0          2d4h   10.244.1.4   securerag-dev-worker   <none>           <none>
kyverno-reports-controller-86d8747f78-vsjl4      1/1     Running   0          2d4h   10.244.1.5   securerag-dev-worker   <none>           <none>
```

## Kyverno policies

```text
NAME                                   ADMISSION   BACKGROUND   READY   AGE    FAILURE POLICY   VALIDATE   MUTATE   GENERATE   VERIFY IMAGES   MESSAGE
securerag-audit-cleartext-env-values   true        true         True    2d4h                    1          0        0          0               Ready
securerag-require-pod-security         true        true         True    2d4h                    2          0        0          0               Ready
securerag-require-workload-controls    true        true         True    2d4h                    2          0        0          0               Ready
securerag-restrict-image-references    true        true         True    2d4h                    3          0        0          0               Ready
securerag-restrict-service-exposure    true        true         True    2d4h                    1          0        0          0               Ready
securerag-restrict-volume-types        true        true         True    2d4h                    1          0        0          0               Ready
securerag-verify-cosign-images         true        false        True    2d4h                    0          0        0          1               Ready
```

## Kyverno policy reports

```text
NAMESPACE       NAME                                                               KIND         NAME                                      PASS   FAIL   WARN   ERROR   SKIP   AGE
securerag-hub   policyreport.wgpolicyk8s.io/0a3d3e0d-a464-42b2-9ef3-aee1733adc0a   Service      auth-users                                1      0      0      0       0      2d4h
securerag-hub   policyreport.wgpolicyk8s.io/0a5e82ad-8497-4920-a770-8f4a85416e1f   ReplicaSet   auth-users-79bbc9bd7b                     4      0      0      0       0      37h
securerag-hub   policyreport.wgpolicyk8s.io/19fa5e60-c872-41e2-8050-c0cb44ec1542   ReplicaSet   auth-users-5fc697bf7                      4      0      0      0       0      36h
securerag-hub   policyreport.wgpolicyk8s.io/1cad4ca1-4611-4d56-9b80-754f539c1a73   ReplicaSet   conversation-service-b7f9cdbd9            4      0      0      0       0      37h
securerag-hub   policyreport.wgpolicyk8s.io/1f1a46ed-5d7a-4439-90c8-298d74c5fb56   ReplicaSet   chatbot-manager-7b547c6c84                4      0      0      0       0      35h
securerag-hub   policyreport.wgpolicyk8s.io/1f6f8db0-6b5f-4983-b492-f417a1960f38   ReplicaSet   chatbot-manager-86f8b6fcdf                4      0      0      0       0      78m
securerag-hub   policyreport.wgpolicyk8s.io/266b0c5a-3593-4ec5-9532-768d0e410e5b   ReplicaSet   postgres-auth-867ddc6dc8                  4      0      0      0       0      39h
securerag-hub   policyreport.wgpolicyk8s.io/2a29dac3-81b5-4dc2-b833-87b6fb590cad   ReplicaSet   chatbot-manager-6b5d8fd8c5                4      0      0      0       0      36h
securerag-hub   policyreport.wgpolicyk8s.io/2d1b7065-82bb-4605-a3dd-c66446dd5a3b   ReplicaSet   audit-security-service-f5c444568          4      0      0      0       0      37h
securerag-hub   policyreport.wgpolicyk8s.io/31f2d73a-6a81-487f-989c-2f30adeb7628   ReplicaSet   auth-users-769cc68c87                     4      0      0      0       0      36h
securerag-hub   policyreport.wgpolicyk8s.io/333dd948-8621-40e4-bf84-33792c5d38d6   ReplicaSet   portal-web-57896bd95f                     4      0      0      0       0      36h
securerag-hub   policyreport.wgpolicyk8s.io/34f1affc-7074-4936-b263-52f6a5275a54   ReplicaSet   portal-web-789c66c657                     4      0      0      0       0      35h
securerag-hub   policyreport.wgpolicyk8s.io/35c2f710-b51b-448b-a921-860bfe2a4132   Pod          portal-web-859c7cf886-6sgts               6      0      0      0       0      78m
securerag-hub   policyreport.wgpolicyk8s.io/39855113-b0db-45a9-bd55-35c5c4b962fd   ReplicaSet   portal-web-6976f598fc                     4      0      0      0       0      36h
securerag-hub   policyreport.wgpolicyk8s.io/3b20cb20-9822-452b-98d6-9ed5d645054d   ReplicaSet   audit-security-service-795f6b578c         4      0      0      0       0      35h
securerag-hub   policyreport.wgpolicyk8s.io/3bd85446-320f-48ab-8b12-a603114647cf   Pod          auth-users-d694b5685-245ch                6      0      0      0       0      78m
securerag-hub   policyreport.wgpolicyk8s.io/3c19765c-a86a-40ed-9cc0-eb2641881031   ReplicaSet   conversation-service-58c684679d           4      0      0      0       0      37h
securerag-hub   policyreport.wgpolicyk8s.io/3da9eaa4-c54b-4123-a74f-c257d9ed171e   ReplicaSet   audit-security-service-5bfb5d946c         4      0      0      0       0      37h
securerag-hub   policyreport.wgpolicyk8s.io/3ebdcb9a-c594-4809-b3ec-2678e4483669   ReplicaSet   audit-security-service-7b69fcc847         4      0      0      0       0      36h
securerag-hub   policyreport.wgpolicyk8s.io/3ef7a711-17d3-4698-b7ad-ce0d73789909   Service      conversation-service                      1      0      0      0       0      2d4h
securerag-hub   policyreport.wgpolicyk8s.io/4062f3bc-f67d-4bf5-ae14-b710bfcfc798   Service      chatbot-manager                           1      0      0      0       0      2d4h
securerag-hub   policyreport.wgpolicyk8s.io/4cd8522c-9a2c-40c4-9e1f-d94182503bed   Pod          audit-security-service-74457874f7-r7thl   6      0      0      0       0      78m
securerag-hub   policyreport.wgpolicyk8s.io/509e3c23-f161-4daa-89cf-8db899c35090   ReplicaSet   audit-security-service-9ff7f9ddc          4      0      0      0       0      35h
securerag-hub   policyreport.wgpolicyk8s.io/510b4c1a-b4c7-4b3b-af42-77731a720c38   ReplicaSet   auth-users-598db9d4c6                     4      0      0      0       0      35h
securerag-hub   policyreport.wgpolicyk8s.io/52a2a7ad-5d5e-44f7-b267-bd0a4a597481   ReplicaSet   audit-security-service-74955f88           4      0      0      0       0      36h
securerag-hub   policyreport.wgpolicyk8s.io/54174754-1c72-4dcd-8662-58ea684fd8d7   ReplicaSet   portal-web-859c7cf886                     4      0      0      0       0      78m
securerag-hub   policyreport.wgpolicyk8s.io/550169e5-66e9-4b51-b722-ae5962aa0b50   ReplicaSet   chatbot-manager-58d7f6849b                4      0      0      0       0      35h
securerag-hub   policyreport.wgpolicyk8s.io/5d0a62fc-fdcf-4583-b7ee-d37d9b1d8555   ReplicaSet   portal-web-76857f474                      4      0      0      0       0      36h
securerag-hub   policyreport.wgpolicyk8s.io/5d2e461b-876f-4dda-b9b3-ff55053ad039   ReplicaSet   conversation-service-56996dc44            4      0      0      0       0      36h
securerag-hub   policyreport.wgpolicyk8s.io/5d84a9d7-e7c4-4da2-9c0d-3240d69ddeae   ReplicaSet   conversation-service-b474bdc88            4      0      0      0       0      36h
securerag-hub   policyreport.wgpolicyk8s.io/6235ca2c-9c33-4135-aa78-bf8ab5e07a27   Service      portal-web                                1      0      0      0       0      2d4h
securerag-hub   policyreport.wgpolicyk8s.io/63cefdac-d62a-48e2-a20a-c58a68dc843d   Deployment   conversation-service                      6      0      0      0       0      2d4h
securerag-hub   policyreport.wgpolicyk8s.io/65daee68-25ed-4717-a644-118fbd4631ce   Pod          conversation-service-846bf49fcb-7k2dc     6      0      0      0       0      78m
securerag-hub   policyreport.wgpolicyk8s.io/684c4960-735f-47f6-8d0f-03453ba7c244   ReplicaSet   auth-users-765c789fc6                     4      0      0      0       0      36h
securerag-hub   policyreport.wgpolicyk8s.io/6c41b878-e6b6-44a3-8b14-09f88c4346b4   ReplicaSet   chatbot-manager-5c6cf9d966                4      0      0      0       0      37h
securerag-hub   policyreport.wgpolicyk8s.io/6e785438-a00a-470f-bf54-27d6f6e54e0f   Service      audit-security-service                    1      0      0      0       0      2d4h
securerag-hub   policyreport.wgpolicyk8s.io/6e893f61-778d-46b0-b6c4-1eaa551ddbbd   Deployment   audit-security-service                    6      0      0      0       0      2d4h
securerag-hub   policyreport.wgpolicyk8s.io/70e24715-fe2b-40f9-a0c2-5b2247cbc271   ReplicaSet   chatbot-manager-7b994c448c                4      0      0      0       0      37h
securerag-hub   policyreport.wgpolicyk8s.io/75179bb8-f3f1-4a62-805d-f4e3215d3083   ReplicaSet   portal-web-86f5c4dd9                      4      0      0      0       0      37h
securerag-hub   policyreport.wgpolicyk8s.io/77475ed3-8b1e-43a4-ae57-cf9aa6d3b2aa   ReplicaSet   audit-security-service-6b48d76454         4      0      0      0       0      37h
securerag-hub   policyreport.wgpolicyk8s.io/812c08d3-62fa-4452-89a8-74cd47d40dc3   Service      postgres-auth                             0      1      0      0       0      2d4h
securerag-hub   policyreport.wgpolicyk8s.io/87ff860b-05cf-43a0-94f4-7d92588e9277   ReplicaSet   portal-web-c99d94df                       4      0      0      0       0      35h
securerag-hub   policyreport.wgpolicyk8s.io/8e6d7587-b77b-4b16-aaab-f370e729a442   Deployment   auth-users                                6      0      0      0       0      2d4h
securerag-hub   policyreport.wgpolicyk8s.io/8e9bcc46-f271-4a05-91ca-9ac3275c9620   ReplicaSet   auth-users-d694b5685                      4      0      0      0       0      78m
securerag-hub   policyreport.wgpolicyk8s.io/8f80d2d3-06b9-4515-a4aa-c291dbd59761   ReplicaSet   chatbot-manager-dc75467b9                 4      0      0      0       0      36h
securerag-hub   policyreport.wgpolicyk8s.io/9494dd87-bba8-4034-8381-311e8145c6dc   ReplicaSet   postgres-auth-68d59c77df                  4      0      0      0       0      2d4h
securerag-hub   policyreport.wgpolicyk8s.io/9c720644-dbc8-4bc8-ad76-3d9ce2830762   ReplicaSet   conversation-service-846bf49fcb           4      0      0      0       0      78m
securerag-hub   policyreport.wgpolicyk8s.io/9ec48471-b899-45fd-9d8d-db32461b117f   ReplicaSet   portal-web-5df67f74d7                     4      0      0      0       0      37h
securerag-hub   policyreport.wgpolicyk8s.io/9f13c0b4-4bfe-4b5f-bc4e-5839b08ee1a6   ReplicaSet   auth-users-5d47d77944                     4      0      0      0       0      37h
securerag-hub   policyreport.wgpolicyk8s.io/9fb12a23-a97b-46c0-9292-2c2bc7aa63b3   ReplicaSet   conversation-service-87f9f8849            4      0      0      0       0      35h
securerag-hub   policyreport.wgpolicyk8s.io/a3257214-fc0b-4099-8f13-97df1c56c280   Deployment   portal-web                                6      0      0      0       0      2d4h
securerag-hub   policyreport.wgpolicyk8s.io/a85e2028-1ca7-472f-800c-c1035d1bbc3b   ReplicaSet   portal-web-5f9765cd74                     4      0      0      0       0      35h
securerag-hub   policyreport.wgpolicyk8s.io/a88c6718-ce35-4e3a-acbf-9d0b15a476d9   Deployment   postgres-auth                             6      0      0      0       0      2d4h
securerag-hub   policyreport.wgpolicyk8s.io/af71af39-c8e5-416e-a092-0dce0fa10906   ReplicaSet   chatbot-manager-5f7575f4cd                4      0      0      0       0      36h
securerag-hub   policyreport.wgpolicyk8s.io/b3b8afad-f6ef-4c1c-b9b0-3a6b03cb5f74   ReplicaSet   conversation-service-6556bc84fd           4      0      0      0       0      35h
securerag-hub   policyreport.wgpolicyk8s.io/b3d88c53-7bec-4d1a-86ca-a5649d3eb3fd   ReplicaSet   auth-users-6f6b795bc4                     4      0      0      0       0      35h
securerag-hub   policyreport.wgpolicyk8s.io/b4d8f55f-f077-4bec-bfc3-8c6295da0d66   ReplicaSet   portal-web-76c5f7f694                     4      0      0      0       0      36h
securerag-hub   policyreport.wgpolicyk8s.io/b7d5cba0-6b7a-4e95-aa34-4adae5d2f9f4   ReplicaSet   audit-security-service-64c76646b4         4      0      0      0       0      35h
securerag-hub   policyreport.wgpolicyk8s.io/b85cf3e1-0d72-4751-991b-d0635c7e01a3   ReplicaSet   chatbot-manager-78799bdf68                4      0      0      0       0      37h
securerag-hub   policyreport.wgpolicyk8s.io/be5331ba-7841-4a90-b4de-8848da99ffed   ReplicaSet   chatbot-manager-687ff4d5b5                4      0      0      0       0      36h
securerag-hub   policyreport.wgpolicyk8s.io/c688c8a1-a4cf-4041-8cd5-9b3166d1ce00   ReplicaSet   chatbot-manager-96c45c5db                 4      0      0      0       0      35h
securerag-hub   policyreport.wgpolicyk8s.io/cc7baf9b-8ccb-420a-9d0e-67f0f7f00b5f   ReplicaSet   conversation-service-75985585dc           4      0      0      0       0      37h
securerag-hub   policyreport.wgpolicyk8s.io/d43efa4f-3a8f-47de-bf5d-97a3843b4560   ReplicaSet   audit-security-service-74457874f7         4      0      0      0       0      78m
securerag-hub   policyreport.wgpolicyk8s.io/d6d2c937-bfde-4091-b0a8-f5dec9034618   ReplicaSet   auth-users-77c4b76bc8                     4      0      0      0       0      35h
securerag-hub   policyreport.wgpolicyk8s.io/d84f0bcf-cf81-4581-bd6f-bd30ca745ce3   ReplicaSet   conversation-service-5867bd579d           4      0      0      0       0      36h
securerag-hub   policyreport.wgpolicyk8s.io/dea14c97-e579-403d-832d-40b617798c2c   ReplicaSet   audit-security-service-5d77466d5          4      0      0      0       0      36h
securerag-hub   policyreport.wgpolicyk8s.io/e4f9720c-6e3a-4f18-97dc-65256e745aa9   ReplicaSet   audit-security-service-7656b75df8         4      0      0      0       0      36h
securerag-hub   policyreport.wgpolicyk8s.io/e584f575-1a29-4905-99e3-0dd88ade705c   ReplicaSet   auth-users-5bb6478cbb                     4      0      0      0       0      37h
securerag-hub   policyreport.wgpolicyk8s.io/e818b118-4c40-4352-9247-437512e33884   ReplicaSet   conversation-service-59595d8bd5           4      0      0      0       0      36h
securerag-hub   policyreport.wgpolicyk8s.io/ed1ac94c-aeee-4eda-9a0f-3a151b7679f2   ReplicaSet   auth-users-b6d75c865                      4      0      0      0       0      36h
securerag-hub   policyreport.wgpolicyk8s.io/f23e7eae-3ce2-4d10-867a-967afe8cdaf6   ReplicaSet   conversation-service-7cdbb854c9           4      0      0      0       0      35h
securerag-hub   policyreport.wgpolicyk8s.io/f53146aa-6772-4a1f-864e-bbe1c746cd8a   ReplicaSet   portal-web-5b644644f5                     4      0      0      0       0      37h
securerag-hub   policyreport.wgpolicyk8s.io/f75b07f6-3613-4be7-9720-3a5fd6d156b3   Pod          chatbot-manager-86f8b6fcdf-n6xbz          6      0      0      0       0      78m
securerag-hub   policyreport.wgpolicyk8s.io/ff3cff52-8512-4da4-8a83-725e29a7b44f   Deployment   chatbot-manager                           6      0      0      0       0      2d4h
```

## SecureRAG deployment images

```text
audit-security-service	localhost:5001/securerag-hub-audit-security-service:demo 
auth-users	localhost:5001/securerag-hub-auth-users:demo 
chatbot-manager	localhost:5001/securerag-hub-chatbot-manager:demo 
conversation-service	localhost:5001/securerag-hub-conversation-service:demo 
portal-web	localhost:5001/securerag-hub-portal-web:demo 
postgres-auth	postgres:16-alpine 
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
