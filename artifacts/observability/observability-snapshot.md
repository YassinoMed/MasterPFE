# Observability Snapshot - SecureRAG Hub

- Generated at: `2026-06-21T09:02:59Z`
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
NAME                                     READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS               IMAGES                                                    SELECTOR
deployment.apps/audit-security-service   0/1     1            0           13m   audit-security-service   localhost:5001/securerag-hub-audit-security-service:dev   app.kubernetes.io/name=audit-security-service,app.kubernetes.io/part-of=securerag-hub
deployment.apps/auth-users               0/1     1            0           13m   auth-users               localhost:5001/securerag-hub-auth-users:dev               app.kubernetes.io/name=auth-users,app.kubernetes.io/part-of=securerag-hub
deployment.apps/chatbot-manager          0/1     1            0           13m   chatbot-manager          localhost:5001/securerag-hub-chatbot-manager:dev          app.kubernetes.io/name=chatbot-manager,app.kubernetes.io/part-of=securerag-hub
deployment.apps/conversation-service     0/1     1            0           13m   conversation-service     localhost:5001/securerag-hub-conversation-service:dev     app.kubernetes.io/name=conversation-service,app.kubernetes.io/part-of=securerag-hub
deployment.apps/portal-web               0/1     1            0           13m   portal-web               localhost:5001/securerag-hub-portal-web:dev               app.kubernetes.io/name=portal-web,app.kubernetes.io/part-of=securerag-hub
deployment.apps/postgres-auth            0/1     1            0           13m   postgres-auth            postgres:16-alpine                                        app.kubernetes.io/name=postgres-auth,app.kubernetes.io/part-of=securerag-hub

NAME                                         READY   STATUS                       RESTARTS   AGE   IP            NODE                   NOMINATED NODE   READINESS GATES
pod/audit-security-service-5fddbb654-n5ltk   0/1     ImagePullBackOff             0          13m   10.244.1.2    securerag-dev-worker   <none>           <none>
pod/audit-security-service-b478dc875-b5s9d   0/1     ImagePullBackOff             0          13m   10.244.1.12   securerag-dev-worker   <none>           <none>
pod/auth-users-799b8b5664-whwzb              0/1     ImagePullBackOff             0          13m   10.244.1.3    securerag-dev-worker   <none>           <none>
pod/auth-users-c4b94d64b-t6k79               0/1     ImagePullBackOff             0          13m   10.244.1.9    securerag-dev-worker   <none>           <none>
pod/chatbot-manager-779b7cc44b-bskxh         0/1     ImagePullBackOff             0          13m   10.244.1.4    securerag-dev-worker   <none>           <none>
pod/chatbot-manager-976899cb8-jprbg          0/1     ImagePullBackOff             0          13m   10.244.1.10   securerag-dev-worker   <none>           <none>
pod/conversation-service-64f99b44db-6n2vv    0/1     ImagePullBackOff             0          13m   10.244.1.11   securerag-dev-worker   <none>           <none>
pod/conversation-service-778479dbbf-wwfcx    0/1     ImagePullBackOff             0          13m   10.244.1.5    securerag-dev-worker   <none>           <none>
pod/portal-web-68d97f97f-2sjcd               0/1     ImagePullBackOff             0          13m   10.244.1.8    securerag-dev-worker   <none>           <none>
pod/portal-web-6ff6cd4545-swmh5              0/1     ImagePullBackOff             0          13m   10.244.1.6    securerag-dev-worker   <none>           <none>
pod/postgres-auth-867ddc6dc8-w9xgr           0/1     CreateContainerConfigError   0          13m   10.244.1.7    securerag-dev-worker   <none>           <none>

NAME                             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE   SELECTOR
service/audit-security-service   ClusterIP   10.96.181.217   <none>        8000/TCP         13m   app.kubernetes.io/name=audit-security-service,app.kubernetes.io/part-of=securerag-hub
service/auth-users               ClusterIP   10.96.66.119    <none>        8000/TCP         13m   app.kubernetes.io/name=auth-users,app.kubernetes.io/part-of=securerag-hub
service/chatbot-manager          ClusterIP   10.96.87.229    <none>        8000/TCP         13m   app.kubernetes.io/name=chatbot-manager,app.kubernetes.io/part-of=securerag-hub
service/conversation-service     ClusterIP   10.96.227.164   <none>        8000/TCP         13m   app.kubernetes.io/name=conversation-service,app.kubernetes.io/part-of=securerag-hub
service/portal-web               NodePort    10.96.85.85     <none>        8000:30081/TCP   13m   app.kubernetes.io/name=portal-web,app.kubernetes.io/part-of=securerag-hub
service/postgres-auth            ClusterIP   10.96.73.148    <none>        5432/TCP         13m   app.kubernetes.io/name=postgres-auth,app.kubernetes.io/part-of=securerag-hub
```

## HPA

```text
NAME         REFERENCE               TARGETS              MINPODS   MAXPODS   REPLICAS   AGE
portal-web   Deployment/portal-web   cpu: <unknown>/70%   1         3         1          13m
```

## PDB

```text
NAME                         MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
audit-security-service-pdb   1               N/A               0                     13m
auth-users-pdb               1               N/A               0                     13m
chatbot-manager-pdb          1               N/A               0                     13m
conversation-service-pdb     1               N/A               0                     13m
portal-web-pdb               1               N/A               0                     13m
```

## Recent namespace events

```text
LAST SEEN   TYPE      REASON                         OBJECT                                        MESSAGE
68s         Warning   PolicyViolation                service/postgres-auth                         policy securerag-restrict-service-exposure/allow-nodeport-only-for-portal-web fail: Only portal-web may use NodePort in the local demo overlay; LoadBalancer is forbidden.
69s         Warning   PolicyViolation                pod/postgres-auth-867ddc6dc8-w9xgr            policy securerag-restrict-image-references/restrict-registries fail: validation failure: validation error: Runtime images must come from localhost:5001 or ghcr.io. rule restrict-registries[0] failed at path /image/ rule restrict-registries[1] failed at path /image/
68s         Warning   PolicyViolation                pod/postgres-auth-867ddc6dc8-w9xgr            policy securerag-restrict-image-references/restrict-registries fail: validation failure: validation error: Runtime images must come from localhost:5001 or ghcr.io. rule restrict-registries[0] failed at path /image/ rule restrict-registries[1] failed at path /image/
39s         Warning   PolicyViolation                pod/postgres-auth-867ddc6dc8-w9xgr            policy securerag-restrict-image-references/restrict-registries fail: validation failure: validation error: Runtime images must come from localhost:5001 or ghcr.io. rule restrict-registries[0] failed at path /image/ rule restrict-registries[1] failed at path /image/
39s         Warning   PolicyViolation                service/postgres-auth                         policy securerag-restrict-service-exposure/allow-nodeport-only-for-portal-web fail: Only portal-web may use NodePort in the local demo overlay; LoadBalancer is forbidden.
13m         Normal    Scheduled                      pod/portal-web-68d97f97f-2sjcd                Successfully assigned securerag-hub/portal-web-68d97f97f-2sjcd to securerag-dev-worker
13m         Normal    Scheduled                      pod/auth-users-799b8b5664-whwzb               Successfully assigned securerag-hub/auth-users-799b8b5664-whwzb to securerag-dev-worker
13m         Normal    SuccessfulCreate               replicaset/auth-users-c4b94d64b               Created pod: auth-users-c4b94d64b-t6k79
13m         Normal    ScalingReplicaSet              deployment/conversation-service               Scaled up replica set conversation-service-778479dbbf from 0 to 1
13m         Normal    SuccessfulCreate               replicaset/conversation-service-778479dbbf    Created pod: conversation-service-778479dbbf-wwfcx
13m         Normal    ScalingReplicaSet              deployment/portal-web                         Scaled up replica set portal-web-6ff6cd4545 from 0 to 1
13m         Normal    ScalingReplicaSet              deployment/postgres-auth                      Scaled up replica set postgres-auth-867ddc6dc8 from 0 to 1
13m         Normal    SuccessfulCreate               replicaset/postgres-auth-867ddc6dc8           Created pod: postgres-auth-867ddc6dc8-w9xgr
13m         Normal    ScalingReplicaSet              deployment/portal-web                         Scaled up replica set portal-web-68d97f97f from 0 to 1
13m         Normal    ScalingReplicaSet              deployment/audit-security-service             Scaled up replica set audit-security-service-5fddbb654 from 0 to 1
13m         Normal    Scheduled                      pod/conversation-service-778479dbbf-wwfcx     Successfully assigned securerag-hub/conversation-service-778479dbbf-wwfcx to securerag-dev-worker
13m         Normal    SuccessfulCreate               replicaset/audit-security-service-5fddbb654   Created pod: audit-security-service-5fddbb654-n5ltk
13m         Normal    ScalingReplicaSet              deployment/chatbot-manager                    Scaled up replica set chatbot-manager-779b7cc44b from 0 to 1
13m         Normal    Scheduled                      pod/postgres-auth-867ddc6dc8-w9xgr            Successfully assigned securerag-hub/postgres-auth-867ddc6dc8-w9xgr to securerag-dev-worker
13m         Normal    SuccessfulCreate               replicaset/chatbot-manager-779b7cc44b         Created pod: chatbot-manager-779b7cc44b-bskxh
13m         Normal    SuccessfulCreate               replicaset/portal-web-6ff6cd4545              Created pod: portal-web-6ff6cd4545-swmh5
13m         Normal    SuccessfulCreate               replicaset/portal-web-68d97f97f               Created pod: portal-web-68d97f97f-2sjcd
13m         Normal    SuccessfulCreate               replicaset/auth-users-799b8b5664              Created pod: auth-users-799b8b5664-whwzb
13m         Normal    Scheduled                      pod/auth-users-c4b94d64b-t6k79                Successfully assigned securerag-hub/auth-users-c4b94d64b-t6k79 to securerag-dev-worker
13m         Normal    Scheduled                      pod/chatbot-manager-779b7cc44b-bskxh          Successfully assigned securerag-hub/chatbot-manager-779b7cc44b-bskxh to securerag-dev-worker
13m         Normal    ScalingReplicaSet              deployment/auth-users                         Scaled up replica set auth-users-c4b94d64b from 0 to 1
13m         Normal    ScalingReplicaSet              deployment/auth-users                         Scaled up replica set auth-users-799b8b5664 from 0 to 1
13m         Normal    Scheduled                      pod/audit-security-service-5fddbb654-n5ltk    Successfully assigned securerag-hub/audit-security-service-5fddbb654-n5ltk to securerag-dev-worker
13m         Normal    Scheduled                      pod/portal-web-6ff6cd4545-swmh5               Successfully assigned securerag-hub/portal-web-6ff6cd4545-swmh5 to securerag-dev-worker
13m         Normal    ScalingReplicaSet              deployment/conversation-service               Scaled up replica set conversation-service-64f99b44db from 0 to 1
13m         Normal    SuccessfulCreate               replicaset/chatbot-manager-976899cb8          Created pod: chatbot-manager-976899cb8-jprbg
13m         Normal    SuccessfulCreate               replicaset/conversation-service-64f99b44db    Created pod: conversation-service-64f99b44db-6n2vv
13m         Normal    Scheduled                      pod/conversation-service-64f99b44db-6n2vv     Successfully assigned securerag-hub/conversation-service-64f99b44db-6n2vv to securerag-dev-worker
13m         Normal    ScalingReplicaSet              deployment/chatbot-manager                    Scaled up replica set chatbot-manager-976899cb8 from 0 to 1
13m         Normal    Pulling                        pod/postgres-auth-867ddc6dc8-w9xgr            Pulling image "postgres:16-alpine"
13m         Normal    Scheduled                      pod/audit-security-service-b478dc875-b5s9d    Successfully assigned securerag-hub/audit-security-service-b478dc875-b5s9d to securerag-dev-worker
13m         Normal    Scheduled                      pod/chatbot-manager-976899cb8-jprbg           Successfully assigned securerag-hub/chatbot-manager-976899cb8-jprbg to securerag-dev-worker
13m         Normal    ScalingReplicaSet              deployment/audit-security-service             Scaled up replica set audit-security-service-b478dc875 from 0 to 1
13m         Normal    SuccessfulCreate               replicaset/audit-security-service-b478dc875   Created pod: audit-security-service-b478dc875-b5s9d
13m         Normal    Pulled                         pod/postgres-auth-867ddc6dc8-w9xgr            Successfully pulled image "postgres:16-alpine" in 4.79s (4.794s including waiting). Image size: 116039346 bytes.
12m         Warning   FailedGetResourceMetric        horizontalpodautoscaler/portal-web            failed to get cpu utilization: unable to get metrics for resource cpu: unable to fetch metrics from resource metrics API: the server could not find the requested resource (get pods.metrics.k8s.io)
12m         Warning   FailedComputeMetricsReplicas   horizontalpodautoscaler/portal-web            invalid metrics (1 invalid out of 1), first error is: failed to get cpu resource metric value: failed to get cpu utilization: unable to get metrics for resource cpu: unable to fetch metrics from resource metrics API: the server could not find the requested resource (get pods.metrics.k8s.io)
10m         Normal    Pulling                        pod/portal-web-68d97f97f-2sjcd                Pulling image "localhost:5001/securerag-hub-portal-web:dev"
10m         Warning   Failed                         pod/portal-web-68d97f97f-2sjcd                Failed to pull image "localhost:5001/securerag-hub-portal-web:dev": failed to pull and unpack image "localhost:5001/securerag-hub-portal-web:dev": failed to resolve reference "localhost:5001/securerag-hub-portal-web:dev": failed to do request: Head "http://kind-registry:5000/v2/securerag-hub-portal-web/manifests/dev?ns=localhost%3A5001": dial tcp: lookup kind-registry on 172.18.0.1:53: server misbehaving
10m         Warning   Failed                         pod/portal-web-68d97f97f-2sjcd                Error: ErrImagePull
10m         Warning   Failed                         pod/conversation-service-778479dbbf-wwfcx     Failed to pull image "localhost:5001/securerag-hub-conversation-service:dev": failed to pull and unpack image "localhost:5001/securerag-hub-conversation-service:dev": failed to resolve reference "localhost:5001/securerag-hub-conversation-service:dev": failed to do request: Head "http://kind-registry:5000/v2/securerag-hub-conversation-service/manifests/dev?ns=localhost%3A5001": dial tcp: lookup kind-registry on 172.18.0.1:53: server misbehaving
10m         Normal    Pulling                        pod/conversation-service-778479dbbf-wwfcx     Pulling image "localhost:5001/securerag-hub-conversation-service:dev"
10m         Warning   Failed                         pod/conversation-service-778479dbbf-wwfcx     Error: ErrImagePull
10m         Warning   Failed                         pod/portal-web-6ff6cd4545-swmh5               Failed to pull image "localhost:5001/securerag-hub-portal-web:dev": failed to pull and unpack image "localhost:5001/securerag-hub-portal-web:dev": failed to resolve reference "localhost:5001/securerag-hub-portal-web:dev": failed to do request: Head "http://kind-registry:5000/v2/securerag-hub-portal-web/manifests/dev?ns=localhost%3A5001": dial tcp: lookup kind-registry on 172.18.0.1:53: server misbehaving
10m         Warning   Failed                         pod/portal-web-6ff6cd4545-swmh5               Error: ErrImagePull
10m         Normal    Pulling                        pod/portal-web-6ff6cd4545-swmh5               Pulling image "localhost:5001/securerag-hub-portal-web:dev"
10m         Warning   Failed                         pod/auth-users-799b8b5664-whwzb               Failed to pull image "localhost:5001/securerag-hub-auth-users:dev": failed to pull and unpack image "localhost:5001/securerag-hub-auth-users:dev": failed to resolve reference "localhost:5001/securerag-hub-auth-users:dev": failed to do request: Head "http://kind-registry:5000/v2/securerag-hub-auth-users/manifests/dev?ns=localhost%3A5001": dial tcp: lookup kind-registry on 172.18.0.1:53: server misbehaving
10m         Warning   Failed                         pod/auth-users-799b8b5664-whwzb               Error: ErrImagePull
10m         Normal    Pulling                        pod/auth-users-799b8b5664-whwzb               Pulling image "localhost:5001/securerag-hub-auth-users:dev"
10m         Normal    Pulling                        pod/audit-security-service-5fddbb654-n5ltk    Pulling image "localhost:5001/securerag-hub-audit-security-service:dev"
10m         Warning   Failed                         pod/audit-security-service-5fddbb654-n5ltk    Error: ErrImagePull
10m         Warning   Failed                         pod/audit-security-service-5fddbb654-n5ltk    Failed to pull image "localhost:5001/securerag-hub-audit-security-service:dev": failed to pull and unpack image "localhost:5001/securerag-hub-audit-security-service:dev": failed to resolve reference "localhost:5001/securerag-hub-audit-security-service:dev": failed to do request: Head "http://kind-registry:5000/v2/securerag-hub-audit-security-service/manifests/dev?ns=localhost%3A5001": dial tcp: lookup kind-registry on 172.18.0.1:53: server misbehaving
10m         Normal    Pulling                        pod/auth-users-c4b94d64b-t6k79                Pulling image "localhost:5001/securerag-hub-auth-users:dev"
10m         Warning   Failed                         pod/auth-users-c4b94d64b-t6k79                Failed to pull image "localhost:5001/securerag-hub-auth-users:dev": failed to pull and unpack image "localhost:5001/securerag-hub-auth-users:dev": failed to resolve reference "localhost:5001/securerag-hub-auth-users:dev": failed to do request: Head "http://kind-registry:5000/v2/securerag-hub-auth-users/manifests/dev?ns=localhost%3A5001": dial tcp: lookup kind-registry on 172.18.0.1:53: server misbehaving
10m         Warning   Failed                         pod/auth-users-c4b94d64b-t6k79                Error: ErrImagePull
10m         Warning   Failed                         pod/chatbot-manager-779b7cc44b-bskxh          Error: ErrImagePull
10m         Warning   Failed                         pod/chatbot-manager-779b7cc44b-bskxh          Failed to pull image "localhost:5001/securerag-hub-chatbot-manager:dev": failed to pull and unpack image "localhost:5001/securerag-hub-chatbot-manager:dev": failed to resolve reference "localhost:5001/securerag-hub-chatbot-manager:dev": failed to do request: Head "http://kind-registry:5000/v2/securerag-hub-chatbot-manager/manifests/dev?ns=localhost%3A5001": dial tcp: lookup kind-registry on 172.18.0.1:53: server misbehaving
10m         Normal    Pulling                        pod/chatbot-manager-779b7cc44b-bskxh          Pulling image "localhost:5001/securerag-hub-chatbot-manager:dev"
10m         Warning   FailedComputeMetricsReplicas   horizontalpodautoscaler/portal-web            invalid metrics (1 invalid out of 1), first error is: failed to get cpu resource metric value: failed to get cpu utilization: unable to get metrics for resource cpu: unable to fetch metrics from resource metrics API: the server is currently unable to handle the request (get pods.metrics.k8s.io)
10m         Normal    Pulling                        pod/conversation-service-64f99b44db-6n2vv     Pulling image "localhost:5001/securerag-hub-conversation-service:dev"
10m         Warning   Failed                         pod/conversation-service-64f99b44db-6n2vv     Error: ErrImagePull
10m         Warning   Failed                         pod/conversation-service-64f99b44db-6n2vv     Failed to pull image "localhost:5001/securerag-hub-conversation-service:dev": failed to pull and unpack image "localhost:5001/securerag-hub-conversation-service:dev": failed to resolve reference "localhost:5001/securerag-hub-conversation-service:dev": failed to do request: Head "http://kind-registry:5000/v2/securerag-hub-conversation-service/manifests/dev?ns=localhost%3A5001": dial tcp: lookup kind-registry on 172.18.0.1:53: server misbehaving
10m         Normal    Pulling                        pod/chatbot-manager-976899cb8-jprbg           Pulling image "localhost:5001/securerag-hub-chatbot-manager:dev"
10m         Warning   Failed                         pod/chatbot-manager-976899cb8-jprbg           Error: ErrImagePull
10m         Warning   Failed                         pod/chatbot-manager-976899cb8-jprbg           Failed to pull image "localhost:5001/securerag-hub-chatbot-manager:dev": failed to pull and unpack image "localhost:5001/securerag-hub-chatbot-manager:dev": failed to resolve reference "localhost:5001/securerag-hub-chatbot-manager:dev": failed to do request: Head "http://kind-registry:5000/v2/securerag-hub-chatbot-manager/manifests/dev?ns=localhost%3A5001": dial tcp: lookup kind-registry on 172.18.0.1:53: server misbehaving
10m         Normal    Pulling                        pod/audit-security-service-b478dc875-b5s9d    Pulling image "localhost:5001/securerag-hub-audit-security-service:dev"
10m         Warning   Failed                         pod/audit-security-service-b478dc875-b5s9d    Failed to pull image "localhost:5001/securerag-hub-audit-security-service:dev": failed to pull and unpack image "localhost:5001/securerag-hub-audit-security-service:dev": failed to resolve reference "localhost:5001/securerag-hub-audit-security-service:dev": failed to do request: Head "http://kind-registry:5000/v2/securerag-hub-audit-security-service/manifests/dev?ns=localhost%3A5001": dial tcp: lookup kind-registry on 172.18.0.1:53: server misbehaving
10m         Warning   Failed                         pod/audit-security-service-b478dc875-b5s9d    Error: ErrImagePull
7m56s       Normal    Scheduled                      pod/curl-smoke-1782031804                     Successfully assigned securerag-hub/curl-smoke-1782031804 to securerag-dev-worker
7m55s       Normal    Pulling                        pod/curl-smoke-1782031804                     Pulling image "curlimages/curl:8.11.1"
7m53s       Normal    Started                        pod/curl-smoke-1782031804                     Started container curl-smoke-1782031804
7m53s       Normal    Created                        pod/curl-smoke-1782031804                     Created container: curl-smoke-1782031804
7m53s       Normal    Pulled                         pod/curl-smoke-1782031804                     Successfully pulled image "curlimages/curl:8.11.1" in 2.185s (2.185s including waiting). Image size: 9560620 bytes.
7m20s       Normal    Created                        pod/curl-sec-smoke-1782032139                 Created container: curl-sec-smoke-1782032139
7m20s       Normal    Pulled                         pod/curl-sec-smoke-1782032139                 Container image "curlimages/curl:8.11.1" already present on machine
7m20s       Normal    Scheduled                      pod/curl-sec-smoke-1782032139                 Successfully assigned securerag-hub/curl-sec-smoke-1782032139 to securerag-dev-worker
7m19s       Normal    Started                        pod/curl-sec-smoke-1782032139                 Started container curl-sec-smoke-1782032139
6m47s       Normal    Scheduled                      pod/e2e-functional-check-1782032173           Successfully assigned securerag-hub/e2e-functional-check-1782032173 to securerag-dev-worker
6m46s       Normal    Pulled                         pod/e2e-functional-check-1782032173           Container image "curlimages/curl:8.11.1" already present on machine
6m46s       Normal    Created                        pod/e2e-functional-check-1782032173           Created container: e2e-functional-check-1782032173
6m46s       Normal    Started                        pod/e2e-functional-check-1782032173           Started container e2e-functional-check-1782032173
3m8s        Normal    BackOff                        pod/auth-users-c4b94d64b-t6k79                Back-off pulling image "localhost:5001/securerag-hub-auth-users:dev"
3m6s        Normal    BackOff                        pod/audit-security-service-5fddbb654-n5ltk    Back-off pulling image "localhost:5001/securerag-hub-audit-security-service:dev"
3m6s        Warning   Failed                         pod/audit-security-service-5fddbb654-n5ltk    Error: ImagePullBackOff
3m5s        Normal    BackOff                        pod/conversation-service-778479dbbf-wwfcx     Back-off pulling image "localhost:5001/securerag-hub-conversation-service:dev"
3m2s        Normal    BackOff                        pod/portal-web-6ff6cd4545-swmh5               Back-off pulling image "localhost:5001/securerag-hub-portal-web:dev"
3m2s        Warning   Failed                         pod/portal-web-6ff6cd4545-swmh5               Error: ImagePullBackOff
3m1s        Normal    BackOff                        pod/chatbot-manager-976899cb8-jprbg           Back-off pulling image "localhost:5001/securerag-hub-chatbot-manager:dev"
3m1s        Warning   Failed                         pod/auth-users-799b8b5664-whwzb               Error: ImagePullBackOff
3m1s        Normal    BackOff                        pod/conversation-service-64f99b44db-6n2vv     Back-off pulling image "localhost:5001/securerag-hub-conversation-service:dev"
3m1s        Warning   Failed                         pod/chatbot-manager-976899cb8-jprbg           Error: ImagePullBackOff
3m1s        Warning   Failed                         pod/conversation-service-64f99b44db-6n2vv     Error: ImagePullBackOff
3m1s        Normal    BackOff                        pod/auth-users-799b8b5664-whwzb               Back-off pulling image "localhost:5001/securerag-hub-auth-users:dev"
3m          Normal    BackOff                        pod/portal-web-68d97f97f-2sjcd                Back-off pulling image "localhost:5001/securerag-hub-portal-web:dev"
3m          Warning   Failed                         pod/portal-web-68d97f97f-2sjcd                Error: ImagePullBackOff
3m          Warning   Failed                         pod/chatbot-manager-779b7cc44b-bskxh          Error: ImagePullBackOff
3m          Normal    BackOff                        pod/chatbot-manager-779b7cc44b-bskxh          Back-off pulling image "localhost:5001/securerag-hub-chatbot-manager:dev"
2m59s       Warning   Failed                         pod/audit-security-service-b478dc875-b5s9d    Error: ImagePullBackOff
2m59s       Normal    BackOff                        pod/audit-security-service-b478dc875-b5s9d    Back-off pulling image "localhost:5001/securerag-hub-audit-security-service:dev"
2m58s       Normal    Pulled                         pod/postgres-auth-867ddc6dc8-w9xgr            Container image "postgres:16-alpine" already present on machine
2m58s       Warning   Failed                         pod/postgres-auth-867ddc6dc8-w9xgr            Error: secret "securerag-common-secrets" not found
2m54s       Warning   FailedGetResourceMetric        horizontalpodautoscaler/portal-web            failed to get cpu utilization: unable to get metrics for resource cpu: unable to fetch metrics from resource metrics API: the server is currently unable to handle the request (get pods.metrics.k8s.io)
2m53s       Warning   Failed                         pod/auth-users-c4b94d64b-t6k79                Error: ImagePullBackOff
2m52s       Warning   Failed                         pod/conversation-service-778479dbbf-wwfcx     Error: ImagePullBackOff
```

## Metrics API

```text
NAME                     SERVICE                      AVAILABLE                  AGE
v1beta1.metrics.k8s.io   kube-system/metrics-server   False (MissingEndpoints)   12m
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
NAME                                   ADMISSION   BACKGROUND   READY   AGE   FAILURE POLICY   VALIDATE   MUTATE   GENERATE   VERIFY IMAGES   MESSAGE
securerag-audit-cleartext-env-values   true        true         True    71s                    1          0        0          0               Ready
securerag-require-pod-security         true        true         True    71s                    2          0        0          0               Ready
securerag-require-workload-controls    true        true         True    70s                    2          0        0          0               Ready
securerag-restrict-image-references    true        true         True    70s                    3          0        0          0               Ready
securerag-restrict-service-exposure    true        true         True    70s                    1          0        0          0               Ready
securerag-restrict-volume-types        true        true         True    70s                    1          0        0          0               Ready
securerag-verify-cosign-images         true        false        True    70s                    0          0        0          1               Ready
```

## Policy reports

```text
NAMESPACE       NAME                                                               KIND         NAME                                     PASS   FAIL   WARN   ERROR   SKIP   AGE
securerag-hub   policyreport.wgpolicyk8s.io/02177cb2-a975-43cf-b9cc-34095a19f9f6   Pod          portal-web-6ff6cd4545-swmh5              6      0      0      0       0      60s
securerag-hub   policyreport.wgpolicyk8s.io/0af2c865-3b0d-49a5-a7da-804ce361d6fc   Deployment   portal-web                               6      0      0      0       0      60s
securerag-hub   policyreport.wgpolicyk8s.io/0fe2bf13-3895-45a1-9c6c-a69487ef6a1f   Pod          auth-users-c4b94d64b-t6k79               6      0      0      0       0      60s
securerag-hub   policyreport.wgpolicyk8s.io/10830846-6264-4388-aafd-f1e94ec58b2e   Service      audit-security-service                   1      0      0      0       0      59s
securerag-hub   policyreport.wgpolicyk8s.io/10f26d7a-9da3-4ed5-9b82-cfe2edcd975d   ReplicaSet   conversation-service-64f99b44db          4      0      0      0       0      60s
securerag-hub   policyreport.wgpolicyk8s.io/1d20f675-dcad-44af-8df9-c109e1bd88ca   ReplicaSet   postgres-auth-867ddc6dc8                 4      0      0      0       0      60s
securerag-hub   policyreport.wgpolicyk8s.io/23d605ae-917e-4db5-aee5-de8763ef1892   Pod          conversation-service-64f99b44db-6n2vv    6      0      0      0       0      61s
securerag-hub   policyreport.wgpolicyk8s.io/25c40f4e-5780-4f17-b412-fae7b23694c9   ReplicaSet   portal-web-6ff6cd4545                    4      0      0      0       0      60s
securerag-hub   policyreport.wgpolicyk8s.io/2b96f891-7d77-432a-a657-2f4cf7a67833   Service      chatbot-manager                          1      0      0      0       0      59s
securerag-hub   policyreport.wgpolicyk8s.io/3bbde1fc-579f-4c67-9b3a-bfcf87521c1b   Pod          audit-security-service-b478dc875-b5s9d   6      0      0      0       0      60s
securerag-hub   policyreport.wgpolicyk8s.io/4209f692-729b-4575-a1cd-a95e38138066   Pod          audit-security-service-5fddbb654-n5ltk   6      0      0      0       0      61s
securerag-hub   policyreport.wgpolicyk8s.io/5b36bbc6-f77e-4689-94db-209c0e890d24   Service      auth-users                               1      0      0      0       0      59s
securerag-hub   policyreport.wgpolicyk8s.io/5f6a66e2-d4aa-4c42-98b6-13faaf3d6c6a   ReplicaSet   auth-users-c4b94d64b                     4      0      0      0       0      60s
securerag-hub   policyreport.wgpolicyk8s.io/609c3fc4-1423-4b8d-94f9-6caf8d95dedc   Pod          auth-users-799b8b5664-whwzb              6      0      0      0       0      60s
securerag-hub   policyreport.wgpolicyk8s.io/685da5a9-4050-42fa-b69f-263a00ebfcbc   ReplicaSet   audit-security-service-b478dc875         4      0      0      0       0      60s
securerag-hub   policyreport.wgpolicyk8s.io/766e969b-569f-407e-a6ae-a067c015f512   Pod          chatbot-manager-779b7cc44b-bskxh         6      0      0      0       0      61s
securerag-hub   policyreport.wgpolicyk8s.io/7f8a19b2-19ee-4239-9aab-d77c8429e96d   Service      postgres-auth                            0      1      0      0       0      59s
securerag-hub   policyreport.wgpolicyk8s.io/815a6cf6-65d1-41a3-9c66-b0e3257ac10b   Deployment   auth-users                               6      0      0      0       0      60s
securerag-hub   policyreport.wgpolicyk8s.io/819080ea-ed29-482c-b6da-9fce980be1ea   ReplicaSet   chatbot-manager-779b7cc44b               4      0      0      0       0      60s
securerag-hub   policyreport.wgpolicyk8s.io/823cb9df-09d9-409a-b559-9a017d2b039e   Service      portal-web                               1      0      0      0       0      59s
securerag-hub   policyreport.wgpolicyk8s.io/84f8448f-378d-4597-9353-c6213983f615   Pod          chatbot-manager-976899cb8-jprbg          6      0      0      0       0      60s
securerag-hub   policyreport.wgpolicyk8s.io/868ed9d4-86e1-4b4d-a066-23e3fc1c45af   Service      conversation-service                     1      0      0      0       0      59s
securerag-hub   policyreport.wgpolicyk8s.io/8f63f457-7089-4f26-969c-86663c792739   Pod          postgres-auth-867ddc6dc8-w9xgr           5      1      0      0       0      61s
securerag-hub   policyreport.wgpolicyk8s.io/92fc148d-803c-4129-a59e-070e1605f256   ReplicaSet   conversation-service-778479dbbf          4      0      0      0       0      60s
securerag-hub   policyreport.wgpolicyk8s.io/9628a5b1-1536-434b-9b79-da5bc5bf96bb   Deployment   chatbot-manager                          6      0      0      0       0      60s
securerag-hub   policyreport.wgpolicyk8s.io/9bd25686-b67e-43a7-8b3b-7d9f702956d0   Deployment   audit-security-service                   6      0      0      0       0      60s
securerag-hub   policyreport.wgpolicyk8s.io/a53b69a9-54f7-416e-ba4b-702605a564ca   Deployment   postgres-auth                            6      0      0      0       0      60s
securerag-hub   policyreport.wgpolicyk8s.io/af637b0d-f110-4122-8983-4ce3bbaed2c0   Pod          portal-web-68d97f97f-2sjcd               6      0      0      0       0      60s
securerag-hub   policyreport.wgpolicyk8s.io/b3f4cb53-6c92-499d-a2b3-901fe2b3a82f   ReplicaSet   chatbot-manager-976899cb8                4      0      0      0       0      60s
securerag-hub   policyreport.wgpolicyk8s.io/c4ac0686-47c1-443c-8a88-ec1714ddaea3   ReplicaSet   audit-security-service-5fddbb654         4      0      0      0       0      60s
securerag-hub   policyreport.wgpolicyk8s.io/d9707dd8-805d-4f50-a777-82ee2269df80   ReplicaSet   auth-users-799b8b5664                    4      0      0      0       0      60s
securerag-hub   policyreport.wgpolicyk8s.io/db5d9e32-aae8-4dde-805f-bcfc8f026cc0   Pod          conversation-service-778479dbbf-wwfcx    6      0      0      0       0      60s
securerag-hub   policyreport.wgpolicyk8s.io/f50b3b4a-7035-46ba-9337-488f1ee6a07c   ReplicaSet   portal-web-68d97f97f                     4      0      0      0       0      60s
securerag-hub   policyreport.wgpolicyk8s.io/fa6b373e-acf4-4955-b39c-e6af826a73bf   Deployment   conversation-service                     6      0      0      0       0      60s
```

## Jenkins login endpoint

```text
  % Total    % Received % Xferd  Average Speed  Time    Time    Time   Current
                                 Dload  Upload  Total   Spent   Left   Speed
  0      0   0      0   0      0      0      0                              0
curl: (7) Failed to connect to localhost port 8085 after 0 ms: Could not connect to server
```

## Reading guide

- If `kubectl top` fails, metrics-server is not ready or not installed.
- If HPA targets are `<unknown>`, metrics-server is not feeding resource metrics.
- If Kyverno policy reports are absent, Kyverno is not installed or policies have not generated reports yet.
- For the official demo, this snapshot is enough for a factual runtime proof. Prometheus/Grafana/Loki remain an optional expert extension.
