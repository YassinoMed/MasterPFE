# Production Runtime Evidence - SecureRAG Hub

- Generated at UTC: `2026-06-21T09:02:26Z`
- Namespace: `securerag-hub`
- Status: `PARTIEL`

| Component | Status | Detail |
|---|---:|---|
| Kubernetes API | TERMINÉ | API server reachable |
| Official deployments | PARTIEL | Availability check for five Laravel workloads |
| HPA objects | TERMINÉ | HPA resources returned for namespace |
| metrics-server | DÉPENDANT_DE_L_ENVIRONNEMENT | kubectl top pods/nodes unavailable |
| PodDisruptionBudget | TERMINÉ | PDB resources returned for namespace |

## Kubernetes context

```text
kind-securerag-dev
```

## Deployments

```text
NAME                     READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS               IMAGES                                                    SELECTOR
audit-security-service   0/1     1            0           13m   audit-security-service   localhost:5001/securerag-hub-audit-security-service:dev   app.kubernetes.io/name=audit-security-service,app.kubernetes.io/part-of=securerag-hub
auth-users               0/1     1            0           13m   auth-users               localhost:5001/securerag-hub-auth-users:dev               app.kubernetes.io/name=auth-users,app.kubernetes.io/part-of=securerag-hub
chatbot-manager          0/1     1            0           13m   chatbot-manager          localhost:5001/securerag-hub-chatbot-manager:dev          app.kubernetes.io/name=chatbot-manager,app.kubernetes.io/part-of=securerag-hub
conversation-service     0/1     1            0           13m   conversation-service     localhost:5001/securerag-hub-conversation-service:dev     app.kubernetes.io/name=conversation-service,app.kubernetes.io/part-of=securerag-hub
portal-web               0/1     1            0           13m   portal-web               localhost:5001/securerag-hub-portal-web:dev               app.kubernetes.io/name=portal-web,app.kubernetes.io/part-of=securerag-hub
postgres-auth            0/1     1            0           13m   postgres-auth            postgres:16-alpine                                        app.kubernetes.io/name=postgres-auth,app.kubernetes.io/part-of=securerag-hub
```

## Pods

```text
NAME                                     READY   STATUS                       RESTARTS   AGE   IP            NODE                   NOMINATED NODE   READINESS GATES
audit-security-service-5fddbb654-n5ltk   0/1     ImagePullBackOff             0          13m   10.244.1.2    securerag-dev-worker   <none>           <none>
audit-security-service-b478dc875-b5s9d   0/1     ImagePullBackOff             0          13m   10.244.1.12   securerag-dev-worker   <none>           <none>
auth-users-799b8b5664-whwzb              0/1     ImagePullBackOff             0          13m   10.244.1.3    securerag-dev-worker   <none>           <none>
auth-users-c4b94d64b-t6k79               0/1     ImagePullBackOff             0          13m   10.244.1.9    securerag-dev-worker   <none>           <none>
chatbot-manager-779b7cc44b-bskxh         0/1     ImagePullBackOff             0          13m   10.244.1.4    securerag-dev-worker   <none>           <none>
chatbot-manager-976899cb8-jprbg          0/1     ImagePullBackOff             0          13m   10.244.1.10   securerag-dev-worker   <none>           <none>
conversation-service-64f99b44db-6n2vv    0/1     ImagePullBackOff             0          13m   10.244.1.11   securerag-dev-worker   <none>           <none>
conversation-service-778479dbbf-wwfcx    0/1     ImagePullBackOff             0          13m   10.244.1.5    securerag-dev-worker   <none>           <none>
portal-web-68d97f97f-2sjcd               0/1     ImagePullBackOff             0          13m   10.244.1.8    securerag-dev-worker   <none>           <none>
portal-web-6ff6cd4545-swmh5              0/1     ImagePullBackOff             0          13m   10.244.1.6    securerag-dev-worker   <none>           <none>
postgres-auth-867ddc6dc8-w9xgr           0/1     CreateContainerConfigError   0          13m   10.244.1.7    securerag-dev-worker   <none>           <none>
```

## Services

```text
NAME                     TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE   SELECTOR
audit-security-service   ClusterIP   10.96.181.217   <none>        8000/TCP         13m   app.kubernetes.io/name=audit-security-service,app.kubernetes.io/part-of=securerag-hub
auth-users               ClusterIP   10.96.66.119    <none>        8000/TCP         13m   app.kubernetes.io/name=auth-users,app.kubernetes.io/part-of=securerag-hub
chatbot-manager          ClusterIP   10.96.87.229    <none>        8000/TCP         13m   app.kubernetes.io/name=chatbot-manager,app.kubernetes.io/part-of=securerag-hub
conversation-service     ClusterIP   10.96.227.164   <none>        8000/TCP         13m   app.kubernetes.io/name=conversation-service,app.kubernetes.io/part-of=securerag-hub
portal-web               NodePort    10.96.85.85     <none>        8000:30081/TCP   13m   app.kubernetes.io/name=portal-web,app.kubernetes.io/part-of=securerag-hub
postgres-auth            ClusterIP   10.96.73.148    <none>        5432/TCP         13m   app.kubernetes.io/name=postgres-auth,app.kubernetes.io/part-of=securerag-hub
```

## ServiceAccounts

```text
NAME                        SECRETS   AGE
default                     0         13m
sa-audit-security-service   0         13m
sa-auth-users               0         13m
sa-chatbot-manager          0         13m
sa-conversation-service     0         13m
sa-portal-web               0         13m
sa-postgres-auth            0         13m
sa-validation               0         13m
```

## Roles and RoleBindings

```text
NAME                                                        CREATED AT
role.rbac.authorization.k8s.io/securerag-runtime-readonly   2026-06-21T08:49:51Z

NAME                                                                                      ROLE                              AGE   USERS   GROUPS   SERVICEACCOUNTS
rolebinding.rbac.authorization.k8s.io/securerag-runtime-readonly-audit-security-service   Role/securerag-runtime-readonly   13m                    securerag-hub/sa-audit-security-service
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

## HPA

```text
NAME         REFERENCE               TARGETS              MINPODS   MAXPODS   REPLICAS   AGE
portal-web   Deployment/portal-web   cpu: <unknown>/70%   1         3         1          13m
```

## ResourceQuota

```text
NAME                  REQUEST                                                                                                                                                                           LIMIT                                                                                   AGE
securerag-hub-quota   persistentvolumeclaims: 0/10, pods: 11/30, requests.cpu: 1100m/3, requests.ephemeral-storage: 1664Mi/4Gi, requests.memory: 1408Mi/3Gi, requests.storage: 0/40Gi, services: 6/20   limits.cpu: 3700m/8, limits.ephemeral-storage: 6656Mi/12Gi, limits.memory: 3840Mi/8Gi   13m
```

## LimitRange

```text
NAME                     CREATED AT
securerag-hub-defaults   2026-06-21T08:49:51Z
```

## NetworkPolicies

```text
NAME                             POD-SELECTOR                                                                                                    AGE
allow-dns-egress                 <none>                                                                                                          13m
allow-validation-egress          app.kubernetes.io/part-of=securerag-hub,job-role=validation                                                     13m
allow-validation-ingress         app.kubernetes.io/name in (audit-security-service,auth-users,chatbot-manager,conversation-service,portal-web)   13m
audit-security-service-network   app.kubernetes.io/name=audit-security-service,app.kubernetes.io/part-of=securerag-hub                           13m
auth-users-policy                app.kubernetes.io/name=auth-users,app.kubernetes.io/part-of=securerag-hub                                       13m
chatbot-manager-policy           app.kubernetes.io/name=chatbot-manager,app.kubernetes.io/part-of=securerag-hub                                  13m
conversation-service-network     app.kubernetes.io/name=conversation-service,app.kubernetes.io/part-of=securerag-hub                             13m
default-deny-all                 <none>                                                                                                          13m
portal-web-policy                app.kubernetes.io/name=portal-web,app.kubernetes.io/part-of=securerag-hub                                       13m
postgres-auth-policy             app.kubernetes.io/name=postgres-auth,app.kubernetes.io/part-of=securerag-hub                                    13m
```

## Pod images and imageIDs

```text
audit-security-service-5fddbb654-n5ltk	localhost:5001/securerag-hub-audit-security-service:dev	
audit-security-service-b478dc875-b5s9d	localhost:5001/securerag-hub-audit-security-service:dev	
auth-users-799b8b5664-whwzb	localhost:5001/securerag-hub-auth-users:dev	
auth-users-c4b94d64b-t6k79	localhost:5001/securerag-hub-auth-users:dev	
chatbot-manager-779b7cc44b-bskxh	localhost:5001/securerag-hub-chatbot-manager:dev	
chatbot-manager-976899cb8-jprbg	localhost:5001/securerag-hub-chatbot-manager:dev	
conversation-service-64f99b44db-6n2vv	localhost:5001/securerag-hub-conversation-service:dev	
conversation-service-778479dbbf-wwfcx	localhost:5001/securerag-hub-conversation-service:dev	
portal-web-68d97f97f-2sjcd	localhost:5001/securerag-hub-portal-web:dev	
portal-web-6ff6cd4545-swmh5	localhost:5001/securerag-hub-portal-web:dev	
postgres-auth-867ddc6dc8-w9xgr	postgres:16-alpine	
```

## Recent events

```text
LAST SEEN   TYPE      REASON                         OBJECT                                        MESSAGE
66s         Warning   PolicyViolation                service/postgres-auth                         policy securerag-restrict-service-exposure/allow-nodeport-only-for-portal-web fail: Only portal-web may use NodePort in the local demo overlay; LoadBalancer is forbidden.
66s         Warning   PolicyViolation                pod/postgres-auth-867ddc6dc8-w9xgr            policy securerag-restrict-image-references/restrict-registries fail: validation failure: validation error: Runtime images must come from localhost:5001 or ghcr.io. rule restrict-registries[0] failed at path /image/ rule restrict-registries[1] failed at path /image/
65s         Warning   PolicyViolation                pod/postgres-auth-867ddc6dc8-w9xgr            policy securerag-restrict-image-references/restrict-registries fail: validation failure: validation error: Runtime images must come from localhost:5001 or ghcr.io. rule restrict-registries[0] failed at path /image/ rule restrict-registries[1] failed at path /image/
36s         Warning   PolicyViolation                pod/postgres-auth-867ddc6dc8-w9xgr            policy securerag-restrict-image-references/restrict-registries fail: validation failure: validation error: Runtime images must come from localhost:5001 or ghcr.io. rule restrict-registries[0] failed at path /image/ rule restrict-registries[1] failed at path /image/
36s         Warning   PolicyViolation                service/postgres-auth                         policy securerag-restrict-service-exposure/allow-nodeport-only-for-portal-web fail: Only portal-web may use NodePort in the local demo overlay; LoadBalancer is forbidden.
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
7m53s       Normal    Scheduled                      pod/curl-smoke-1782031804                     Successfully assigned securerag-hub/curl-smoke-1782031804 to securerag-dev-worker
7m52s       Normal    Pulling                        pod/curl-smoke-1782031804                     Pulling image "curlimages/curl:8.11.1"
7m50s       Normal    Started                        pod/curl-smoke-1782031804                     Started container curl-smoke-1782031804
7m50s       Normal    Created                        pod/curl-smoke-1782031804                     Created container: curl-smoke-1782031804
7m50s       Normal    Pulled                         pod/curl-smoke-1782031804                     Successfully pulled image "curlimages/curl:8.11.1" in 2.185s (2.185s including waiting). Image size: 9560620 bytes.
7m17s       Normal    Created                        pod/curl-sec-smoke-1782032139                 Created container: curl-sec-smoke-1782032139
7m17s       Normal    Pulled                         pod/curl-sec-smoke-1782032139                 Container image "curlimages/curl:8.11.1" already present on machine
7m17s       Normal    Scheduled                      pod/curl-sec-smoke-1782032139                 Successfully assigned securerag-hub/curl-sec-smoke-1782032139 to securerag-dev-worker
7m16s       Normal    Started                        pod/curl-sec-smoke-1782032139                 Started container curl-sec-smoke-1782032139
6m44s       Normal    Scheduled                      pod/e2e-functional-check-1782032173           Successfully assigned securerag-hub/e2e-functional-check-1782032173 to securerag-dev-worker
6m43s       Normal    Pulled                         pod/e2e-functional-check-1782032173           Container image "curlimages/curl:8.11.1" already present on machine
6m43s       Normal    Created                        pod/e2e-functional-check-1782032173           Created container: e2e-functional-check-1782032173
6m43s       Normal    Started                        pod/e2e-functional-check-1782032173           Started container e2e-functional-check-1782032173
3m5s        Normal    BackOff                        pod/auth-users-c4b94d64b-t6k79                Back-off pulling image "localhost:5001/securerag-hub-auth-users:dev"
3m3s        Normal    BackOff                        pod/audit-security-service-5fddbb654-n5ltk    Back-off pulling image "localhost:5001/securerag-hub-audit-security-service:dev"
3m3s        Warning   Failed                         pod/audit-security-service-5fddbb654-n5ltk    Error: ImagePullBackOff
3m2s        Normal    BackOff                        pod/conversation-service-778479dbbf-wwfcx     Back-off pulling image "localhost:5001/securerag-hub-conversation-service:dev"
2m59s       Normal    BackOff                        pod/portal-web-6ff6cd4545-swmh5               Back-off pulling image "localhost:5001/securerag-hub-portal-web:dev"
2m59s       Warning   Failed                         pod/portal-web-6ff6cd4545-swmh5               Error: ImagePullBackOff
2m58s       Normal    BackOff                        pod/chatbot-manager-976899cb8-jprbg           Back-off pulling image "localhost:5001/securerag-hub-chatbot-manager:dev"
2m58s       Warning   Failed                         pod/auth-users-799b8b5664-whwzb               Error: ImagePullBackOff
2m58s       Normal    BackOff                        pod/conversation-service-64f99b44db-6n2vv     Back-off pulling image "localhost:5001/securerag-hub-conversation-service:dev"
2m58s       Warning   Failed                         pod/chatbot-manager-976899cb8-jprbg           Error: ImagePullBackOff
2m58s       Warning   Failed                         pod/conversation-service-64f99b44db-6n2vv     Error: ImagePullBackOff
2m58s       Normal    BackOff                        pod/auth-users-799b8b5664-whwzb               Back-off pulling image "localhost:5001/securerag-hub-auth-users:dev"
2m57s       Normal    BackOff                        pod/portal-web-68d97f97f-2sjcd                Back-off pulling image "localhost:5001/securerag-hub-portal-web:dev"
2m57s       Warning   Failed                         pod/portal-web-68d97f97f-2sjcd                Error: ImagePullBackOff
2m57s       Warning   Failed                         pod/chatbot-manager-779b7cc44b-bskxh          Error: ImagePullBackOff
2m57s       Normal    BackOff                        pod/chatbot-manager-779b7cc44b-bskxh          Back-off pulling image "localhost:5001/securerag-hub-chatbot-manager:dev"
2m56s       Warning   Failed                         pod/audit-security-service-b478dc875-b5s9d    Error: ImagePullBackOff
2m56s       Normal    BackOff                        pod/audit-security-service-b478dc875-b5s9d    Back-off pulling image "localhost:5001/securerag-hub-audit-security-service:dev"
2m55s       Normal    Pulled                         pod/postgres-auth-867ddc6dc8-w9xgr            Container image "postgres:16-alpine" already present on machine
2m55s       Warning   Failed                         pod/postgres-auth-867ddc6dc8-w9xgr            Error: secret "securerag-common-secrets" not found
2m51s       Warning   FailedGetResourceMetric        horizontalpodautoscaler/portal-web            failed to get cpu utilization: unable to get metrics for resource cpu: unable to fetch metrics from resource metrics API: the server is currently unable to handle the request (get pods.metrics.k8s.io)
2m50s       Warning   Failed                         pod/auth-users-c4b94d64b-t6k79                Error: ImagePullBackOff
2m49s       Warning   Failed                         pod/conversation-service-778479dbbf-wwfcx     Error: ImagePullBackOff
```

## Metrics APIService

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

## Describe deployment/portal-web

```text
Name:                   portal-web
Namespace:              securerag-hub
CreationTimestamp:      Sun, 21 Jun 2026 08:49:51 +0000
Labels:                 app.kubernetes.io/part-of=securerag-hub
Annotations:            deployment.kubernetes.io/revision: 2
                        kube-score/ignore:
                          pod-probes, container-security-context-user-group-id, deployment-replicas, networkpolicy-targets-pod, container-image-pull-policy, pod-net...
Selector:               app.kubernetes.io/name=portal-web,app.kubernetes.io/part-of=securerag-hub
Replicas:               1 desired | 1 updated | 2 total | 0 available | 2 unavailable
StrategyType:           RollingUpdate
MinReadySeconds:        0
RollingUpdateStrategy:  0 max unavailable, 1 max surge
Pod Template:
  Labels:           app.kubernetes.io/name=portal-web
                    app.kubernetes.io/part-of=securerag-hub
  Annotations:      kube-score/ignore:
                      pod-probes, container-security-context-user-group-id, deployment-replicas, networkpolicy-targets-pod, container-image-pull-policy, pod-net...
                    kubectl.kubernetes.io/restartedAt: 2026-06-21T08:49:51Z
                    security.securerag.dev/internal-cleartext-justification: Internal ClusterIP service calls only; egress is restricted by NetworkPolicies.
                    security.securerag.dev/internal-cleartext-scope: cluster-only-networkpolicy
  Service Account:  sa-portal-web
  Containers:
   portal-web:
    Image:      localhost:5001/securerag-hub-portal-web:dev
    Port:       8000/TCP (http)
    Host Port:  0/TCP (http)
    Limits:
      cpu:                400m
      ephemeral-storage:  1Gi
      memory:             512Mi
    Requests:
      cpu:                100m
      ephemeral-storage:  256Mi
      memory:             128Mi
    Liveness:             http-get http://:http/health delay=30s timeout=3s period=20s #success=1 #failure=3
    Readiness:            http-get http://:http/health delay=10s timeout=3s period=10s #success=1 #failure=6
    Startup:              http-get http://:http/health delay=5s timeout=3s period=5s #success=1 #failure=18
    Environment Variables from:
      securerag-common-config   ConfigMap  Optional: false
      securerag-common-secrets  Secret     Optional: true
    Environment:
      APP_ENV:                        production
      APP_DEBUG:                      false
      INTERNAL_SERVICE_SCHEME:        http
      APP_URL:                        $(INTERNAL_SERVICE_SCHEME)://portal-web:8000
      DB_CONNECTION:                  sqlite
      DB_DATABASE:                    /tmp/securerag-runtime/database/database.sqlite
      SESSION_DRIVER:                 file
      CACHE_STORE:                    file
      LOG_CHANNEL:                    stderr
      CREATE_DOTENV:                  false
      QUEUE_CONNECTION:               sync
      SECURERAG_PORTAL_BACKEND_MODE:  auto
      AUTH_USERS_BASE_URL:            $(INTERNAL_SERVICE_SCHEME)://auth-users:8000
      CHATBOT_MANAGER_BASE_URL:       $(INTERNAL_SERVICE_SCHEME)://chatbot-manager:8000
      CONVERSATION_BASE_URL:          $(INTERNAL_SERVICE_SCHEME)://conversation-service:8000
      AUDIT_SECURITY_BASE_URL:        $(INTERNAL_SERVICE_SCHEME)://audit-security-service:8000
    Mounts:
      /tmp from tmp (rw)
      /var/www/html/bootstrap/cache from app-cache (rw)
      /var/www/html/storage from app-storage (rw)
  Volumes:
   app-storage:
    Type:       EmptyDir (a temporary directory that shares a pod's lifetime)
    Medium:     
    SizeLimit:  <unset>
   app-cache:
    Type:       EmptyDir (a temporary directory that shares a pod's lifetime)
    Medium:     
    SizeLimit:  <unset>
   tmp:
    Type:          EmptyDir (a temporary directory that shares a pod's lifetime)
    Medium:        
    SizeLimit:     <unset>
  Node-Selectors:  <none>
  Tolerations:     <none>
Conditions:
  Type           Status  Reason
  ----           ------  ------
  Available      False   MinimumReplicasUnavailable
  Progressing    False   ProgressDeadlineExceeded
OldReplicaSets:  portal-web-6ff6cd4545 (1/1 replicas created)
NewReplicaSet:   portal-web-68d97f97f (1/1 replicas created)
Events:
  Type    Reason             Age   From                   Message
  ----    ------             ----  ----                   -------
  Normal  ScalingReplicaSet  13m   deployment-controller  Scaled up replica set portal-web-6ff6cd4545 from 0 to 1
  Normal  ScalingReplicaSet  13m   deployment-controller  Scaled up replica set portal-web-68d97f97f from 0 to 1
```

## Logs deployment/portal-web

```text
Found 2 pods, using pod/portal-web-68d97f97f-2sjcd
Error from server (BadRequest): container "portal-web" in pod "portal-web-68d97f97f-2sjcd" is waiting to start: trying and failing to pull image
```

## Describe deployment/auth-users

```text
Name:                   auth-users
Namespace:              securerag-hub
CreationTimestamp:      Sun, 21 Jun 2026 08:49:51 +0000
Labels:                 app.kubernetes.io/part-of=securerag-hub
Annotations:            deployment.kubernetes.io/revision: 2
                        kube-score/ignore:
                          pod-probes, container-security-context-user-group-id, deployment-replicas, networkpolicy-targets-pod, container-image-pull-policy, pod-net...
Selector:               app.kubernetes.io/name=auth-users,app.kubernetes.io/part-of=securerag-hub
Replicas:               1 desired | 1 updated | 2 total | 0 available | 2 unavailable
StrategyType:           RollingUpdate
MinReadySeconds:        0
RollingUpdateStrategy:  25% max unavailable, 25% max surge
Pod Template:
  Labels:           app.kubernetes.io/name=auth-users
                    app.kubernetes.io/part-of=securerag-hub
  Annotations:      kube-score/ignore:
                      pod-probes, container-security-context-user-group-id, deployment-replicas, networkpolicy-targets-pod, container-image-pull-policy, pod-net...
                    kubectl.kubernetes.io/restartedAt: 2026-06-21T08:49:51Z
                    security.securerag.dev/internal-cleartext-justification: Internal ClusterIP service calls only; egress is restricted by NetworkPolicies.
                    security.securerag.dev/internal-cleartext-scope: cluster-only-networkpolicy
  Service Account:  sa-auth-users
  Containers:
   auth-users:
    Image:      localhost:5001/securerag-hub-auth-users:dev
    Port:       8000/TCP (http)
    Host Port:  0/TCP (http)
    Limits:
      cpu:                300m
      ephemeral-storage:  512Mi
      memory:             256Mi
    Requests:
      cpu:                100m
      ephemeral-storage:  128Mi
      memory:             128Mi
    Liveness:             http-get http://:http/health delay=15s timeout=3s period=20s #success=1 #failure=3
    Readiness:            http-get http://:http/health delay=5s timeout=3s period=10s #success=1 #failure=6
    Startup:              http-get http://:http/health delay=5s timeout=3s period=5s #success=1 #failure=18
    Environment Variables from:
      securerag-common-config   ConfigMap  Optional: false
      securerag-common-secrets  Secret     Optional: true
    Environment:
      SERVICE_NAME:                 auth-users-service
      INTERNAL_SERVICE_SCHEME:      http
      APP_ENV:                      production
      APP_DEBUG:                    false
      APP_URL:                      $(INTERNAL_SERVICE_SCHEME)://auth-users:8000
      DB_CONNECTION:                pgsql
      DB_HOST:                      postgres-auth
      DB_PORT:                      5432
      DB_DATABASE:                  auth_users
      DB_USERNAME:                  securerag
      SESSION_DRIVER:               file
      CACHE_STORE:                  file
      QUEUE_CONNECTION:             sync
      LOG_CHANNEL:                  stderr
      CREATE_DOTENV:                false
      SECURERAG_AUTHZ_ALLOW_LOCAL:  false
    Mounts:
      /tmp from tmp (rw)
  Volumes:
   tmp:
    Type:          EmptyDir (a temporary directory that shares a pod's lifetime)
    Medium:        
    SizeLimit:     <unset>
  Node-Selectors:  <none>
  Tolerations:     <none>
Conditions:
  Type           Status  Reason
  ----           ------  ------
  Available      False   MinimumReplicasUnavailable
  Progressing    False   ProgressDeadlineExceeded
OldReplicaSets:  auth-users-799b8b5664 (1/1 replicas created)
NewReplicaSet:   auth-users-c4b94d64b (1/1 replicas created)
Events:
  Type    Reason             Age   From                   Message
  ----    ------             ----  ----                   -------
  Normal  ScalingReplicaSet  13m   deployment-controller  Scaled up replica set auth-users-799b8b5664 from 0 to 1
  Normal  ScalingReplicaSet  13m   deployment-controller  Scaled up replica set auth-users-c4b94d64b from 0 to 1
```

## Logs deployment/auth-users

```text
Found 2 pods, using pod/auth-users-799b8b5664-whwzb
Error from server (BadRequest): container "auth-users" in pod "auth-users-799b8b5664-whwzb" is waiting to start: trying and failing to pull image
```

## Describe deployment/chatbot-manager

```text
Name:                   chatbot-manager
Namespace:              securerag-hub
CreationTimestamp:      Sun, 21 Jun 2026 08:49:51 +0000
Labels:                 app.kubernetes.io/part-of=securerag-hub
Annotations:            deployment.kubernetes.io/revision: 2
                        kube-score/ignore:
                          pod-probes, container-security-context-user-group-id, deployment-replicas, networkpolicy-targets-pod, container-image-pull-policy, pod-net...
Selector:               app.kubernetes.io/name=chatbot-manager,app.kubernetes.io/part-of=securerag-hub
Replicas:               1 desired | 1 updated | 2 total | 0 available | 2 unavailable
StrategyType:           RollingUpdate
MinReadySeconds:        0
RollingUpdateStrategy:  25% max unavailable, 25% max surge
Pod Template:
  Labels:           app.kubernetes.io/name=chatbot-manager
                    app.kubernetes.io/part-of=securerag-hub
  Annotations:      kube-score/ignore:
                      pod-probes, container-security-context-user-group-id, deployment-replicas, networkpolicy-targets-pod, container-image-pull-policy, pod-net...
                    kubectl.kubernetes.io/restartedAt: 2026-06-21T08:49:51Z
                    security.securerag.dev/internal-cleartext-justification: Internal ClusterIP service calls only; egress is restricted by NetworkPolicies.
                    security.securerag.dev/internal-cleartext-scope: cluster-only-networkpolicy
  Service Account:  sa-chatbot-manager
  Containers:
   chatbot-manager:
    Image:      localhost:5001/securerag-hub-chatbot-manager:dev
    Port:       8000/TCP (http)
    Host Port:  0/TCP (http)
    Limits:
      cpu:                300m
      ephemeral-storage:  512Mi
      memory:             256Mi
    Requests:
      cpu:                100m
      ephemeral-storage:  128Mi
      memory:             128Mi
    Liveness:             http-get http://:http/health delay=15s timeout=3s period=20s #success=1 #failure=3
    Readiness:            http-get http://:http/health delay=5s timeout=3s period=10s #success=1 #failure=6
    Startup:              http-get http://:http/health delay=5s timeout=3s period=5s #success=1 #failure=18
    Environment Variables from:
      securerag-common-config   ConfigMap  Optional: false
      securerag-common-secrets  Secret     Optional: true
    Environment:
      SERVICE_NAME:                 chatbot-manager-service
      INTERNAL_SERVICE_SCHEME:      http
      AUTH_USERS_URL:               $(INTERNAL_SERVICE_SCHEME)://auth-users:8000
      APP_ENV:                      production
      APP_DEBUG:                    false
      APP_URL:                      $(INTERNAL_SERVICE_SCHEME)://chatbot-manager:8000
      DB_CONNECTION:                sqlite
      DB_DATABASE:                  /tmp/securerag-runtime/database/database.sqlite
      SESSION_DRIVER:               file
      CACHE_STORE:                  file
      QUEUE_CONNECTION:             sync
      LOG_CHANNEL:                  stderr
      CREATE_DOTENV:                false
      SECURERAG_AUTHZ_ALLOW_LOCAL:  false
    Mounts:
      /tmp from tmp (rw)
  Volumes:
   tmp:
    Type:          EmptyDir (a temporary directory that shares a pod's lifetime)
    Medium:        
    SizeLimit:     <unset>
  Node-Selectors:  <none>
  Tolerations:     <none>
Conditions:
  Type           Status  Reason
  ----           ------  ------
  Available      False   MinimumReplicasUnavailable
  Progressing    False   ProgressDeadlineExceeded
OldReplicaSets:  chatbot-manager-779b7cc44b (1/1 replicas created)
NewReplicaSet:   chatbot-manager-976899cb8 (1/1 replicas created)
Events:
  Type    Reason             Age   From                   Message
  ----    ------             ----  ----                   -------
  Normal  ScalingReplicaSet  13m   deployment-controller  Scaled up replica set chatbot-manager-779b7cc44b from 0 to 1
  Normal  ScalingReplicaSet  13m   deployment-controller  Scaled up replica set chatbot-manager-976899cb8 from 0 to 1
```

## Logs deployment/chatbot-manager

```text
Found 2 pods, using pod/chatbot-manager-779b7cc44b-bskxh
Error from server (BadRequest): container "chatbot-manager" in pod "chatbot-manager-779b7cc44b-bskxh" is waiting to start: trying and failing to pull image
```

## Describe deployment/conversation-service

```text
Name:                   conversation-service
Namespace:              securerag-hub
CreationTimestamp:      Sun, 21 Jun 2026 08:49:51 +0000
Labels:                 app.kubernetes.io/part-of=securerag-hub
Annotations:            deployment.kubernetes.io/revision: 2
                        kube-score/ignore:
                          pod-probes, container-security-context-user-group-id, deployment-replicas, networkpolicy-targets-pod, container-image-pull-policy, pod-net...
Selector:               app.kubernetes.io/name=conversation-service,app.kubernetes.io/part-of=securerag-hub
Replicas:               1 desired | 1 updated | 2 total | 0 available | 2 unavailable
StrategyType:           RollingUpdate
MinReadySeconds:        0
RollingUpdateStrategy:  25% max unavailable, 25% max surge
Pod Template:
  Labels:           app.kubernetes.io/name=conversation-service
                    app.kubernetes.io/part-of=securerag-hub
  Annotations:      kube-score/ignore:
                      pod-probes, container-security-context-user-group-id, deployment-replicas, networkpolicy-targets-pod, container-image-pull-policy, pod-net...
                    kubectl.kubernetes.io/restartedAt: 2026-06-21T08:49:52Z
                    security.securerag.dev/internal-cleartext-justification: Internal ClusterIP service calls only; egress is restricted by NetworkPolicies.
                    security.securerag.dev/internal-cleartext-scope: cluster-only-networkpolicy
  Service Account:  sa-conversation-service
  Containers:
   conversation-service:
    Image:      localhost:5001/securerag-hub-conversation-service:dev
    Port:       8000/TCP (http)
    Host Port:  0/TCP (http)
    Limits:
      cpu:                300m
      ephemeral-storage:  512Mi
      memory:             384Mi
    Requests:
      cpu:                100m
      ephemeral-storage:  128Mi
      memory:             128Mi
    Liveness:             http-get http://:http/health delay=15s timeout=3s period=20s #success=1 #failure=3
    Readiness:            http-get http://:http/health delay=5s timeout=3s period=10s #success=1 #failure=6
    Startup:              http-get http://:http/health delay=5s timeout=3s period=5s #success=1 #failure=18
    Environment Variables from:
      securerag-common-config   ConfigMap  Optional: false
      securerag-common-secrets  Secret     Optional: true
    Environment:
      SERVICE_NAME:                 conversation-service
      INTERNAL_SERVICE_SCHEME:      http
      APP_ENV:                      production
      APP_DEBUG:                    false
      APP_URL:                      $(INTERNAL_SERVICE_SCHEME)://conversation-service:8000
      DB_CONNECTION:                sqlite
      DB_DATABASE:                  /tmp/securerag-runtime/database/database.sqlite
      SESSION_DRIVER:               file
      CACHE_STORE:                  file
      QUEUE_CONNECTION:             sync
      LOG_CHANNEL:                  stderr
      CREATE_DOTENV:                false
      SECURERAG_AUTHZ_ALLOW_LOCAL:  false
    Mounts:
      /tmp from tmp (rw)
  Volumes:
   tmp:
    Type:          EmptyDir (a temporary directory that shares a pod's lifetime)
    Medium:        
    SizeLimit:     <unset>
  Node-Selectors:  <none>
  Tolerations:     <none>
Conditions:
  Type           Status  Reason
  ----           ------  ------
  Available      False   MinimumReplicasUnavailable
  Progressing    False   ProgressDeadlineExceeded
OldReplicaSets:  conversation-service-778479dbbf (1/1 replicas created)
NewReplicaSet:   conversation-service-64f99b44db (1/1 replicas created)
Events:
  Type    Reason             Age   From                   Message
  ----    ------             ----  ----                   -------
  Normal  ScalingReplicaSet  13m   deployment-controller  Scaled up replica set conversation-service-778479dbbf from 0 to 1
  Normal  ScalingReplicaSet  13m   deployment-controller  Scaled up replica set conversation-service-64f99b44db from 0 to 1
```

## Logs deployment/conversation-service

```text
Found 2 pods, using pod/conversation-service-778479dbbf-wwfcx
Error from server (BadRequest): container "conversation-service" in pod "conversation-service-778479dbbf-wwfcx" is waiting to start: trying and failing to pull image
```

## Describe deployment/audit-security-service

```text
Name:                   audit-security-service
Namespace:              securerag-hub
CreationTimestamp:      Sun, 21 Jun 2026 08:49:51 +0000
Labels:                 app.kubernetes.io/part-of=securerag-hub
Annotations:            deployment.kubernetes.io/revision: 2
                        kube-score/ignore:
                          pod-probes, container-security-context-user-group-id, deployment-replicas, networkpolicy-targets-pod, container-image-pull-policy, pod-net...
Selector:               app.kubernetes.io/name=audit-security-service,app.kubernetes.io/part-of=securerag-hub
Replicas:               1 desired | 1 updated | 2 total | 0 available | 2 unavailable
StrategyType:           RollingUpdate
MinReadySeconds:        0
RollingUpdateStrategy:  25% max unavailable, 25% max surge
Pod Template:
  Labels:           app.kubernetes.io/name=audit-security-service
                    app.kubernetes.io/part-of=securerag-hub
  Annotations:      kube-score/ignore:
                      pod-probes, container-security-context-user-group-id, deployment-replicas, networkpolicy-targets-pod, container-image-pull-policy, pod-net...
                    kubectl.kubernetes.io/restartedAt: 2026-06-21T08:49:52Z
                    security.securerag.dev/internal-cleartext-justification: Internal ClusterIP service calls only; egress is restricted by NetworkPolicies.
                    security.securerag.dev/internal-cleartext-scope: cluster-only-networkpolicy
  Service Account:  sa-audit-security-service
  Containers:
   audit-security-service:
    Image:      localhost:5001/securerag-hub-audit-security-service:dev
    Port:       8000/TCP (http)
    Host Port:  0/TCP (http)
    Limits:
      cpu:                300m
      ephemeral-storage:  512Mi
      memory:             384Mi
    Requests:
      cpu:                100m
      ephemeral-storage:  128Mi
      memory:             128Mi
    Liveness:             http-get http://:http/health delay=15s timeout=3s period=20s #success=1 #failure=3
    Readiness:            http-get http://:http/health delay=5s timeout=3s period=10s #success=1 #failure=6
    Startup:              http-get http://:http/health delay=5s timeout=3s period=5s #success=1 #failure=18
    Environment Variables from:
      securerag-common-config   ConfigMap  Optional: false
      securerag-common-secrets  Secret     Optional: true
    Environment:
      SERVICE_NAME:                 audit-security-service
      INTERNAL_SERVICE_SCHEME:      http
      APP_ENV:                      production
      APP_DEBUG:                    false
      APP_URL:                      $(INTERNAL_SERVICE_SCHEME)://audit-security-service:8000
      DB_CONNECTION:                sqlite
      DB_DATABASE:                  /tmp/securerag-runtime/database/database.sqlite
      SESSION_DRIVER:               file
      CACHE_STORE:                  file
      QUEUE_CONNECTION:             sync
      LOG_CHANNEL:                  stderr
      CREATE_DOTENV:                false
      SECURERAG_AUTHZ_ALLOW_LOCAL:  false
    Mounts:
      /tmp from tmp (rw)
  Volumes:
   tmp:
    Type:          EmptyDir (a temporary directory that shares a pod's lifetime)
    Medium:        
    SizeLimit:     <unset>
  Node-Selectors:  <none>
  Tolerations:     <none>
Conditions:
  Type           Status  Reason
  ----           ------  ------
  Available      False   MinimumReplicasUnavailable
  Progressing    False   ProgressDeadlineExceeded
OldReplicaSets:  audit-security-service-5fddbb654 (1/1 replicas created)
NewReplicaSet:   audit-security-service-b478dc875 (1/1 replicas created)
Events:
  Type    Reason             Age   From                   Message
  ----    ------             ----  ----                   -------
  Normal  ScalingReplicaSet  13m   deployment-controller  Scaled up replica set audit-security-service-5fddbb654 from 0 to 1
  Normal  ScalingReplicaSet  13m   deployment-controller  Scaled up replica set audit-security-service-b478dc875 from 0 to 1
```

## Logs deployment/audit-security-service

```text
Found 2 pods, using pod/audit-security-service-5fddbb654-n5ltk
Error from server (BadRequest): container "audit-security-service" in pod "audit-security-service-5fddbb654-n5ltk" is waiting to start: trying and failing to pull image
```

## Reading guide

- `TERMINÉ` means the runtime command succeeded in the current cluster.
- `PARTIEL` means the Kubernetes object is missing or incomplete.
- `DÉPENDANT_DE_L_ENVIRONNEMENT` means an active cluster, metrics-server or kubeconfig is required.
- This script is read-only and does not install, patch, delete or restart any workload.
