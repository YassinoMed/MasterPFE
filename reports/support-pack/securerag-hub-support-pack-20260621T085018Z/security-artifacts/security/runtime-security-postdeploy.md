# Runtime Security Post-Deployment Report - SecureRAG Hub

- Generated at UTC: `2026-06-21T08:50:09Z`
- Namespace: `securerag-hub`
- Status: `PARTIEL`

## Global controls

| Control | Status | Evidence |
|---|---:|---|
| `default-deny-all` NetworkPolicy | TERMINÉ | `kubectl get networkpolicy -n securerag-hub` |
| `allow-dns-egress` NetworkPolicy | TERMINÉ | `kubectl get networkpolicy -n securerag-hub` |
| Runtime readonly Role | TERMINÉ | `securerag-runtime-readonly` |
| Audit service RoleBinding | TERMINÉ | `securerag-runtime-readonly-audit-security-service` |

## Workload summary

| Workload | Status | Ready / Desired | imageID coverage | Runtime hardening coverage | ServiceAccount | NetPol | HPA | PDB |
|---|---:|---:|---:|---:|---|---|---|---|
| `auth-users` | PARTIEL | 0 / 1 | 0 / 1 | 0 / 1 | `sa-auth-users` | `True` | `False` | `True` |
| `chatbot-manager` | PARTIEL | 0 / 1 | 0 / 1 | 0 / 1 | `sa-chatbot-manager` | `True` | `False` | `True` |
| `conversation-service` | PARTIEL | 0 / 1 | 0 / 1 | 0 / 1 | `sa-conversation-service` | `True` | `False` | `True` |
| `audit-security-service` | PARTIEL | 0 / 1 | 0 / 1 | 0 / 1 | `sa-audit-security-service` | `True` | `False` | `True` |
| `portal-web` | PARTIEL | 0 / 1 | 0 / 1 | 0 / 1 | `sa-portal-web` | `True` | `True` | `True` |

## Workload details

### auth-users

- Gap: HPA missing
- Gap: ready pods 0/1
- Pod `auth-users-799b8b5664-whwzb` ready=`False` created=`2026-06-21T08:49:51Z` imageIDs=`1`
  - Runtime hardening checks matched the active Pod spec.
  - imageID: ``
- Pod `auth-users-c4b94d64b-t6k79` ready=`False` created=`2026-06-21T08:49:51Z` imageIDs=`1`
  - Runtime hardening checks matched the active Pod spec.
  - imageID: ``

### chatbot-manager

- Gap: HPA missing
- Gap: ready pods 0/1
- Pod `chatbot-manager-779b7cc44b-bskxh` ready=`False` created=`2026-06-21T08:49:51Z` imageIDs=`1`
  - Runtime hardening checks matched the active Pod spec.
  - imageID: ``
- Pod `chatbot-manager-976899cb8-jprbg` ready=`False` created=`2026-06-21T08:49:52Z` imageIDs=`1`
  - Runtime hardening checks matched the active Pod spec.
  - imageID: ``

### conversation-service

- Gap: HPA missing
- Gap: ready pods 0/1
- Pod `conversation-service-64f99b44db-6n2vv` ready=`False` created=`2026-06-21T08:49:52Z` imageIDs=`1`
  - Runtime hardening checks matched the active Pod spec.
  - imageID: ``
- Pod `conversation-service-778479dbbf-wwfcx` ready=`False` created=`2026-06-21T08:49:51Z` imageIDs=`1`
  - Runtime hardening checks matched the active Pod spec.
  - imageID: ``

### audit-security-service

- Gap: HPA missing
- Gap: ready pods 0/1
- Pod `audit-security-service-5fddbb654-n5ltk` ready=`False` created=`2026-06-21T08:49:51Z` imageIDs=`1`
  - Runtime hardening checks matched the active Pod spec.
  - imageID: ``
- Pod `audit-security-service-b478dc875-b5s9d` ready=`False` created=`2026-06-21T08:49:52Z` imageIDs=`1`
  - Runtime hardening checks matched the active Pod spec.
  - imageID: ``

### portal-web

- Gap: ready pods 0/1
- Pod `portal-web-68d97f97f-2sjcd` ready=`False` created=`2026-06-21T08:49:51Z` imageIDs=`1`
  - Runtime hardening checks matched the active Pod spec.
  - imageID: ``
- Pod `portal-web-6ff6cd4545-swmh5` ready=`False` created=`2026-06-21T08:49:51Z` imageIDs=`1`
  - Runtime hardening checks matched the active Pod spec.
  - imageID: ``

## Honest reading

- `TERMINÉ` means the active Deployments and live Pods match the expected runtime security controls.
- `PARTIEL` means at least one live workload, Pod or cluster-side control is missing or inconsistent.
- `DÉPENDANT_DE_L_ENVIRONNEMENT` means the current cluster or namespace is not reachable.

## Deployments

```text
NAME                     READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS               IMAGES                                                    SELECTOR
audit-security-service   0/1     1            0           18s   audit-security-service   localhost:5001/securerag-hub-audit-security-service:dev   app.kubernetes.io/name=audit-security-service,app.kubernetes.io/part-of=securerag-hub
auth-users               0/1     1            0           18s   auth-users               localhost:5001/securerag-hub-auth-users:dev               app.kubernetes.io/name=auth-users,app.kubernetes.io/part-of=securerag-hub
chatbot-manager          0/1     1            0           18s   chatbot-manager          localhost:5001/securerag-hub-chatbot-manager:dev          app.kubernetes.io/name=chatbot-manager,app.kubernetes.io/part-of=securerag-hub
conversation-service     0/1     1            0           18s   conversation-service     localhost:5001/securerag-hub-conversation-service:dev     app.kubernetes.io/name=conversation-service,app.kubernetes.io/part-of=securerag-hub
portal-web               0/1     1            0           18s   portal-web               localhost:5001/securerag-hub-portal-web:dev               app.kubernetes.io/name=portal-web,app.kubernetes.io/part-of=securerag-hub
postgres-auth            0/1     1            0           18s   postgres-auth            postgres:16-alpine                                        app.kubernetes.io/name=postgres-auth,app.kubernetes.io/part-of=securerag-hub
```

## Pods

```text
NAME                                     READY   STATUS                       RESTARTS   AGE   IP            NODE                   NOMINATED NODE   READINESS GATES
audit-security-service-5fddbb654-n5ltk   0/1     ImagePullBackOff             0          18s   10.244.1.2    securerag-dev-worker   <none>           <none>
audit-security-service-b478dc875-b5s9d   0/1     ErrImagePull                 0          17s   10.244.1.12   securerag-dev-worker   <none>           <none>
auth-users-799b8b5664-whwzb              0/1     ImagePullBackOff             0          18s   10.244.1.3    securerag-dev-worker   <none>           <none>
auth-users-c4b94d64b-t6k79               0/1     ErrImagePull                 0          18s   10.244.1.9    securerag-dev-worker   <none>           <none>
chatbot-manager-779b7cc44b-bskxh         0/1     ImagePullBackOff             0          18s   10.244.1.4    securerag-dev-worker   <none>           <none>
chatbot-manager-976899cb8-jprbg          0/1     ErrImagePull                 0          17s   10.244.1.10   securerag-dev-worker   <none>           <none>
conversation-service-64f99b44db-6n2vv    0/1     ImagePullBackOff             0          17s   10.244.1.11   securerag-dev-worker   <none>           <none>
conversation-service-778479dbbf-wwfcx    0/1     ErrImagePull                 0          18s   10.244.1.5    securerag-dev-worker   <none>           <none>
portal-web-68d97f97f-2sjcd               0/1     ErrImagePull                 0          18s   10.244.1.8    securerag-dev-worker   <none>           <none>
portal-web-6ff6cd4545-swmh5              0/1     ImagePullBackOff             0          18s   10.244.1.6    securerag-dev-worker   <none>           <none>
postgres-auth-867ddc6dc8-w9xgr           0/1     CreateContainerConfigError   0          18s   10.244.1.7    securerag-dev-worker   <none>           <none>
```

## Deployment images and imageIDs

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

## ServiceAccounts

```text
NAME                        SECRETS   AGE
default                     0         18s
sa-audit-security-service   0         18s
sa-auth-users               0         18s
sa-chatbot-manager          0         18s
sa-conversation-service     0         18s
sa-portal-web               0         18s
sa-postgres-auth            0         18s
sa-validation               0         18s
```

## Roles and RoleBindings

```text
NAME                                                        CREATED AT
role.rbac.authorization.k8s.io/securerag-runtime-readonly   2026-06-21T08:49:51Z

NAME                                                                                      ROLE                              AGE   USERS   GROUPS   SERVICEACCOUNTS
rolebinding.rbac.authorization.k8s.io/securerag-runtime-readonly-audit-security-service   Role/securerag-runtime-readonly   18s                    securerag-hub/sa-audit-security-service
```

## NetworkPolicies

```text
NAME                             POD-SELECTOR                                                                                                    AGE
allow-dns-egress                 <none>                                                                                                          18s
allow-validation-egress          app.kubernetes.io/part-of=securerag-hub,job-role=validation                                                     18s
allow-validation-ingress         app.kubernetes.io/name in (audit-security-service,auth-users,chatbot-manager,conversation-service,portal-web)   18s
audit-security-service-network   app.kubernetes.io/name=audit-security-service,app.kubernetes.io/part-of=securerag-hub                           18s
auth-users-policy                app.kubernetes.io/name=auth-users,app.kubernetes.io/part-of=securerag-hub                                       18s
chatbot-manager-policy           app.kubernetes.io/name=chatbot-manager,app.kubernetes.io/part-of=securerag-hub                                  18s
conversation-service-network     app.kubernetes.io/name=conversation-service,app.kubernetes.io/part-of=securerag-hub                             18s
default-deny-all                 <none>                                                                                                          18s
portal-web-policy                app.kubernetes.io/name=portal-web,app.kubernetes.io/part-of=securerag-hub                                       18s
postgres-auth-policy             app.kubernetes.io/name=postgres-auth,app.kubernetes.io/part-of=securerag-hub                                    18s
```

## PodDisruptionBudgets

```text
NAME                         MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
audit-security-service-pdb   1               N/A               0                     18s
auth-users-pdb               1               N/A               0                     18s
chatbot-manager-pdb          1               N/A               0                     18s
conversation-service-pdb     1               N/A               0                     18s
portal-web-pdb               1               N/A               0                     18s
```

## HPA

```text
NAME         REFERENCE               TARGETS              MINPODS   MAXPODS   REPLICAS   AGE
portal-web   Deployment/portal-web   cpu: <unknown>/70%   1         3         1          19s
```

## Recent events

```text
19s         Normal    Scheduled                      pod/postgres-auth-867ddc6dc8-w9xgr            Successfully assigned securerag-hub/postgres-auth-867ddc6dc8-w9xgr to securerag-dev-worker
19s         Normal    ScalingReplicaSet              deployment/portal-web                         Scaled up replica set portal-web-68d97f97f from 0 to 1
19s         Normal    ScalingReplicaSet              deployment/portal-web                         Scaled up replica set portal-web-6ff6cd4545 from 0 to 1
19s         Normal    SuccessfulCreate               replicaset/portal-web-6ff6cd4545              Created pod: portal-web-6ff6cd4545-swmh5
19s         Normal    Scheduled                      pod/chatbot-manager-779b7cc44b-bskxh          Successfully assigned securerag-hub/chatbot-manager-779b7cc44b-bskxh to securerag-dev-worker
19s         Normal    ScalingReplicaSet              deployment/audit-security-service             Scaled up replica set audit-security-service-5fddbb654 from 0 to 1
19s         Normal    Scheduled                      pod/auth-users-c4b94d64b-t6k79                Successfully assigned securerag-hub/auth-users-c4b94d64b-t6k79 to securerag-dev-worker
19s         Normal    Scheduled                      pod/auth-users-799b8b5664-whwzb               Successfully assigned securerag-hub/auth-users-799b8b5664-whwzb to securerag-dev-worker
19s         Normal    ScalingReplicaSet              deployment/auth-users                         Scaled up replica set auth-users-c4b94d64b from 0 to 1
19s         Normal    ScalingReplicaSet              deployment/auth-users                         Scaled up replica set auth-users-799b8b5664 from 0 to 1
19s         Normal    Scheduled                      pod/portal-web-6ff6cd4545-swmh5               Successfully assigned securerag-hub/portal-web-6ff6cd4545-swmh5 to securerag-dev-worker
19s         Normal    SuccessfulCreate               replicaset/auth-users-c4b94d64b               Created pod: auth-users-c4b94d64b-t6k79
19s         Normal    Scheduled                      pod/portal-web-68d97f97f-2sjcd                Successfully assigned securerag-hub/portal-web-68d97f97f-2sjcd to securerag-dev-worker
19s         Normal    ScalingReplicaSet              deployment/postgres-auth                      Scaled up replica set postgres-auth-867ddc6dc8 from 0 to 1
19s         Normal    Scheduled                      pod/audit-security-service-5fddbb654-n5ltk    Successfully assigned securerag-hub/audit-security-service-5fddbb654-n5ltk to securerag-dev-worker
19s         Normal    SuccessfulCreate               replicaset/chatbot-manager-779b7cc44b         Created pod: chatbot-manager-779b7cc44b-bskxh
19s         Normal    SuccessfulCreate               replicaset/portal-web-68d97f97f               Created pod: portal-web-68d97f97f-2sjcd
18s         Normal    BackOff                        pod/chatbot-manager-779b7cc44b-bskxh          Back-off pulling image "localhost:5001/securerag-hub-chatbot-manager:dev"
18s         Normal    Pulling                        pod/portal-web-68d97f97f-2sjcd                Pulling image "localhost:5001/securerag-hub-portal-web:dev"
18s         Warning   Failed                         pod/auth-users-799b8b5664-whwzb               Error: ImagePullBackOff
18s         Normal    BackOff                        pod/auth-users-799b8b5664-whwzb               Back-off pulling image "localhost:5001/securerag-hub-auth-users:dev"
18s         Normal    BackOff                        pod/portal-web-6ff6cd4545-swmh5               Back-off pulling image "localhost:5001/securerag-hub-portal-web:dev"
18s         Warning   Failed                         pod/portal-web-6ff6cd4545-swmh5               Error: ImagePullBackOff
18s         Normal    SuccessfulCreate               replicaset/audit-security-service-b478dc875   Created pod: audit-security-service-b478dc875-b5s9d
18s         Normal    ScalingReplicaSet              deployment/conversation-service               Scaled up replica set conversation-service-64f99b44db from 0 to 1
18s         Normal    ScalingReplicaSet              deployment/audit-security-service             Scaled up replica set audit-security-service-b478dc875 from 0 to 1
18s         Normal    Pulling                        pod/audit-security-service-b478dc875-b5s9d    Pulling image "localhost:5001/securerag-hub-audit-security-service:dev"
18s         Normal    Pulling                        pod/auth-users-c4b94d64b-t6k79                Pulling image "localhost:5001/securerag-hub-auth-users:dev"
18s         Normal    Scheduled                      pod/audit-security-service-b478dc875-b5s9d    Successfully assigned securerag-hub/audit-security-service-b478dc875-b5s9d to securerag-dev-worker
18s         Warning   Failed                         pod/chatbot-manager-779b7cc44b-bskxh          Error: ImagePullBackOff
18s         Normal    Scheduled                      pod/chatbot-manager-976899cb8-jprbg           Successfully assigned securerag-hub/chatbot-manager-976899cb8-jprbg to securerag-dev-worker
18s         Normal    Pulling                        pod/chatbot-manager-976899cb8-jprbg           Pulling image "localhost:5001/securerag-hub-chatbot-manager:dev"
18s         Normal    Pulling                        pod/postgres-auth-867ddc6dc8-w9xgr            Pulling image "postgres:16-alpine"
18s         Normal    SuccessfulCreate               replicaset/conversation-service-64f99b44db    Created pod: conversation-service-64f99b44db-6n2vv
18s         Normal    Scheduled                      pod/conversation-service-64f99b44db-6n2vv     Successfully assigned securerag-hub/conversation-service-64f99b44db-6n2vv to securerag-dev-worker
18s         Normal    ScalingReplicaSet              deployment/chatbot-manager                    Scaled up replica set chatbot-manager-976899cb8 from 0 to 1
18s         Normal    SuccessfulCreate               replicaset/chatbot-manager-976899cb8          Created pod: chatbot-manager-976899cb8-jprbg
14s         Warning   Failed                         pod/portal-web-68d97f97f-2sjcd                Failed to pull image "localhost:5001/securerag-hub-portal-web:dev": failed to pull and unpack image "localhost:5001/securerag-hub-portal-web:dev": failed to resolve reference "localhost:5001/securerag-hub-portal-web:dev": failed to do request: Head "http://kind-registry:5000/v2/securerag-hub-portal-web/manifests/dev?ns=localhost%3A5001": dial tcp: lookup kind-registry on 172.18.0.1:53: server misbehaving
14s         Normal    Pulled                         pod/postgres-auth-867ddc6dc8-w9xgr            Successfully pulled image "postgres:16-alpine" in 4.79s (4.794s including waiting). Image size: 116039346 bytes.
14s         Warning   Failed                         pod/portal-web-68d97f97f-2sjcd                Error: ErrImagePull
13s         Normal    BackOff                        pod/conversation-service-778479dbbf-wwfcx     Back-off pulling image "localhost:5001/securerag-hub-conversation-service:dev"
13s         Warning   Failed                         pod/audit-security-service-b478dc875-b5s9d    Failed to pull image "localhost:5001/securerag-hub-audit-security-service:dev": failed to pull and unpack image "localhost:5001/securerag-hub-audit-security-service:dev": failed to resolve reference "localhost:5001/securerag-hub-audit-security-service:dev": failed to do request: Head "http://kind-registry:5000/v2/securerag-hub-audit-security-service/manifests/dev?ns=localhost%3A5001": dial tcp: lookup kind-registry on 172.18.0.1:53: server misbehaving
13s         Warning   Failed                         pod/audit-security-service-b478dc875-b5s9d    Error: ErrImagePull
13s         Warning   Failed                         pod/auth-users-c4b94d64b-t6k79                Failed to pull image "localhost:5001/securerag-hub-auth-users:dev": failed to pull and unpack image "localhost:5001/securerag-hub-auth-users:dev": failed to resolve reference "localhost:5001/securerag-hub-auth-users:dev": failed to do request: Head "http://kind-registry:5000/v2/securerag-hub-auth-users/manifests/dev?ns=localhost%3A5001": dial tcp: lookup kind-registry on 172.18.0.1:53: server misbehaving
13s         Warning   Failed                         pod/auth-users-c4b94d64b-t6k79                Error: ErrImagePull
13s         Warning   Failed                         pod/chatbot-manager-976899cb8-jprbg           Error: ErrImagePull
13s         Warning   Failed                         pod/chatbot-manager-976899cb8-jprbg           Failed to pull image "localhost:5001/securerag-hub-chatbot-manager:dev": failed to pull and unpack image "localhost:5001/securerag-hub-chatbot-manager:dev": failed to resolve reference "localhost:5001/securerag-hub-chatbot-manager:dev": failed to do request: Head "http://kind-registry:5000/v2/securerag-hub-chatbot-manager/manifests/dev?ns=localhost%3A5001": dial tcp: lookup kind-registry on 172.18.0.1:53: server misbehaving
13s         Warning   Failed                         pod/conversation-service-778479dbbf-wwfcx     Error: ImagePullBackOff
12s         Warning   Failed                         pod/audit-security-service-b478dc875-b5s9d    Error: ImagePullBackOff
12s         Warning   Failed                         pod/chatbot-manager-976899cb8-jprbg           Error: ImagePullBackOff
12s         Normal    BackOff                        pod/chatbot-manager-976899cb8-jprbg           Back-off pulling image "localhost:5001/securerag-hub-chatbot-manager:dev"
12s         Normal    BackOff                        pod/audit-security-service-b478dc875-b5s9d    Back-off pulling image "localhost:5001/securerag-hub-audit-security-service:dev"
12s         Warning   Failed                         pod/auth-users-c4b94d64b-t6k79                Error: ImagePullBackOff
12s         Normal    BackOff                        pod/auth-users-c4b94d64b-t6k79                Back-off pulling image "localhost:5001/securerag-hub-auth-users:dev"
12s         Warning   Failed                         pod/conversation-service-64f99b44db-6n2vv     Error: ImagePullBackOff
12s         Normal    BackOff                        pod/conversation-service-64f99b44db-6n2vv     Back-off pulling image "localhost:5001/securerag-hub-conversation-service:dev"
12s         Normal    BackOff                        pod/portal-web-68d97f97f-2sjcd                Back-off pulling image "localhost:5001/securerag-hub-portal-web:dev"
12s         Warning   Failed                         pod/portal-web-68d97f97f-2sjcd                Error: ImagePullBackOff
7s          Normal    Pulling                        pod/audit-security-service-5fddbb654-n5ltk    Pulling image "localhost:5001/securerag-hub-audit-security-service:dev"
7s          Warning   Failed                         pod/audit-security-service-5fddbb654-n5ltk    Failed to pull image "localhost:5001/securerag-hub-audit-security-service:dev": failed to pull and unpack image "localhost:5001/securerag-hub-audit-security-service:dev": failed to resolve reference "localhost:5001/securerag-hub-audit-security-service:dev": failed to do request: Head "http://kind-registry:5000/v2/securerag-hub-audit-security-service/manifests/dev?ns=localhost%3A5001": dial tcp: lookup kind-registry on 172.18.0.1:53: server misbehaving
7s          Warning   Failed                         pod/audit-security-service-5fddbb654-n5ltk    Error: ErrImagePull
5s          Normal    Pulling                        pod/portal-web-6ff6cd4545-swmh5               Pulling image "localhost:5001/securerag-hub-portal-web:dev"
5s          Normal    Pulling                        pod/chatbot-manager-779b7cc44b-bskxh          Pulling image "localhost:5001/securerag-hub-chatbot-manager:dev"
5s          Warning   Failed                         pod/chatbot-manager-779b7cc44b-bskxh          Error: ErrImagePull
5s          Warning   Failed                         pod/portal-web-6ff6cd4545-swmh5               Failed to pull image "localhost:5001/securerag-hub-portal-web:dev": failed to pull and unpack image "localhost:5001/securerag-hub-portal-web:dev": failed to resolve reference "localhost:5001/securerag-hub-portal-web:dev": failed to do request: Head "http://kind-registry:5000/v2/securerag-hub-portal-web/manifests/dev?ns=localhost%3A5001": dial tcp: lookup kind-registry on 172.18.0.1:53: server misbehaving
5s          Warning   Failed                         pod/portal-web-6ff6cd4545-swmh5               Error: ErrImagePull
5s          Warning   Failed                         pod/chatbot-manager-779b7cc44b-bskxh          Failed to pull image "localhost:5001/securerag-hub-chatbot-manager:dev": failed to pull and unpack image "localhost:5001/securerag-hub-chatbot-manager:dev": failed to resolve reference "localhost:5001/securerag-hub-chatbot-manager:dev": failed to do request: Head "http://kind-registry:5000/v2/securerag-hub-chatbot-manager/manifests/dev?ns=localhost%3A5001": dial tcp: lookup kind-registry on 172.18.0.1:53: server misbehaving
4s          Warning   FailedComputeMetricsReplicas   horizontalpodautoscaler/portal-web            invalid metrics (1 invalid out of 1), first error is: failed to get cpu resource metric value: failed to get cpu utilization: unable to get metrics for resource cpu: unable to fetch metrics from resource metrics API: the server could not find the requested resource (get pods.metrics.k8s.io)
4s          Warning   FailedGetResourceMetric        horizontalpodautoscaler/portal-web            failed to get cpu utilization: unable to get metrics for resource cpu: unable to fetch metrics from resource metrics API: the server could not find the requested resource (get pods.metrics.k8s.io)
3s          Warning   Failed                         pod/auth-users-799b8b5664-whwzb               Failed to pull image "localhost:5001/securerag-hub-auth-users:dev": failed to pull and unpack image "localhost:5001/securerag-hub-auth-users:dev": failed to resolve reference "localhost:5001/securerag-hub-auth-users:dev": failed to do request: Head "http://kind-registry:5000/v2/securerag-hub-auth-users/manifests/dev?ns=localhost%3A5001": dial tcp: lookup kind-registry on 172.18.0.1:53: server misbehaving
3s          Normal    Pulling                        pod/auth-users-799b8b5664-whwzb               Pulling image "localhost:5001/securerag-hub-auth-users:dev"
3s          Warning   Failed                         pod/auth-users-799b8b5664-whwzb               Error: ErrImagePull
3s          Warning   Failed                         pod/postgres-auth-867ddc6dc8-w9xgr            Error: secret "securerag-common-secrets" not found
3s          Normal    Pulled                         pod/postgres-auth-867ddc6dc8-w9xgr            Container image "postgres:16-alpine" already present on machine
2s          Warning   Failed                         pod/conversation-service-64f99b44db-6n2vv     Failed to pull image "localhost:5001/securerag-hub-conversation-service:dev": failed to pull and unpack image "localhost:5001/securerag-hub-conversation-service:dev": failed to resolve reference "localhost:5001/securerag-hub-conversation-service:dev": failed to do request: Head "http://kind-registry:5000/v2/securerag-hub-conversation-service/manifests/dev?ns=localhost%3A5001": dial tcp: lookup kind-registry on 172.18.0.1:53: server misbehaving
2s          Warning   Failed                         pod/conversation-service-64f99b44db-6n2vv     Error: ErrImagePull
2s          Normal    Pulling                        pod/conversation-service-64f99b44db-6n2vv     Pulling image "localhost:5001/securerag-hub-conversation-service:dev"
1s          Warning   Failed                         pod/conversation-service-778479dbbf-wwfcx     Error: ErrImagePull
1s          Normal    Pulling                        pod/conversation-service-778479dbbf-wwfcx     Pulling image "localhost:5001/securerag-hub-conversation-service:dev"
1s          Warning   Failed                         pod/conversation-service-778479dbbf-wwfcx     Failed to pull image "localhost:5001/securerag-hub-conversation-service:dev": failed to pull and unpack image "localhost:5001/securerag-hub-conversation-service:dev": failed to resolve reference "localhost:5001/securerag-hub-conversation-service:dev": failed to do request: Head "http://kind-registry:5000/v2/securerag-hub-conversation-service/manifests/dev?ns=localhost%3A5001": dial tcp: lookup kind-registry on 172.18.0.1:53: server misbehaving
```

## Logs deployment/auth-users

```text
Found 2 pods, using pod/auth-users-799b8b5664-whwzb
Error from server (BadRequest): container "auth-users" in pod "auth-users-799b8b5664-whwzb" is waiting to start: trying and failing to pull image
```

## Logs deployment/chatbot-manager

```text
Found 2 pods, using pod/chatbot-manager-779b7cc44b-bskxh
Error from server (BadRequest): container "chatbot-manager" in pod "chatbot-manager-779b7cc44b-bskxh" is waiting to start: trying and failing to pull image
```

## Logs deployment/conversation-service

```text
Found 2 pods, using pod/conversation-service-778479dbbf-wwfcx
Error from server (BadRequest): container "conversation-service" in pod "conversation-service-778479dbbf-wwfcx" is waiting to start: trying and failing to pull image
```

## Logs deployment/audit-security-service

```text
Found 2 pods, using pod/audit-security-service-5fddbb654-n5ltk
Error from server (BadRequest): container "audit-security-service" in pod "audit-security-service-5fddbb654-n5ltk" is waiting to start: trying and failing to pull image
```

## Logs deployment/portal-web

```text
Found 2 pods, using pod/portal-web-68d97f97f-2sjcd
Error from server (BadRequest): container "portal-web" in pod "portal-web-68d97f97f-2sjcd" is waiting to start: image can't be pulled
```
