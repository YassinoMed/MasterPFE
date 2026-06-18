# Production Cluster Clean Evidence - SecureRAG Hub

- Generated at UTC: `2026-06-17T21:39:32Z`
- Overlay: `infra/k8s/overlays/production`
- Namespace: `securerag-hub`
- Static-only mode: `false`

| Component | Check | Status | Evidence |
|---|---|---:|---|
| `portal-web` | official Deployment rendered | TERMINÉ | Deployment present |
| `auth-users` | official Deployment rendered | TERMINÉ | Deployment present |
| `chatbot-manager` | official Deployment rendered | TERMINÉ | Deployment present |
| `conversation-service` | official Deployment rendered | TERMINÉ | Deployment present |
| `audit-security-service` | official Deployment rendered | TERMINÉ | Deployment present |
| `api-gateway` | excluded from production render | TERMINÉ | not rendered |
| `knowledge-hub` | excluded from production render | TERMINÉ | not rendered |
| `llm-orchestrator` | excluded from production render | TERMINÉ | not rendered |
| `ollama` | excluded from production render | TERMINÉ | not rendered |
| `qdrant` | excluded from production render | TERMINÉ | not rendered |
| `security-auditor` | excluded from production render | TERMINÉ | not rendered |
| `portal-web` | official production exposure | TERMINÉ | type=NodePort, nodePort=30081 |
| Kubernetes API | runtime proof | TERMINÉ | API server reachable |
| `portal-web` | replicas Ready | TERMINÉ | ready=1/1 |
| `auth-users` | replicas Ready | TERMINÉ | ready=1/1 |
| `chatbot-manager` | replicas Ready | TERMINÉ | ready=1/1 |
| `conversation-service` | replicas Ready | TERMINÉ | ready=1/1 |
| `audit-security-service` | replicas Ready | TERMINÉ | ready=1/1 |
| legacy runtime | absent from namespace | TERMINÉ | no legacy objects detected |
| legacy PVCs | absent from namespace | TERMINÉ | no legacy PVC detected |
| `portal-web` | runtime exposure | TERMINÉ | type=NodePort, nodePort=30081 |
| Nodes | all Ready | TERMINÉ | all nodes report Ready |

## Kubernetes context

```text
kind-securerag-dev
```

## Nodes

```text
NAME                          STATUS   ROLES           AGE   VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE                         KERNEL-VERSION      CONTAINER-RUNTIME
securerag-dev-control-plane   Ready    control-plane   36h   v1.33.1   172.18.0.5    <none>        Debian GNU/Linux 12 (bookworm)   6.8.0-124-generic   containerd://2.1.1
securerag-dev-worker          Ready    <none>          36h   v1.33.1   172.18.0.2    <none>        Debian GNU/Linux 12 (bookworm)   6.8.0-124-generic   containerd://2.1.1
```

## Namespace runtime inventory

```text
NAME                                     READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS               IMAGES                                                     SELECTOR
deployment.apps/audit-security-service   1/1     1            1           36h   audit-security-service   localhost:5001/securerag-hub-audit-security-service:demo   app.kubernetes.io/name=audit-security-service,app.kubernetes.io/part-of=securerag-hub
deployment.apps/auth-users               1/1     1            1           36h   auth-users               localhost:5001/securerag-hub-auth-users:demo               app.kubernetes.io/name=auth-users,app.kubernetes.io/part-of=securerag-hub
deployment.apps/chatbot-manager          1/1     1            1           36h   chatbot-manager          localhost:5001/securerag-hub-chatbot-manager:demo          app.kubernetes.io/name=chatbot-manager,app.kubernetes.io/part-of=securerag-hub
deployment.apps/conversation-service     1/1     1            1           36h   conversation-service     localhost:5001/securerag-hub-conversation-service:demo     app.kubernetes.io/name=conversation-service,app.kubernetes.io/part-of=securerag-hub
deployment.apps/portal-web               1/1     1            1           36h   portal-web               localhost:5001/securerag-hub-portal-web:demo               app.kubernetes.io/name=portal-web,app.kubernetes.io/part-of=securerag-hub
deployment.apps/postgres-auth            0/1     0            0           36h   postgres-auth            postgres:16-alpine                                         app.kubernetes.io/name=postgres-auth,app.kubernetes.io/part-of=securerag-hub

NAME                             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE   SELECTOR
service/audit-security-service   ClusterIP   10.96.203.13    <none>        8000/TCP         36h   app.kubernetes.io/name=audit-security-service,app.kubernetes.io/part-of=securerag-hub
service/auth-users               ClusterIP   10.96.249.47    <none>        8000/TCP         36h   app.kubernetes.io/name=auth-users,app.kubernetes.io/part-of=securerag-hub
service/chatbot-manager          ClusterIP   10.96.205.74    <none>        8000/TCP         36h   app.kubernetes.io/name=chatbot-manager,app.kubernetes.io/part-of=securerag-hub
service/conversation-service     ClusterIP   10.96.183.193   <none>        8000/TCP         36h   app.kubernetes.io/name=conversation-service,app.kubernetes.io/part-of=securerag-hub
service/portal-web               NodePort    10.96.107.28    <none>        8000:30081/TCP   36h   app.kubernetes.io/name=portal-web,app.kubernetes.io/part-of=securerag-hub
service/postgres-auth            ClusterIP   10.96.143.14    <none>        5432/TCP         36h   app.kubernetes.io/name=postgres-auth,app.kubernetes.io/part-of=securerag-hub

NAME                                                    MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
poddisruptionbudget.policy/audit-security-service-pdb   1               N/A               0                     36h
poddisruptionbudget.policy/auth-users-pdb               1               N/A               0                     36h
poddisruptionbudget.policy/chatbot-manager-pdb          1               N/A               0                     36h
poddisruptionbudget.policy/conversation-service-pdb     1               N/A               0                     36h
poddisruptionbudget.policy/portal-web-pdb               1               N/A               0                     36h

NAME                                             REFERENCE               TARGETS       MINPODS   MAXPODS   REPLICAS   AGE
horizontalpodautoscaler.autoscaling/portal-web   Deployment/portal-web   cpu: 2%/70%   1         3         1          36h
```

## Pods

```text
NAME                                     READY   STATUS    RESTARTS   AGE   IP             NODE                   NOMINATED NODE   READINESS GATES
audit-security-service-9ff7f9ddc-km222   1/1     Running   0          20h   10.244.1.175   securerag-dev-worker   <none>           <none>
auth-users-6f6b795bc4-xk9x5              1/1     Running   0          9h    10.244.1.188   securerag-dev-worker   <none>           <none>
chatbot-manager-58d7f6849b-62rdm         1/1     Running   0          20h   10.244.1.177   securerag-dev-worker   <none>           <none>
conversation-service-6556bc84fd-n75n4    1/1     Running   0          20h   10.244.1.178   securerag-dev-worker   <none>           <none>
portal-web-c99d94df-tgk7n                1/1     Running   0          9h    10.244.1.187   securerag-dev-worker   <none>           <none>
```

## Legacy runtime inventory

```text
NAME                                     READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/audit-security-service   1/1     1            1           36h
deployment.apps/auth-users               1/1     1            1           36h
deployment.apps/chatbot-manager          1/1     1            1           36h
deployment.apps/conversation-service     1/1     1            1           36h
deployment.apps/portal-web               1/1     1            1           36h
deployment.apps/postgres-auth            0/1     0            0           36h

NAME                             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
service/audit-security-service   ClusterIP   10.96.203.13    <none>        8000/TCP         36h
service/auth-users               ClusterIP   10.96.249.47    <none>        8000/TCP         36h
service/chatbot-manager          ClusterIP   10.96.205.74    <none>        8000/TCP         36h
service/conversation-service     ClusterIP   10.96.183.193   <none>        8000/TCP         36h
service/portal-web               NodePort    10.96.107.28    <none>        8000:30081/TCP   36h
service/postgres-auth            ClusterIP   10.96.143.14    <none>        5432/TCP         36h

NAME                                             REFERENCE               TARGETS       MINPODS   MAXPODS   REPLICAS   AGE
horizontalpodautoscaler.autoscaling/portal-web   Deployment/portal-web   cpu: 2%/70%   1         3         1          36h

NAME                                                    MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
poddisruptionbudget.policy/audit-security-service-pdb   1               N/A               0                     36h
poddisruptionbudget.policy/auth-users-pdb               1               N/A               0                     36h
poddisruptionbudget.policy/chatbot-manager-pdb          1               N/A               0                     36h
poddisruptionbudget.policy/conversation-service-pdb     1               N/A               0                     36h
poddisruptionbudget.policy/portal-web-pdb               1               N/A               0                     36h

NAME                                                             POD-SELECTOR                                                                                                    AGE
networkpolicy.networking.k8s.io/allow-dns-egress                 <none>                                                                                                          36h
networkpolicy.networking.k8s.io/allow-validation-egress          app.kubernetes.io/part-of=securerag-hub,job-role=validation                                                     36h
networkpolicy.networking.k8s.io/allow-validation-ingress         app.kubernetes.io/name in (audit-security-service,auth-users,chatbot-manager,conversation-service,portal-web)   36h
networkpolicy.networking.k8s.io/audit-security-service-network   app.kubernetes.io/name=audit-security-service,app.kubernetes.io/part-of=securerag-hub                           36h
networkpolicy.networking.k8s.io/auth-users-policy                app.kubernetes.io/name=auth-users,app.kubernetes.io/part-of=securerag-hub                                       36h
networkpolicy.networking.k8s.io/chatbot-manager-policy           app.kubernetes.io/name=chatbot-manager,app.kubernetes.io/part-of=securerag-hub                                  36h
networkpolicy.networking.k8s.io/conversation-service-network     app.kubernetes.io/name=conversation-service,app.kubernetes.io/part-of=securerag-hub                             36h
networkpolicy.networking.k8s.io/default-deny-all                 <none>                                                                                                          36h
networkpolicy.networking.k8s.io/portal-web-policy                app.kubernetes.io/name=portal-web,app.kubernetes.io/part-of=securerag-hub                                       36h
networkpolicy.networking.k8s.io/postgres-auth-policy             app.kubernetes.io/name=postgres-auth,app.kubernetes.io/part-of=securerag-hub                                    36h

NAME                                       SECRETS   AGE
serviceaccount/default                     0         36h
serviceaccount/sa-audit-security-service   0         36h
serviceaccount/sa-auth-users               0         36h
serviceaccount/sa-chatbot-manager          0         36h
serviceaccount/sa-conversation-service     0         36h
serviceaccount/sa-portal-web               0         36h
serviceaccount/sa-postgres-auth            0         36h
serviceaccount/sa-validation               0         36h
```

## Reading guide

- `TERMINÉ` means the static or runtime control succeeded.
- `PARTIEL` means the cluster answered but the production-only runtime is not clean or not fully Ready.
- `DÉPENDANT_DE_L_ENVIRONNEMENT` means no active Kubernetes API or namespace was available.
- `PRÊT_NON_EXÉCUTÉ` means the validation was intentionally limited to static rendering.
