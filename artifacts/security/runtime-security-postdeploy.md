# Runtime Security Post-Deployment Report - SecureRAG Hub

- Generated at UTC: `2026-07-05T11:59:18Z`
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
| `auth-users` | PARTIEL | 3 / 3 | 3 / 3 | 3 / 3 | `sa-auth-users` | `True` | `False` | `True` |
| `chatbot-manager` | PARTIEL | 1 / 1 | 1 / 1 | 1 / 1 | `sa-chatbot-manager` | `True` | `False` | `True` |
| `conversation-service` | PARTIEL | 1 / 1 | 1 / 1 | 1 / 1 | `sa-conversation-service` | `True` | `False` | `True` |
| `audit-security-service` | PARTIEL | 1 / 1 | 1 / 1 | 1 / 1 | `sa-audit-security-service` | `True` | `False` | `True` |
| `portal-web` | TERMINÉ | 3 / 3 | 3 / 3 | 3 / 3 | `sa-portal-web` | `True` | `True` | `True` |

## Workload details

### auth-users

- Gap: HPA missing
- Pod `auth-users-8678978685-bfl4l` ready=`True` created=`2026-06-25T10:30:42Z` imageIDs=`1`
  - Runtime hardening checks matched the active Pod spec.
  - imageID: `localhost:5001/securerag-hub-auth-users@sha256:7b24d8aa5f36d0db05d10fb2a46286711cc4a2304f47dde84ba796362aef5522`
- Pod `auth-users-8678978685-l7968` ready=`True` created=`2026-06-25T10:30:54Z` imageIDs=`1`
  - Runtime hardening checks matched the active Pod spec.
  - imageID: `localhost:5001/securerag-hub-auth-users@sha256:7b24d8aa5f36d0db05d10fb2a46286711cc4a2304f47dde84ba796362aef5522`
- Pod `auth-users-8678978685-zrn25` ready=`True` created=`2026-06-25T10:31:25Z` imageIDs=`1`
  - Runtime hardening checks matched the active Pod spec.
  - imageID: `localhost:5001/securerag-hub-auth-users@sha256:7b24d8aa5f36d0db05d10fb2a46286711cc4a2304f47dde84ba796362aef5522`

### chatbot-manager

- Gap: HPA missing
- Pod `chatbot-manager-79b79d59c4-lvgtp` ready=`True` created=`2026-06-25T10:30:42Z` imageIDs=`1`
  - Runtime hardening checks matched the active Pod spec.
  - imageID: `localhost:5001/securerag-hub-chatbot-manager@sha256:086ed526afb4439f6d4c5590326be3a757574ccda5e894ce1b652054bde84513`

### conversation-service

- Gap: HPA missing
- Pod `conversation-service-6bc4c7dbc6-pq7xf` ready=`True` created=`2026-06-25T10:30:43Z` imageIDs=`1`
  - Runtime hardening checks matched the active Pod spec.
  - imageID: `localhost:5001/securerag-hub-conversation-service@sha256:35f53f4cd274b54021812ed48b95991af875c7e8e0aa66c53bb06df65fe4e03f`

### audit-security-service

- Gap: HPA missing
- Pod `audit-security-service-667b7997b4-j5m7r` ready=`True` created=`2026-06-25T10:30:43Z` imageIDs=`1`
  - Runtime hardening checks matched the active Pod spec.
  - imageID: `localhost:5001/securerag-hub-audit-security-service@sha256:6cf5cd864a1eb4b9179869b55519c1ba7b86d03f355b28506d3b7de97325d9bb`

### portal-web

- No deployment-level hardening gap detected.
- Pod `portal-web-859c78db95-8xxmr` ready=`True` created=`2026-06-25T10:31:26Z` imageIDs=`1`
  - Runtime hardening checks matched the active Pod spec.
  - imageID: `localhost:5001/securerag-hub-portal-web@sha256:fa1fc37b44b4cedc7e32c38940f1971f5e9af7c7b6d425d66d3214cd4bc18f80`
- Pod `portal-web-859c78db95-v9vwx` ready=`True` created=`2026-06-25T10:30:59Z` imageIDs=`1`
  - Runtime hardening checks matched the active Pod spec.
  - imageID: `localhost:5001/securerag-hub-portal-web@sha256:fa1fc37b44b4cedc7e32c38940f1971f5e9af7c7b6d425d66d3214cd4bc18f80`
- Pod `portal-web-859c78db95-z68jt` ready=`True` created=`2026-06-25T10:30:42Z` imageIDs=`1`
  - Runtime hardening checks matched the active Pod spec.
  - imageID: `localhost:5001/securerag-hub-portal-web@sha256:fa1fc37b44b4cedc7e32c38940f1971f5e9af7c7b6d425d66d3214cd4bc18f80`

## Honest reading

- `TERMINÉ` means the active Deployments and live Pods match the expected runtime security controls.
- `PARTIEL` means at least one live workload, Pod or cluster-side control is missing or inconsistent.
- `DÉPENDANT_DE_L_ENVIRONNEMENT` means the current cluster or namespace is not reachable.

## Deployments

```text
NAME                     READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS               IMAGES                                                     SELECTOR
audit-security-service   1/1     1            1           11d   audit-security-service   localhost:5001/securerag-hub-audit-security-service:demo   app.kubernetes.io/name=audit-security-service,app.kubernetes.io/part-of=securerag-hub
auth-users               3/3     3            3           11d   auth-users               localhost:5001/securerag-hub-auth-users:demo               app.kubernetes.io/name=auth-users,app.kubernetes.io/part-of=securerag-hub
chatbot-manager          1/1     1            1           11d   chatbot-manager          localhost:5001/securerag-hub-chatbot-manager:demo          app.kubernetes.io/name=chatbot-manager,app.kubernetes.io/part-of=securerag-hub
conversation-service     1/1     1            1           11d   conversation-service     localhost:5001/securerag-hub-conversation-service:demo     app.kubernetes.io/name=conversation-service,app.kubernetes.io/part-of=securerag-hub
portal-web               3/3     3            3           11d   portal-web               localhost:5001/securerag-hub-portal-web:demo               app.kubernetes.io/name=portal-web,app.kubernetes.io/part-of=securerag-hub
postgres-auth            1/1     1            1           11d   postgres-auth            localhost:5001/postgres:16-alpine                          app.kubernetes.io/name=postgres-auth,app.kubernetes.io/part-of=securerag-hub
```

## Pods

```text
NAME                                      READY   STATUS    RESTARTS   AGE   IP             NODE                   NOMINATED NODE   READINESS GATES
audit-security-service-667b7997b4-j5m7r   1/1     Running   0          10d   10.244.1.226   securerag-dev-worker   <none>           <none>
auth-users-8678978685-bfl4l               1/1     Running   0          10d   10.244.1.223   securerag-dev-worker   <none>           <none>
auth-users-8678978685-l7968               1/1     Running   0          10d   10.244.1.227   securerag-dev-worker   <none>           <none>
auth-users-8678978685-zrn25               1/1     Running   0          10d   10.244.1.229   securerag-dev-worker   <none>           <none>
chatbot-manager-79b79d59c4-lvgtp          1/1     Running   0          10d   10.244.1.224   securerag-dev-worker   <none>           <none>
conversation-service-6bc4c7dbc6-pq7xf     1/1     Running   0          10d   10.244.1.225   securerag-dev-worker   <none>           <none>
portal-web-859c78db95-8xxmr               1/1     Running   0          10d   10.244.1.230   securerag-dev-worker   <none>           <none>
portal-web-859c78db95-v9vwx               1/1     Running   0          10d   10.244.1.228   securerag-dev-worker   <none>           <none>
portal-web-859c78db95-z68jt               1/1     Running   0          10d   10.244.1.222   securerag-dev-worker   <none>           <none>
postgres-auth-fbf55db78-kwlh4             1/1     Running   0          10d   10.244.1.212   securerag-dev-worker   <none>           <none>
```

## Deployment images and imageIDs

```text
audit-security-service-667b7997b4-j5m7r	localhost:5001/securerag-hub-audit-security-service:demo	localhost:5001/securerag-hub-audit-security-service@sha256:6cf5cd864a1eb4b9179869b55519c1ba7b86d03f355b28506d3b7de97325d9bb
auth-users-8678978685-bfl4l	localhost:5001/securerag-hub-auth-users:demo	localhost:5001/securerag-hub-auth-users@sha256:7b24d8aa5f36d0db05d10fb2a46286711cc4a2304f47dde84ba796362aef5522
auth-users-8678978685-l7968	localhost:5001/securerag-hub-auth-users:demo	localhost:5001/securerag-hub-auth-users@sha256:7b24d8aa5f36d0db05d10fb2a46286711cc4a2304f47dde84ba796362aef5522
auth-users-8678978685-zrn25	localhost:5001/securerag-hub-auth-users:demo	localhost:5001/securerag-hub-auth-users@sha256:7b24d8aa5f36d0db05d10fb2a46286711cc4a2304f47dde84ba796362aef5522
chatbot-manager-79b79d59c4-lvgtp	localhost:5001/securerag-hub-chatbot-manager:demo	localhost:5001/securerag-hub-chatbot-manager@sha256:086ed526afb4439f6d4c5590326be3a757574ccda5e894ce1b652054bde84513
conversation-service-6bc4c7dbc6-pq7xf	localhost:5001/securerag-hub-conversation-service:demo	localhost:5001/securerag-hub-conversation-service@sha256:35f53f4cd274b54021812ed48b95991af875c7e8e0aa66c53bb06df65fe4e03f
portal-web-859c78db95-8xxmr	localhost:5001/securerag-hub-portal-web:demo	localhost:5001/securerag-hub-portal-web@sha256:fa1fc37b44b4cedc7e32c38940f1971f5e9af7c7b6d425d66d3214cd4bc18f80
portal-web-859c78db95-v9vwx	localhost:5001/securerag-hub-portal-web:demo	localhost:5001/securerag-hub-portal-web@sha256:fa1fc37b44b4cedc7e32c38940f1971f5e9af7c7b6d425d66d3214cd4bc18f80
portal-web-859c78db95-z68jt	localhost:5001/securerag-hub-portal-web:demo	localhost:5001/securerag-hub-portal-web@sha256:fa1fc37b44b4cedc7e32c38940f1971f5e9af7c7b6d425d66d3214cd4bc18f80
postgres-auth-fbf55db78-kwlh4	docker.io/library/postgres:16-alpine	docker.io/library/postgres@sha256:e013e867e712fec275706a6c51c966f0bb0c93cfa8f51000f85a15f9865a28cb
```

## ServiceAccounts

```text
NAME                        SECRETS   AGE
default                     0         11d
sa-audit-security-service   0         11d
sa-auth-users               0         11d
sa-chatbot-manager          0         11d
sa-conversation-service     0         11d
sa-portal-web               0         11d
sa-postgres-auth            0         11d
sa-validation               0         11d
```

## Roles and RoleBindings

```text
NAME                                                        CREATED AT
role.rbac.authorization.k8s.io/securerag-runtime-readonly   2026-06-24T11:03:14Z

NAME                                                                                      ROLE                              AGE   USERS   GROUPS   SERVICEACCOUNTS
rolebinding.rbac.authorization.k8s.io/securerag-runtime-readonly-audit-security-service   Role/securerag-runtime-readonly   11d                    securerag-hub/sa-audit-security-service
```

## NetworkPolicies

```text
NAME                             POD-SELECTOR                                                                                                    AGE
allow-dns-egress                 <none>                                                                                                          11d
allow-validation-egress          app.kubernetes.io/part-of=securerag-hub,job-role=validation                                                     11d
allow-validation-ingress         app.kubernetes.io/name in (audit-security-service,auth-users,chatbot-manager,conversation-service,portal-web)   11d
audit-security-service-network   app.kubernetes.io/name=audit-security-service,app.kubernetes.io/part-of=securerag-hub                           11d
auth-users-policy                app.kubernetes.io/name=auth-users,app.kubernetes.io/part-of=securerag-hub                                       11d
chatbot-manager-policy           app.kubernetes.io/name=chatbot-manager,app.kubernetes.io/part-of=securerag-hub                                  11d
conversation-service-network     app.kubernetes.io/name=conversation-service,app.kubernetes.io/part-of=securerag-hub                             11d
default-deny-all                 <none>                                                                                                          11d
portal-web-policy                app.kubernetes.io/name=portal-web,app.kubernetes.io/part-of=securerag-hub                                       11d
postgres-auth-policy             app.kubernetes.io/name=postgres-auth,app.kubernetes.io/part-of=securerag-hub                                    11d
```

## PodDisruptionBudgets

```text
NAME                         MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
audit-security-service-pdb   1               N/A               0                     11d
auth-users-pdb               1               N/A               2                     11d
chatbot-manager-pdb          1               N/A               0                     11d
conversation-service-pdb     1               N/A               0                     11d
portal-web-pdb               1               N/A               2                     11d
```

## HPA

```text
NAME         REFERENCE               TARGETS              MINPODS   MAXPODS   REPLICAS   AGE
portal-web   Deployment/portal-web   cpu: <unknown>/70%   1         3         3          11d
```

## Recent events

```text
LAST SEEN   TYPE      REASON                    OBJECT                                      MESSAGE
5m56s       Warning   PolicyViolation           service/postgres-auth                       policy securerag-restrict-service-exposure/allow-nodeport-only-for-portal-web fail: Only portal-web may use NodePort in the local demo overlay; LoadBalancer is forbidden.
108s        Normal    Pulled                    pod/curl-smoke-1783252650                   Container image "curlimages/curl:8.11.1" already present on machine
108s        Normal    Scheduled                 pod/curl-smoke-1783252650                   Successfully assigned securerag-hub/curl-smoke-1783252650 to securerag-dev-worker
107s        Normal    Created                   pod/curl-smoke-1783252650                   Created container: curl-smoke-1783252650
107s        Normal    Started                   pod/curl-smoke-1783252650                   Started container curl-smoke-1783252650
104s        Normal    Scheduled                 pod/curl-sec-smoke-1783252655               Successfully assigned securerag-hub/curl-sec-smoke-1783252655 to securerag-dev-worker
103s        Normal    Started                   pod/curl-sec-smoke-1783252655               Started container curl-sec-smoke-1783252655
103s        Normal    Created                   pod/curl-sec-smoke-1783252655               Created container: curl-sec-smoke-1783252655
103s        Normal    Pulled                    pod/curl-sec-smoke-1783252655               Container image "curlimages/curl:8.11.1" already present on machine
100s        Normal    Scheduled                 pod/e2e-functional-check-1783252659         Successfully assigned securerag-hub/e2e-functional-check-1783252659 to securerag-dev-worker
99s         Normal    Created                   pod/e2e-functional-check-1783252659         Created container: e2e-functional-check-1783252659
99s         Normal    Pulled                    pod/e2e-functional-check-1783252659         Container image "curlimages/curl:8.11.1" already present on machine
98s         Normal    Started                   pod/e2e-functional-check-1783252659         Started container e2e-functional-check-1783252659
96s         Normal    Scheduled                 pod/auditor-availability-check-1783252663   Successfully assigned securerag-hub/auditor-availability-check-1783252663 to securerag-dev-worker
96s         Normal    Pulled                    pod/auditor-availability-check-1783252663   Container image "curlimages/curl:8.11.1" already present on machine
95s         Normal    Created                   pod/auditor-availability-check-1783252663   Created container: auditor-availability-check-1783252663
95s         Normal    Started                   pod/auditor-availability-check-1783252663   Started container auditor-availability-check-1783252663
93s         Normal    Scheduled                 pod/auditor-endpoint-check-1783252663       Successfully assigned securerag-hub/auditor-endpoint-check-1783252663 to securerag-dev-worker
92s         Normal    Pulled                    pod/auditor-endpoint-check-1783252663       Container image "curlimages/curl:8.11.1" already present on machine
92s         Normal    Started                   pod/auditor-endpoint-check-1783252663       Started container auditor-endpoint-check-1783252663
92s         Normal    Created                   pod/auditor-endpoint-check-1783252663       Created container: auditor-endpoint-check-1783252663
35s         Warning   FailedGetResourceMetric   horizontalpodautoscaler/portal-web          failed to get cpu utilization: unable to get metrics for resource cpu: unable to fetch metrics from resource metrics API: the server could not find the requested resource (get pods.metrics.k8s.io)
26s         Normal    Scheduled                 pod/curl-smoke-1783252733                   Successfully assigned securerag-hub/curl-smoke-1783252733 to securerag-dev-worker
25s         Normal    Created                   pod/curl-smoke-1783252733                   Created container: curl-smoke-1783252733
25s         Normal    Pulled                    pod/curl-smoke-1783252733                   Container image "curlimages/curl:8.11.1" already present on machine
24s         Normal    Started                   pod/curl-smoke-1783252733                   Started container curl-smoke-1783252733
22s         Normal    Scheduled                 pod/curl-sec-smoke-1783252737               Successfully assigned securerag-hub/curl-sec-smoke-1783252737 to securerag-dev-worker
21s         Normal    Created                   pod/curl-sec-smoke-1783252737               Created container: curl-sec-smoke-1783252737
21s         Normal    Pulled                    pod/curl-sec-smoke-1783252737               Container image "curlimages/curl:8.11.1" already present on machine
20s         Normal    Started                   pod/curl-sec-smoke-1783252737               Started container curl-sec-smoke-1783252737
18s         Normal    Scheduled                 pod/e2e-functional-check-1783252741         Successfully assigned securerag-hub/e2e-functional-check-1783252741 to securerag-dev-worker
17s         Normal    Created                   pod/e2e-functional-check-1783252741         Created container: e2e-functional-check-1783252741
17s         Normal    Pulled                    pod/e2e-functional-check-1783252741         Container image "curlimages/curl:8.11.1" already present on machine
16s         Normal    Started                   pod/e2e-functional-check-1783252741         Started container e2e-functional-check-1783252741
14s         Normal    Scheduled                 pod/auditor-availability-check-1783252745   Successfully assigned securerag-hub/auditor-availability-check-1783252745 to securerag-dev-worker
13s         Normal    Pulled                    pod/auditor-availability-check-1783252745   Container image "curlimages/curl:8.11.1" already present on machine
13s         Normal    Created                   pod/auditor-availability-check-1783252745   Created container: auditor-availability-check-1783252745
12s         Normal    Started                   pod/auditor-availability-check-1783252745   Started container auditor-availability-check-1783252745
11s         Normal    Scheduled                 pod/auditor-endpoint-check-1783252745       Successfully assigned securerag-hub/auditor-endpoint-check-1783252745 to securerag-dev-worker
10s         Normal    Pulled                    pod/auditor-endpoint-check-1783252745       Container image "curlimages/curl:8.11.1" already present on machine
10s         Normal    Created                   pod/auditor-endpoint-check-1783252745       Created container: auditor-endpoint-check-1783252745
9s          Normal    Started                   pod/auditor-endpoint-check-1783252745       Started container auditor-endpoint-check-1783252745
```

## Logs deployment/auth-users

```text
Found 3 pods, using pod/auth-users-8678978685-bfl4l
  2026-07-05 11:50:34 /health ...................................... ~ 0.09ms
  2026-07-05 11:50:43 /health ...................................... ~ 0.08ms
  2026-07-05 11:50:44 /health ...................................... ~ 0.10ms
  2026-07-05 11:50:54 /health ...................................... ~ 0.08ms
  2026-07-05 11:51:03 /health ...................................... ~ 0.10ms
  2026-07-05 11:51:04 /health ...................................... ~ 0.10ms
  2026-07-05 11:51:14 /health ...................................... ~ 0.09ms
  2026-07-05 11:51:23 /health ...................................... ~ 0.11ms
  2026-07-05 11:51:24 /health ...................................... ~ 0.08ms
  2026-07-05 11:51:34 /health ...................................... ~ 0.15ms
  2026-07-05 11:51:43 /health ...................................... ~ 0.08ms
  2026-07-05 11:51:44 /health ...................................... ~ 0.09ms
  2026-07-05 11:51:54 /health ...................................... ~ 0.10ms
  2026-07-05 11:52:03 /health ...................................... ~ 0.10ms
  2026-07-05 11:52:04 /health ...................................... ~ 0.08ms
  2026-07-05 11:52:14 /health ...................................... ~ 0.07ms
  2026-07-05 11:52:23 /health ...................................... ~ 0.09ms
  2026-07-05 11:52:24 /health ...................................... ~ 0.10ms
  2026-07-05 11:52:34 /health ...................................... ~ 0.10ms
  2026-07-05 11:52:43 /health ...................................... ~ 0.09ms
  2026-07-05 11:52:44 /health ...................................... ~ 0.11ms
  2026-07-05 11:52:54 /health ...................................... ~ 0.10ms
  2026-07-05 11:53:03 /health ...................................... ~ 0.09ms
  2026-07-05 11:53:04 /health ...................................... ~ 0.10ms
  2026-07-05 11:53:14 /health ...................................... ~ 0.12ms
  2026-07-05 11:53:23 /health ...................................... ~ 0.25ms
  2026-07-05 11:53:24 /health ...................................... ~ 0.13ms
  2026-07-05 11:53:34 /health ...................................... ~ 0.07ms
  2026-07-05 11:53:43 /health ...................................... ~ 0.08ms
  2026-07-05 11:53:44 /health ...................................... ~ 0.11ms
  2026-07-05 11:53:54 /health ...................................... ~ 0.08ms
  2026-07-05 11:54:03 /health ...................................... ~ 0.11ms
  2026-07-05 11:54:04 /health ...................................... ~ 0.08ms
  2026-07-05 11:54:14 /health ...................................... ~ 0.10ms
  2026-07-05 11:54:23 /health ...................................... ~ 0.10ms
  2026-07-05 11:54:24 /health ...................................... ~ 0.16ms
  2026-07-05 11:54:34 /health ...................................... ~ 0.11ms
  2026-07-05 11:54:43 /health ...................................... ~ 0.08ms
  2026-07-05 11:54:44 /health ...................................... ~ 0.09ms
  2026-07-05 11:54:54 /health ...................................... ~ 0.08ms
  2026-07-05 11:55:03 /health ...................................... ~ 0.11ms
  2026-07-05 11:55:04 /health ...................................... ~ 0.07ms
  2026-07-05 11:55:14 /health ...................................... ~ 0.09ms
  2026-07-05 11:55:23 /health ...................................... ~ 0.10ms
  2026-07-05 11:55:24 /health ...................................... ~ 0.08ms
  2026-07-05 11:55:34 /health ...................................... ~ 0.09ms
  2026-07-05 11:55:43 /health ...................................... ~ 0.11ms
  2026-07-05 11:55:44 /health ...................................... ~ 0.14ms
  2026-07-05 11:55:54 /health ...................................... ~ 0.13ms
  2026-07-05 11:56:03 /health ...................................... ~ 0.08ms
  2026-07-05 11:56:04 /health ...................................... ~ 0.08ms
  2026-07-05 11:56:14 /health ...................................... ~ 0.11ms
  2026-07-05 11:56:23 /health ...................................... ~ 0.09ms
  2026-07-05 11:56:24 /health ...................................... ~ 0.10ms
  2026-07-05 11:56:34 /health ...................................... ~ 0.08ms
  2026-07-05 11:56:43 /health ...................................... ~ 0.10ms
  2026-07-05 11:56:44 /health ...................................... ~ 0.09ms
  2026-07-05 11:56:54 /health ...................................... ~ 0.08ms
  2026-07-05 11:57:03 /health ...................................... ~ 0.40ms
  2026-07-05 11:57:04 /health ...................................... ~ 0.08ms
  2026-07-05 11:57:14 /health ...................................... ~ 0.13ms
  2026-07-05 11:57:23 /health ...................................... ~ 0.07ms
  2026-07-05 11:57:24 /health ...................................... ~ 0.10ms
  2026-07-05 11:57:34 /health ...................................... ~ 0.10ms
  2026-07-05 11:57:43 /health ...................................... ~ 0.07ms
  2026-07-05 11:57:44 /health ...................................... ~ 0.08ms
  2026-07-05 11:57:54 /health ...................................... ~ 0.14ms
  2026-07-05 11:58:03 /health ...................................... ~ 0.08ms
  2026-07-05 11:58:04 /health ...................................... ~ 0.08ms
  2026-07-05 11:58:14 /health ...................................... ~ 0.11ms
  2026-07-05 11:58:23 /health ...................................... ~ 0.13ms
  2026-07-05 11:58:24 /health ...................................... ~ 0.08ms
  2026-07-05 11:58:34 /health ...................................... ~ 0.10ms
  2026-07-05 11:58:43 /health ...................................... ~ 0.08ms
  2026-07-05 11:58:44 /health ...................................... ~ 0.09ms
  2026-07-05 11:58:54 /health ...................................... ~ 0.14ms
  2026-07-05 11:58:55 /health ...................................... ~ 0.13ms
  2026-07-05 11:59:03 /health ...................................... ~ 0.08ms
  2026-07-05 11:59:04 /health ...................................... ~ 0.12ms
  2026-07-05 11:59:14 /health ...................................... ~ 0.11ms
```

## Logs deployment/chatbot-manager

```text
  2026-07-05 11:50:54 /health ...................................... ~ 0.13ms
  2026-07-05 11:51:03 /health ...................................... ~ 0.08ms
  2026-07-05 11:51:04 /health ...................................... ~ 0.10ms
  2026-07-05 11:51:14 /health ...................................... ~ 0.08ms
  2026-07-05 11:51:23 /health ...................................... ~ 0.10ms
  2026-07-05 11:51:24 /health ...................................... ~ 0.09ms
  2026-07-05 11:51:34 /health ...................................... ~ 0.10ms
  2026-07-05 11:51:43 /health ...................................... ~ 0.10ms
  2026-07-05 11:51:44 /health ...................................... ~ 0.12ms
  2026-07-05 11:51:54 /health ...................................... ~ 0.11ms
  2026-07-05 11:52:03 /health ...................................... ~ 0.09ms
  2026-07-05 11:52:04 /health ...................................... ~ 0.13ms
  2026-07-05 11:52:14 /health ...................................... ~ 0.10ms
  2026-07-05 11:52:23 /health ...................................... ~ 0.08ms
  2026-07-05 11:52:24 /health ...................................... ~ 0.09ms
  2026-07-05 11:52:34 /health ...................................... ~ 0.08ms
  2026-07-05 11:52:43 /health ...................................... ~ 0.09ms
  2026-07-05 11:52:44 /health ...................................... ~ 0.12ms
  2026-07-05 11:52:54 /health ...................................... ~ 0.08ms
  2026-07-05 11:53:03 /health ...................................... ~ 0.12ms
  2026-07-05 11:53:04 /health ...................................... ~ 0.09ms
  2026-07-05 11:53:14 /health ...................................... ~ 0.08ms
  2026-07-05 11:53:23 /health ...................................... ~ 0.14ms
  2026-07-05 11:53:24 /health ...................................... ~ 0.20ms
  2026-07-05 11:53:34 /health ...................................... ~ 0.10ms
  2026-07-05 11:53:43 /health ...................................... ~ 0.09ms
  2026-07-05 11:53:44 /health ...................................... ~ 0.10ms
  2026-07-05 11:53:54 /health ...................................... ~ 0.08ms
  2026-07-05 11:54:03 /health ...................................... ~ 0.10ms
  2026-07-05 11:54:04 /health ...................................... ~ 0.07ms
  2026-07-05 11:54:14 /health ...................................... ~ 0.10ms
  2026-07-05 11:54:23 /health ...................................... ~ 0.10ms
  2026-07-05 11:54:24 /health ...................................... ~ 0.08ms
  2026-07-05 11:54:34 /health ...................................... ~ 0.10ms
  2026-07-05 11:54:43 /health ...................................... ~ 0.07ms
  2026-07-05 11:54:44 /health ...................................... ~ 0.07ms
  2026-07-05 11:54:54 /health ...................................... ~ 0.16ms
  2026-07-05 11:55:03 /health ...................................... ~ 0.10ms
  2026-07-05 11:55:04 /health ...................................... ~ 0.10ms
  2026-07-05 11:55:14 /health ...................................... ~ 0.12ms
  2026-07-05 11:55:23 /health ...................................... ~ 0.08ms
  2026-07-05 11:55:24 /health ...................................... ~ 0.11ms
  2026-07-05 11:55:34 /health ...................................... ~ 0.15ms
  2026-07-05 11:55:43 /health ...................................... ~ 0.10ms
  2026-07-05 11:55:44 /health ...................................... ~ 0.11ms
  2026-07-05 11:55:54 /health ...................................... ~ 0.08ms
  2026-07-05 11:56:03 /health ...................................... ~ 0.09ms
  2026-07-05 11:56:04 /health ...................................... ~ 0.08ms
  2026-07-05 11:56:14 /health ...................................... ~ 0.09ms
  2026-07-05 11:56:23 /health ...................................... ~ 0.08ms
  2026-07-05 11:56:24 /health ...................................... ~ 0.09ms
  2026-07-05 11:56:34 /health ...................................... ~ 0.07ms
  2026-07-05 11:56:43 /health ...................................... ~ 0.10ms
  2026-07-05 11:56:44 /health ...................................... ~ 0.10ms
  2026-07-05 11:56:54 /health ...................................... ~ 0.08ms
  2026-07-05 11:57:03 /health ...................................... ~ 0.10ms
  2026-07-05 11:57:04 /health ...................................... ~ 0.07ms
  2026-07-05 11:57:14 /health ...................................... ~ 0.08ms
  2026-07-05 11:57:23 /health ...................................... ~ 0.07ms
  2026-07-05 11:57:24 /health ...................................... ~ 0.10ms
  2026-07-05 11:57:32 /health ...................................... ~ 0.07ms
  2026-07-05 11:57:34 /health ...................................... ~ 0.12ms
  2026-07-05 11:57:41 /health ...................................... ~ 0.08ms
  2026-07-05 11:57:43 /health ...................................... ~ 0.11ms
  2026-07-05 11:57:44 /health ...................................... ~ 0.09ms
  2026-07-05 11:57:54 /health ...................................... ~ 0.09ms
  2026-07-05 11:58:03 /health ...................................... ~ 0.08ms
  2026-07-05 11:58:04 /health ...................................... ~ 0.08ms
  2026-07-05 11:58:14 /health ...................................... ~ 0.11ms
  2026-07-05 11:58:23 /health ...................................... ~ 0.09ms
  2026-07-05 11:58:24 /health ...................................... ~ 0.10ms
  2026-07-05 11:58:34 /health ...................................... ~ 0.10ms
  2026-07-05 11:58:43 /health ...................................... ~ 0.08ms
  2026-07-05 11:58:44 /health ...................................... ~ 0.07ms
  2026-07-05 11:58:54 /health ...................................... ~ 0.07ms
  2026-07-05 11:58:55 /health ...................................... ~ 0.10ms
  2026-07-05 11:59:03 /health ...................................... ~ 0.07ms
  2026-07-05 11:59:03 /health ...................................... ~ 0.08ms
  2026-07-05 11:59:04 /health ...................................... ~ 0.08ms
  2026-07-05 11:59:14 /health ...................................... ~ 0.13ms
```

## Logs deployment/conversation-service

```text
  2026-07-05 11:50:54 /health ...................................... ~ 0.14ms
  2026-07-05 11:51:03 /health ...................................... ~ 0.08ms
  2026-07-05 11:51:04 /health ...................................... ~ 0.10ms
  2026-07-05 11:51:14 /health ...................................... ~ 0.09ms
  2026-07-05 11:51:23 /health ...................................... ~ 0.11ms
  2026-07-05 11:51:24 /health ...................................... ~ 0.08ms
  2026-07-05 11:51:34 /health ...................................... ~ 0.09ms
  2026-07-05 11:51:43 /health ...................................... ~ 0.09ms
  2026-07-05 11:51:44 /health ...................................... ~ 0.10ms
  2026-07-05 11:51:54 /health ...................................... ~ 0.08ms
  2026-07-05 11:52:03 /health ...................................... ~ 0.08ms
  2026-07-05 11:52:04 /health ...................................... ~ 0.10ms
  2026-07-05 11:52:14 /health ...................................... ~ 0.09ms
  2026-07-05 11:52:23 /health ...................................... ~ 0.10ms
  2026-07-05 11:52:24 /health ...................................... ~ 0.08ms
  2026-07-05 11:52:34 /health ...................................... ~ 0.13ms
  2026-07-05 11:52:43 /health ...................................... ~ 0.09ms
  2026-07-05 11:52:44 /health ...................................... ~ 0.12ms
  2026-07-05 11:52:54 /health ...................................... ~ 0.10ms
  2026-07-05 11:53:03 /health ...................................... ~ 0.10ms
  2026-07-05 11:53:04 /health ...................................... ~ 0.08ms
  2026-07-05 11:53:14 /health ...................................... ~ 0.09ms
  2026-07-05 11:53:23 /health ...................................... ~ 0.11ms
  2026-07-05 11:53:24 /health ...................................... ~ 0.10ms
  2026-07-05 11:53:34 /health ...................................... ~ 0.12ms
  2026-07-05 11:53:43 /health ...................................... ~ 0.09ms
  2026-07-05 11:53:44 /health ...................................... ~ 0.08ms
  2026-07-05 11:53:54 /health ...................................... ~ 0.08ms
  2026-07-05 11:54:03 /health ...................................... ~ 0.08ms
  2026-07-05 11:54:04 /health ...................................... ~ 0.08ms
  2026-07-05 11:54:14 /health ...................................... ~ 0.10ms
  2026-07-05 11:54:23 /health ...................................... ~ 0.12ms
  2026-07-05 11:54:24 /health ...................................... ~ 0.09ms
  2026-07-05 11:54:34 /health ...................................... ~ 0.09ms
  2026-07-05 11:54:43 /health ...................................... ~ 0.10ms
  2026-07-05 11:54:44 /health ...................................... ~ 0.09ms
  2026-07-05 11:54:54 /health ...................................... ~ 0.16ms
  2026-07-05 11:55:03 /health ...................................... ~ 0.12ms
  2026-07-05 11:55:04 /health ...................................... ~ 0.11ms
  2026-07-05 11:55:14 /health ...................................... ~ 0.21ms
  2026-07-05 11:55:23 /health ...................................... ~ 0.10ms
  2026-07-05 11:55:24 /health ...................................... ~ 0.09ms
  2026-07-05 11:55:34 /health ...................................... ~ 0.08ms
  2026-07-05 11:55:43 /health ...................................... ~ 0.08ms
  2026-07-05 11:55:44 /health ...................................... ~ 0.08ms
  2026-07-05 11:55:54 /health ...................................... ~ 0.10ms
  2026-07-05 11:56:03 /health ...................................... ~ 0.10ms
  2026-07-05 11:56:04 /health ...................................... ~ 0.08ms
  2026-07-05 11:56:14 /health ...................................... ~ 0.08ms
  2026-07-05 11:56:23 /health ...................................... ~ 0.11ms
  2026-07-05 11:56:24 /health ...................................... ~ 0.85ms
  2026-07-05 11:56:34 /health ...................................... ~ 0.09ms
  2026-07-05 11:56:43 /health ...................................... ~ 0.11ms
  2026-07-05 11:56:44 /health ...................................... ~ 0.20ms
  2026-07-05 11:56:54 /health ...................................... ~ 0.09ms
  2026-07-05 11:57:03 /health ...................................... ~ 0.08ms
  2026-07-05 11:57:04 /health ...................................... ~ 0.07ms
  2026-07-05 11:57:14 /health ...................................... ~ 0.08ms
  2026-07-05 11:57:23 /health ...................................... ~ 0.07ms
  2026-07-05 11:57:24 /health ...................................... ~ 0.07ms
  2026-07-05 11:57:33 /health ...................................... ~ 0.09ms
  2026-07-05 11:57:34 /health ...................................... ~ 0.08ms
  2026-07-05 11:57:41 /health ...................................... ~ 0.08ms
  2026-07-05 11:57:43 /health ...................................... ~ 0.08ms
  2026-07-05 11:57:44 /health ...................................... ~ 0.07ms
  2026-07-05 11:57:54 /health ...................................... ~ 0.09ms
  2026-07-05 11:58:03 /health ...................................... ~ 0.10ms
  2026-07-05 11:58:04 /health ...................................... ~ 0.08ms
  2026-07-05 11:58:14 /health ...................................... ~ 0.09ms
  2026-07-05 11:58:23 /health ...................................... ~ 0.07ms
  2026-07-05 11:58:24 /health .................................... ~ 500.33ms
  2026-07-05 11:58:34 /health .................................... ~ 500.39ms
  2026-07-05 11:58:43 /health ...................................... ~ 0.07ms
  2026-07-05 11:58:44 /health ...................................... ~ 0.02ms
  2026-07-05 11:58:54 /health ...................................... ~ 0.07ms
  2026-07-05 11:58:55 /health ...................................... ~ 0.08ms
  2026-07-05 11:59:03 /health ...................................... ~ 0.11ms
  2026-07-05 11:59:03 /health ...................................... ~ 0.67ms
  2026-07-05 11:59:04 /health ...................................... ~ 0.12ms
  2026-07-05 11:59:14 /health ...................................... ~ 0.08ms
```

## Logs deployment/audit-security-service

```text
  2026-07-05 11:51:23 /health ...................................... ~ 0.11ms
  2026-07-05 11:51:24 /health ...................................... ~ 0.09ms
  2026-07-05 11:51:34 /health ...................................... ~ 0.12ms
  2026-07-05 11:51:43 /health ...................................... ~ 0.13ms
  2026-07-05 11:51:44 /health ...................................... ~ 0.08ms
  2026-07-05 11:51:54 /health ...................................... ~ 0.09ms
  2026-07-05 11:52:03 /health ...................................... ~ 0.08ms
  2026-07-05 11:52:04 /health ...................................... ~ 0.20ms
  2026-07-05 11:52:14 /health ...................................... ~ 0.09ms
  2026-07-05 11:52:23 /health ...................................... ~ 0.08ms
  2026-07-05 11:52:24 /health ...................................... ~ 0.09ms
  2026-07-05 11:52:34 /health ...................................... ~ 0.08ms
  2026-07-05 11:52:43 /health ...................................... ~ 0.10ms
  2026-07-05 11:52:44 /health ...................................... ~ 0.08ms
  2026-07-05 11:52:54 /health ...................................... ~ 0.07ms
  2026-07-05 11:53:03 /health ...................................... ~ 0.12ms
  2026-07-05 11:53:04 /health ...................................... ~ 0.09ms
  2026-07-05 11:53:14 /health ...................................... ~ 0.11ms
  2026-07-05 11:53:23 /health ...................................... ~ 0.08ms
  2026-07-05 11:53:24 /health ...................................... ~ 0.13ms
  2026-07-05 11:53:34 /health ...................................... ~ 0.15ms
  2026-07-05 11:53:43 /health ...................................... ~ 0.14ms
  2026-07-05 11:53:44 /health ...................................... ~ 0.10ms
  2026-07-05 11:53:54 /health ...................................... ~ 0.08ms
  2026-07-05 11:54:03 /health ...................................... ~ 0.19ms
  2026-07-05 11:54:04 /health ...................................... ~ 0.10ms
  2026-07-05 11:54:14 /health ...................................... ~ 0.11ms
  2026-07-05 11:54:23 /health ...................................... ~ 0.09ms
  2026-07-05 11:54:24 /health ...................................... ~ 0.07ms
  2026-07-05 11:54:34 /health ...................................... ~ 0.09ms
  2026-07-05 11:54:43 /health ...................................... ~ 0.08ms
  2026-07-05 11:54:44 /health ...................................... ~ 0.08ms
  2026-07-05 11:54:54 /health ...................................... ~ 0.10ms
  2026-07-05 11:55:03 /health ...................................... ~ 0.08ms
  2026-07-05 11:55:04 /health ...................................... ~ 0.08ms
  2026-07-05 11:55:14 /health ...................................... ~ 0.09ms
  2026-07-05 11:55:23 /health ...................................... ~ 0.08ms
  2026-07-05 11:55:24 /health ...................................... ~ 0.10ms
  2026-07-05 11:55:34 /health ...................................... ~ 0.12ms
  2026-07-05 11:55:43 /health ...................................... ~ 0.09ms
  2026-07-05 11:55:44 /health ...................................... ~ 0.12ms
  2026-07-05 11:55:54 /health ...................................... ~ 0.14ms
  2026-07-05 11:56:03 /health ...................................... ~ 0.08ms
  2026-07-05 11:56:04 /health ...................................... ~ 0.13ms
  2026-07-05 11:56:14 /health ...................................... ~ 0.13ms
  2026-07-05 11:56:23 /health ...................................... ~ 0.09ms
  2026-07-05 11:56:24 /health ...................................... ~ 0.09ms
  2026-07-05 11:56:34 /health ...................................... ~ 0.09ms
  2026-07-05 11:56:43 /health ...................................... ~ 0.09ms
  2026-07-05 11:56:44 /health ...................................... ~ 0.08ms
  2026-07-05 11:56:54 /health ...................................... ~ 0.17ms
  2026-07-05 11:57:03 /health ...................................... ~ 0.10ms
  2026-07-05 11:57:04 /health ...................................... ~ 0.13ms
  2026-07-05 11:57:14 /health ...................................... ~ 0.07ms
  2026-07-05 11:57:23 /health ...................................... ~ 0.14ms
  2026-07-05 11:57:24 /health ...................................... ~ 0.07ms
  2026-07-05 11:57:33 /health ...................................... ~ 0.11ms
  2026-07-05 11:57:34 /health ...................................... ~ 0.08ms
  2026-07-05 11:57:41 /health ...................................... ~ 0.07ms
  2026-07-05 11:57:43 /health ...................................... ~ 0.08ms
  2026-07-05 11:57:44 /health ...................................... ~ 0.11ms
  2026-07-05 11:57:44 /health ...................................... ~ 0.10ms
  2026-07-05 11:57:47 /api/v1/audit-logs ........................... ~ 0.20ms
  2026-07-05 11:57:54 /health ...................................... ~ 0.07ms
  2026-07-05 11:58:03 /health ...................................... ~ 0.16ms
  2026-07-05 11:58:04 /health ...................................... ~ 0.07ms
  2026-07-05 11:58:14 /health ...................................... ~ 0.09ms
  2026-07-05 11:58:23 /health ...................................... ~ 0.11ms
  2026-07-05 11:58:24 /health ...................................... ~ 0.16ms
  2026-07-05 11:58:34 /health ...................................... ~ 0.14ms
  2026-07-05 11:58:43 /health ...................................... ~ 0.09ms
  2026-07-05 11:58:44 /health ...................................... ~ 0.07ms
  2026-07-05 11:58:54 /health ...................................... ~ 0.08ms
  2026-07-05 11:58:55 /health ...................................... ~ 0.10ms
  2026-07-05 11:59:03 /health ...................................... ~ 0.08ms
  2026-07-05 11:59:03 /health ...................................... ~ 0.03ms
  2026-07-05 11:59:04 /health ...................................... ~ 0.08ms
  2026-07-05 11:59:07 /health ...................................... ~ 0.10ms
  2026-07-05 11:59:10 /api/v1/audit-logs ........................... ~ 0.08ms
  2026-07-05 11:59:14 /health ...................................... ~ 0.10ms
```

## Logs deployment/portal-web

```text
Found 3 pods, using pod/portal-web-859c78db95-z68jt
  2026-07-05 11:51:29 /health ...................................... ~ 0.09ms
  2026-07-05 11:51:39 /health ...................................... ~ 0.10ms
  2026-07-05 11:51:43 /health ...................................... ~ 0.08ms
  2026-07-05 11:51:49 /health ...................................... ~ 0.10ms
  2026-07-05 11:51:59 /health ...................................... ~ 0.08ms
  2026-07-05 11:52:03 /health ...................................... ~ 0.11ms
  2026-07-05 11:52:09 /health ...................................... ~ 0.11ms
  2026-07-05 11:52:19 /health ...................................... ~ 0.08ms
  2026-07-05 11:52:23 /health .................................... ~ 500.44ms
  2026-07-05 11:52:29 /health ...................................... ~ 0.09ms
  2026-07-05 11:52:39 /health ...................................... ~ 0.09ms
  2026-07-05 11:52:43 /health .................................... ~ 500.31ms
  2026-07-05 11:52:49 /health ...................................... ~ 0.07ms
  2026-07-05 11:52:59 /health ...................................... ~ 0.12ms
  2026-07-05 11:53:03 /health ...................................... ~ 0.11ms
  2026-07-05 11:53:09 /health ...................................... ~ 0.08ms
  2026-07-05 11:53:19 /health ...................................... ~ 0.08ms
  2026-07-05 11:53:23 /health ...................................... ~ 0.10ms
  2026-07-05 11:53:29 /health ...................................... ~ 0.11ms
  2026-07-05 11:53:39 /health ...................................... ~ 0.08ms
  2026-07-05 11:53:43 /health ...................................... ~ 0.09ms
  2026-07-05 11:53:49 /health ...................................... ~ 0.10ms
  2026-07-05 11:53:59 /health ...................................... ~ 0.09ms
  2026-07-05 11:54:03 /health ...................................... ~ 0.08ms
  2026-07-05 11:54:09 /health ...................................... ~ 0.10ms
  2026-07-05 11:54:19 /health ...................................... ~ 0.12ms
  2026-07-05 11:54:23 /health ...................................... ~ 0.12ms
  2026-07-05 11:54:29 /health ...................................... ~ 0.08ms
  2026-07-05 11:54:39 /health ...................................... ~ 0.09ms
  2026-07-05 11:54:43 /health ...................................... ~ 0.10ms
  2026-07-05 11:54:49 /health ...................................... ~ 0.09ms
  2026-07-05 11:54:59 /health ...................................... ~ 0.10ms
  2026-07-05 11:55:03 /health ...................................... ~ 0.11ms
  2026-07-05 11:55:09 /health ...................................... ~ 0.08ms
  2026-07-05 11:55:19 /health ...................................... ~ 0.09ms
  2026-07-05 11:55:23 /health ...................................... ~ 0.16ms
  2026-07-05 11:55:29 /health ...................................... ~ 0.10ms
  2026-07-05 11:55:39 /health ...................................... ~ 0.08ms
  2026-07-05 11:55:43 /health ...................................... ~ 0.09ms
  2026-07-05 11:55:49 /health ...................................... ~ 0.09ms
  2026-07-05 11:55:59 /health ...................................... ~ 0.14ms
  2026-07-05 11:56:03 /health ...................................... ~ 0.09ms
  2026-07-05 11:56:09 /health ...................................... ~ 0.10ms
  2026-07-05 11:56:19 /health ...................................... ~ 0.10ms
  2026-07-05 11:56:23 /health ...................................... ~ 0.12ms
  2026-07-05 11:56:29 /health ...................................... ~ 0.10ms
  2026-07-05 11:56:39 /health ...................................... ~ 0.11ms
  2026-07-05 11:56:43 /health ...................................... ~ 0.10ms
  2026-07-05 11:56:49 /health ...................................... ~ 0.08ms
  2026-07-05 11:56:59 /health ...................................... ~ 0.08ms
  2026-07-05 11:57:03 /health ...................................... ~ 0.10ms
  2026-07-05 11:57:09 /health ...................................... ~ 0.09ms
  2026-07-05 11:57:19 /health ...................................... ~ 0.10ms
  2026-07-05 11:57:23 /health ...................................... ~ 0.09ms
  2026-07-05 11:57:29 /health ...................................... ~ 0.09ms
  2026-07-05 11:57:32 / ............................................ ~ 0.09ms
  2026-07-05 11:57:36 /.env ........................................ ~ 0.08ms
  2026-07-05 11:57:36 /admin ....................................... ~ 0.04ms
  2026-07-05 11:57:39 /health .................................... ~ 500.37ms
  2026-07-05 11:57:41 /health ...................................... ~ 0.11ms
  2026-07-05 11:57:43 /health ...................................... ~ 0.09ms
  2026-07-05 11:57:49 /health .................................... ~ 500.29ms
  2026-07-05 11:57:59 /health ...................................... ~ 0.07ms
  2026-07-05 11:58:03 /health ...................................... ~ 0.08ms
  2026-07-05 11:58:09 /health ...................................... ~ 0.10ms
  2026-07-05 11:58:19 /health ...................................... ~ 0.08ms
  2026-07-05 11:58:23 /health ...................................... ~ 0.11ms
  2026-07-05 11:58:29 /health ...................................... ~ 0.08ms
  2026-07-05 11:58:39 /health ...................................... ~ 0.09ms
  2026-07-05 11:58:43 /health ...................................... ~ 0.09ms
  2026-07-05 11:58:49 /health ...................................... ~ 0.10ms
  2026-07-05 11:58:55 /health ...................................... ~ 0.08ms
  2026-07-05 11:58:55 / ............................................ ~ 0.11ms
  2026-07-05 11:58:59 /health ...................................... ~ 0.09ms
  2026-07-05 11:58:59 /storage/ .................................... ~ 0.17ms
  2026-07-05 11:59:03 /health ...................................... ~ 0.11ms
  2026-07-05 11:59:03 /health ...................................... ~ 0.08ms
  2026-07-05 11:59:05 /health ...................................... ~ 0.15ms
  2026-07-05 11:59:09 /health ...................................... ~ 0.09ms
  2026-07-05 11:59:19 /health ...................................... ~ 0.09ms
```
