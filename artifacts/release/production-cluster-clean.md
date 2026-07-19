# Production Cluster Clean Evidence - SecureRAG Hub

- Generated at UTC: `2026-07-18T13:11:48Z`
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
| `portal-web` | replicas Ready | PARTIEL | ready=0/2 |
| `auth-users` | replicas Ready | PARTIEL | ready=1/3 |
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
securerag-dev-control-plane   Ready    control-plane   24d   v1.33.1   172.18.0.2    <none>        Debian GNU/Linux 12 (bookworm)   6.8.0-124-generic   containerd://2.1.1
securerag-dev-worker          Ready    <none>          24d   v1.33.1   172.18.0.3    <none>        Debian GNU/Linux 12 (bookworm)   6.8.0-124-generic   containerd://2.1.1
```

## Namespace runtime inventory

```text
NAME                                     READY   UP-TO-DATE   AVAILABLE   AGE     CONTAINERS               IMAGES                                                     SELECTOR
deployment.apps/audit-security-service   1/1     1            1           24d     audit-security-service   localhost:5001/securerag-hub-audit-security-service:demo   app.kubernetes.io/name=audit-security-service,app.kubernetes.io/part-of=securerag-hub
deployment.apps/auth-users               1/3     1            1           7d14h   auth-users               localhost:5001/securerag-hub-auth-users:demo               app.kubernetes.io/name=auth-users,app.kubernetes.io/part-of=securerag-hub
deployment.apps/chatbot-manager          1/1     1            1           24d     chatbot-manager          localhost:5001/securerag-hub-chatbot-manager:demo          app.kubernetes.io/name=chatbot-manager,app.kubernetes.io/part-of=securerag-hub
deployment.apps/conversation-service     1/1     1            1           24d     conversation-service     localhost:5001/securerag-hub-conversation-service:demo     app.kubernetes.io/name=conversation-service,app.kubernetes.io/part-of=securerag-hub
deployment.apps/portal-web               0/2     1            0           24d     portal-web               localhost:5001/securerag-hub-portal-web:demo               app.kubernetes.io/name=portal-web,app.kubernetes.io/part-of=securerag-hub
deployment.apps/postgres-auth            1/1     1            1           24d     postgres-auth            localhost:5001/postgres:16-alpine                          app.kubernetes.io/name=postgres-auth,app.kubernetes.io/part-of=securerag-hub

NAME                             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE   SELECTOR
service/audit-security-service   ClusterIP   10.96.104.151   <none>        8000/TCP         24d   app.kubernetes.io/name=audit-security-service,app.kubernetes.io/part-of=securerag-hub
service/auth-users               ClusterIP   10.96.139.68    <none>        8000/TCP         24d   app.kubernetes.io/name=auth-users,app.kubernetes.io/part-of=securerag-hub
service/chatbot-manager          ClusterIP   10.96.189.113   <none>        8000/TCP         24d   app.kubernetes.io/name=chatbot-manager,app.kubernetes.io/part-of=securerag-hub
service/conversation-service     ClusterIP   10.96.192.110   <none>        8000/TCP         24d   app.kubernetes.io/name=conversation-service,app.kubernetes.io/part-of=securerag-hub
service/portal-web               NodePort    10.96.193.87    <none>        8000:30081/TCP   24d   app.kubernetes.io/name=portal-web,app.kubernetes.io/part-of=securerag-hub
service/postgres-auth            ClusterIP   10.96.110.118   <none>        5432/TCP         24d   app.kubernetes.io/name=postgres-auth,app.kubernetes.io/part-of=securerag-hub

NAME                                                    MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
poddisruptionbudget.policy/audit-security-service-pdb   1               N/A               0                     24d
poddisruptionbudget.policy/auth-users-pdb               1               N/A               0                     24d
poddisruptionbudget.policy/chatbot-manager-pdb          1               N/A               0                     24d
poddisruptionbudget.policy/conversation-service-pdb     1               N/A               0                     24d
poddisruptionbudget.policy/portal-web-pdb               1               N/A               0                     24d

NAME                                             REFERENCE               TARGETS              MINPODS   MAXPODS   REPLICAS   AGE
horizontalpodautoscaler.autoscaling/portal-web   Deployment/portal-web   cpu: <unknown>/70%   1         3         2          24d
```

## Pods

```text
NAME                                      READY   STATUS    RESTARTS      AGE     IP             NODE                   NOMINATED NODE   READINESS GATES
audit-security-service-5dc8b86497-srmhp   1/1     Running   1 (44h ago)   7d5h    10.244.0.96    securerag-dev-worker   <none>           <none>
auth-users-557c884c45-skbzz               1/1     Running   1 (44h ago)   7d5h    10.244.0.174   securerag-dev-worker   <none>           <none>
chatbot-manager-5c868487d8-gh4sv          1/1     Running   1 (44h ago)   7d5h    10.244.0.251   securerag-dev-worker   <none>           <none>
conversation-service-7678f59b49-fqg8b     1/1     Running   1 (44h ago)   7d5h    10.244.0.116   securerag-dev-worker   <none>           <none>
portal-web-84bd8bb87c-fm7sj               0/1     Running   60            7d14h   10.244.0.137   securerag-dev-worker   <none>           <none>
postgres-auth-fbf55db78-kwlh4             1/1     Running   1 (44h ago)   23d     10.244.0.202   securerag-dev-worker   <none>           <none>
```

## Legacy runtime inventory

```text
NAME                                     READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/audit-security-service   1/1     1            1           24d
deployment.apps/auth-users               1/3     1            1           7d14h
deployment.apps/chatbot-manager          1/1     1            1           24d
deployment.apps/conversation-service     1/1     1            1           24d
deployment.apps/portal-web               0/2     1            0           24d
deployment.apps/postgres-auth            1/1     1            1           24d

NAME                             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
service/audit-security-service   ClusterIP   10.96.104.151   <none>        8000/TCP         24d
service/auth-users               ClusterIP   10.96.139.68    <none>        8000/TCP         24d
service/chatbot-manager          ClusterIP   10.96.189.113   <none>        8000/TCP         24d
service/conversation-service     ClusterIP   10.96.192.110   <none>        8000/TCP         24d
service/portal-web               NodePort    10.96.193.87    <none>        8000:30081/TCP   24d
service/postgres-auth            ClusterIP   10.96.110.118   <none>        5432/TCP         24d

NAME                                             REFERENCE               TARGETS              MINPODS   MAXPODS   REPLICAS   AGE
horizontalpodautoscaler.autoscaling/portal-web   Deployment/portal-web   cpu: <unknown>/70%   1         3         2          24d

NAME                                                    MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
poddisruptionbudget.policy/audit-security-service-pdb   1               N/A               0                     24d
poddisruptionbudget.policy/auth-users-pdb               1               N/A               0                     24d
poddisruptionbudget.policy/chatbot-manager-pdb          1               N/A               0                     24d
poddisruptionbudget.policy/conversation-service-pdb     1               N/A               0                     24d
poddisruptionbudget.policy/portal-web-pdb               1               N/A               0                     24d

NAME                                                             POD-SELECTOR                                                                                                    AGE
networkpolicy.networking.k8s.io/allow-dns-egress                 <none>                                                                                                          24d
networkpolicy.networking.k8s.io/allow-prometheus-scraping        app.kubernetes.io/name in (audit-security-service,auth-users,chatbot-manager,conversation-service,portal-web)   7d19h
networkpolicy.networking.k8s.io/allow-validation-egress          app.kubernetes.io/part-of=securerag-hub,job-role=validation                                                     24d
networkpolicy.networking.k8s.io/allow-validation-ingress         app.kubernetes.io/name in (audit-security-service,auth-users,chatbot-manager,conversation-service,portal-web)   24d
networkpolicy.networking.k8s.io/audit-security-service-network   app.kubernetes.io/name=audit-security-service,app.kubernetes.io/part-of=securerag-hub                           24d
networkpolicy.networking.k8s.io/auth-users-policy                app.kubernetes.io/name=auth-users,app.kubernetes.io/part-of=securerag-hub                                       24d
networkpolicy.networking.k8s.io/chatbot-manager-policy           app.kubernetes.io/name=chatbot-manager,app.kubernetes.io/part-of=securerag-hub                                  24d
networkpolicy.networking.k8s.io/conversation-service-network     app.kubernetes.io/name=conversation-service,app.kubernetes.io/part-of=securerag-hub                             24d
networkpolicy.networking.k8s.io/default-deny-all                 <none>                                                                                                          24d
networkpolicy.networking.k8s.io/portal-web-policy                app.kubernetes.io/name=portal-web,app.kubernetes.io/part-of=securerag-hub                                       24d
networkpolicy.networking.k8s.io/postgres-auth-policy             app.kubernetes.io/part-of=securerag-hub,cnpg.io/cluster=postgres-auth                                           24d

NAME                                       SECRETS   AGE
serviceaccount/default                     0         24d
serviceaccount/jenkins                     0         5h29m
serviceaccount/jenkins-admin               0         6h1m
serviceaccount/sa-audit-security-service   0         24d
serviceaccount/sa-auth-users               0         24d
serviceaccount/sa-chatbot-manager          0         24d
serviceaccount/sa-conversation-service     0         24d
serviceaccount/sa-portal-web               0         24d
serviceaccount/sa-postgres-auth            0         24d
serviceaccount/sa-validation               0         24d
```

## Reading guide

- `TERMINÉ` means the static or runtime control succeeded.
- `PARTIEL` means the cluster answered but the production-only runtime is not clean or not fully Ready.
- `DÉPENDANT_DE_L_ENVIRONNEMENT` means no active Kubernetes API or namespace was available.
- `PRÊT_NON_EXÉCUTÉ` means the validation was intentionally limited to static rendering.
