# Observability Snapshot - SecureRAG Hub

- Generated at: `2026-07-18T13:28:53Z`
- Namespace: `securerag-hub`
- Jenkins URL: `http://localhost:8085`

## Scope

This report captures runtime observability evidence without mutating the cluster. It complements, but does not replace, a full Prometheus/Grafana/Loki stack.

## Kubernetes context

```text
kind-securerag-dev
```

## Workloads

```text
NAME                                     READY   UP-TO-DATE   AVAILABLE   AGE     CONTAINERS               IMAGES                                                     SELECTOR
deployment.apps/audit-security-service   1/1     1            1           24d     audit-security-service   localhost:5001/securerag-hub-audit-security-service:demo   app.kubernetes.io/name=audit-security-service,app.kubernetes.io/part-of=securerag-hub
deployment.apps/auth-users               1/3     1            1           7d14h   auth-users               localhost:5001/securerag-hub-auth-users:demo               app.kubernetes.io/name=auth-users,app.kubernetes.io/part-of=securerag-hub
deployment.apps/chatbot-manager          1/1     1            1           24d     chatbot-manager          localhost:5001/securerag-hub-chatbot-manager:demo          app.kubernetes.io/name=chatbot-manager,app.kubernetes.io/part-of=securerag-hub
deployment.apps/conversation-service     1/1     1            1           24d     conversation-service     localhost:5001/securerag-hub-conversation-service:demo     app.kubernetes.io/name=conversation-service,app.kubernetes.io/part-of=securerag-hub
deployment.apps/portal-web               0/2     1            0           24d     portal-web               localhost:5001/securerag-hub-portal-web:demo               app.kubernetes.io/name=portal-web,app.kubernetes.io/part-of=securerag-hub
deployment.apps/postgres-auth            1/1     1            1           24d     postgres-auth            localhost:5001/postgres:16-alpine                          app.kubernetes.io/name=postgres-auth,app.kubernetes.io/part-of=securerag-hub

NAME                                          READY   STATUS                       RESTARTS       AGE     IP             NODE                   NOMINATED NODE   READINESS GATES
pod/audit-security-service-5dc8b86497-srmhp   1/1     Running                      1 (44h ago)    7d5h    10.244.0.96    securerag-dev-worker   <none>           <none>
pod/auth-users-557c884c45-skbzz               1/1     Running                      1 (44h ago)    7d5h    10.244.0.174   securerag-dev-worker   <none>           <none>
pod/chatbot-manager-5c868487d8-gh4sv          1/1     Running                      1 (44h ago)    7d5h    10.244.0.251   securerag-dev-worker   <none>           <none>
pod/conversation-service-7678f59b49-fqg8b     1/1     Running                      1 (44h ago)    7d5h    10.244.0.116   securerag-dev-worker   <none>           <none>
pod/portal-web-84bd8bb87c-fm7sj               0/1     CreateContainerConfigError   63 (10m ago)   7d14h   10.244.0.137   securerag-dev-worker   <none>           <none>
pod/postgres-auth-fbf55db78-kwlh4             1/1     Running                      1 (44h ago)    23d     10.244.0.202   securerag-dev-worker   <none>           <none>

NAME                             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE   SELECTOR
service/audit-security-service   ClusterIP   10.96.104.151   <none>        8000/TCP         24d   app.kubernetes.io/name=audit-security-service,app.kubernetes.io/part-of=securerag-hub
service/auth-users               ClusterIP   10.96.139.68    <none>        8000/TCP         24d   app.kubernetes.io/name=auth-users,app.kubernetes.io/part-of=securerag-hub
service/chatbot-manager          ClusterIP   10.96.189.113   <none>        8000/TCP         24d   app.kubernetes.io/name=chatbot-manager,app.kubernetes.io/part-of=securerag-hub
service/conversation-service     ClusterIP   10.96.192.110   <none>        8000/TCP         24d   app.kubernetes.io/name=conversation-service,app.kubernetes.io/part-of=securerag-hub
service/portal-web               NodePort    10.96.193.87    <none>        8000:30081/TCP   24d   app.kubernetes.io/name=portal-web,app.kubernetes.io/part-of=securerag-hub
service/postgres-auth            ClusterIP   10.96.110.118   <none>        5432/TCP         24d   app.kubernetes.io/name=postgres-auth,app.kubernetes.io/part-of=securerag-hub
```

## HPA

```text
NAME         REFERENCE               TARGETS              MINPODS   MAXPODS   REPLICAS   AGE
portal-web   Deployment/portal-web   cpu: <unknown>/70%   1         3         2          24d
```

## PDB

```text
NAME                         MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
audit-security-service-pdb   1               N/A               0                     24d
auth-users-pdb               1               N/A               0                     24d
chatbot-manager-pdb          1               N/A               0                     24d
conversation-service-pdb     1               N/A               0                     24d
portal-web-pdb               1               N/A               0                     24d
```

## Recent namespace events

```text
LAST SEEN   TYPE      REASON            OBJECT                                        MESSAGE
27m         Warning   PolicyViolation   replicaset/portal-web-5c9c9c5d66              policy securerag-disallow-root-containers/autogen-check-run-as-non-root fail: validation error: Pods must run as non-root (runAsNonRoot: true). rule autogen-check-run-as-non-root failed at path /spec/template/spec/containers/0/securityContext/runAsNonRoot/
67m         Warning   Unhealthy         pod/conversation-service-7678f59b49-fqg8b     Liveness probe failed: Get "http://10.244.0.116:8000/health": context deadline exceeded (Client.Timeout exceeded while awaiting headers)
67m         Warning   Unhealthy         pod/chatbot-manager-5c868487d8-gh4sv          Liveness probe failed: Get "http://10.244.0.251:8000/health": context deadline exceeded (Client.Timeout exceeded while awaiting headers)
67m         Warning   Unhealthy         pod/audit-security-service-5dc8b86497-srmhp   Readiness probe failed: Get "http://10.244.0.96:8000/health": context deadline exceeded (Client.Timeout exceeded while awaiting headers)
65m         Normal    Pulled            pod/portal-web-84bd8bb87c-fm7sj               Successfully pulled image "localhost:5001/securerag-hub-portal-web:demo" in 1.397s (1.398s including waiting). Image size: 268260149 bytes.
65m         Warning   Failed            pod/portal-web-84bd8bb87c-fm7sj               Error: failed to sync configmap cache: timed out waiting for the condition
65m         Warning   Unhealthy         pod/auth-users-557c884c45-skbzz               Liveness probe failed: Get "http://10.244.0.174:8000/health": context deadline exceeded (Client.Timeout exceeded while awaiting headers)
57m         Normal    Killing           pod/portal-web-84bd8bb87c-fm7sj               Container portal-web failed startup probe, will be restarted
52m         Warning   Unhealthy         pod/audit-security-service-5dc8b86497-srmhp   Liveness probe failed: Get "http://10.244.0.96:8000/health": context deadline exceeded (Client.Timeout exceeded while awaiting headers)
48m         Normal    Pulled            pod/portal-web-84bd8bb87c-fm7sj               Successfully pulled image "localhost:5001/securerag-hub-portal-web:demo" in 2.797s (2.797s including waiting). Image size: 268260149 bytes.
41m         Normal    Created           pod/portal-web-84bd8bb87c-fm7sj               Created container: portal-web
36m         Warning   BackOff           pod/portal-web-84bd8bb87c-fm7sj               Back-off restarting failed container portal-web in pod portal-web-84bd8bb87c-fm7sj_securerag-hub(d11acadd-fcfb-4a6e-8ac3-2f0b40202c04)
30m         Warning   Unhealthy         pod/conversation-service-7678f59b49-fqg8b     Readiness probe failed: Get "http://10.244.0.116:8000/health": context deadline exceeded (Client.Timeout exceeded while awaiting headers)
30m         Warning   Unhealthy         pod/chatbot-manager-5c868487d8-gh4sv          Readiness probe failed: Get "http://10.244.0.251:8000/health": context deadline exceeded (Client.Timeout exceeded while awaiting headers)
30m         Normal    Started           pod/portal-web-84bd8bb87c-fm7sj               Started container portal-web
30m         Warning   Unhealthy         pod/auth-users-557c884c45-skbzz               Readiness probe failed: Get "http://10.244.0.174:8000/health": context deadline exceeded (Client.Timeout exceeded while awaiting headers)
28m         Warning   Unhealthy         pod/postgres-auth-fbf55db78-kwlh4             Liveness probe failed: command timed out: "pg_isready -U securerag -d auth_users" timed out after 3s
25m         Warning   Unhealthy         pod/portal-web-84bd8bb87c-fm7sj               Startup probe failed: Get "http://10.244.0.137:8000/health": context deadline exceeded (Client.Timeout exceeded while awaiting headers)
24m         Warning   Unhealthy         pod/postgres-auth-fbf55db78-kwlh4             Readiness probe failed: command timed out: "pg_isready -U securerag -d auth_users" timed out after 3s
23m         Normal    Pulling           pod/portal-web-84bd8bb87c-fm7sj               Pulling image "localhost:5001/securerag-hub-portal-web:demo"
```

## Metrics API

```text
NAME                     SERVICE                      AVAILABLE                  AGE
v1beta1.metrics.k8s.io   kube-system/metrics-server   False (MissingEndpoints)   12d
```

## Node metrics

```text
error: Metrics API not available
```

## Pod metrics

```text
error: Metrics API not available
```

## Kyverno policies

```text
NAME                                       ADMISSION   BACKGROUND   READY   AGE     FAILURE POLICY   VALIDATE   MUTATE   GENERATE   VERIFY IMAGES   MESSAGE
securerag-audit-cleartext-env-values       true        true         True    24d                      1          0        0          0               Ready
securerag-disallow-host-network            true        true         True    23d                      1          0        0          0               Ready
securerag-disallow-root-containers         true        true         True    23d                      1          0        0          0               Ready
securerag-require-workload-controls        true        true         True    24d                      2          0        0          0               Ready
securerag-restrict-image-references        true        true         True    24d                      3          0        0          0               Ready
securerag-restrict-service-exposure        true        true         True    24d                      1          0        0          0               Ready
securerag-restrict-volume-types            true        true         True    24d                      1          0        0          0               Ready
securerag-verify-cosign-images             true        false        True    7d15h                    0          0        0          1               Ready
securerag-verify-image-signature-keyless   true        false        True    13h                      0          0        0          1               Ready
```

## Policy reports

```text
NAMESPACE       NAME                                                               KIND         NAME                                      PASS   FAIL   WARN   ERROR   SKIP   AGE
securerag-hub   policyreport.wgpolicyk8s.io/0350047a-d79c-41e2-8adb-53417a3cbd0a   Service      postgres-auth                             0      1      0      0       0      23d
securerag-hub   policyreport.wgpolicyk8s.io/07560cd6-0890-43e8-b7e1-76b5197e7549   ReplicaSet   auth-users-74ff9d7df7                     4      0      0      0       0      7d5h
securerag-hub   policyreport.wgpolicyk8s.io/10185b5a-7130-48e7-8e39-d853f2a14cec   ReplicaSet   auth-users-8f47d4955                      4      0      0      0       0      31h
securerag-hub   policyreport.wgpolicyk8s.io/13e42b35-f56d-4837-b241-56b211cf1b9c   ReplicaSet   portal-web-859c78db95                     4      0      0      0       0      23d
securerag-hub   policyreport.wgpolicyk8s.io/160a30d1-951f-4b2d-86b1-cfaa9afcd886   ReplicaSet   portal-web-77bdb897d7                     4      0      0      0       0      7d5h
securerag-hub   policyreport.wgpolicyk8s.io/16c2ab2b-3766-4556-810a-35608f6fcf93   ReplicaSet   conversation-service-85fbdc56b5           4      0      0      0       0      23d
securerag-hub   policyreport.wgpolicyk8s.io/17bbd7fd-4bca-48c2-bb5c-571f1e86c965   ReplicaSet   chatbot-manager-6f559d96db                4      0      0      0       0      7d5h
securerag-hub   policyreport.wgpolicyk8s.io/192a2894-7a70-4373-b9fd-ce59b17650f6   Deployment   postgres-auth                             6      0      0      0       0      23d
securerag-hub   policyreport.wgpolicyk8s.io/1c8ffea2-619b-40c8-979b-2f9d15105166   ReplicaSet   conversation-service-694d9d678d           4      0      0      0       0      23d
securerag-hub   policyreport.wgpolicyk8s.io/20b53e71-8d84-4ef8-a6a6-306560e75636   ReplicaSet   portal-web-7f59d969c                      4      0      0      0       0      7d5h
securerag-hub   policyreport.wgpolicyk8s.io/20c00360-74ac-4fe7-bd4f-d85faa23d0c5   ReplicaSet   portal-web-599f478c6c                     4      0      0      0       0      7d5h
securerag-hub   policyreport.wgpolicyk8s.io/217ae067-d472-473a-a9bc-a8a50b78a7e9   Service      chatbot-manager                           1      0      0      0       0      23d
securerag-hub   policyreport.wgpolicyk8s.io/2189daa1-9ef7-47bd-9f75-6c59c2ad74fd   ReplicaSet   portal-web-84bd8bb87c                     4      0      0      0       0      7d5h
securerag-hub   policyreport.wgpolicyk8s.io/248bf76a-c1f5-4ba7-9a6b-49bfbf38301b   Deployment   conversation-service                      8      0      0      0       0      23d
securerag-hub   policyreport.wgpolicyk8s.io/27a287bf-5f54-4553-b721-b136d7c0ca67   Pod          audit-security-service-5dc8b86497-srmhp   6      0      0      0       0      7d5h
securerag-hub   policyreport.wgpolicyk8s.io/323b7c2c-3d44-4546-be50-d0d721e881d2   ReplicaSet   chatbot-manager-7747c5c74c                4      0      0      0       0      23d
securerag-hub   policyreport.wgpolicyk8s.io/359c9837-0c6b-4bf1-b18d-33b4193d9444   ReplicaSet   portal-web-7f59b76ccd                     4      0      0      0       0      7d5h
securerag-hub   policyreport.wgpolicyk8s.io/38d24002-41e2-4e47-8cde-c2cad01dfa47   ReplicaSet   chatbot-manager-7586fb94f6                4      0      0      0       0      7d5h
securerag-hub   policyreport.wgpolicyk8s.io/4326e73c-2baf-4cbf-a5b0-73a1b7c14372   ReplicaSet   portal-web-5c9c9c5d66                     3      1      0      0       0      7d5h
securerag-hub   policyreport.wgpolicyk8s.io/447727d8-eb69-4e19-941b-87c4fc0ab0cc   ReplicaSet   auth-users-557c884c45                     4      0      0      0       0      7d5h
securerag-hub   policyreport.wgpolicyk8s.io/4ab0f761-1403-4963-a4b3-008823a81898   Service      auth-users                                1      0      0      0       0      23d
securerag-hub   policyreport.wgpolicyk8s.io/4b27aa40-3665-49ca-b772-c2a4d0c3a89e   ReplicaSet   audit-security-service-5dc8b86497         4      0      0      0       0      7d5h
securerag-hub   policyreport.wgpolicyk8s.io/58cfc763-ed9c-41f1-8458-8bbd746078ed   ReplicaSet   conversation-service-55b9dcbc4            4      0      0      0       0      23d
securerag-hub   policyreport.wgpolicyk8s.io/61ee4927-985f-42de-bb9f-5c790cab03b6   Service      portal-web                                1      0      0      0       0      23d
securerag-hub   policyreport.wgpolicyk8s.io/63862f14-20ca-4349-887d-63551f58c0be   ReplicaSet   chatbot-manager-6495b5556                 4      0      0      0       0      7d5h
securerag-hub   policyreport.wgpolicyk8s.io/6b2da2d0-eee5-40ae-b046-c4a71026ad8c   ReplicaSet   chatbot-manager-58d8fdb94f                4      0      0      0       0      23d
securerag-hub   policyreport.wgpolicyk8s.io/734ac693-75f4-4b15-a24a-f7d8813a3379   ReplicaSet   conversation-service-6bc4c7dbc6           4      0      0      0       0      23d
securerag-hub   policyreport.wgpolicyk8s.io/73f729dd-1d38-427f-bf7f-bcf80824ecda   Service      audit-security-service                    1      0      0      0       0      23d
securerag-hub   policyreport.wgpolicyk8s.io/74cdeb19-fc0d-4da2-b3d7-b77c2f079177   ReplicaSet   chatbot-manager-5c868487d8                4      0      0      0       0      7d5h
securerag-hub   policyreport.wgpolicyk8s.io/77975d08-ebb1-40c3-94bd-10f19a083438   ReplicaSet   conversation-service-7678f59b49           4      0      0      0       0      7d5h
securerag-hub   policyreport.wgpolicyk8s.io/79260f4d-dbc3-48a3-8a95-32c06b39788c   ReplicaSet   chatbot-manager-6d6958b667                4      0      0      0       0      23d
securerag-hub   policyreport.wgpolicyk8s.io/7d79e610-c6c7-4bb7-b4ca-3c661f741fdd   Deployment   portal-web                                8      0      0      0       0      23d
securerag-hub   policyreport.wgpolicyk8s.io/86918803-8195-4a6a-b539-09a07e5c99db   Deployment   chatbot-manager                           8      0      0      0       0      23d
securerag-hub   policyreport.wgpolicyk8s.io/87138f5d-d854-410d-b852-913fcfd252ff   ReplicaSet   chatbot-manager-5b9d9fd58                 4      0      0      0       0      7d5h
securerag-hub   policyreport.wgpolicyk8s.io/879b8b74-6a97-4d85-8a39-986fa293a2de   Pod          chatbot-manager-5c868487d8-gh4sv          6      0      0      0       0      7d5h
securerag-hub   policyreport.wgpolicyk8s.io/881ec9ad-a48c-498d-9c16-2acfc7870b9b   ReplicaSet   portal-web-588b497f88                     3      1      0      0       0      7d5h
securerag-hub   policyreport.wgpolicyk8s.io/88ccebff-15de-443a-900f-6d86db2f951f   ReplicaSet   audit-security-service-85976dc85b         4      0      0      0       0      23d
securerag-hub   policyreport.wgpolicyk8s.io/8c655d04-cb54-4b54-9e72-8f9aab94cc8e   ReplicaSet   audit-security-service-78c49d959f         4      0      0      0       0      7d5h
securerag-hub   policyreport.wgpolicyk8s.io/9136f5fc-616b-4c76-8079-c94699dd682a   ReplicaSet   chatbot-manager-79b79d59c4                4      0      0      0       0      23d
securerag-hub   policyreport.wgpolicyk8s.io/9dddcbf3-d260-4413-8b18-9492bb9818f0   ReplicaSet   portal-web-5967644c8                      4      0      0      0       0      7d5h
securerag-hub   policyreport.wgpolicyk8s.io/a6c80d01-971f-49dd-b2d7-6d108bd38626   ReplicaSet   chatbot-manager-54b9bb64f8                4      0      0      0       0      23d
securerag-hub   policyreport.wgpolicyk8s.io/abbe03ff-6f5c-453c-8f16-3de4311f5334   Pod          postgres-auth-fbf55db78-kwlh4             6      0      0      0       0      23d
securerag-hub   policyreport.wgpolicyk8s.io/b12793b7-4529-421f-bd0a-b11bb98c9df2   ReplicaSet   postgres-auth-fbf55db78                   4      0      0      0       0      23d
securerag-hub   policyreport.wgpolicyk8s.io/b4615b5f-f987-4994-a369-f80edf553bc1   ReplicaSet   conversation-service-75f6978f87           4      0      0      0       0      7d5h
securerag-hub   policyreport.wgpolicyk8s.io/b71a80f7-25bb-463f-9b65-5eb41e913f04   ReplicaSet   audit-security-service-585f5dc795         4      0      0      0       0      23d
securerag-hub   policyreport.wgpolicyk8s.io/b89623d5-e5f1-4ccb-9775-d2190af5af3c   ReplicaSet   conversation-service-6fb95765f5           4      0      0      0       0      7d5h
securerag-hub   policyreport.wgpolicyk8s.io/b9971807-6241-4d22-a7c9-0726ee47e43d   ReplicaSet   portal-web-5898f9c5cd                     4      0      0      0       0      23d
securerag-hub   policyreport.wgpolicyk8s.io/ba1b7c01-8628-4a6a-ab3d-421745dc17ee   ReplicaSet   audit-security-service-bdc97f8f6          4      0      0      0       0      23d
securerag-hub   policyreport.wgpolicyk8s.io/becdfea9-e978-4596-b866-e592e11c75f0   Service      conversation-service                      1      0      0      0       0      23d
securerag-hub   policyreport.wgpolicyk8s.io/c4f9d1c8-3e32-4ecd-8f29-8d45b265fdaf   ReplicaSet   audit-security-service-6c44bb459c         4      0      0      0       0      23d
securerag-hub   policyreport.wgpolicyk8s.io/c51f1592-1df8-446b-b925-806e34afaa26   Pod          conversation-service-7678f59b49-fqg8b     6      0      0      0       0      7d5h
securerag-hub   policyreport.wgpolicyk8s.io/c7884863-99d7-417e-972a-ed9de3a16975   ReplicaSet   conversation-service-5cf55dcc7f           4      0      0      0       0      7d5h
securerag-hub   policyreport.wgpolicyk8s.io/c84ad9d8-6fde-4a67-838e-82757d29b3f4   ReplicaSet   postgres-auth-867ddc6dc8                  4      0      0      0       0      23d
securerag-hub   policyreport.wgpolicyk8s.io/ccc92b8b-e3c8-4fd0-8b74-64ac3d81d5ec   Deployment   auth-users                                8      0      0      0       0      7d5h
securerag-hub   policyreport.wgpolicyk8s.io/cec81aa5-7bae-4abe-853c-3683962471a7   ReplicaSet   audit-security-service-68c6959445         4      0      0      0       0      7d5h
securerag-hub   policyreport.wgpolicyk8s.io/d11acadd-fcfb-4a6e-8ac3-2f0b40202c04   Pod          portal-web-84bd8bb87c-fm7sj               6      0      0      0       0      7d5h
securerag-hub   policyreport.wgpolicyk8s.io/d3939ec7-56f3-4ee5-8309-806bb5235471   ReplicaSet   audit-security-service-6c79b48cc7         4      0      0      0       0      7d5h
securerag-hub   policyreport.wgpolicyk8s.io/d9e5a673-5769-4105-b455-579bd2e9b7b5   ReplicaSet   conversation-service-7875d66875           4      0      0      0       0      7d5h
securerag-hub   policyreport.wgpolicyk8s.io/de6e0f1e-b407-42d4-98ba-97defcfa8be1   ReplicaSet   portal-web-548bf768cc                     4      0      0      0       0      7d5h
securerag-hub   policyreport.wgpolicyk8s.io/e654cd9d-f6e0-478f-8a56-11ea90800c46   ReplicaSet   conversation-service-748d585b85           4      0      0      0       0      7d5h
securerag-hub   policyreport.wgpolicyk8s.io/e7006b96-1463-44f8-a100-08f52004c3cf   Deployment   audit-security-service                    8      0      0      0       0      23d
securerag-hub   policyreport.wgpolicyk8s.io/e8b0d0a0-8eba-49ad-9e42-0b5ce9d2b194   ReplicaSet   audit-security-service-667b7997b4         4      0      0      0       0      23d
securerag-hub   policyreport.wgpolicyk8s.io/e970ecc4-7caf-49dc-aaeb-c3b1643d6415   ReplicaSet   postgres-auth-b66fb7bb6                   4      0      0      0       0      23d
securerag-hub   policyreport.wgpolicyk8s.io/efdb4fba-cc0b-4537-9c71-e9f86df246ec   Pod          auth-users-557c884c45-skbzz               6      0      0      0       0      7d5h
securerag-hub   policyreport.wgpolicyk8s.io/f2a8e7c2-4d4e-4357-b4f3-53ca3253ffb9   ReplicaSet   chatbot-manager-648b486f4f                4      0      0      0       0      7d5h
securerag-hub   policyreport.wgpolicyk8s.io/f499c55c-544c-403a-8eb8-a7352a2cff7d   ReplicaSet   audit-security-service-7466d4686c         4      0      0      0       0      7d5h
securerag-hub   policyreport.wgpolicyk8s.io/fa986290-6783-4c5c-96a1-10a344820a90   ReplicaSet   audit-security-service-6d858c9c5c         4      0      0      0       0      7d5h
securerag-hub   policyreport.wgpolicyk8s.io/fe97b470-c794-452d-9b69-c83387bd069e   ReplicaSet   conversation-service-5ffc5d5ff6           4      0      0      0       0      23d
```

## Jenkins login endpoint

```text
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
HTTP/1.1 200 OK
Server: Jetty(12.1.8)
Date: Sat, 18 Jul 2026 13:30:00 GMT
X-Content-Type-Options: nosniff
Reporting-Endpoints: content-security-policy: http://localhost:8085/content-security-policy-reporting-endpoint/wYyDdEyQFEIntbhm1VVoHPaa34YSAscMtb23Nw8ktGU=:YW5vbnltb3Vz:aHVkc29uLm1vZGVsLkh1ZHNvbg==:bG9naW4=
Content-Security-Policy-Report-Only: base-uri 'none'; default-src 'self'; form-action 'self'; frame-ancestors 'self'; img-src 'self' data:; script-src 'report-sample' 'self' usage.jenkins.io; style-src 'report-sample' 'self' 'unsafe-inline'; report-to content-security-policy; report-uri http://localhost:8085/content-security-policy-reporting-endpoint/wYyDdEyQFEIntbhm1VVoHPaa34YSAscMtb23Nw8ktGU=:YW5vbnltb3Vz:aHVkc29uLm1vZGVsLkh1ZHNvbg==:bG9naW4=
Content-Type: text/html;charset=utf-8
Expires: Thu, 01 Jan 1970 00:00:00 GMT
Cache-Control: no-cache,no-store,must-revalidate
X-Hudson: 1.395
X-Jenkins: 2.555.3
X-Jenkins-Session: b1be05f1
X-Frame-Options: sameorigin
X-Instance-Identity: MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA5JUo+DlkkugY4jH3+ZwFNSVwfU4sL4yjIAcDGwvdRhN1XNiuYZu7waQGXmGV6E2dXIpfMKIoKSIzmPbOdh0zfp67NxXBQzwdcePNQQp0IT9q1XxDWCyq/WFvcAq18QrYRDsb+tv4MJ0TYGzbN8iPyop68SDE/90TcdvIZRsuue++lJE1z5WEVI8RphxBSfUERN4/FzXtmgB7gdL77ZHFJ5Y3Y8UsU3+1gSq4bl+8geM9XvPl8mTONhVYflCbvzoT3AGp/JJr85nJr0AXiJIbySpe1NaWQ947wT+3olnhBJuU8znKfCGWwHjQFJ3urMSfSfK9eed9a8a4sZrt5nebTwIDAQAB
Set-Cookie: JSESSIONID.82c7e68f=node015bpd5vtrxqui1tzwc2tmwk8v2428.node0; Path=/; HttpOnly; SameSite=Lax
Transfer-Encoding: chunked

```

## Reading guide

- If `kubectl top` fails, metrics-server is not ready or not installed.
- If HPA targets are `<unknown>`, metrics-server is not feeding resource metrics.
- If Kyverno policy reports are absent, Kyverno is not installed or policies have not generated reports yet.
- For the official demo, this snapshot is enough for a factual runtime proof. Prometheus/Grafana/Loki remain an optional expert extension.
