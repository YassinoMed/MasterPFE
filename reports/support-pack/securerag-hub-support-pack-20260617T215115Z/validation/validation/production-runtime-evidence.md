# Production Runtime Evidence - SecureRAG Hub

- Generated at UTC: `2026-06-17T21:51:00Z`
- Namespace: `securerag-hub`
- Status: `TERMINÉ`

| Component | Status | Detail |
|---|---:|---|
| Kubernetes API | TERMINÉ | API server reachable |
| Official deployments | TERMINÉ | Availability check for five Laravel workloads |
| HPA objects | TERMINÉ | HPA resources returned for namespace |
| metrics-server | TERMINÉ | kubectl top works for pods and nodes |
| PodDisruptionBudget | TERMINÉ | PDB resources returned for namespace |

## Kubernetes context

```text
kind-securerag-dev
```

## Deployments

```text
NAME                     READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS               IMAGES                                                     SELECTOR
audit-security-service   1/1     1            1           37h   audit-security-service   localhost:5001/securerag-hub-audit-security-service:demo   app.kubernetes.io/name=audit-security-service,app.kubernetes.io/part-of=securerag-hub
auth-users               1/1     1            1           37h   auth-users               localhost:5001/securerag-hub-auth-users:demo               app.kubernetes.io/name=auth-users,app.kubernetes.io/part-of=securerag-hub
chatbot-manager          1/1     1            1           37h   chatbot-manager          localhost:5001/securerag-hub-chatbot-manager:demo          app.kubernetes.io/name=chatbot-manager,app.kubernetes.io/part-of=securerag-hub
conversation-service     1/1     1            1           37h   conversation-service     localhost:5001/securerag-hub-conversation-service:demo     app.kubernetes.io/name=conversation-service,app.kubernetes.io/part-of=securerag-hub
portal-web               1/1     1            1           37h   portal-web               localhost:5001/securerag-hub-portal-web:demo               app.kubernetes.io/name=portal-web,app.kubernetes.io/part-of=securerag-hub
postgres-auth            0/1     0            0           37h   postgres-auth            postgres:16-alpine                                         app.kubernetes.io/name=postgres-auth,app.kubernetes.io/part-of=securerag-hub
```

## Pods

```text
NAME                                     READY   STATUS    RESTARTS   AGE   IP             NODE                   NOMINATED NODE   READINESS GATES
audit-security-service-9ff7f9ddc-km222   1/1     Running   0          20h   10.244.1.175   securerag-dev-worker   <none>           <none>
auth-users-6f6b795bc4-xk9x5              1/1     Running   0          9h    10.244.1.188   securerag-dev-worker   <none>           <none>
chatbot-manager-58d7f6849b-62rdm         1/1     Running   0          20h   10.244.1.177   securerag-dev-worker   <none>           <none>
conversation-service-6556bc84fd-n75n4    1/1     Running   0          20h   10.244.1.178   securerag-dev-worker   <none>           <none>
portal-web-c99d94df-tgk7n                1/1     Running   0          10h   10.244.1.187   securerag-dev-worker   <none>           <none>
```

## Services

```text
NAME                     TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE   SELECTOR
audit-security-service   ClusterIP   10.96.203.13    <none>        8000/TCP         37h   app.kubernetes.io/name=audit-security-service,app.kubernetes.io/part-of=securerag-hub
auth-users               ClusterIP   10.96.249.47    <none>        8000/TCP         37h   app.kubernetes.io/name=auth-users,app.kubernetes.io/part-of=securerag-hub
chatbot-manager          ClusterIP   10.96.205.74    <none>        8000/TCP         37h   app.kubernetes.io/name=chatbot-manager,app.kubernetes.io/part-of=securerag-hub
conversation-service     ClusterIP   10.96.183.193   <none>        8000/TCP         37h   app.kubernetes.io/name=conversation-service,app.kubernetes.io/part-of=securerag-hub
portal-web               NodePort    10.96.107.28    <none>        8000:30081/TCP   37h   app.kubernetes.io/name=portal-web,app.kubernetes.io/part-of=securerag-hub
postgres-auth            ClusterIP   10.96.143.14    <none>        5432/TCP         37h   app.kubernetes.io/name=postgres-auth,app.kubernetes.io/part-of=securerag-hub
```

## ServiceAccounts

```text
NAME                        SECRETS   AGE
default                     0         37h
sa-audit-security-service   0         37h
sa-auth-users               0         37h
sa-chatbot-manager          0         37h
sa-conversation-service     0         37h
sa-portal-web               0         37h
sa-postgres-auth            0         37h
sa-validation               0         37h
```

## Roles and RoleBindings

```text
NAME                                                        CREATED AT
role.rbac.authorization.k8s.io/securerag-runtime-readonly   2026-06-16T08:42:21Z

NAME                                                                                      ROLE                              AGE   USERS   GROUPS   SERVICEACCOUNTS
rolebinding.rbac.authorization.k8s.io/securerag-runtime-readonly-audit-security-service   Role/securerag-runtime-readonly   37h                    securerag-hub/sa-audit-security-service
```

## PDB

```text
NAME                         MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
audit-security-service-pdb   1               N/A               0                     37h
auth-users-pdb               1               N/A               0                     37h
chatbot-manager-pdb          1               N/A               0                     37h
conversation-service-pdb     1               N/A               0                     37h
portal-web-pdb               1               N/A               0                     37h
```

## HPA

```text
NAME         REFERENCE               TARGETS       MINPODS   MAXPODS   REPLICAS   AGE
portal-web   Deployment/portal-web   cpu: 2%/70%   1         3         1          37h
```

## ResourceQuota

```text
NAME                  REQUEST                                                                                                                                                                       LIMIT                                                                                AGE
securerag-hub-quota   persistentvolumeclaims: 0/10, pods: 5/30, requests.cpu: 500m/3, requests.ephemeral-storage: 768Mi/4Gi, requests.memory: 640Mi/3Gi, requests.storage: 0/40Gi, services: 6/20   limits.cpu: 1600m/8, limits.ephemeral-storage: 3Gi/12Gi, limits.memory: 1792Mi/8Gi   37h
```

## LimitRange

```text
NAME                     CREATED AT
securerag-hub-defaults   2026-06-16T08:42:21Z
```

## NetworkPolicies

```text
NAME                             POD-SELECTOR                                                                                                    AGE
allow-dns-egress                 <none>                                                                                                          37h
allow-validation-egress          app.kubernetes.io/part-of=securerag-hub,job-role=validation                                                     37h
allow-validation-ingress         app.kubernetes.io/name in (audit-security-service,auth-users,chatbot-manager,conversation-service,portal-web)   37h
audit-security-service-network   app.kubernetes.io/name=audit-security-service,app.kubernetes.io/part-of=securerag-hub                           37h
auth-users-policy                app.kubernetes.io/name=auth-users,app.kubernetes.io/part-of=securerag-hub                                       37h
chatbot-manager-policy           app.kubernetes.io/name=chatbot-manager,app.kubernetes.io/part-of=securerag-hub                                  37h
conversation-service-network     app.kubernetes.io/name=conversation-service,app.kubernetes.io/part-of=securerag-hub                             37h
default-deny-all                 <none>                                                                                                          37h
portal-web-policy                app.kubernetes.io/name=portal-web,app.kubernetes.io/part-of=securerag-hub                                       37h
postgres-auth-policy             app.kubernetes.io/name=postgres-auth,app.kubernetes.io/part-of=securerag-hub                                    37h
```

## Pod images and imageIDs

```text
audit-security-service-9ff7f9ddc-km222	localhost:5001/securerag-hub-audit-security-service:demo	localhost:5001/securerag-hub-audit-security-service@sha256:dbe4052bfaa5e483971304008e290afa273b7043d7cefb21e3e2c814a43a574d
auth-users-6f6b795bc4-xk9x5	localhost:5001/securerag-hub-auth-users:demo	localhost:5001/securerag-hub-auth-users@sha256:0539a63c0387008274def09c44115a07361973950844e7610c24cbbcc113db0f
chatbot-manager-58d7f6849b-62rdm	localhost:5001/securerag-hub-chatbot-manager:demo	localhost:5001/securerag-hub-chatbot-manager@sha256:fab7c3001344ff2872c9cf761ffbe62b82d2371063f8b177136245b1eb86af67
conversation-service-6556bc84fd-n75n4	localhost:5001/securerag-hub-conversation-service:demo	localhost:5001/securerag-hub-conversation-service@sha256:c1c7f050e081f70f8aac9f21bcad8633fb3f2049f6752d94f39373d0f8b29b37
portal-web-c99d94df-tgk7n	localhost:5001/securerag-hub-portal-web:demo	localhost:5001/securerag-hub-portal-web@sha256:0cbc3de627ab4bc5e9c8d591dc0ec07a063ec3dec32d41984ce0536d66094550
```

## Recent events

```text
LAST SEEN   TYPE      REASON            OBJECT                                MESSAGE
8m10s       Warning   PolicyViolation   service/postgres-auth                 policy securerag-restrict-service-exposure/allow-nodeport-only-for-portal-web fail: Only portal-web may use NodePort in the local demo overlay; LoadBalancer is forbidden.
53m         Warning   FailedCreate      replicaset/postgres-auth-867ddc6dc8   Error creating: admission webhook "validate.kyverno.svc-fail" denied the request: ...
36m         Warning   FailedCreate      replicaset/postgres-auth-867ddc6dc8   Error creating: admission webhook "validate.kyverno.svc-fail" denied the request: ...
20m         Warning   FailedCreate      replicaset/postgres-auth-867ddc6dc8   Error creating: admission webhook "validate.kyverno.svc-fail" denied the request: ...
3m22s       Warning   FailedCreate      replicaset/postgres-auth-867ddc6dc8   Error creating: admission webhook "validate.kyverno.svc-fail" denied the request: ...
```

## Metrics APIService

```text
NAME                     SERVICE                      AVAILABLE   AGE
v1beta1.metrics.k8s.io   kube-system/metrics-server   True        9h
```

## Node metrics

```text
NAME                          CPU(cores)   CPU(%)   MEMORY(bytes)   MEMORY(%)   
securerag-dev-control-plane   153m         1%       1090Mi          6%          
securerag-dev-worker          79m          0%       1468Mi          9%          
```

## Pod metrics

```text
NAME                                     CPU(cores)   MEMORY(bytes)   
audit-security-service-9ff7f9ddc-km222   2m           57Mi            
auth-users-6f6b795bc4-xk9x5              2m           57Mi            
chatbot-manager-58d7f6849b-62rdm         2m           57Mi            
conversation-service-6556bc84fd-n75n4    2m           57Mi            
portal-web-c99d94df-tgk7n                2m           61Mi            
```

## Describe deployment/portal-web

```text
Name:                   portal-web
Namespace:              securerag-hub
CreationTimestamp:      Tue, 16 Jun 2026 10:42:21 +0200
Labels:                 app.kubernetes.io/part-of=securerag-hub
Annotations:            deployment.kubernetes.io/revision: 16
                        kube-score/ignore:
                          pod-probes, container-security-context-user-group-id, deployment-replicas, networkpolicy-targets-pod, container-image-pull-policy, pod-net...
Selector:               app.kubernetes.io/name=portal-web,app.kubernetes.io/part-of=securerag-hub
Replicas:               1 desired | 1 updated | 1 total | 1 available | 0 unavailable
StrategyType:           RollingUpdate
MinReadySeconds:        0
RollingUpdateStrategy:  25% max unavailable, 25% max surge
Pod Template:
  Labels:           app.kubernetes.io/name=portal-web
                    app.kubernetes.io/part-of=securerag-hub
  Annotations:      kube-score/ignore:
                      pod-probes, container-security-context-user-group-id, deployment-replicas, networkpolicy-targets-pod, container-image-pull-policy, pod-net...
                    kubectl.kubernetes.io/restartedAt: 2026-06-17T03:06:57+02:00
                    security.securerag.dev/internal-cleartext-justification: Internal ClusterIP service calls only; egress is restricted by NetworkPolicies.
                    security.securerag.dev/internal-cleartext-scope: cluster-only-networkpolicy
  Service Account:  sa-portal-web
  Containers:
   portal-web:
    Image:      localhost:5001/securerag-hub-portal-web:demo
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
  Progressing    True    NewReplicaSetAvailable
  Available      True    MinimumReplicasAvailable
OldReplicaSets:  portal-web-dddbbf886 (0/0 replicas created), portal-web-5df67f74d7 (0/0 replicas created), portal-web-5b644644f5 (0/0 replicas created), portal-web-86f5c4dd9 (0/0 replicas created), portal-web-6976f598fc (0/0 replicas created), portal-web-76857f474 (0/0 replicas created), portal-web-76c5f7f694 (0/0 replicas created), portal-web-57896bd95f (0/0 replicas created), portal-web-5f9765cd74 (0/0 replicas created), portal-web-789c66c657 (0/0 replicas created)
NewReplicaSet:   portal-web-c99d94df (1/1 replicas created)
Events:          <none>
```

## Logs deployment/portal-web

```text
  2026-06-17 21:37:50 /health ...................................... ~ 0.09ms
  2026-06-17 21:37:59 /health ...................................... ~ 0.11ms
  2026-06-17 21:38:00 /health ...................................... ~ 0.07ms
  2026-06-17 21:38:10 /health ...................................... ~ 0.10ms
  2026-06-17 21:38:19 /health ...................................... ~ 0.09ms
  2026-06-17 21:38:20 /health ...................................... ~ 0.07ms
  2026-06-17 21:38:30 /health ...................................... ~ 0.08ms
  2026-06-17 21:38:39 /health ...................................... ~ 0.08ms
  2026-06-17 21:38:40 /health ...................................... ~ 0.07ms
  2026-06-17 21:38:50 /health ...................................... ~ 0.12ms
  2026-06-17 21:38:59 /health ...................................... ~ 0.07ms
  2026-06-17 21:39:00 /health ...................................... ~ 0.07ms
  2026-06-17 21:39:10 /health ...................................... ~ 0.07ms
  2026-06-17 21:39:19 /health ...................................... ~ 0.08ms
  2026-06-17 21:39:20 /health ...................................... ~ 0.11ms
  2026-06-17 21:39:30 /health ...................................... ~ 0.07ms
  2026-06-17 21:39:39 /health ...................................... ~ 0.07ms
  2026-06-17 21:39:40 /health ...................................... ~ 0.10ms
  2026-06-17 21:39:50 /health ...................................... ~ 0.10ms
  2026-06-17 21:39:59 /health ...................................... ~ 0.10ms
  2026-06-17 21:40:00 /health ...................................... ~ 0.08ms
  2026-06-17 21:40:10 /health ...................................... ~ 0.17ms
  2026-06-17 21:40:19 /health ...................................... ~ 0.07ms
  2026-06-17 21:40:20 /health ...................................... ~ 0.10ms
  2026-06-17 21:40:30 /health ...................................... ~ 0.09ms
  2026-06-17 21:40:39 /health ...................................... ~ 0.08ms
  2026-06-17 21:40:40 /health ...................................... ~ 0.07ms
  2026-06-17 21:40:50 /health ...................................... ~ 0.08ms
  2026-06-17 21:40:59 /health ...................................... ~ 0.09ms
  2026-06-17 21:41:00 /health ...................................... ~ 0.07ms
  2026-06-17 21:41:10 /health ...................................... ~ 0.11ms
  2026-06-17 21:41:19 /health ...................................... ~ 0.09ms
  2026-06-17 21:41:20 /health ...................................... ~ 0.07ms
  2026-06-17 21:41:30 /health ...................................... ~ 0.08ms
  2026-06-17 21:41:39 /health ...................................... ~ 0.07ms
  2026-06-17 21:41:40 /health ...................................... ~ 0.07ms
  2026-06-17 21:41:50 /health ...................................... ~ 0.08ms
  2026-06-17 21:41:59 /health ...................................... ~ 0.08ms
  2026-06-17 21:42:00 /health ...................................... ~ 0.08ms
  2026-06-17 21:42:10 /health ...................................... ~ 0.07ms
  2026-06-17 21:42:19 /health ...................................... ~ 0.10ms
  2026-06-17 21:42:20 /health ...................................... ~ 0.08ms
  2026-06-17 21:42:30 /health ...................................... ~ 0.08ms
  2026-06-17 21:42:39 /health ...................................... ~ 0.07ms
  2026-06-17 21:42:40 /health ...................................... ~ 0.09ms
  2026-06-17 21:42:50 /health ...................................... ~ 0.12ms
  2026-06-17 21:42:59 /health ...................................... ~ 0.10ms
  2026-06-17 21:43:00 /health ...................................... ~ 0.09ms
  2026-06-17 21:43:10 /health ...................................... ~ 0.08ms
  2026-06-17 21:43:19 /health ...................................... ~ 0.09ms
  2026-06-17 21:43:20 /health ...................................... ~ 0.09ms
  2026-06-17 21:43:30 /health ...................................... ~ 0.09ms
  2026-06-17 21:43:39 /health ...................................... ~ 0.07ms
  2026-06-17 21:43:40 /health ...................................... ~ 0.08ms
  2026-06-17 21:43:50 /health ...................................... ~ 0.08ms
  2026-06-17 21:43:59 /health ...................................... ~ 0.07ms
  2026-06-17 21:44:00 /health ...................................... ~ 0.07ms
  2026-06-17 21:44:10 /health ...................................... ~ 0.08ms
  2026-06-17 21:44:19 /health ...................................... ~ 0.08ms
  2026-06-17 21:44:20 /health ...................................... ~ 0.08ms
  2026-06-17 21:44:30 /health ...................................... ~ 0.08ms
  2026-06-17 21:44:39 /health ...................................... ~ 0.09ms
  2026-06-17 21:44:40 /health ...................................... ~ 0.09ms
  2026-06-17 21:44:50 /health ...................................... ~ 0.10ms
  2026-06-17 21:44:59 /health ...................................... ~ 0.08ms
  2026-06-17 21:45:00 /health ...................................... ~ 0.07ms
  2026-06-17 21:45:10 /health ...................................... ~ 0.07ms
  2026-06-17 21:45:19 /health ...................................... ~ 0.14ms
  2026-06-17 21:45:20 /health ...................................... ~ 0.08ms
  2026-06-17 21:45:30 /health ...................................... ~ 0.08ms
  2026-06-17 21:45:39 /health ...................................... ~ 0.09ms
  2026-06-17 21:45:40 /health ...................................... ~ 0.15ms
  2026-06-17 21:45:50 /health ...................................... ~ 0.10ms
  2026-06-17 21:45:59 /health ...................................... ~ 0.08ms
  2026-06-17 21:46:00 /health ...................................... ~ 0.10ms
  2026-06-17 21:46:10 /health ...................................... ~ 0.10ms
  2026-06-17 21:46:19 /health ...................................... ~ 0.11ms
  2026-06-17 21:46:20 /health ...................................... ~ 0.08ms
  2026-06-17 21:46:30 /health ...................................... ~ 0.08ms
  2026-06-17 21:46:39 /health ...................................... ~ 0.08ms
  2026-06-17 21:46:40 /health ...................................... ~ 0.08ms
  2026-06-17 21:46:50 /health ...................................... ~ 0.11ms
  2026-06-17 21:46:59 /health ...................................... ~ 0.09ms
  2026-06-17 21:47:00 /health ...................................... ~ 0.09ms
  2026-06-17 21:47:10 /health ...................................... ~ 0.08ms
  2026-06-17 21:47:19 /health ...................................... ~ 0.07ms
  2026-06-17 21:47:20 /health .................................... ~ 500.26ms
  2026-06-17 21:47:30 /health .................................... ~ 500.28ms
  2026-06-17 21:47:39 /health ...................................... ~ 0.09ms
  2026-06-17 21:47:40 /health ...................................... ~ 0.10ms
  2026-06-17 21:47:50 /health ...................................... ~ 0.07ms
  2026-06-17 21:47:59 /health ...................................... ~ 0.07ms
  2026-06-17 21:48:00 /health ...................................... ~ 0.07ms
  2026-06-17 21:48:10 /health ...................................... ~ 0.07ms
  2026-06-17 21:48:19 /health ...................................... ~ 0.08ms
  2026-06-17 21:48:20 /health ...................................... ~ 0.07ms
  2026-06-17 21:48:30 /health ...................................... ~ 0.10ms
  2026-06-17 21:48:39 /health ...................................... ~ 0.10ms
  2026-06-17 21:48:40 /health ...................................... ~ 0.09ms
  2026-06-17 21:48:50 /health ...................................... ~ 0.14ms
  2026-06-17 21:48:59 /health ...................................... ~ 0.11ms
  2026-06-17 21:49:00 /health ...................................... ~ 0.07ms
  2026-06-17 21:49:10 /health ...................................... ~ 0.09ms
  2026-06-17 21:49:19 /health ...................................... ~ 0.09ms
  2026-06-17 21:49:20 /health ...................................... ~ 0.12ms
  2026-06-17 21:49:30 /health ...................................... ~ 0.09ms
  2026-06-17 21:49:39 /health ...................................... ~ 0.09ms
  2026-06-17 21:49:40 /health ...................................... ~ 0.08ms
  2026-06-17 21:49:50 /health ...................................... ~ 0.08ms
  2026-06-17 21:49:59 /health ...................................... ~ 0.08ms
  2026-06-17 21:50:00 /health ...................................... ~ 0.07ms
  2026-06-17 21:50:10 /health ...................................... ~ 0.09ms
  2026-06-17 21:50:19 /health ...................................... ~ 0.11ms
  2026-06-17 21:50:20 /health ...................................... ~ 0.12ms
  2026-06-17 21:50:30 /health ...................................... ~ 0.08ms
  2026-06-17 21:50:39 /health ...................................... ~ 0.08ms
  2026-06-17 21:50:40 /health ...................................... ~ 0.08ms
  2026-06-17 21:50:50 /health ...................................... ~ 0.07ms
  2026-06-17 21:50:59 /health ...................................... ~ 0.08ms
  2026-06-17 21:51:00 /health ...................................... ~ 0.07ms
```

## Describe deployment/auth-users

```text
Name:                   auth-users
Namespace:              securerag-hub
CreationTimestamp:      Tue, 16 Jun 2026 10:42:21 +0200
Labels:                 app.kubernetes.io/part-of=securerag-hub
Annotations:            deployment.kubernetes.io/revision: 17
                        kube-score/ignore:
                          pod-probes, container-security-context-user-group-id, deployment-replicas, networkpolicy-targets-pod, container-image-pull-policy, pod-net...
Selector:               app.kubernetes.io/name=auth-users,app.kubernetes.io/part-of=securerag-hub
Replicas:               1 desired | 1 updated | 1 total | 1 available | 0 unavailable
StrategyType:           RollingUpdate
MinReadySeconds:        0
RollingUpdateStrategy:  25% max unavailable, 25% max surge
Pod Template:
  Labels:           app.kubernetes.io/name=auth-users
                    app.kubernetes.io/part-of=securerag-hub
  Annotations:      kube-score/ignore:
                      pod-probes, container-security-context-user-group-id, deployment-replicas, networkpolicy-targets-pod, container-image-pull-policy, pod-net...
                    kubectl.kubernetes.io/restartedAt: 2026-06-17T03:06:57+02:00
                    security.securerag.dev/internal-cleartext-justification: Internal ClusterIP service calls only; egress is restricted by NetworkPolicies.
                    security.securerag.dev/internal-cleartext-scope: cluster-only-networkpolicy
  Service Account:  sa-auth-users
  Containers:
   auth-users:
    Image:      localhost:5001/securerag-hub-auth-users:demo
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
  Progressing    True    NewReplicaSetAvailable
  Available      True    MinimumReplicasAvailable
OldReplicaSets:  auth-users-864b89f474 (0/0 replicas created), auth-users-5d47d77944 (0/0 replicas created), auth-users-79bbc9bd7b (0/0 replicas created), auth-users-5bb6478cbb (0/0 replicas created), auth-users-769cc68c87 (0/0 replicas created), auth-users-b6d75c865 (0/0 replicas created), auth-users-5fc697bf7 (0/0 replicas created), auth-users-765c789fc6 (0/0 replicas created), auth-users-598db9d4c6 (0/0 replicas created), auth-users-77c4b76bc8 (0/0 replicas created)
NewReplicaSet:   auth-users-6f6b795bc4 (1/1 replicas created)
Events:          <none>
```

## Logs deployment/auth-users

```text
  2026-06-17 21:37:43 /health ...................................... ~ 0.09ms
  2026-06-17 21:37:53 /health ...................................... ~ 0.11ms
  2026-06-17 21:37:58 /health ...................................... ~ 0.10ms
  2026-06-17 21:38:03 /health ...................................... ~ 0.08ms
  2026-06-17 21:38:13 /health ...................................... ~ 0.08ms
  2026-06-17 21:38:18 /health ...................................... ~ 0.11ms
  2026-06-17 21:38:23 /health ...................................... ~ 0.12ms
  2026-06-17 21:38:33 /health ...................................... ~ 0.08ms
  2026-06-17 21:38:38 /health ...................................... ~ 0.10ms
  2026-06-17 21:38:43 /health ...................................... ~ 0.11ms
  2026-06-17 21:38:53 /health ...................................... ~ 0.13ms
  2026-06-17 21:38:58 /health ...................................... ~ 0.10ms
  2026-06-17 21:39:03 /health ...................................... ~ 0.09ms
  2026-06-17 21:39:13 /health ...................................... ~ 0.12ms
  2026-06-17 21:39:18 /health ...................................... ~ 0.09ms
  2026-06-17 21:39:23 /health ...................................... ~ 0.08ms
  2026-06-17 21:39:33 /health ...................................... ~ 0.08ms
  2026-06-17 21:39:38 /health ...................................... ~ 0.10ms
  2026-06-17 21:39:43 /health ...................................... ~ 0.09ms
  2026-06-17 21:39:53 /health ...................................... ~ 0.08ms
  2026-06-17 21:39:58 /health ...................................... ~ 0.08ms
  2026-06-17 21:40:03 /health ...................................... ~ 0.10ms
  2026-06-17 21:40:13 /health ...................................... ~ 0.10ms
  2026-06-17 21:40:18 /health ...................................... ~ 0.07ms
  2026-06-17 21:40:23 /health ...................................... ~ 0.08ms
  2026-06-17 21:40:33 /health ...................................... ~ 0.09ms
  2026-06-17 21:40:38 /health ...................................... ~ 0.12ms
  2026-06-17 21:40:43 /health ...................................... ~ 0.13ms
  2026-06-17 21:40:53 /health ...................................... ~ 0.11ms
  2026-06-17 21:40:58 /health ...................................... ~ 0.09ms
  2026-06-17 21:41:03 /health ...................................... ~ 0.16ms
  2026-06-17 21:41:13 /health ...................................... ~ 0.09ms
  2026-06-17 21:41:18 /health ...................................... ~ 0.10ms
  2026-06-17 21:41:23 /health ...................................... ~ 0.08ms
  2026-06-17 21:41:33 /health ...................................... ~ 0.10ms
  2026-06-17 21:41:38 /health ...................................... ~ 0.09ms
  2026-06-17 21:41:43 /health ...................................... ~ 0.08ms
  2026-06-17 21:41:53 /health ...................................... ~ 0.08ms
  2026-06-17 21:41:58 /health ...................................... ~ 0.10ms
  2026-06-17 21:42:03 /health ...................................... ~ 0.09ms
  2026-06-17 21:42:13 /health ...................................... ~ 0.09ms
  2026-06-17 21:42:18 /health ...................................... ~ 0.08ms
  2026-06-17 21:42:23 /health ...................................... ~ 0.08ms
  2026-06-17 21:42:33 /health ...................................... ~ 0.09ms
  2026-06-17 21:42:38 /health ...................................... ~ 0.10ms
  2026-06-17 21:42:43 /health ...................................... ~ 0.10ms
  2026-06-17 21:42:53 /health ...................................... ~ 0.08ms
  2026-06-17 21:42:58 /health ...................................... ~ 0.08ms
  2026-06-17 21:43:03 /health ...................................... ~ 0.09ms
  2026-06-17 21:43:13 /health ...................................... ~ 0.10ms
  2026-06-17 21:43:18 /health ...................................... ~ 0.08ms
  2026-06-17 21:43:23 /health ...................................... ~ 0.08ms
  2026-06-17 21:43:33 /health ...................................... ~ 0.09ms
  2026-06-17 21:43:38 /health ...................................... ~ 0.08ms
  2026-06-17 21:43:43 /health ...................................... ~ 0.08ms
  2026-06-17 21:43:53 /health ...................................... ~ 0.09ms
  2026-06-17 21:43:58 /health ...................................... ~ 0.08ms
  2026-06-17 21:44:03 /health ...................................... ~ 0.11ms
  2026-06-17 21:44:13 /health ...................................... ~ 0.07ms
  2026-06-17 21:44:18 /health ...................................... ~ 0.07ms
  2026-06-17 21:44:23 /health ...................................... ~ 0.08ms
  2026-06-17 21:44:33 /health ...................................... ~ 0.10ms
  2026-06-17 21:44:38 /health ...................................... ~ 0.09ms
  2026-06-17 21:44:43 /health ...................................... ~ 0.09ms
  2026-06-17 21:44:53 /health ...................................... ~ 0.07ms
  2026-06-17 21:44:58 /health ...................................... ~ 0.07ms
  2026-06-17 21:45:03 /health ...................................... ~ 0.10ms
  2026-06-17 21:45:13 /health ...................................... ~ 0.12ms
  2026-06-17 21:45:18 /health ...................................... ~ 0.09ms
  2026-06-17 21:45:23 /health ...................................... ~ 0.10ms
  2026-06-17 21:45:33 /health ...................................... ~ 0.07ms
  2026-06-17 21:45:38 /health ...................................... ~ 0.09ms
  2026-06-17 21:45:43 /health ...................................... ~ 0.09ms
  2026-06-17 21:45:53 /health ...................................... ~ 0.08ms
  2026-06-17 21:45:58 /health ...................................... ~ 0.10ms
  2026-06-17 21:46:03 /health ...................................... ~ 0.10ms
  2026-06-17 21:46:13 /health ...................................... ~ 0.09ms
  2026-06-17 21:46:18 /health ...................................... ~ 0.08ms
  2026-06-17 21:46:23 /health ...................................... ~ 0.10ms
  2026-06-17 21:46:33 /health ...................................... ~ 0.08ms
  2026-06-17 21:46:38 /health ...................................... ~ 0.08ms
  2026-06-17 21:46:43 /health ...................................... ~ 0.08ms
  2026-06-17 21:46:53 /health ...................................... ~ 0.10ms
  2026-06-17 21:46:58 /health ...................................... ~ 0.08ms
  2026-06-17 21:47:03 /health ...................................... ~ 0.11ms
  2026-06-17 21:47:13 /health ...................................... ~ 0.08ms
  2026-06-17 21:47:18 /health ...................................... ~ 0.08ms
  2026-06-17 21:47:23 /health ...................................... ~ 0.08ms
  2026-06-17 21:47:33 /health ...................................... ~ 0.08ms
  2026-06-17 21:47:38 /health ...................................... ~ 0.10ms
  2026-06-17 21:47:43 /health ...................................... ~ 0.08ms
  2026-06-17 21:47:53 /health ...................................... ~ 0.09ms
  2026-06-17 21:47:58 /health ...................................... ~ 0.08ms
  2026-06-17 21:48:03 /health ...................................... ~ 0.08ms
  2026-06-17 21:48:13 /health ...................................... ~ 0.09ms
  2026-06-17 21:48:18 /health ...................................... ~ 0.08ms
  2026-06-17 21:48:23 /health ...................................... ~ 0.10ms
  2026-06-17 21:48:33 /health ...................................... ~ 0.13ms
  2026-06-17 21:48:38 /health ...................................... ~ 0.08ms
  2026-06-17 21:48:43 /health ...................................... ~ 0.10ms
  2026-06-17 21:48:53 /health ...................................... ~ 0.10ms
  2026-06-17 21:48:58 /health ...................................... ~ 0.09ms
  2026-06-17 21:49:03 /health ...................................... ~ 0.13ms
  2026-06-17 21:49:13 /health ...................................... ~ 0.11ms
  2026-06-17 21:49:18 /health ...................................... ~ 0.09ms
  2026-06-17 21:49:23 /health ...................................... ~ 0.09ms
  2026-06-17 21:49:33 /health .................................... ~ 500.27ms
  2026-06-17 21:49:38 /health ...................................... ~ 0.08ms
  2026-06-17 21:49:43 /health .................................... ~ 500.28ms
  2026-06-17 21:49:53 /health .................................... ~ 500.26ms
  2026-06-17 21:49:58 /health ...................................... ~ 0.09ms
  2026-06-17 21:50:03 /health ...................................... ~ 0.07ms
  2026-06-17 21:50:13 /health ...................................... ~ 0.08ms
  2026-06-17 21:50:18 /health ...................................... ~ 0.09ms
  2026-06-17 21:50:23 /health ...................................... ~ 0.09ms
  2026-06-17 21:50:33 /health ...................................... ~ 0.09ms
  2026-06-17 21:50:38 /health ...................................... ~ 0.08ms
  2026-06-17 21:50:43 /health ...................................... ~ 0.08ms
  2026-06-17 21:50:53 /health ...................................... ~ 0.08ms
  2026-06-17 21:50:58 /health ...................................... ~ 0.11ms
```

## Describe deployment/chatbot-manager

```text
Name:                   chatbot-manager
Namespace:              securerag-hub
CreationTimestamp:      Tue, 16 Jun 2026 10:42:21 +0200
Labels:                 app.kubernetes.io/part-of=securerag-hub
Annotations:            deployment.kubernetes.io/revision: 17
                        kube-score/ignore:
                          pod-probes, container-security-context-user-group-id, deployment-replicas, networkpolicy-targets-pod, container-image-pull-policy, pod-net...
Selector:               app.kubernetes.io/name=chatbot-manager,app.kubernetes.io/part-of=securerag-hub
Replicas:               1 desired | 1 updated | 1 total | 1 available | 0 unavailable
StrategyType:           RollingUpdate
MinReadySeconds:        0
RollingUpdateStrategy:  25% max unavailable, 25% max surge
Pod Template:
  Labels:           app.kubernetes.io/name=chatbot-manager
                    app.kubernetes.io/part-of=securerag-hub
  Annotations:      kube-score/ignore:
                      pod-probes, container-security-context-user-group-id, deployment-replicas, networkpolicy-targets-pod, container-image-pull-policy, pod-net...
                    kubectl.kubernetes.io/restartedAt: 2026-06-17T03:06:57+02:00
                    security.securerag.dev/internal-cleartext-justification: Internal ClusterIP service calls only; egress is restricted by NetworkPolicies.
                    security.securerag.dev/internal-cleartext-scope: cluster-only-networkpolicy
  Service Account:  sa-chatbot-manager
  Containers:
   chatbot-manager:
    Image:      localhost:5001/securerag-hub-chatbot-manager:demo
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
  Progressing    True    NewReplicaSetAvailable
  Available      True    MinimumReplicasAvailable
OldReplicaSets:  chatbot-manager-69b49bffb4 (0/0 replicas created), chatbot-manager-5c6cf9d966 (0/0 replicas created), chatbot-manager-7b994c448c (0/0 replicas created), chatbot-manager-78799bdf68 (0/0 replicas created), chatbot-manager-6b5d8fd8c5 (0/0 replicas created), chatbot-manager-687ff4d5b5 (0/0 replicas created), chatbot-manager-dc75467b9 (0/0 replicas created), chatbot-manager-5f7575f4cd (0/0 replicas created), chatbot-manager-96c45c5db (0/0 replicas created), chatbot-manager-7b547c6c84 (0/0 replicas created)
NewReplicaSet:   chatbot-manager-58d7f6849b (1/1 replicas created)
Events:          <none>
```

## Logs deployment/chatbot-manager

```text
  2026-06-17 21:37:52 /health ...................................... ~ 0.09ms
  2026-06-17 21:37:56 /health ...................................... ~ 0.12ms
  2026-06-17 21:38:02 /health ...................................... ~ 0.10ms
  2026-06-17 21:38:12 /health ...................................... ~ 0.07ms
  2026-06-17 21:38:16 /health ...................................... ~ 0.08ms
  2026-06-17 21:38:22 /health ...................................... ~ 0.09ms
  2026-06-17 21:38:32 /health ...................................... ~ 0.10ms
  2026-06-17 21:38:36 /health ...................................... ~ 0.08ms
  2026-06-17 21:38:42 /health ...................................... ~ 0.09ms
  2026-06-17 21:38:52 /health ...................................... ~ 0.10ms
  2026-06-17 21:38:56 /health ...................................... ~ 0.13ms
  2026-06-17 21:39:02 /health ...................................... ~ 0.28ms
  2026-06-17 21:39:12 /health ...................................... ~ 0.10ms
  2026-06-17 21:39:16 /health ...................................... ~ 0.07ms
  2026-06-17 21:39:22 /health ...................................... ~ 0.15ms
  2026-06-17 21:39:32 /health ...................................... ~ 0.10ms
  2026-06-17 21:39:36 /health ...................................... ~ 0.08ms
  2026-06-17 21:39:42 /health ...................................... ~ 0.09ms
  2026-06-17 21:39:52 /health ...................................... ~ 0.17ms
  2026-06-17 21:39:56 /health ...................................... ~ 0.11ms
  2026-06-17 21:40:02 /health ...................................... ~ 0.09ms
  2026-06-17 21:40:12 /health ...................................... ~ 0.10ms
  2026-06-17 21:40:16 /health ...................................... ~ 0.09ms
  2026-06-17 21:40:22 /health ...................................... ~ 0.09ms
  2026-06-17 21:40:32 /health ...................................... ~ 0.08ms
  2026-06-17 21:40:36 /health ...................................... ~ 0.08ms
  2026-06-17 21:40:42 /health ...................................... ~ 0.08ms
  2026-06-17 21:40:52 /health ...................................... ~ 0.07ms
  2026-06-17 21:40:56 /health ...................................... ~ 0.09ms
  2026-06-17 21:41:02 /health ...................................... ~ 0.08ms
  2026-06-17 21:41:12 /health ...................................... ~ 0.11ms
  2026-06-17 21:41:16 /health ...................................... ~ 0.15ms
  2026-06-17 21:41:22 /health ...................................... ~ 0.24ms
  2026-06-17 21:41:32 /health ...................................... ~ 0.09ms
  2026-06-17 21:41:36 /health ...................................... ~ 0.07ms
  2026-06-17 21:41:42 /health ...................................... ~ 0.08ms
  2026-06-17 21:41:52 /health ...................................... ~ 0.17ms
  2026-06-17 21:41:56 /health ...................................... ~ 0.07ms
  2026-06-17 21:42:02 /health ...................................... ~ 0.11ms
  2026-06-17 21:42:12 /health ...................................... ~ 0.08ms
  2026-06-17 21:42:16 /health ...................................... ~ 0.08ms
  2026-06-17 21:42:22 /health ...................................... ~ 0.07ms
  2026-06-17 21:42:32 /health ...................................... ~ 0.09ms
  2026-06-17 21:42:36 /health ...................................... ~ 0.15ms
  2026-06-17 21:42:42 /health ...................................... ~ 0.08ms
  2026-06-17 21:42:52 /health ...................................... ~ 0.08ms
  2026-06-17 21:42:56 /health ...................................... ~ 0.08ms
  2026-06-17 21:43:02 /health ...................................... ~ 0.08ms
  2026-06-17 21:43:12 /health ...................................... ~ 0.08ms
  2026-06-17 21:43:16 /health ...................................... ~ 0.08ms
  2026-06-17 21:43:22 /health ...................................... ~ 0.09ms
  2026-06-17 21:43:32 /health ...................................... ~ 0.08ms
  2026-06-17 21:43:36 /health ...................................... ~ 0.09ms
  2026-06-17 21:43:42 /health ...................................... ~ 0.10ms
  2026-06-17 21:43:52 /health ...................................... ~ 0.07ms
  2026-06-17 21:43:56 /health ...................................... ~ 0.09ms
  2026-06-17 21:44:02 /health ...................................... ~ 0.15ms
  2026-06-17 21:44:12 /health ...................................... ~ 0.08ms
  2026-06-17 21:44:16 /health ...................................... ~ 0.08ms
  2026-06-17 21:44:22 /health ...................................... ~ 0.10ms
  2026-06-17 21:44:32 /health ...................................... ~ 0.08ms
  2026-06-17 21:44:36 /health ...................................... ~ 0.09ms
  2026-06-17 21:44:42 /health ...................................... ~ 0.09ms
  2026-06-17 21:44:52 /health ...................................... ~ 0.07ms
  2026-06-17 21:44:56 /health ...................................... ~ 0.09ms
  2026-06-17 21:45:02 /health ...................................... ~ 0.09ms
  2026-06-17 21:45:12 /health ...................................... ~ 0.12ms
  2026-06-17 21:45:16 /health ...................................... ~ 0.10ms
  2026-06-17 21:45:22 /health ...................................... ~ 0.09ms
  2026-06-17 21:45:32 /health ...................................... ~ 0.09ms
  2026-06-17 21:45:36 /health ...................................... ~ 0.10ms
  2026-06-17 21:45:42 /health ...................................... ~ 0.10ms
  2026-06-17 21:45:52 /health ...................................... ~ 0.08ms
  2026-06-17 21:45:56 /health ...................................... ~ 0.08ms
  2026-06-17 21:46:02 /health ...................................... ~ 0.09ms
  2026-06-17 21:46:12 /health ...................................... ~ 0.08ms
  2026-06-17 21:46:16 /health ...................................... ~ 0.07ms
  2026-06-17 21:46:22 /health ...................................... ~ 0.08ms
  2026-06-17 21:46:32 /health ...................................... ~ 0.09ms
  2026-06-17 21:46:36 /health ...................................... ~ 0.08ms
  2026-06-17 21:46:42 /health ...................................... ~ 0.08ms
  2026-06-17 21:46:52 /health ...................................... ~ 0.17ms
  2026-06-17 21:46:56 /health ...................................... ~ 0.10ms
  2026-06-17 21:47:02 /health ...................................... ~ 0.08ms
  2026-06-17 21:47:12 /health ...................................... ~ 0.08ms
  2026-06-17 21:47:16 /health ...................................... ~ 0.08ms
  2026-06-17 21:47:22 /health ...................................... ~ 0.07ms
  2026-06-17 21:47:32 /health ...................................... ~ 0.09ms
  2026-06-17 21:47:36 /health ...................................... ~ 0.07ms
  2026-06-17 21:47:42 /health ...................................... ~ 0.10ms
  2026-06-17 21:47:52 /health ...................................... ~ 0.07ms
  2026-06-17 21:47:56 /health ...................................... ~ 0.08ms
  2026-06-17 21:48:02 /health ...................................... ~ 0.08ms
  2026-06-17 21:48:12 /health ...................................... ~ 0.10ms
  2026-06-17 21:48:16 /health ...................................... ~ 0.10ms
  2026-06-17 21:48:22 /health ...................................... ~ 0.09ms
  2026-06-17 21:48:32 /health ...................................... ~ 0.08ms
  2026-06-17 21:48:36 /health ...................................... ~ 0.10ms
  2026-06-17 21:48:42 /health ...................................... ~ 0.10ms
  2026-06-17 21:48:52 /health ...................................... ~ 0.09ms
  2026-06-17 21:48:56 /health ...................................... ~ 0.08ms
  2026-06-17 21:49:02 /health ...................................... ~ 0.08ms
  2026-06-17 21:49:12 /health ...................................... ~ 0.08ms
  2026-06-17 21:49:16 /health ...................................... ~ 0.10ms
  2026-06-17 21:49:22 /health ...................................... ~ 0.10ms
  2026-06-17 21:49:32 /health ...................................... ~ 0.22ms
  2026-06-17 21:49:36 /health ...................................... ~ 0.18ms
  2026-06-17 21:49:42 /health ...................................... ~ 0.10ms
  2026-06-17 21:49:52 /health ...................................... ~ 0.10ms
  2026-06-17 21:49:56 /health ...................................... ~ 0.09ms
  2026-06-17 21:50:02 /health ...................................... ~ 0.15ms
  2026-06-17 21:50:12 /health ...................................... ~ 0.08ms
  2026-06-17 21:50:16 /health ...................................... ~ 0.08ms
  2026-06-17 21:50:22 /health ...................................... ~ 0.08ms
  2026-06-17 21:50:32 /health ...................................... ~ 0.08ms
  2026-06-17 21:50:36 /health ...................................... ~ 0.10ms
  2026-06-17 21:50:42 /health ...................................... ~ 0.10ms
  2026-06-17 21:50:52 /health ...................................... ~ 0.10ms
  2026-06-17 21:50:56 /health ...................................... ~ 0.10ms
  2026-06-17 21:51:02 /health ...................................... ~ 0.08ms
```

## Describe deployment/conversation-service

```text
Name:                   conversation-service
Namespace:              securerag-hub
CreationTimestamp:      Tue, 16 Jun 2026 10:42:21 +0200
Labels:                 app.kubernetes.io/part-of=securerag-hub
Annotations:            deployment.kubernetes.io/revision: 16
                        kube-score/ignore:
                          pod-probes, container-security-context-user-group-id, deployment-replicas, networkpolicy-targets-pod, container-image-pull-policy, pod-net...
Selector:               app.kubernetes.io/name=conversation-service,app.kubernetes.io/part-of=securerag-hub
Replicas:               1 desired | 1 updated | 1 total | 1 available | 0 unavailable
StrategyType:           RollingUpdate
MinReadySeconds:        0
RollingUpdateStrategy:  25% max unavailable, 25% max surge
Pod Template:
  Labels:           app.kubernetes.io/name=conversation-service
                    app.kubernetes.io/part-of=securerag-hub
  Annotations:      kube-score/ignore:
                      pod-probes, container-security-context-user-group-id, deployment-replicas, networkpolicy-targets-pod, container-image-pull-policy, pod-net...
                    kubectl.kubernetes.io/restartedAt: 2026-06-17T03:06:58+02:00
                    security.securerag.dev/internal-cleartext-justification: Internal ClusterIP service calls only; egress is restricted by NetworkPolicies.
                    security.securerag.dev/internal-cleartext-scope: cluster-only-networkpolicy
  Service Account:  sa-conversation-service
  Containers:
   conversation-service:
    Image:      localhost:5001/securerag-hub-conversation-service:demo
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
  Progressing    True    NewReplicaSetAvailable
  Available      True    MinimumReplicasAvailable
OldReplicaSets:  conversation-service-776d78c8b7 (0/0 replicas created), conversation-service-b7f9cdbd9 (0/0 replicas created), conversation-service-58c684679d (0/0 replicas created), conversation-service-75985585dc (0/0 replicas created), conversation-service-5867bd579d (0/0 replicas created), conversation-service-56996dc44 (0/0 replicas created), conversation-service-b474bdc88 (0/0 replicas created), conversation-service-59595d8bd5 (0/0 replicas created), conversation-service-87f9f8849 (0/0 replicas created), conversation-service-7cdbb854c9 (0/0 replicas created)
NewReplicaSet:   conversation-service-6556bc84fd (1/1 replicas created)
Events:          <none>
```

## Logs deployment/conversation-service

```text
  2026-06-17 21:37:52 /health ...................................... ~ 0.07ms
  2026-06-17 21:37:56 /health ...................................... ~ 0.10ms
  2026-06-17 21:38:02 /health ...................................... ~ 0.10ms
  2026-06-17 21:38:12 /health ...................................... ~ 0.09ms
  2026-06-17 21:38:16 /health ...................................... ~ 0.08ms
  2026-06-17 21:38:22 /health ...................................... ~ 0.08ms
  2026-06-17 21:38:32 /health ...................................... ~ 0.12ms
  2026-06-17 21:38:36 /health ...................................... ~ 0.08ms
  2026-06-17 21:38:42 /health ...................................... ~ 0.08ms
  2026-06-17 21:38:52 /health ...................................... ~ 0.10ms
  2026-06-17 21:38:56 /health ...................................... ~ 0.11ms
  2026-06-17 21:39:02 /health ...................................... ~ 0.10ms
  2026-06-17 21:39:12 /health ...................................... ~ 0.08ms
  2026-06-17 21:39:16 /health ...................................... ~ 0.09ms
  2026-06-17 21:39:22 /health ...................................... ~ 0.10ms
  2026-06-17 21:39:32 /health ...................................... ~ 0.10ms
  2026-06-17 21:39:36 /health ...................................... ~ 0.10ms
  2026-06-17 21:39:42 /health ...................................... ~ 0.08ms
  2026-06-17 21:39:52 /health ...................................... ~ 0.10ms
  2026-06-17 21:39:56 /health ...................................... ~ 0.10ms
  2026-06-17 21:40:02 /health ...................................... ~ 0.09ms
  2026-06-17 21:40:12 /health ...................................... ~ 0.12ms
  2026-06-17 21:40:16 /health ...................................... ~ 0.08ms
  2026-06-17 21:40:22 /health ...................................... ~ 0.07ms
  2026-06-17 21:40:32 /health ...................................... ~ 0.15ms
  2026-06-17 21:40:36 /health ...................................... ~ 0.07ms
  2026-06-17 21:40:42 /health ...................................... ~ 0.10ms
  2026-06-17 21:40:52 /health ...................................... ~ 0.11ms
  2026-06-17 21:40:56 /health ...................................... ~ 0.08ms
  2026-06-17 21:41:02 /health ...................................... ~ 0.11ms
  2026-06-17 21:41:12 /health ...................................... ~ 0.10ms
  2026-06-17 21:41:16 /health ...................................... ~ 0.10ms
  2026-06-17 21:41:22 /health ...................................... ~ 0.09ms
  2026-06-17 21:41:32 /health ...................................... ~ 0.07ms
  2026-06-17 21:41:36 /health ...................................... ~ 0.08ms
  2026-06-17 21:41:42 /health ...................................... ~ 0.08ms
  2026-06-17 21:41:52 /health ...................................... ~ 0.07ms
  2026-06-17 21:41:56 /health ...................................... ~ 0.10ms
  2026-06-17 21:42:02 /health ...................................... ~ 0.10ms
  2026-06-17 21:42:12 /health ...................................... ~ 0.10ms
  2026-06-17 21:42:16 /health ...................................... ~ 0.08ms
  2026-06-17 21:42:22 /health ...................................... ~ 0.08ms
  2026-06-17 21:42:32 /health ...................................... ~ 0.09ms
  2026-06-17 21:42:36 /health ...................................... ~ 0.07ms
  2026-06-17 21:42:42 /health ...................................... ~ 0.07ms
  2026-06-17 21:42:52 /health ...................................... ~ 0.18ms
  2026-06-17 21:42:56 /health ...................................... ~ 0.10ms
  2026-06-17 21:43:02 /health ...................................... ~ 0.10ms
  2026-06-17 21:43:12 /health ...................................... ~ 0.08ms
  2026-06-17 21:43:16 /health ...................................... ~ 0.08ms
  2026-06-17 21:43:22 /health ...................................... ~ 0.08ms
  2026-06-17 21:43:32 /health ...................................... ~ 0.07ms
  2026-06-17 21:43:36 /health ...................................... ~ 0.08ms
  2026-06-17 21:43:42 /health ...................................... ~ 0.12ms
  2026-06-17 21:43:52 /health ...................................... ~ 0.08ms
  2026-06-17 21:43:56 /health ...................................... ~ 0.08ms
  2026-06-17 21:44:02 /health ...................................... ~ 0.08ms
  2026-06-17 21:44:12 /health ...................................... ~ 0.07ms
  2026-06-17 21:44:16 /health ...................................... ~ 0.12ms
  2026-06-17 21:44:22 /health ...................................... ~ 0.10ms
  2026-06-17 21:44:32 /health ...................................... ~ 0.09ms
  2026-06-17 21:44:36 /health ...................................... ~ 0.09ms
  2026-06-17 21:44:42 /health ...................................... ~ 0.07ms
  2026-06-17 21:44:52 /health ...................................... ~ 0.07ms
  2026-06-17 21:44:56 /health ...................................... ~ 0.13ms
  2026-06-17 21:45:02 /health ...................................... ~ 0.08ms
  2026-06-17 21:45:12 /health ...................................... ~ 0.10ms
  2026-06-17 21:45:16 /health ...................................... ~ 0.08ms
  2026-06-17 21:45:22 /health ...................................... ~ 0.08ms
  2026-06-17 21:45:32 /health ...................................... ~ 0.10ms
  2026-06-17 21:45:36 /health ...................................... ~ 0.10ms
  2026-06-17 21:45:42 /health ...................................... ~ 0.09ms
  2026-06-17 21:45:52 /health ...................................... ~ 0.08ms
  2026-06-17 21:45:56 /health ...................................... ~ 0.14ms
  2026-06-17 21:46:02 /health ...................................... ~ 0.08ms
  2026-06-17 21:46:12 /health ...................................... ~ 0.07ms
  2026-06-17 21:46:16 /health ...................................... ~ 0.08ms
  2026-06-17 21:46:22 /health ...................................... ~ 0.08ms
  2026-06-17 21:46:32 /health ...................................... ~ 0.08ms
  2026-06-17 21:46:36 /health ...................................... ~ 0.10ms
  2026-06-17 21:46:42 /health ...................................... ~ 0.10ms
  2026-06-17 21:46:52 /health ...................................... ~ 0.09ms
  2026-06-17 21:46:56 /health ...................................... ~ 0.07ms
  2026-06-17 21:47:02 /health ...................................... ~ 0.08ms
  2026-06-17 21:47:12 /health ...................................... ~ 0.08ms
  2026-06-17 21:47:16 /health ...................................... ~ 0.08ms
  2026-06-17 21:47:22 /health ...................................... ~ 0.08ms
  2026-06-17 21:47:32 /health ...................................... ~ 0.08ms
  2026-06-17 21:47:36 /health ...................................... ~ 0.10ms
  2026-06-17 21:47:42 /health ...................................... ~ 0.07ms
  2026-06-17 21:47:52 /health ...................................... ~ 0.09ms
  2026-06-17 21:47:56 /health ...................................... ~ 0.08ms
  2026-06-17 21:48:02 /health ...................................... ~ 0.10ms
  2026-06-17 21:48:12 /health ...................................... ~ 0.07ms
  2026-06-17 21:48:16 /health ...................................... ~ 0.07ms
  2026-06-17 21:48:22 /health ...................................... ~ 0.08ms
  2026-06-17 21:48:32 /health ...................................... ~ 0.08ms
  2026-06-17 21:48:36 /health ...................................... ~ 0.08ms
  2026-06-17 21:48:42 /health ...................................... ~ 0.09ms
  2026-06-17 21:48:52 /health ...................................... ~ 0.08ms
  2026-06-17 21:48:56 /health ...................................... ~ 0.08ms
  2026-06-17 21:49:02 /health ...................................... ~ 0.09ms
  2026-06-17 21:49:12 /health ...................................... ~ 0.10ms
  2026-06-17 21:49:16 /health ...................................... ~ 0.10ms
  2026-06-17 21:49:22 /health ...................................... ~ 0.32ms
  2026-06-17 21:49:32 /health ...................................... ~ 0.10ms
  2026-06-17 21:49:36 /health ...................................... ~ 0.08ms
  2026-06-17 21:49:42 /health ...................................... ~ 0.10ms
  2026-06-17 21:49:52 /health .................................... ~ 500.29ms
  2026-06-17 21:49:56 /health ...................................... ~ 0.10ms
  2026-06-17 21:50:02 /health .................................... ~ 500.31ms
  2026-06-17 21:50:12 /health .................................... ~ 500.37ms
  2026-06-17 21:50:16 /health ...................................... ~ 0.09ms
  2026-06-17 21:50:22 /health ...................................... ~ 0.07ms
  2026-06-17 21:50:32 /health ...................................... ~ 0.11ms
  2026-06-17 21:50:36 /health ...................................... ~ 0.08ms
  2026-06-17 21:50:42 /health ...................................... ~ 0.08ms
  2026-06-17 21:50:52 /health ...................................... ~ 0.09ms
  2026-06-17 21:50:56 /health ...................................... ~ 0.11ms
  2026-06-17 21:51:02 /health ...................................... ~ 0.10ms
```

## Describe deployment/audit-security-service

```text
Name:                   audit-security-service
Namespace:              securerag-hub
CreationTimestamp:      Tue, 16 Jun 2026 10:42:21 +0200
Labels:                 app.kubernetes.io/part-of=securerag-hub
Annotations:            deployment.kubernetes.io/revision: 16
                        kube-score/ignore:
                          pod-probes, container-security-context-user-group-id, deployment-replicas, networkpolicy-targets-pod, container-image-pull-policy, pod-net...
Selector:               app.kubernetes.io/name=audit-security-service,app.kubernetes.io/part-of=securerag-hub
Replicas:               1 desired | 1 updated | 1 total | 1 available | 0 unavailable
StrategyType:           RollingUpdate
MinReadySeconds:        0
RollingUpdateStrategy:  25% max unavailable, 25% max surge
Pod Template:
  Labels:           app.kubernetes.io/name=audit-security-service
                    app.kubernetes.io/part-of=securerag-hub
  Annotations:      kube-score/ignore:
                      pod-probes, container-security-context-user-group-id, deployment-replicas, networkpolicy-targets-pod, container-image-pull-policy, pod-net...
                    kubectl.kubernetes.io/restartedAt: 2026-06-17T03:06:58+02:00
                    security.securerag.dev/internal-cleartext-justification: Internal ClusterIP service calls only; egress is restricted by NetworkPolicies.
                    security.securerag.dev/internal-cleartext-scope: cluster-only-networkpolicy
  Service Account:  sa-audit-security-service
  Containers:
   audit-security-service:
    Image:      localhost:5001/securerag-hub-audit-security-service:demo
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
  Progressing    True    NewReplicaSetAvailable
  Available      True    MinimumReplicasAvailable
OldReplicaSets:  audit-security-service-5b66576f9d (0/0 replicas created), audit-security-service-f5c444568 (0/0 replicas created), audit-security-service-5bfb5d946c (0/0 replicas created), audit-security-service-6b48d76454 (0/0 replicas created), audit-security-service-7b69fcc847 (0/0 replicas created), audit-security-service-5d77466d5 (0/0 replicas created), audit-security-service-7656b75df8 (0/0 replicas created), audit-security-service-74955f88 (0/0 replicas created), audit-security-service-64c76646b4 (0/0 replicas created), audit-security-service-795f6b578c (0/0 replicas created)
NewReplicaSet:   audit-security-service-9ff7f9ddc (1/1 replicas created)
Events:          <none>
```

## Logs deployment/audit-security-service

```text
  2026-06-17 21:37:51 /health ...................................... ~ 0.08ms
  2026-06-17 21:37:56 /health ...................................... ~ 0.08ms
  2026-06-17 21:38:01 /health ...................................... ~ 0.16ms
  2026-06-17 21:38:11 /health ...................................... ~ 0.08ms
  2026-06-17 21:38:16 /health ...................................... ~ 0.15ms
  2026-06-17 21:38:21 /health ...................................... ~ 0.09ms
  2026-06-17 21:38:31 /health ...................................... ~ 0.09ms
  2026-06-17 21:38:36 /health ...................................... ~ 0.07ms
  2026-06-17 21:38:41 /health ...................................... ~ 0.09ms
  2026-06-17 21:38:51 /health ...................................... ~ 0.08ms
  2026-06-17 21:38:56 /health ...................................... ~ 0.10ms
  2026-06-17 21:39:01 /health ...................................... ~ 0.09ms
  2026-06-17 21:39:11 /health ...................................... ~ 0.09ms
  2026-06-17 21:39:16 /health ...................................... ~ 0.08ms
  2026-06-17 21:39:21 /health ...................................... ~ 0.09ms
  2026-06-17 21:39:31 /health ...................................... ~ 0.09ms
  2026-06-17 21:39:36 /health ...................................... ~ 0.09ms
  2026-06-17 21:39:41 /health ...................................... ~ 0.13ms
  2026-06-17 21:39:51 /health ...................................... ~ 0.08ms
  2026-06-17 21:39:56 /health ...................................... ~ 0.08ms
  2026-06-17 21:40:01 /health ...................................... ~ 0.10ms
  2026-06-17 21:40:11 /health ...................................... ~ 0.08ms
  2026-06-17 21:40:16 /health ...................................... ~ 0.08ms
  2026-06-17 21:40:21 /health ...................................... ~ 0.09ms
  2026-06-17 21:40:31 /health ...................................... ~ 0.10ms
  2026-06-17 21:40:36 /health ...................................... ~ 0.07ms
  2026-06-17 21:40:41 /health ...................................... ~ 0.09ms
  2026-06-17 21:40:51 /health ...................................... ~ 0.10ms
  2026-06-17 21:40:56 /health ...................................... ~ 0.10ms
  2026-06-17 21:41:01 /health ...................................... ~ 0.07ms
  2026-06-17 21:41:11 /health ...................................... ~ 0.07ms
  2026-06-17 21:41:16 /health ...................................... ~ 0.10ms
  2026-06-17 21:41:21 /health ...................................... ~ 0.14ms
  2026-06-17 21:41:31 /health ...................................... ~ 0.08ms
  2026-06-17 21:41:36 /health ...................................... ~ 0.08ms
  2026-06-17 21:41:41 /health ...................................... ~ 0.12ms
  2026-06-17 21:41:51 /health ...................................... ~ 0.09ms
  2026-06-17 21:41:56 /health ...................................... ~ 0.08ms
  2026-06-17 21:42:01 /health ...................................... ~ 0.09ms
  2026-06-17 21:42:11 /health ...................................... ~ 0.08ms
  2026-06-17 21:42:16 /health ...................................... ~ 0.07ms
  2026-06-17 21:42:21 /health ...................................... ~ 0.08ms
  2026-06-17 21:42:31 /health ...................................... ~ 0.09ms
  2026-06-17 21:42:36 /health ...................................... ~ 0.08ms
  2026-06-17 21:42:41 /health ...................................... ~ 0.08ms
  2026-06-17 21:42:51 /health ...................................... ~ 0.13ms
  2026-06-17 21:42:56 /health ...................................... ~ 0.08ms
  2026-06-17 21:43:01 /health ...................................... ~ 0.10ms
  2026-06-17 21:43:11 /health ...................................... ~ 0.10ms
  2026-06-17 21:43:16 /health ...................................... ~ 0.09ms
  2026-06-17 21:43:21 /health ...................................... ~ 0.09ms
  2026-06-17 21:43:31 /health ...................................... ~ 0.08ms
  2026-06-17 21:43:36 /health ...................................... ~ 0.08ms
  2026-06-17 21:43:41 /health ...................................... ~ 0.11ms
  2026-06-17 21:43:51 /health ...................................... ~ 0.08ms
  2026-06-17 21:43:56 /health ...................................... ~ 0.10ms
  2026-06-17 21:44:01 /health ...................................... ~ 0.08ms
  2026-06-17 21:44:11 /health ...................................... ~ 0.09ms
  2026-06-17 21:44:16 /health ...................................... ~ 0.08ms
  2026-06-17 21:44:21 /health ...................................... ~ 0.11ms
  2026-06-17 21:44:31 /health ...................................... ~ 0.08ms
  2026-06-17 21:44:36 /health ...................................... ~ 0.07ms
  2026-06-17 21:44:41 /health ...................................... ~ 0.08ms
  2026-06-17 21:44:51 /health ...................................... ~ 0.11ms
  2026-06-17 21:44:56 /health ...................................... ~ 0.08ms
  2026-06-17 21:45:01 /health ...................................... ~ 0.08ms
  2026-06-17 21:45:11 /health ...................................... ~ 0.07ms
  2026-06-17 21:45:16 /health ...................................... ~ 0.13ms
  2026-06-17 21:45:21 /health ...................................... ~ 0.07ms
  2026-06-17 21:45:31 /health ...................................... ~ 0.07ms
  2026-06-17 21:45:36 /health ...................................... ~ 0.16ms
  2026-06-17 21:45:41 /health ...................................... ~ 0.08ms
  2026-06-17 21:45:51 /health ...................................... ~ 0.09ms
  2026-06-17 21:45:56 /health ...................................... ~ 0.15ms
  2026-06-17 21:46:01 /health .................................... ~ 500.33ms
  2026-06-17 21:46:11 /health .................................... ~ 500.28ms
  2026-06-17 21:46:16 /health ...................................... ~ 0.08ms
  2026-06-17 21:46:21 /health .................................... ~ 500.32ms
  2026-06-17 21:46:31 /health ...................................... ~ 0.08ms
  2026-06-17 21:46:36 /health ...................................... ~ 0.15ms
  2026-06-17 21:46:41 /health ...................................... ~ 0.09ms
  2026-06-17 21:46:51 /health ...................................... ~ 0.11ms
  2026-06-17 21:46:56 /health ...................................... ~ 0.09ms
  2026-06-17 21:47:01 /health ...................................... ~ 0.09ms
  2026-06-17 21:47:11 /health ...................................... ~ 0.10ms
  2026-06-17 21:47:16 /health ...................................... ~ 0.10ms
  2026-06-17 21:47:21 /health ...................................... ~ 0.08ms
  2026-06-17 21:47:31 /health ...................................... ~ 0.10ms
  2026-06-17 21:47:36 /health ...................................... ~ 0.10ms
  2026-06-17 21:47:41 /health ...................................... ~ 0.13ms
  2026-06-17 21:47:51 /health ...................................... ~ 0.08ms
  2026-06-17 21:47:56 /health ...................................... ~ 0.09ms
  2026-06-17 21:48:01 /health ...................................... ~ 0.10ms
  2026-06-17 21:48:11 /health ...................................... ~ 0.09ms
  2026-06-17 21:48:16 /health ...................................... ~ 0.09ms
  2026-06-17 21:48:21 /health ...................................... ~ 0.07ms
  2026-06-17 21:48:31 /health ...................................... ~ 0.10ms
  2026-06-17 21:48:36 /health ...................................... ~ 0.09ms
  2026-06-17 21:48:41 /health ...................................... ~ 0.08ms
  2026-06-17 21:48:51 /health ...................................... ~ 0.09ms
  2026-06-17 21:48:56 /health ...................................... ~ 0.09ms
  2026-06-17 21:49:01 /health ...................................... ~ 0.08ms
  2026-06-17 21:49:11 /health ...................................... ~ 0.09ms
  2026-06-17 21:49:16 /health ...................................... ~ 0.11ms
  2026-06-17 21:49:21 /health ...................................... ~ 0.09ms
  2026-06-17 21:49:31 /health ...................................... ~ 0.12ms
  2026-06-17 21:49:36 /health ...................................... ~ 0.08ms
  2026-06-17 21:49:41 /health ...................................... ~ 0.10ms
  2026-06-17 21:49:51 /health ...................................... ~ 0.08ms
  2026-06-17 21:49:56 /health ...................................... ~ 0.09ms
  2026-06-17 21:50:01 /health ...................................... ~ 0.15ms
  2026-06-17 21:50:11 /health ...................................... ~ 0.13ms
  2026-06-17 21:50:16 /health ...................................... ~ 0.10ms
  2026-06-17 21:50:21 /health ...................................... ~ 0.08ms
  2026-06-17 21:50:31 /health ...................................... ~ 0.08ms
  2026-06-17 21:50:36 /health ...................................... ~ 0.08ms
  2026-06-17 21:50:41 /health ...................................... ~ 0.09ms
  2026-06-17 21:50:51 /health ...................................... ~ 0.08ms
  2026-06-17 21:50:56 /health ...................................... ~ 0.09ms
  2026-06-17 21:51:01 /health ...................................... ~ 0.14ms
```

## Reading guide

- `TERMINÉ` means the runtime command succeeded in the current cluster.
- `PARTIEL` means the Kubernetes object is missing or incomplete.
- `DÉPENDANT_DE_L_ENVIRONNEMENT` means an active cluster, metrics-server or kubeconfig is required.
- This script is read-only and does not install, patch, delete or restart any workload.
