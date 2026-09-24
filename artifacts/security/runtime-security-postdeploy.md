# Runtime Security Post-Deployment Report - SecureRAG Hub

- Generated at UTC: `2026-09-23T04:45:45Z`
- Namespace: `securerag-hub`
- Status: `TERMINÉ`

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
| `auth-users` | TERMINÉ | 1 / 1 | 1 / 1 | 1 / 1 | `sa-auth-users` | `True` | `True` | `True` |
| `chatbot-manager` | TERMINÉ | 1 / 1 | 1 / 1 | 1 / 1 | `sa-chatbot-manager` | `True` | `True` | `True` |
| `conversation-service` | TERMINÉ | 1 / 1 | 1 / 1 | 1 / 1 | `sa-conversation-service` | `True` | `True` | `True` |
| `audit-security-service` | TERMINÉ | 1 / 1 | 1 / 1 | 1 / 1 | `sa-audit-security-service` | `True` | `True` | `True` |
| `portal-web` | TERMINÉ | 1 / 1 | 1 / 1 | 1 / 1 | `sa-portal-web` | `True` | `True` | `True` |

## Workload details

### auth-users

- No deployment-level hardening gap detected.
- Pod `auth-users-776cc8bfdb-95sj7` ready=`True` created=`2026-09-22T12:09:21Z` imageIDs=`1`
  - Runtime hardening checks matched the active Pod spec.
  - imageID: `localhost:5001/securerag-hub-auth-users@sha256:0d7795be3c8c678f3616779b1365d5ae160efce38b6a2e03c8b6fba3bf74ec93`

### chatbot-manager

- No deployment-level hardening gap detected.
- Pod `chatbot-manager-77b78ffb97-dl96v` ready=`True` created=`2026-09-22T12:09:21Z` imageIDs=`1`
  - Runtime hardening checks matched the active Pod spec.
  - imageID: `localhost:5001/securerag-hub-chatbot-manager@sha256:7d52f77d49fe1b3f458cb4c06ac9f3568c2f48c3a4f27dff56a39d59a11195eb`

### conversation-service

- No deployment-level hardening gap detected.
- Pod `conversation-service-86bbd9598b-gr9wd` ready=`True` created=`2026-09-22T12:09:22Z` imageIDs=`1`
  - Runtime hardening checks matched the active Pod spec.
  - imageID: `localhost:5001/securerag-hub-conversation-service@sha256:68e3d1f29ed008be81171d5a9f7711da5b030ad2e26846828905def992fe5b6c`

### audit-security-service

- No deployment-level hardening gap detected.
- Pod `audit-security-service-5fd6685f64-n7fjh` ready=`True` created=`2026-09-22T12:09:22Z` imageIDs=`1`
  - Runtime hardening checks matched the active Pod spec.
  - imageID: `localhost:5001/securerag-hub-audit-security-service@sha256:f681d9c8f698b01be192a2471cc5230652ccc0f2ce8fcbe86433e468ede0a58b`

### portal-web

- No deployment-level hardening gap detected.
- Pod `portal-web-68978bbc68-v4wfb` ready=`True` created=`2026-09-23T03:20:08Z` imageIDs=`1`
  - Runtime hardening checks matched the active Pod spec.
  - imageID: `localhost:5001/securerag-hub-portal-web@sha256:88492602d12bf81f4a6c8f611fb82f75de067e147a4fc0639989b33c7d2a905b`

## Honest reading

- `TERMINÉ` means the active Deployments and live Pods match the expected runtime security controls.
- `PARTIEL` means at least one live workload, Pod or cluster-side control is missing or inconsistent.
- `DÉPENDANT_DE_L_ENVIRONNEMENT` means the current cluster or namespace is not reachable.

## Deployments

```text
NAME                     READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS               IMAGES                                                                                                                        SELECTOR
audit-security-service   1/1     1            1           44h   audit-security-service   localhost:5001/securerag-hub-audit-security-service@sha256:f681d9c8f698b01be192a2471cc5230652ccc0f2ce8fcbe86433e468ede0a58b   app.kubernetes.io/name=audit-security-service,app.kubernetes.io/part-of=securerag-hub
auth-users               1/1     1            1           44h   auth-users               localhost:5001/securerag-hub-auth-users@sha256:0d7795be3c8c678f3616779b1365d5ae160efce38b6a2e03c8b6fba3bf74ec93               app.kubernetes.io/name=auth-users,app.kubernetes.io/part-of=securerag-hub
chatbot-manager          1/1     1            1           44h   chatbot-manager          localhost:5001/securerag-hub-chatbot-manager@sha256:7d52f77d49fe1b3f458cb4c06ac9f3568c2f48c3a4f27dff56a39d59a11195eb          app.kubernetes.io/name=chatbot-manager,app.kubernetes.io/part-of=securerag-hub
conversation-service     1/1     1            1           44h   conversation-service     localhost:5001/securerag-hub-conversation-service@sha256:68e3d1f29ed008be81171d5a9f7711da5b030ad2e26846828905def992fe5b6c     app.kubernetes.io/name=conversation-service,app.kubernetes.io/part-of=securerag-hub
portal-web               1/1     1            1           44h   portal-web               localhost:5001/securerag-hub-portal-web:dev                                                                                   app.kubernetes.io/name=portal-web,app.kubernetes.io/part-of=securerag-hub
postgres-auth            1/1     1            1           44h   postgres-auth            localhost:5001/postgres:16-alpine                                                                                             app.kubernetes.io/name=postgres-auth,app.kubernetes.io/part-of=securerag-hub
```

## Pods

```text
NAME                                      READY   STATUS    RESTARTS     AGE   IP             NODE                   NOMINATED NODE   READINESS GATES
audit-security-service-5fd6685f64-n7fjh   1/1     Running   0            16h   10.244.1.104   securerag-dev-worker   <none>           <none>
auth-users-776cc8bfdb-95sj7               1/1     Running   1 (8h ago)   16h   10.244.1.101   securerag-dev-worker   <none>           <none>
chatbot-manager-77b78ffb97-dl96v          1/1     Running   0            16h   10.244.1.102   securerag-dev-worker   <none>           <none>
conversation-service-86bbd9598b-gr9wd     1/1     Running   0            16h   10.244.1.103   securerag-dev-worker   <none>           <none>
portal-web-68978bbc68-v4wfb               1/1     Running   0            85m   10.244.1.152   securerag-dev-worker   <none>           <none>
postgres-auth-58f89fd9bf-b55hk            1/1     Running   0            16h   10.244.1.94    securerag-dev-worker   <none>           <none>
```

## Deployment images and imageIDs

```text
audit-security-service-5fd6685f64-n7fjh	localhost:5001/securerag-hub-audit-security-service:dev	localhost:5001/securerag-hub-audit-security-service@sha256:f681d9c8f698b01be192a2471cc5230652ccc0f2ce8fcbe86433e468ede0a58b
auth-users-776cc8bfdb-95sj7	localhost:5001/securerag-hub-auth-users:dev	localhost:5001/securerag-hub-auth-users@sha256:0d7795be3c8c678f3616779b1365d5ae160efce38b6a2e03c8b6fba3bf74ec93
chatbot-manager-77b78ffb97-dl96v	localhost:5001/securerag-hub-chatbot-manager:dev	localhost:5001/securerag-hub-chatbot-manager@sha256:7d52f77d49fe1b3f458cb4c06ac9f3568c2f48c3a4f27dff56a39d59a11195eb
conversation-service-86bbd9598b-gr9wd	localhost:5001/securerag-hub-conversation-service:dev	localhost:5001/securerag-hub-conversation-service@sha256:68e3d1f29ed008be81171d5a9f7711da5b030ad2e26846828905def992fe5b6c
portal-web-68978bbc68-v4wfb	localhost:5001/securerag-hub-portal-web:dev	localhost:5001/securerag-hub-portal-web@sha256:88492602d12bf81f4a6c8f611fb82f75de067e147a4fc0639989b33c7d2a905b
postgres-auth-58f89fd9bf-b55hk	localhost:5001/postgres:16-alpine	localhost:5001/postgres@sha256:1a66d744c1b459e13b05a8fca341da84cb63383e99ce262210efee5a319d4551
```

## ServiceAccounts

```text
NAME                        SECRETS   AGE
default                     0         44h
sa-audit-security-service   0         44h
sa-auth-users               0         44h
sa-chatbot-manager          0         44h
sa-conversation-service     0         44h
sa-portal-web               0         44h
sa-postgres-auth            0         44h
sa-validation               0         44h
```

## Roles and RoleBindings

```text
NAME                                                        CREATED AT
role.rbac.authorization.k8s.io/securerag-runtime-readonly   2026-09-21T07:55:08Z

NAME                                                                                      ROLE                              AGE   USERS   GROUPS   SERVICEACCOUNTS
rolebinding.rbac.authorization.k8s.io/securerag-runtime-readonly-audit-security-service   Role/securerag-runtime-readonly   44h                    securerag-hub/sa-audit-security-service
```

## NetworkPolicies

```text
NAME                             POD-SELECTOR                                                                                                    AGE
allow-dns-egress                 <none>                                                                                                          44h
allow-validation-egress          app.kubernetes.io/part-of=securerag-hub,job-role=validation                                                     44h
allow-validation-ingress         app.kubernetes.io/name in (audit-security-service,auth-users,chatbot-manager,conversation-service,portal-web)   44h
audit-security-service-network   app.kubernetes.io/name=audit-security-service,app.kubernetes.io/part-of=securerag-hub                           44h
auth-users-policy                app.kubernetes.io/name=auth-users,app.kubernetes.io/part-of=securerag-hub                                       44h
chatbot-manager-policy           app.kubernetes.io/name=chatbot-manager,app.kubernetes.io/part-of=securerag-hub                                  44h
conversation-service-network     app.kubernetes.io/name=conversation-service,app.kubernetes.io/part-of=securerag-hub                             44h
default-deny-all                 <none>                                                                                                          44h
portal-web-policy                app.kubernetes.io/name=portal-web,app.kubernetes.io/part-of=securerag-hub                                       44h
postgres-auth-policy             app.kubernetes.io/part-of=securerag-hub,cnpg.io/cluster=postgres-auth                                           44h
```

## PodDisruptionBudgets

```text
NAME                         MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
audit-security-service-pdb   1               N/A               0                     44h
auth-users-pdb               1               N/A               0                     44h
chatbot-manager-pdb          1               N/A               0                     44h
conversation-service-pdb     1               N/A               0                     44h
portal-web-pdb               1               N/A               0                     44h
```

## HPA

```text
NAME                     REFERENCE                           TARGETS       MINPODS   MAXPODS   REPLICAS   AGE
audit-security-service   Deployment/audit-security-service   cpu: 0%/70%   1         3         1          11h
auth-users               Deployment/auth-users               cpu: 1%/70%   1         3         1          11h
chatbot-manager          Deployment/chatbot-manager          cpu: 1%/70%   1         3         1          11h
conversation-service     Deployment/conversation-service     cpu: 1%/70%   1         3         1          11h
portal-web               Deployment/portal-web               cpu: 4%/70%   1         3         1          44h
```

## Recent events

```text
LAST SEEN   TYPE      REASON            OBJECT                                      MESSAGE
49m         Warning   PolicyViolation   service/postgres-auth                       policy securerag-restrict-service-exposure/allow-nodeport-only-for-portal-web fail: Only portal-web may use NodePort in the local demo overlay; LoadBalancer is forbidden.
49m         Warning   PolicyViolation   service/postgres-auth                       policy securerag-restrict-service-exposure/allow-nodeport-only-for-portal-web fail: Only portal-web may use NodePort in the local demo overlay; LoadBalancer is forbidden.
33m         Normal    Scheduled         pod/curl-sec-smoke-1790136720               Successfully assigned securerag-hub/curl-sec-smoke-1790136720 to securerag-dev-worker
33m         Normal    Created           pod/curl-sec-smoke-1790136720               Created container: curl-sec-smoke-1790136720
33m         Normal    Pulled            pod/curl-sec-smoke-1790136720               Container image "curlimages/curl:8.11.1" already present on machine
33m         Normal    Started           pod/curl-sec-smoke-1790136720               Started container curl-sec-smoke-1790136720
33m         Normal    Pulled            pod/auditor-availability-check-1790136724   Container image "curlimages/curl:8.11.1" already present on machine
33m         Normal    Created           pod/auditor-availability-check-1790136724   Created container: auditor-availability-check-1790136724
33m         Normal    Scheduled         pod/auditor-availability-check-1790136724   Successfully assigned securerag-hub/auditor-availability-check-1790136724 to securerag-dev-worker
33m         Normal    Started           pod/auditor-availability-check-1790136724   Started container auditor-availability-check-1790136724
33m         Normal    Scheduled         pod/auditor-endpoint-check-1790136724       Successfully assigned securerag-hub/auditor-endpoint-check-1790136724 to securerag-dev-worker
33m         Normal    Created           pod/auditor-endpoint-check-1790136724       Created container: auditor-endpoint-check-1790136724
33m         Normal    Pulled            pod/auditor-endpoint-check-1790136724       Container image "curlimages/curl:8.11.1" already present on machine
33m         Normal    Started           pod/auditor-endpoint-check-1790136724       Started container auditor-endpoint-check-1790136724
33m         Normal    Scheduled         pod/curl-smoke-1790136733                   Successfully assigned securerag-hub/curl-smoke-1790136733 to securerag-dev-worker
33m         Normal    Created           pod/curl-smoke-1790136733                   Created container: curl-smoke-1790136733
33m         Normal    Pulled            pod/curl-smoke-1790136733                   Container image "curlimages/curl:8.11.1" already present on machine
33m         Normal    Started           pod/curl-smoke-1790136733                   Started container curl-smoke-1790136733
33m         Normal    Scheduled         pod/e2e-functional-check-1790136738         Successfully assigned securerag-hub/e2e-functional-check-1790136738 to securerag-dev-worker
33m         Normal    Started           pod/e2e-functional-check-1790136738         Started container e2e-functional-check-1790136738
33m         Normal    Created           pod/e2e-functional-check-1790136738         Created container: e2e-functional-check-1790136738
33m         Normal    Pulled            pod/e2e-functional-check-1790136738         Container image "curlimages/curl:8.11.1" already present on machine
12s         Normal    Scheduled         pod/curl-sec-smoke-1790138733               Successfully assigned securerag-hub/curl-sec-smoke-1790138733 to securerag-dev-worker
12s         Normal    Created           pod/curl-sec-smoke-1790138733               Created container: curl-sec-smoke-1790138733
12s         Normal    Pulled            pod/curl-sec-smoke-1790138733               Container image "curlimages/curl:8.11.1" already present on machine
11s         Normal    Started           pod/curl-sec-smoke-1790138733               Started container curl-sec-smoke-1790138733
9s          Normal    Scheduled         pod/auditor-availability-check-1790138737   Successfully assigned securerag-hub/auditor-availability-check-1790138737 to securerag-dev-worker
8s          Normal    Created           pod/auditor-availability-check-1790138737   Created container: auditor-availability-check-1790138737
8s          Normal    Started           pod/auditor-availability-check-1790138737   Started container auditor-availability-check-1790138737
8s          Normal    Pulled            pod/auditor-availability-check-1790138737   Container image "curlimages/curl:8.11.1" already present on machine
5s          Normal    Scheduled         pod/auditor-endpoint-check-1790138737       Successfully assigned securerag-hub/auditor-endpoint-check-1790138737 to securerag-dev-worker
4s          Normal    Pulled            pod/auditor-endpoint-check-1790138737       Container image "curlimages/curl:8.11.1" already present on machine
4s          Normal    Started           pod/auditor-endpoint-check-1790138737       Started container auditor-endpoint-check-1790138737
4s          Normal    Created           pod/auditor-endpoint-check-1790138737       Created container: auditor-endpoint-check-1790138737
```

## Logs deployment/auth-users

```text
  2026-09-23 04:36:57 /health ...................................... ~ 0.06ms
  2026-09-23 04:37:01 /health ...................................... ~ 0.07ms
  2026-09-23 04:37:07 /health ...................................... ~ 0.07ms
  2026-09-23 04:37:17 /health ...................................... ~ 0.07ms
  2026-09-23 04:37:21 /health ...................................... ~ 0.07ms
  2026-09-23 04:37:27 /health ...................................... ~ 0.06ms
  2026-09-23 04:37:37 /health ...................................... ~ 0.07ms
  2026-09-23 04:37:41 /health ...................................... ~ 0.07ms
  2026-09-23 04:37:47 /health ...................................... ~ 0.07ms
  2026-09-23 04:37:57 /health ...................................... ~ 0.06ms
  2026-09-23 04:38:01 /health ...................................... ~ 0.07ms
  2026-09-23 04:38:07 /health ...................................... ~ 0.07ms
  2026-09-23 04:38:17 /health ...................................... ~ 0.07ms
  2026-09-23 04:38:21 /health ...................................... ~ 0.07ms
  2026-09-23 04:38:27 /health ...................................... ~ 0.07ms
  2026-09-23 04:38:37 /health ...................................... ~ 0.06ms
  2026-09-23 04:38:41 /health ...................................... ~ 0.07ms
  2026-09-23 04:38:47 /health ...................................... ~ 0.06ms
  2026-09-23 04:38:57 /health ...................................... ~ 0.07ms
  2026-09-23 04:39:01 /health ...................................... ~ 0.07ms
  2026-09-23 04:39:07 /health ...................................... ~ 0.07ms
  2026-09-23 04:39:17 /health ...................................... ~ 0.07ms
  2026-09-23 04:39:21 /health ...................................... ~ 0.08ms
  2026-09-23 04:39:27 /health ...................................... ~ 0.06ms
  2026-09-23 04:39:37 /health ...................................... ~ 0.06ms
  2026-09-23 04:39:41 /health ...................................... ~ 0.07ms
  2026-09-23 04:39:47 /health ...................................... ~ 0.06ms
  2026-09-23 04:39:57 /health ...................................... ~ 0.06ms
  2026-09-23 04:40:01 /health ...................................... ~ 0.07ms
  2026-09-23 04:40:07 /health .................................... ~ 500.22ms
  2026-09-23 04:40:17 /health .................................... ~ 500.22ms
  2026-09-23 04:40:21 /health ...................................... ~ 0.07ms
  2026-09-23 04:40:27 /health .................................... ~ 500.21ms
  2026-09-23 04:40:37 /health ...................................... ~ 0.07ms
  2026-09-23 04:40:41 /health ...................................... ~ 0.07ms
  2026-09-23 04:40:47 /health ...................................... ~ 0.07ms
  2026-09-23 04:40:57 /health ...................................... ~ 0.06ms
  2026-09-23 04:41:01 /health ...................................... ~ 0.08ms
  2026-09-23 04:41:07 /health ...................................... ~ 0.07ms
  2026-09-23 04:41:17 /health ...................................... ~ 0.06ms
  2026-09-23 04:41:21 /health ...................................... ~ 0.08ms
  2026-09-23 04:41:27 /health ...................................... ~ 0.06ms
  2026-09-23 04:41:37 /health ...................................... ~ 0.08ms
  2026-09-23 04:41:41 /health ...................................... ~ 0.07ms
  2026-09-23 04:41:47 /health ...................................... ~ 0.07ms
  2026-09-23 04:41:57 /health ...................................... ~ 0.06ms
  2026-09-23 04:42:01 /health ...................................... ~ 0.07ms
  2026-09-23 04:42:07 /health ...................................... ~ 0.09ms
  2026-09-23 04:42:17 /health ...................................... ~ 0.07ms
  2026-09-23 04:42:21 /health ...................................... ~ 0.08ms
  2026-09-23 04:42:27 /health ...................................... ~ 0.07ms
  2026-09-23 04:42:37 /health ...................................... ~ 0.06ms
  2026-09-23 04:42:41 /health ...................................... ~ 0.07ms
  2026-09-23 04:42:47 /health ...................................... ~ 0.06ms
  2026-09-23 04:42:57 /health ...................................... ~ 0.06ms
  2026-09-23 04:43:01 /health ...................................... ~ 0.07ms
  2026-09-23 04:43:07 /health ...................................... ~ 0.07ms
  2026-09-23 04:43:17 /health ...................................... ~ 0.06ms
  2026-09-23 04:43:21 /health ...................................... ~ 0.07ms
  2026-09-23 04:43:27 /health ...................................... ~ 0.06ms
  2026-09-23 04:43:37 /health ...................................... ~ 0.07ms
  2026-09-23 04:43:41 /health ...................................... ~ 0.06ms
  2026-09-23 04:43:47 /health ...................................... ~ 0.06ms
  2026-09-23 04:43:57 /health ...................................... ~ 0.07ms
  2026-09-23 04:44:01 /health ...................................... ~ 0.06ms
  2026-09-23 04:44:07 /health ...................................... ~ 0.06ms
  2026-09-23 04:44:17 /health ...................................... ~ 0.06ms
  2026-09-23 04:44:21 /health ...................................... ~ 0.06ms
  2026-09-23 04:44:27 /health ...................................... ~ 0.06ms
  2026-09-23 04:44:37 /health ...................................... ~ 0.06ms
  2026-09-23 04:44:41 /health ...................................... ~ 0.07ms
  2026-09-23 04:44:47 /health ...................................... ~ 0.06ms
  2026-09-23 04:44:57 /health ...................................... ~ 0.07ms
  2026-09-23 04:45:01 /health ...................................... ~ 0.06ms
  2026-09-23 04:45:07 /health ...................................... ~ 0.06ms
  2026-09-23 04:45:17 /health ...................................... ~ 0.07ms
  2026-09-23 04:45:21 /health .................................... ~ 500.22ms
  2026-09-23 04:45:27 /health ...................................... ~ 0.07ms
  2026-09-23 04:45:37 /health ...................................... ~ 0.06ms
  2026-09-23 04:45:41 /health ...................................... ~ 0.06ms
```

## Logs deployment/chatbot-manager

```text
  2026-09-23 04:36:57 /health ...................................... ~ 0.06ms
  2026-09-23 04:37:02 /health ...................................... ~ 0.06ms
  2026-09-23 04:37:07 /health ...................................... ~ 0.06ms
  2026-09-23 04:37:17 /health ...................................... ~ 0.07ms
  2026-09-23 04:37:22 /health ...................................... ~ 0.07ms
  2026-09-23 04:37:27 /health ...................................... ~ 0.06ms
  2026-09-23 04:37:37 /health ...................................... ~ 0.07ms
  2026-09-23 04:37:42 /health ...................................... ~ 0.07ms
  2026-09-23 04:37:47 /health ...................................... ~ 0.07ms
  2026-09-23 04:37:57 /health ...................................... ~ 0.06ms
  2026-09-23 04:38:02 /health ...................................... ~ 0.07ms
  2026-09-23 04:38:07 /health ...................................... ~ 0.09ms
  2026-09-23 04:38:17 /health ...................................... ~ 0.07ms
  2026-09-23 04:38:22 /health ...................................... ~ 0.07ms
  2026-09-23 04:38:27 /health ...................................... ~ 0.07ms
  2026-09-23 04:38:37 /health ...................................... ~ 0.06ms
  2026-09-23 04:38:42 /health ...................................... ~ 0.07ms
  2026-09-23 04:38:47 /health ...................................... ~ 0.07ms
  2026-09-23 04:38:57 /health ...................................... ~ 0.06ms
  2026-09-23 04:39:02 /health ...................................... ~ 0.07ms
  2026-09-23 04:39:07 /health ...................................... ~ 0.07ms
  2026-09-23 04:39:17 /health ...................................... ~ 0.07ms
  2026-09-23 04:39:22 /health ...................................... ~ 0.06ms
  2026-09-23 04:39:27 /health ...................................... ~ 0.07ms
  2026-09-23 04:39:37 /health ...................................... ~ 0.07ms
  2026-09-23 04:39:42 /health ...................................... ~ 0.07ms
  2026-09-23 04:39:47 /health ...................................... ~ 0.07ms
  2026-09-23 04:39:57 /health ...................................... ~ 0.06ms
  2026-09-23 04:40:02 /health ...................................... ~ 0.06ms
  2026-09-23 04:40:07 /health ...................................... ~ 0.07ms
  2026-09-23 04:40:17 /health ...................................... ~ 0.06ms
  2026-09-23 04:40:22 /health ...................................... ~ 0.07ms
  2026-09-23 04:40:27 /health ...................................... ~ 0.07ms
  2026-09-23 04:40:37 /health ...................................... ~ 0.08ms
  2026-09-23 04:40:42 /health ...................................... ~ 0.07ms
  2026-09-23 04:40:47 /health ...................................... ~ 0.06ms
  2026-09-23 04:40:57 /health ...................................... ~ 0.08ms
  2026-09-23 04:41:02 /health ...................................... ~ 0.07ms
  2026-09-23 04:41:07 /health ...................................... ~ 0.07ms
  2026-09-23 04:41:17 /health ...................................... ~ 0.08ms
  2026-09-23 04:41:22 /health ...................................... ~ 0.06ms
  2026-09-23 04:41:27 /health ...................................... ~ 0.06ms
  2026-09-23 04:41:37 /health ...................................... ~ 0.06ms
  2026-09-23 04:41:42 /health ...................................... ~ 0.06ms
  2026-09-23 04:41:47 /health ...................................... ~ 0.07ms
  2026-09-23 04:41:57 /health ...................................... ~ 0.09ms
  2026-09-23 04:42:02 /health ...................................... ~ 0.07ms
  2026-09-23 04:42:07 /health ...................................... ~ 0.09ms
  2026-09-23 04:42:17 /health ...................................... ~ 0.07ms
  2026-09-23 04:42:22 /health ...................................... ~ 0.07ms
  2026-09-23 04:42:27 /health ...................................... ~ 0.06ms
  2026-09-23 04:42:37 /health ...................................... ~ 0.06ms
  2026-09-23 04:42:42 /health ...................................... ~ 0.07ms
  2026-09-23 04:42:47 /health ...................................... ~ 0.07ms
  2026-09-23 04:42:57 /health ...................................... ~ 0.06ms
  2026-09-23 04:43:02 /health ...................................... ~ 0.06ms
  2026-09-23 04:43:07 /health ...................................... ~ 0.06ms
  2026-09-23 04:43:17 /health ...................................... ~ 0.06ms
  2026-09-23 04:43:22 /health ...................................... ~ 0.07ms
  2026-09-23 04:43:27 /health ...................................... ~ 0.06ms
  2026-09-23 04:43:37 /health ...................................... ~ 0.07ms
  2026-09-23 04:43:42 /health ...................................... ~ 0.07ms
  2026-09-23 04:43:47 /health ...................................... ~ 0.07ms
  2026-09-23 04:43:57 /health ...................................... ~ 0.09ms
  2026-09-23 04:44:02 /health ...................................... ~ 0.07ms
  2026-09-23 04:44:07 /health ...................................... ~ 0.07ms
  2026-09-23 04:44:17 /health ...................................... ~ 0.07ms
  2026-09-23 04:44:22 /health ...................................... ~ 0.06ms
  2026-09-23 04:44:27 /health ...................................... ~ 0.06ms
  2026-09-23 04:44:37 /health ...................................... ~ 0.06ms
  2026-09-23 04:44:42 /health ...................................... ~ 0.06ms
  2026-09-23 04:44:47 /health ...................................... ~ 0.06ms
  2026-09-23 04:44:57 /health ...................................... ~ 0.06ms
  2026-09-23 04:45:02 /health ...................................... ~ 0.07ms
  2026-09-23 04:45:07 /health ...................................... ~ 0.07ms
  2026-09-23 04:45:17 /health ...................................... ~ 0.09ms
  2026-09-23 04:45:22 /health ...................................... ~ 0.07ms
  2026-09-23 04:45:27 /health ...................................... ~ 0.07ms
  2026-09-23 04:45:37 /health ...................................... ~ 0.07ms
  2026-09-23 04:45:42 /health ...................................... ~ 0.07ms
```

## Logs deployment/conversation-service

```text
  2026-09-23 04:36:58 /health ...................................... ~ 0.09ms
  2026-09-23 04:37:02 /health ...................................... ~ 0.07ms
  2026-09-23 04:37:08 /health ...................................... ~ 0.07ms
  2026-09-23 04:37:18 /health ...................................... ~ 0.07ms
  2026-09-23 04:37:22 /health ...................................... ~ 0.07ms
  2026-09-23 04:37:28 /health ...................................... ~ 0.06ms
  2026-09-23 04:37:38 /health ...................................... ~ 0.07ms
  2026-09-23 04:37:42 /health ...................................... ~ 0.06ms
  2026-09-23 04:37:48 /health ...................................... ~ 0.07ms
  2026-09-23 04:37:58 /health ...................................... ~ 0.07ms
  2026-09-23 04:38:02 /health ...................................... ~ 0.07ms
  2026-09-23 04:38:08 /health ...................................... ~ 0.07ms
  2026-09-23 04:38:18 /health ...................................... ~ 0.07ms
  2026-09-23 04:38:22 /health ...................................... ~ 0.07ms
  2026-09-23 04:38:28 /health ...................................... ~ 0.07ms
  2026-09-23 04:38:38 /health ...................................... ~ 0.07ms
  2026-09-23 04:38:42 /health ...................................... ~ 0.06ms
  2026-09-23 04:38:48 /health ...................................... ~ 0.07ms
  2026-09-23 04:38:58 /health ...................................... ~ 0.07ms
  2026-09-23 04:39:02 /health ...................................... ~ 0.07ms
  2026-09-23 04:39:08 /health ...................................... ~ 0.07ms
  2026-09-23 04:39:18 /health ...................................... ~ 0.07ms
  2026-09-23 04:39:22 /health ...................................... ~ 0.06ms
  2026-09-23 04:39:28 /health ...................................... ~ 0.07ms
  2026-09-23 04:39:38 /health ...................................... ~ 0.07ms
  2026-09-23 04:39:42 /health ...................................... ~ 0.06ms
  2026-09-23 04:39:48 /health ...................................... ~ 0.07ms
  2026-09-23 04:39:58 /health ...................................... ~ 0.07ms
  2026-09-23 04:40:02 /health ...................................... ~ 0.06ms
  2026-09-23 04:40:08 /health ...................................... ~ 0.07ms
  2026-09-23 04:40:18 /health ...................................... ~ 0.07ms
  2026-09-23 04:40:22 /health ...................................... ~ 0.06ms
  2026-09-23 04:40:28 /health ...................................... ~ 0.07ms
  2026-09-23 04:40:38 /health ...................................... ~ 0.07ms
  2026-09-23 04:40:42 /health ...................................... ~ 0.06ms
  2026-09-23 04:40:48 /health ...................................... ~ 0.10ms
  2026-09-23 04:40:58 /health ...................................... ~ 0.07ms
  2026-09-23 04:41:02 /health ...................................... ~ 0.07ms
  2026-09-23 04:41:08 /health ...................................... ~ 0.06ms
  2026-09-23 04:41:18 /health ...................................... ~ 0.07ms
  2026-09-23 04:41:22 /health ...................................... ~ 0.07ms
  2026-09-23 04:41:28 /health ...................................... ~ 0.07ms
  2026-09-23 04:41:38 /health ...................................... ~ 0.07ms
  2026-09-23 04:41:42 /health ...................................... ~ 0.07ms
  2026-09-23 04:41:48 /health ...................................... ~ 0.07ms
  2026-09-23 04:41:58 /health ...................................... ~ 0.10ms
  2026-09-23 04:42:02 /health ...................................... ~ 0.07ms
  2026-09-23 04:42:08 /health ...................................... ~ 0.07ms
  2026-09-23 04:42:18 /health ...................................... ~ 0.09ms
  2026-09-23 04:42:22 /health ...................................... ~ 0.06ms
  2026-09-23 04:42:28 /health ...................................... ~ 0.06ms
  2026-09-23 04:42:38 /health ...................................... ~ 0.06ms
  2026-09-23 04:42:42 /health ...................................... ~ 0.06ms
  2026-09-23 04:42:48 /health ...................................... ~ 0.07ms
  2026-09-23 04:42:58 /health ...................................... ~ 0.06ms
  2026-09-23 04:43:02 /health ...................................... ~ 0.06ms
  2026-09-23 04:43:08 /health ...................................... ~ 0.06ms
  2026-09-23 04:43:18 /health ...................................... ~ 0.07ms
  2026-09-23 04:43:22 /health ...................................... ~ 0.06ms
  2026-09-23 04:43:28 /health ...................................... ~ 0.07ms
  2026-09-23 04:43:38 /health ...................................... ~ 0.07ms
  2026-09-23 04:43:42 /health ...................................... ~ 0.06ms
  2026-09-23 04:43:48 /health ...................................... ~ 0.07ms
  2026-09-23 04:43:58 /health ...................................... ~ 0.07ms
  2026-09-23 04:44:02 /health ...................................... ~ 0.06ms
  2026-09-23 04:44:08 /health ...................................... ~ 0.07ms
  2026-09-23 04:44:18 /health ...................................... ~ 0.07ms
  2026-09-23 04:44:22 /health ...................................... ~ 0.06ms
  2026-09-23 04:44:28 /health ...................................... ~ 0.07ms
  2026-09-23 04:44:38 /health ...................................... ~ 0.06ms
  2026-09-23 04:44:42 /health ...................................... ~ 0.06ms
  2026-09-23 04:44:48 /health ...................................... ~ 0.07ms
  2026-09-23 04:44:58 /health ...................................... ~ 0.07ms
  2026-09-23 04:45:02 /health ...................................... ~ 0.06ms
  2026-09-23 04:45:08 /health ...................................... ~ 0.07ms
  2026-09-23 04:45:18 /health ...................................... ~ 0.07ms
  2026-09-23 04:45:22 /health ...................................... ~ 0.07ms
  2026-09-23 04:45:28 /health ...................................... ~ 0.07ms
  2026-09-23 04:45:38 /health ...................................... ~ 0.07ms
  2026-09-23 04:45:42 /health ...................................... ~ 0.07ms
```

## Logs deployment/audit-security-service

```text
  2026-09-23 04:37:08 /health ...................................... ~ 0.07ms
  2026-09-23 04:37:18 /health ...................................... ~ 0.07ms
  2026-09-23 04:37:22 /health ...................................... ~ 0.07ms
  2026-09-23 04:37:28 /health ...................................... ~ 0.07ms
  2026-09-23 04:37:38 /health ...................................... ~ 0.06ms
  2026-09-23 04:37:42 /health ...................................... ~ 0.07ms
  2026-09-23 04:37:48 /health ...................................... ~ 0.07ms
  2026-09-23 04:37:58 /health ...................................... ~ 0.07ms
  2026-09-23 04:38:02 /health ...................................... ~ 0.08ms
  2026-09-23 04:38:08 /health ...................................... ~ 0.07ms
  2026-09-23 04:38:18 /health ...................................... ~ 0.07ms
  2026-09-23 04:38:22 /health ...................................... ~ 0.06ms
  2026-09-23 04:38:28 /health ...................................... ~ 0.06ms
  2026-09-23 04:38:38 /health ...................................... ~ 0.06ms
  2026-09-23 04:38:42 /health ...................................... ~ 0.06ms
  2026-09-23 04:38:48 /health ...................................... ~ 0.07ms
  2026-09-23 04:38:58 /health ...................................... ~ 0.07ms
  2026-09-23 04:39:02 /health ...................................... ~ 0.09ms
  2026-09-23 04:39:08 /health ...................................... ~ 0.07ms
  2026-09-23 04:39:18 /health ...................................... ~ 0.07ms
  2026-09-23 04:39:22 /health ...................................... ~ 0.06ms
  2026-09-23 04:39:28 /health ...................................... ~ 0.07ms
  2026-09-23 04:39:38 /health ...................................... ~ 0.07ms
  2026-09-23 04:39:42 /health ...................................... ~ 0.07ms
  2026-09-23 04:39:48 /health ...................................... ~ 0.09ms
  2026-09-23 04:39:58 /health ...................................... ~ 0.07ms
  2026-09-23 04:40:02 /health ...................................... ~ 0.07ms
  2026-09-23 04:40:08 /health ...................................... ~ 0.06ms
  2026-09-23 04:40:18 /health ...................................... ~ 0.07ms
  2026-09-23 04:40:22 /health ...................................... ~ 0.07ms
  2026-09-23 04:40:28 /health ...................................... ~ 0.06ms
  2026-09-23 04:40:38 /health ...................................... ~ 0.06ms
  2026-09-23 04:40:42 /health ...................................... ~ 0.06ms
  2026-09-23 04:40:48 /health ...................................... ~ 0.07ms
  2026-09-23 04:40:58 /health ...................................... ~ 0.07ms
  2026-09-23 04:41:02 /health ...................................... ~ 0.07ms
  2026-09-23 04:41:08 /health ...................................... ~ 0.06ms
  2026-09-23 04:41:18 /health ...................................... ~ 0.07ms
  2026-09-23 04:41:22 /health ...................................... ~ 0.06ms
  2026-09-23 04:41:28 /health ...................................... ~ 0.08ms
  2026-09-23 04:41:38 /health ...................................... ~ 0.07ms
  2026-09-23 04:41:42 /health ...................................... ~ 0.06ms
  2026-09-23 04:41:48 /health ...................................... ~ 0.08ms
  2026-09-23 04:41:58 /health ...................................... ~ 0.09ms
  2026-09-23 04:42:02 /health ...................................... ~ 0.07ms
  2026-09-23 04:42:08 /health ...................................... ~ 0.09ms
  2026-09-23 04:42:18 /health ...................................... ~ 0.09ms
  2026-09-23 04:42:22 /health ...................................... ~ 0.07ms
  2026-09-23 04:42:28 /health ...................................... ~ 0.07ms
  2026-09-23 04:42:38 /health ...................................... ~ 0.07ms
  2026-09-23 04:42:42 /health ...................................... ~ 0.06ms
  2026-09-23 04:42:48 /health ...................................... ~ 0.07ms
  2026-09-23 04:42:58 /health ...................................... ~ 0.07ms
  2026-09-23 04:43:02 /health ...................................... ~ 0.07ms
  2026-09-23 04:43:08 /health ...................................... ~ 0.07ms
  2026-09-23 04:43:18 /health ...................................... ~ 0.09ms
  2026-09-23 04:43:22 /health ...................................... ~ 0.07ms
  2026-09-23 04:43:28 /health ...................................... ~ 0.07ms
  2026-09-23 04:43:38 /health ...................................... ~ 0.07ms
  2026-09-23 04:43:42 /health ...................................... ~ 0.06ms
  2026-09-23 04:43:48 /health ...................................... ~ 0.07ms
  2026-09-23 04:43:58 /health ...................................... ~ 0.07ms
  2026-09-23 04:44:02 /health ...................................... ~ 0.07ms
  2026-09-23 04:44:08 /health ...................................... ~ 0.07ms
  2026-09-23 04:44:18 /health ...................................... ~ 0.07ms
  2026-09-23 04:44:22 /health ...................................... ~ 0.06ms
  2026-09-23 04:44:28 /health ...................................... ~ 0.07ms
  2026-09-23 04:44:38 /health ...................................... ~ 0.07ms
  2026-09-23 04:44:42 /health ...................................... ~ 0.07ms
  2026-09-23 04:44:48 /health ...................................... ~ 0.07ms
  2026-09-23 04:44:58 /health ...................................... ~ 0.08ms
  2026-09-23 04:45:02 /health ...................................... ~ 0.07ms
  2026-09-23 04:45:08 /health ...................................... ~ 0.07ms
  2026-09-23 04:45:18 /health ...................................... ~ 0.07ms
  2026-09-23 04:45:22 /health ...................................... ~ 0.07ms
  2026-09-23 04:45:28 /health ...................................... ~ 0.09ms
  2026-09-23 04:45:38 /health ...................................... ~ 0.07ms
  2026-09-23 04:45:39 /health ...................................... ~ 0.07ms
  2026-09-23 04:45:42 /health ...................................... ~ 0.07ms
  2026-09-23 04:45:43 /api/v1/audit-logs ........................... ~ 0.07ms
```

## Logs deployment/portal-web

```text
  2026-09-23 04:37:29 /health ...................................... ~ 0.07ms
  2026-09-23 04:37:39 /health ...................................... ~ 0.07ms
  2026-09-23 04:37:48 /health ...................................... ~ 0.07ms
  2026-09-23 04:37:49 /health ...................................... ~ 0.07ms
  2026-09-23 04:37:59 /health ...................................... ~ 0.07ms
  2026-09-23 04:38:08 /health ...................................... ~ 0.07ms
  2026-09-23 04:38:09 /health ...................................... ~ 0.07ms
  2026-09-23 04:38:19 /health ...................................... ~ 0.07ms
  2026-09-23 04:38:28 /health ...................................... ~ 0.07ms
  2026-09-23 04:38:29 /health ...................................... ~ 0.07ms
  2026-09-23 04:38:39 /health ...................................... ~ 0.08ms
  2026-09-23 04:38:48 /health ...................................... ~ 0.07ms
  2026-09-23 04:38:49 /health ...................................... ~ 0.07ms
  2026-09-23 04:38:59 /health ...................................... ~ 0.07ms
  2026-09-23 04:39:08 /health ...................................... ~ 0.07ms
  2026-09-23 04:39:09 /health ...................................... ~ 0.07ms
  2026-09-23 04:39:19 /health ...................................... ~ 0.07ms
  2026-09-23 04:39:28 /health .................................... ~ 500.23ms
  2026-09-23 04:39:29 /health ...................................... ~ 0.07ms
  2026-09-23 04:39:39 /health ...................................... ~ 0.07ms
  2026-09-23 04:39:48 /health .................................... ~ 500.23ms
  2026-09-23 04:39:49 /health ...................................... ~ 0.07ms
  2026-09-23 04:39:59 /health ...................................... ~ 0.07ms
  2026-09-23 04:40:08 /health ...................................... ~ 0.06ms
  2026-09-23 04:40:09 /health ...................................... ~ 0.07ms
  2026-09-23 04:40:19 /health ...................................... ~ 0.07ms
  2026-09-23 04:40:28 /health ...................................... ~ 0.06ms
  2026-09-23 04:40:29 /health ...................................... ~ 0.07ms
  2026-09-23 04:40:39 /health ...................................... ~ 0.07ms
  2026-09-23 04:40:48 /health ...................................... ~ 0.06ms
  2026-09-23 04:40:49 /health ...................................... ~ 0.07ms
  2026-09-23 04:40:59 /health ...................................... ~ 0.07ms
  2026-09-23 04:41:08 /health ...................................... ~ 0.06ms
  2026-09-23 04:41:09 /health ...................................... ~ 0.07ms
  2026-09-23 04:41:19 /health ...................................... ~ 0.10ms
  2026-09-23 04:41:28 /health ...................................... ~ 0.06ms
  2026-09-23 04:41:29 /health ...................................... ~ 0.08ms
  2026-09-23 04:41:39 /health ...................................... ~ 0.07ms
  2026-09-23 04:41:48 /health ...................................... ~ 0.06ms
  2026-09-23 04:41:49 /health ...................................... ~ 0.09ms
  2026-09-23 04:41:59 /health ...................................... ~ 0.09ms
  2026-09-23 04:42:08 /health ...................................... ~ 0.06ms
  2026-09-23 04:42:09 /health ...................................... ~ 0.07ms
  2026-09-23 04:42:19 /health ...................................... ~ 0.09ms
  2026-09-23 04:42:28 /health ...................................... ~ 0.06ms
  2026-09-23 04:42:29 /health ...................................... ~ 0.07ms
  2026-09-23 04:42:39 /health ...................................... ~ 0.07ms
  2026-09-23 04:42:48 /health ...................................... ~ 0.06ms
  2026-09-23 04:42:49 /health ...................................... ~ 0.07ms
  2026-09-23 04:42:59 /health .................................... ~ 500.25ms
  2026-09-23 04:43:08 /health ...................................... ~ 0.07ms
  2026-09-23 04:43:09 /health .................................... ~ 500.22ms
  2026-09-23 04:43:19 /health .................................... ~ 500.23ms
  2026-09-23 04:43:28 /health ...................................... ~ 0.07ms
  2026-09-23 04:43:29 /health ...................................... ~ 0.10ms
  2026-09-23 04:43:39 /health ...................................... ~ 0.06ms
  2026-09-23 04:43:48 /health ...................................... ~ 0.06ms
  2026-09-23 04:43:49 /health ...................................... ~ 0.06ms
  2026-09-23 04:43:59 /health ...................................... ~ 0.06ms
  2026-09-23 04:44:08 /health ...................................... ~ 0.07ms
  2026-09-23 04:44:09 /health ...................................... ~ 0.06ms
  2026-09-23 04:44:19 /health ...................................... ~ 0.06ms
  2026-09-23 04:44:28 /health ...................................... ~ 0.08ms
  2026-09-23 04:44:29 /health ...................................... ~ 0.06ms
  2026-09-23 04:44:39 /health ...................................... ~ 0.07ms
  2026-09-23 04:44:48 /health ...................................... ~ 0.06ms
  2026-09-23 04:44:49 /health ...................................... ~ 0.06ms
  2026-09-23 04:44:59 /health ...................................... ~ 0.07ms
  2026-09-23 04:45:08 /health ...................................... ~ 0.07ms
  2026-09-23 04:45:09 /health ...................................... ~ 0.07ms
  2026-09-23 04:45:19 /health ...................................... ~ 0.09ms
  2026-09-23 04:45:28 /health ...................................... ~ 0.07ms
  2026-09-23 04:45:29 /health ...................................... ~ 0.07ms
  2026-09-23 04:45:35 /.env ........................................ ~ 0.07ms
  2026-09-23 04:45:35 /storage/ .................................... ~ 0.02ms
  2026-09-23 04:45:35 /admin ....................................... ~ 0.02ms
  2026-09-23 04:45:35 /api/secrets ................................. ~ 0.02ms
  2026-09-23 04:45:35 /dashboard ................................... ~ 0.02ms
  2026-09-23 04:45:35 / ............................................ ~ 0.02ms
  2026-09-23 04:45:39 /health ...................................... ~ 0.07ms
```
