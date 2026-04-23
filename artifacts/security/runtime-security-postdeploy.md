# Runtime Security Post-Deployment Report - SecureRAG Hub

- Generated at UTC: `2026-04-22T17:41:07Z`
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
| `auth-users` | TERMINÉ | 2 / 2 | 2 / 2 | 2 / 2 | `sa-auth-users` | `True` | `True` | `True` |
| `chatbot-manager` | TERMINÉ | 2 / 2 | 2 / 2 | 2 / 2 | `sa-chatbot-manager` | `True` | `True` | `True` |
| `conversation-service` | TERMINÉ | 2 / 2 | 2 / 2 | 2 / 2 | `sa-conversation-service` | `True` | `True` | `True` |
| `audit-security-service` | TERMINÉ | 2 / 2 | 2 / 2 | 2 / 2 | `sa-audit-security-service` | `True` | `True` | `True` |
| `portal-web` | TERMINÉ | 3 / 3 | 3 / 3 | 3 / 3 | `sa-portal-web` | `True` | `True` | `True` |

## Workload details

### auth-users

- No deployment-level hardening gap detected.
- Pod `auth-users-58df94bcb8-2cbgb` ready=`True` created=`2026-04-22T14:51:47Z` imageIDs=`1`
  - Runtime hardening checks matched the active Pod spec.
  - imageID: `localhost:5001/securerag-hub-auth-users@sha256:a24823c29f2a122a979b70bdfb3e55308f15bc0543d57aa3ed0108b2d15858a2`
- Pod `auth-users-58df94bcb8-ncghs` ready=`True` created=`2026-04-22T14:52:23Z` imageIDs=`1`
  - Runtime hardening checks matched the active Pod spec.
  - imageID: `localhost:5001/securerag-hub-auth-users@sha256:a24823c29f2a122a979b70bdfb3e55308f15bc0543d57aa3ed0108b2d15858a2`

### chatbot-manager

- No deployment-level hardening gap detected.
- Pod `chatbot-manager-659cdc7cdc-25cgq` ready=`True` created=`2026-04-22T14:51:47Z` imageIDs=`1`
  - Runtime hardening checks matched the active Pod spec.
  - imageID: `localhost:5001/securerag-hub-chatbot-manager@sha256:c3d6137749412b624a94be14a611d941d82b614630ad14f1e3bed867c100a0d4`
- Pod `chatbot-manager-659cdc7cdc-db6dr` ready=`True` created=`2026-04-22T14:52:18Z` imageIDs=`1`
  - Runtime hardening checks matched the active Pod spec.
  - imageID: `localhost:5001/securerag-hub-chatbot-manager@sha256:c3d6137749412b624a94be14a611d941d82b614630ad14f1e3bed867c100a0d4`

### conversation-service

- No deployment-level hardening gap detected.
- Pod `conversation-service-6c9f48ff84-tk7zx` ready=`True` created=`2026-04-22T14:52:18Z` imageIDs=`1`
  - Runtime hardening checks matched the active Pod spec.
  - imageID: `localhost:5001/securerag-hub-conversation-service@sha256:79da79ea590f4df64b5f8f86f9c09bd335c28f5968b94fd6266a608084e21e48`
- Pod `conversation-service-6c9f48ff84-z8qhh` ready=`True` created=`2026-04-22T14:51:47Z` imageIDs=`1`
  - Runtime hardening checks matched the active Pod spec.
  - imageID: `localhost:5001/securerag-hub-conversation-service@sha256:79da79ea590f4df64b5f8f86f9c09bd335c28f5968b94fd6266a608084e21e48`

### audit-security-service

- No deployment-level hardening gap detected.
- Pod `audit-security-service-568984ff67-mmgg7` ready=`True` created=`2026-04-22T14:51:47Z` imageIDs=`1`
  - Runtime hardening checks matched the active Pod spec.
  - imageID: `localhost:5001/securerag-hub-audit-security-service@sha256:913e469cfb32945378452fde7b58da3ba66c6fd231c0d6ad3de64425308d7459`
- Pod `audit-security-service-568984ff67-pjtzt` ready=`True` created=`2026-04-22T14:52:23Z` imageIDs=`1`
  - Runtime hardening checks matched the active Pod spec.
  - imageID: `localhost:5001/securerag-hub-audit-security-service@sha256:913e469cfb32945378452fde7b58da3ba66c6fd231c0d6ad3de64425308d7459`

### portal-web

- No deployment-level hardening gap detected.
- Pod `portal-web-6859f8c7b7-k64rs` ready=`True` created=`2026-04-22T14:52:55Z` imageIDs=`1`
  - Runtime hardening checks matched the active Pod spec.
  - imageID: `localhost:5001/securerag-hub-portal-web@sha256:7c8563a385b2600a6250348bfcf94b945b498862c83e1360c2973040b886f468`
- Pod `portal-web-6859f8c7b7-kjdgj` ready=`True` created=`2026-04-22T14:51:46Z` imageIDs=`1`
  - Runtime hardening checks matched the active Pod spec.
  - imageID: `localhost:5001/securerag-hub-portal-web@sha256:7c8563a385b2600a6250348bfcf94b945b498862c83e1360c2973040b886f468`
- Pod `portal-web-6859f8c7b7-lwthj` ready=`True` created=`2026-04-22T14:52:28Z` imageIDs=`1`
  - Runtime hardening checks matched the active Pod spec.
  - imageID: `localhost:5001/securerag-hub-portal-web@sha256:7c8563a385b2600a6250348bfcf94b945b498862c83e1360c2973040b886f468`

## Honest reading

- `TERMINÉ` means the active Deployments and live Pods match the expected runtime security controls.
- `PARTIEL` means at least one live workload, Pod or cluster-side control is missing or inconsistent.
- `DÉPENDANT_DE_L_ENVIRONNEMENT` means the current cluster or namespace is not reachable.

## Deployments

```text
NAME                     READY   UP-TO-DATE   AVAILABLE   AGE    CONTAINERS               IMAGES                                                           SELECTOR
audit-security-service   2/2     2            2           169m   audit-security-service   localhost:5001/securerag-hub-audit-security-service:production   app.kubernetes.io/name=audit-security-service,app.kubernetes.io/part-of=securerag-hub
auth-users               2/2     2            2           169m   auth-users               localhost:5001/securerag-hub-auth-users:production               app.kubernetes.io/name=auth-users,app.kubernetes.io/part-of=securerag-hub
chatbot-manager          2/2     2            2           169m   chatbot-manager          localhost:5001/securerag-hub-chatbot-manager:production          app.kubernetes.io/name=chatbot-manager,app.kubernetes.io/part-of=securerag-hub
conversation-service     2/2     2            2           169m   conversation-service     localhost:5001/securerag-hub-conversation-service:production     app.kubernetes.io/name=conversation-service,app.kubernetes.io/part-of=securerag-hub
portal-web               3/3     3            3           169m   portal-web               localhost:5001/securerag-hub-portal-web:production               app.kubernetes.io/name=portal-web,app.kubernetes.io/part-of=securerag-hub
```

## Pods

```text
NAME                                      READY   STATUS    RESTARTS   AGE    IP            NODE                     NOMINATED NODE   READINESS GATES
audit-security-service-568984ff67-mmgg7   1/1     Running   0          169m   10.244.4.6    securerag-prod-worker2   <none>           <none>
audit-security-service-568984ff67-pjtzt   1/1     Running   0          168m   10.244.2.8    securerag-prod-worker    <none>           <none>
auth-users-58df94bcb8-2cbgb               1/1     Running   0          169m   10.244.3.6    securerag-prod-worker3   <none>           <none>
auth-users-58df94bcb8-ncghs               1/1     Running   0          168m   10.244.4.9    securerag-prod-worker2   <none>           <none>
chatbot-manager-659cdc7cdc-25cgq          1/1     Running   0          169m   10.244.2.6    securerag-prod-worker    <none>           <none>
chatbot-manager-659cdc7cdc-db6dr          1/1     Running   0          168m   10.244.4.7    securerag-prod-worker2   <none>           <none>
conversation-service-6c9f48ff84-tk7zx     1/1     Running   0          168m   10.244.4.8    securerag-prod-worker2   <none>           <none>
conversation-service-6c9f48ff84-z8qhh     1/1     Running   0          169m   10.244.2.7    securerag-prod-worker    <none>           <none>
portal-web-6859f8c7b7-k64rs               1/1     Running   0          168m   10.244.4.10   securerag-prod-worker2   <none>           <none>
portal-web-6859f8c7b7-kjdgj               1/1     Running   0          169m   10.244.2.5    securerag-prod-worker    <none>           <none>
portal-web-6859f8c7b7-lwthj               1/1     Running   0          168m   10.244.3.7    securerag-prod-worker3   <none>           <none>
```

## Deployment images and imageIDs

```text
audit-security-service-568984ff67-mmgg7	localhost:5001/securerag-hub-audit-security-service:production	localhost:5001/securerag-hub-audit-security-service@sha256:913e469cfb32945378452fde7b58da3ba66c6fd231c0d6ad3de64425308d7459
audit-security-service-568984ff67-pjtzt	localhost:5001/securerag-hub-audit-security-service:production	localhost:5001/securerag-hub-audit-security-service@sha256:913e469cfb32945378452fde7b58da3ba66c6fd231c0d6ad3de64425308d7459
auth-users-58df94bcb8-2cbgb	localhost:5001/securerag-hub-auth-users:production	localhost:5001/securerag-hub-auth-users@sha256:a24823c29f2a122a979b70bdfb3e55308f15bc0543d57aa3ed0108b2d15858a2
auth-users-58df94bcb8-ncghs	localhost:5001/securerag-hub-auth-users:production	localhost:5001/securerag-hub-auth-users@sha256:a24823c29f2a122a979b70bdfb3e55308f15bc0543d57aa3ed0108b2d15858a2
chatbot-manager-659cdc7cdc-25cgq	localhost:5001/securerag-hub-chatbot-manager:production	localhost:5001/securerag-hub-chatbot-manager@sha256:c3d6137749412b624a94be14a611d941d82b614630ad14f1e3bed867c100a0d4
chatbot-manager-659cdc7cdc-db6dr	localhost:5001/securerag-hub-chatbot-manager:production	localhost:5001/securerag-hub-chatbot-manager@sha256:c3d6137749412b624a94be14a611d941d82b614630ad14f1e3bed867c100a0d4
conversation-service-6c9f48ff84-tk7zx	localhost:5001/securerag-hub-conversation-service:production	localhost:5001/securerag-hub-conversation-service@sha256:79da79ea590f4df64b5f8f86f9c09bd335c28f5968b94fd6266a608084e21e48
conversation-service-6c9f48ff84-z8qhh	localhost:5001/securerag-hub-conversation-service:production	localhost:5001/securerag-hub-conversation-service@sha256:79da79ea590f4df64b5f8f86f9c09bd335c28f5968b94fd6266a608084e21e48
portal-web-6859f8c7b7-k64rs	localhost:5001/securerag-hub-portal-web:production	localhost:5001/securerag-hub-portal-web@sha256:7c8563a385b2600a6250348bfcf94b945b498862c83e1360c2973040b886f468
portal-web-6859f8c7b7-kjdgj	localhost:5001/securerag-hub-portal-web:production	localhost:5001/securerag-hub-portal-web@sha256:7c8563a385b2600a6250348bfcf94b945b498862c83e1360c2973040b886f468
portal-web-6859f8c7b7-lwthj	localhost:5001/securerag-hub-portal-web:production	localhost:5001/securerag-hub-portal-web@sha256:7c8563a385b2600a6250348bfcf94b945b498862c83e1360c2973040b886f468
```

## ServiceAccounts

```text
NAME                        SECRETS   AGE
default                     0         169m
sa-audit-security-service   0         169m
sa-auth-users               0         169m
sa-chatbot-manager          0         169m
sa-conversation-service     0         169m
sa-portal-web               0         169m
sa-validation               0         169m
```

## Roles and RoleBindings

```text
NAME                                                        CREATED AT
role.rbac.authorization.k8s.io/securerag-runtime-readonly   2026-04-22T14:51:46Z

NAME                                                                                      ROLE                              AGE    USERS   GROUPS   SERVICEACCOUNTS
rolebinding.rbac.authorization.k8s.io/securerag-runtime-readonly-audit-security-service   Role/securerag-runtime-readonly   169m                    securerag-hub/sa-audit-security-service
```

## NetworkPolicies

```text
NAME                             POD-SELECTOR                                                                                                    AGE
allow-dns-egress                 <none>                                                                                                          169m
allow-validation-egress          app.kubernetes.io/part-of=securerag-hub,job-role=validation                                                     169m
allow-validation-ingress         app.kubernetes.io/name in (audit-security-service,auth-users,chatbot-manager,conversation-service,portal-web)   169m
audit-security-service-network   app.kubernetes.io/name=audit-security-service,app.kubernetes.io/part-of=securerag-hub                           169m
auth-users-policy                app.kubernetes.io/name=auth-users,app.kubernetes.io/part-of=securerag-hub                                       169m
chatbot-manager-policy           app.kubernetes.io/name=chatbot-manager,app.kubernetes.io/part-of=securerag-hub                                  169m
conversation-service-network     app.kubernetes.io/name=conversation-service,app.kubernetes.io/part-of=securerag-hub                             169m
default-deny-all                 <none>                                                                                                          169m
portal-web-policy                app.kubernetes.io/name=portal-web,app.kubernetes.io/part-of=securerag-hub                                       169m
```

## PodDisruptionBudgets

```text
NAME                         MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
audit-security-service-pdb   1               N/A               1                     169m
auth-users-pdb               1               N/A               1                     169m
chatbot-manager-pdb          1               N/A               1                     169m
conversation-service-pdb     1               N/A               1                     169m
portal-web-pdb               2               N/A               1                     169m
```

## HPA

```text
NAME                     REFERENCE                           TARGETS                        MINPODS   MAXPODS   REPLICAS   AGE
audit-security-service   Deployment/audit-security-service   cpu: 2%/70%, memory: 45%/80%   2         6         2          169m
auth-users               Deployment/auth-users               cpu: 2%/70%, memory: 45%/80%   2         6         2          169m
chatbot-manager          Deployment/chatbot-manager          cpu: 2%/70%, memory: 45%/80%   2         6         2          169m
conversation-service     Deployment/conversation-service     cpu: 1%/70%, memory: 45%/80%   2         8         2          169m
portal-web               Deployment/portal-web               cpu: 2%/70%, memory: 44%/80%   3         9         3          169m
```

## Recent events

```text
LAST SEEN   TYPE      REASON            OBJECT                              MESSAGE
45m         Warning   PolicyViolation   deployment/audit-security-service   policy securerag-require-workload-controls/require-container-health-probes fail: validation error: Every SecureRAG deployment container must declare readiness, liveness and startup probes. rule require-container-health-probes failed at path /spec/template/spec/containers/0/livenessProbe/
45m         Warning   PolicyViolation   deployment/auth-users               policy securerag-require-workload-controls/require-container-health-probes fail: validation error: Every SecureRAG deployment container must declare readiness, liveness and startup probes. rule require-container-health-probes failed at path /spec/template/spec/containers/0/livenessProbe/
45m         Warning   PolicyViolation   deployment/chatbot-manager          policy securerag-require-workload-controls/require-container-health-probes fail: validation error: Every SecureRAG deployment container must declare readiness, liveness and startup probes. rule require-container-health-probes failed at path /spec/template/spec/containers/0/livenessProbe/
45m         Warning   PolicyViolation   deployment/conversation-service     policy securerag-require-workload-controls/require-container-health-probes fail: validation error: Every SecureRAG deployment container must declare readiness, liveness and startup probes. rule require-container-health-probes failed at path /spec/template/spec/containers/0/livenessProbe/
45m         Warning   PolicyViolation   deployment/portal-web               policy securerag-require-workload-controls/require-container-health-probes fail: validation error: Every SecureRAG deployment container must declare readiness, liveness and startup probes. rule require-container-health-probes failed at path /spec/template/spec/containers/0/livenessProbe/
```

## Logs deployment/auth-users

```text
Found 2 pods, using pod/auth-users-58df94bcb8-2cbgb
  2026-04-22 17:32:23 /health ...................................... ~ 0.07ms
  2026-04-22 17:32:27 /health ...................................... ~ 0.09ms
  2026-04-22 17:32:33 /health ...................................... ~ 0.08ms
  2026-04-22 17:32:43 /health ...................................... ~ 0.07ms
  2026-04-22 17:32:47 /health ...................................... ~ 0.07ms
  2026-04-22 17:32:53 /health ...................................... ~ 0.07ms
  2026-04-22 17:33:03 /health ...................................... ~ 0.08ms
  2026-04-22 17:33:07 /health ...................................... ~ 0.08ms
  2026-04-22 17:33:13 /health ...................................... ~ 0.08ms
  2026-04-22 17:33:23 /health ...................................... ~ 0.07ms
  2026-04-22 17:33:27 /health ...................................... ~ 0.07ms
  2026-04-22 17:33:33 /health ...................................... ~ 0.08ms
  2026-04-22 17:33:43 /health ...................................... ~ 0.10ms
  2026-04-22 17:33:47 /health ...................................... ~ 0.12ms
  2026-04-22 17:33:53 /health ...................................... ~ 0.07ms
  2026-04-22 17:34:03 /health ...................................... ~ 0.08ms
  2026-04-22 17:34:07 /health ...................................... ~ 0.09ms
  2026-04-22 17:34:13 /health ...................................... ~ 0.07ms
  2026-04-22 17:34:23 /health ...................................... ~ 0.12ms
  2026-04-22 17:34:27 /health ...................................... ~ 0.07ms
  2026-04-22 17:34:33 /health ...................................... ~ 0.11ms
  2026-04-22 17:34:43 /health ...................................... ~ 0.10ms
  2026-04-22 17:34:47 /health ...................................... ~ 0.12ms
  2026-04-22 17:34:53 /health ...................................... ~ 0.15ms
  2026-04-22 17:35:03 /health ...................................... ~ 0.07ms
  2026-04-22 17:35:07 /health ...................................... ~ 0.07ms
  2026-04-22 17:35:13 /health ...................................... ~ 0.07ms
  2026-04-22 17:35:23 /health ...................................... ~ 0.07ms
  2026-04-22 17:35:27 /health ...................................... ~ 0.10ms
  2026-04-22 17:35:33 /health ...................................... ~ 0.08ms
  2026-04-22 17:35:43 /health ...................................... ~ 0.07ms
  2026-04-22 17:35:47 /health ...................................... ~ 0.07ms
  2026-04-22 17:35:53 /health ...................................... ~ 0.10ms
  2026-04-22 17:36:03 /health ...................................... ~ 0.07ms
  2026-04-22 17:36:07 /health ...................................... ~ 0.08ms
  2026-04-22 17:36:13 /health ...................................... ~ 0.11ms
  2026-04-22 17:36:23 /health ...................................... ~ 0.07ms
  2026-04-22 17:36:27 /health ...................................... ~ 0.09ms
  2026-04-22 17:36:33 /health ...................................... ~ 0.07ms
  2026-04-22 17:36:43 /health ...................................... ~ 0.07ms
  2026-04-22 17:36:47 /health ...................................... ~ 0.07ms
  2026-04-22 17:36:53 /health ...................................... ~ 0.10ms
  2026-04-22 17:37:03 /health ...................................... ~ 0.09ms
  2026-04-22 17:37:07 /health ...................................... ~ 0.10ms
  2026-04-22 17:37:13 /health ...................................... ~ 0.07ms
  2026-04-22 17:37:23 /health ...................................... ~ 0.07ms
  2026-04-22 17:37:27 /health ...................................... ~ 0.07ms
  2026-04-22 17:37:33 /health ...................................... ~ 0.08ms
  2026-04-22 17:37:43 /health ...................................... ~ 0.07ms
  2026-04-22 17:37:47 /health ...................................... ~ 0.08ms
  2026-04-22 17:37:53 /health ...................................... ~ 0.09ms
  2026-04-22 17:38:03 /health ...................................... ~ 0.09ms
  2026-04-22 17:38:07 /health ...................................... ~ 0.07ms
  2026-04-22 17:38:13 /health ...................................... ~ 0.08ms
  2026-04-22 17:38:23 /health ...................................... ~ 0.07ms
  2026-04-22 17:38:27 /health ...................................... ~ 0.08ms
  2026-04-22 17:38:33 /health ...................................... ~ 0.07ms
  2026-04-22 17:38:43 /health ...................................... ~ 0.25ms
  2026-04-22 17:38:47 /health ...................................... ~ 0.07ms
  2026-04-22 17:38:53 /health ...................................... ~ 0.08ms
  2026-04-22 17:39:03 /health ...................................... ~ 0.19ms
  2026-04-22 17:39:07 /health ...................................... ~ 0.07ms
  2026-04-22 17:39:13 /health ...................................... ~ 0.09ms
  2026-04-22 17:39:23 /health ...................................... ~ 0.09ms
  2026-04-22 17:39:27 /health ...................................... ~ 0.07ms
  2026-04-22 17:39:33 /health ...................................... ~ 0.07ms
  2026-04-22 17:39:43 /health ...................................... ~ 0.09ms
  2026-04-22 17:39:47 /health ...................................... ~ 0.08ms
  2026-04-22 17:39:53 /health ...................................... ~ 0.10ms
  2026-04-22 17:40:03 /health ...................................... ~ 0.10ms
  2026-04-22 17:40:07 /health .................................... ~ 500.35ms
  2026-04-22 17:40:13 /health ...................................... ~ 0.07ms
  2026-04-22 17:40:23 /health ...................................... ~ 0.07ms
  2026-04-22 17:40:27 /health .................................... ~ 500.29ms
  2026-04-22 17:40:33 /health ...................................... ~ 0.07ms
  2026-04-22 17:40:43 /health ...................................... ~ 0.07ms
  2026-04-22 17:40:47 /health ...................................... ~ 0.07ms
  2026-04-22 17:40:53 /health ...................................... ~ 0.08ms
  2026-04-22 17:41:03 /health ...................................... ~ 0.07ms
  2026-04-22 17:41:07 /health ...................................... ~ 0.07ms
```

## Logs deployment/chatbot-manager

```text
Found 2 pods, using pod/chatbot-manager-659cdc7cdc-25cgq
  2026-04-22 17:32:27 /health ...................................... ~ 0.07ms
  2026-04-22 17:32:28 /health ...................................... ~ 0.07ms
  2026-04-22 17:32:38 /health ...................................... ~ 0.08ms
  2026-04-22 17:32:47 /health ...................................... ~ 0.07ms
  2026-04-22 17:32:48 /health ...................................... ~ 0.08ms
  2026-04-22 17:32:58 /health ...................................... ~ 0.09ms
  2026-04-22 17:33:07 /health ...................................... ~ 0.07ms
  2026-04-22 17:33:08 /health ...................................... ~ 0.07ms
  2026-04-22 17:33:18 /health ...................................... ~ 0.07ms
  2026-04-22 17:33:27 /health ...................................... ~ 0.08ms
  2026-04-22 17:33:28 /health ...................................... ~ 0.07ms
  2026-04-22 17:33:38 /health ...................................... ~ 0.08ms
  2026-04-22 17:33:47 /health ...................................... ~ 0.10ms
  2026-04-22 17:33:48 /health ...................................... ~ 0.09ms
  2026-04-22 17:33:58 /health ...................................... ~ 0.07ms
  2026-04-22 17:34:07 /health ...................................... ~ 0.07ms
  2026-04-22 17:34:08 /health ...................................... ~ 0.09ms
  2026-04-22 17:34:18 /health ...................................... ~ 0.08ms
  2026-04-22 17:34:27 /health ...................................... ~ 0.08ms
  2026-04-22 17:34:28 /health ...................................... ~ 0.08ms
  2026-04-22 17:34:38 /health ...................................... ~ 0.07ms
  2026-04-22 17:34:47 /health ...................................... ~ 0.19ms
  2026-04-22 17:34:48 /health ...................................... ~ 0.07ms
  2026-04-22 17:34:58 /health ...................................... ~ 0.09ms
  2026-04-22 17:35:07 /health ...................................... ~ 0.10ms
  2026-04-22 17:35:08 /health ...................................... ~ 0.09ms
  2026-04-22 17:35:18 /health ...................................... ~ 0.09ms
  2026-04-22 17:35:27 /health ...................................... ~ 0.08ms
  2026-04-22 17:35:28 /health ...................................... ~ 0.07ms
  2026-04-22 17:35:38 /health ...................................... ~ 0.07ms
  2026-04-22 17:35:47 /health ...................................... ~ 0.07ms
  2026-04-22 17:35:48 /health ...................................... ~ 0.08ms
  2026-04-22 17:35:58 /health ...................................... ~ 0.09ms
  2026-04-22 17:36:07 /health ...................................... ~ 0.07ms
  2026-04-22 17:36:08 /health ...................................... ~ 0.10ms
  2026-04-22 17:36:18 /health ...................................... ~ 0.08ms
  2026-04-22 17:36:27 /health ...................................... ~ 0.07ms
  2026-04-22 17:36:28 /health ...................................... ~ 0.09ms
  2026-04-22 17:36:38 /health ...................................... ~ 0.07ms
  2026-04-22 17:36:47 /health .................................... ~ 500.27ms
  2026-04-22 17:36:48 /health ...................................... ~ 0.08ms
  2026-04-22 17:36:58 /health ...................................... ~ 0.09ms
  2026-04-22 17:37:07 /health ...................................... ~ 0.07ms
  2026-04-22 17:37:08 /health ...................................... ~ 0.08ms
  2026-04-22 17:37:18 /health ...................................... ~ 0.08ms
  2026-04-22 17:37:27 /health ...................................... ~ 0.07ms
  2026-04-22 17:37:28 /health ...................................... ~ 0.07ms
  2026-04-22 17:37:38 /health ...................................... ~ 0.08ms
  2026-04-22 17:37:47 /health ...................................... ~ 0.09ms
  2026-04-22 17:37:48 /health ...................................... ~ 0.07ms
  2026-04-22 17:37:58 /health ...................................... ~ 0.08ms
  2026-04-22 17:38:07 /health ...................................... ~ 0.07ms
  2026-04-22 17:38:08 /health ...................................... ~ 0.08ms
  2026-04-22 17:38:18 /health ...................................... ~ 0.07ms
  2026-04-22 17:38:27 /health ...................................... ~ 0.07ms
  2026-04-22 17:38:28 /health ...................................... ~ 0.10ms
  2026-04-22 17:38:38 /health ...................................... ~ 0.13ms
  2026-04-22 17:38:47 /health ...................................... ~ 0.12ms
  2026-04-22 17:38:48 /health ...................................... ~ 0.07ms
  2026-04-22 17:38:58 /health ...................................... ~ 0.07ms
  2026-04-22 17:39:07 /health ...................................... ~ 0.07ms
  2026-04-22 17:39:08 /health ...................................... ~ 0.09ms
  2026-04-22 17:39:18 /health ...................................... ~ 0.07ms
  2026-04-22 17:39:27 /health ...................................... ~ 0.08ms
  2026-04-22 17:39:28 /health ...................................... ~ 0.07ms
  2026-04-22 17:39:38 /health ...................................... ~ 0.08ms
  2026-04-22 17:39:47 /health ...................................... ~ 0.07ms
  2026-04-22 17:39:48 /health ...................................... ~ 0.09ms
  2026-04-22 17:39:58 /health ...................................... ~ 0.07ms
  2026-04-22 17:40:07 /health ...................................... ~ 0.08ms
  2026-04-22 17:40:08 /health ...................................... ~ 0.09ms
  2026-04-22 17:40:18 /health ...................................... ~ 0.09ms
  2026-04-22 17:40:27 /health ...................................... ~ 0.07ms
  2026-04-22 17:40:28 /health ...................................... ~ 0.08ms
  2026-04-22 17:40:38 /health ...................................... ~ 0.07ms
  2026-04-22 17:40:47 /health ...................................... ~ 0.08ms
  2026-04-22 17:40:48 /health .................................... ~ 500.36ms
  2026-04-22 17:40:58 /health .................................... ~ 500.29ms
  2026-04-22 17:41:07 /health ...................................... ~ 0.63ms
  2026-04-22 17:41:08 /health ...................................... ~ 0.07ms
```

## Logs deployment/conversation-service

```text
Found 2 pods, using pod/conversation-service-6c9f48ff84-z8qhh
  2026-04-22 17:32:18 /health ...................................... ~ 0.07ms
  2026-04-22 17:32:28 /health ...................................... ~ 0.12ms
  2026-04-22 17:32:28 /health ...................................... ~ 0.10ms
  2026-04-22 17:32:38 /health ...................................... ~ 0.08ms
  2026-04-22 17:32:48 /health ...................................... ~ 0.07ms
  2026-04-22 17:32:48 /health ...................................... ~ 0.07ms
  2026-04-22 17:32:58 /health ...................................... ~ 0.07ms
  2026-04-22 17:33:08 /health ...................................... ~ 0.07ms
  2026-04-22 17:33:08 /health ...................................... ~ 0.07ms
  2026-04-22 17:33:18 /health ...................................... ~ 0.07ms
  2026-04-22 17:33:28 /health ...................................... ~ 0.07ms
  2026-04-22 17:33:28 /health ...................................... ~ 0.07ms
  2026-04-22 17:33:38 /health ...................................... ~ 0.08ms
  2026-04-22 17:33:48 /health ...................................... ~ 0.09ms
  2026-04-22 17:33:48 /health ...................................... ~ 0.09ms
  2026-04-22 17:33:58 /health ...................................... ~ 0.08ms
  2026-04-22 17:34:08 /health ...................................... ~ 0.07ms
  2026-04-22 17:34:08 /health ...................................... ~ 0.07ms
  2026-04-22 17:34:18 /health ...................................... ~ 0.09ms
  2026-04-22 17:34:28 /health ...................................... ~ 0.07ms
  2026-04-22 17:34:28 /health ...................................... ~ 0.09ms
  2026-04-22 17:34:38 /health ...................................... ~ 0.09ms
  2026-04-22 17:34:48 /health ...................................... ~ 0.07ms
  2026-04-22 17:34:48 /health ...................................... ~ 0.10ms
  2026-04-22 17:34:58 /health ...................................... ~ 0.11ms
  2026-04-22 17:35:08 /health ...................................... ~ 0.09ms
  2026-04-22 17:35:08 /health ...................................... ~ 0.07ms
  2026-04-22 17:35:18 /health ...................................... ~ 0.07ms
  2026-04-22 17:35:28 /health ...................................... ~ 0.07ms
  2026-04-22 17:35:28 /health ...................................... ~ 0.07ms
  2026-04-22 17:35:38 /health ...................................... ~ 0.08ms
  2026-04-22 17:35:48 /health ...................................... ~ 0.07ms
  2026-04-22 17:35:48 /health ...................................... ~ 0.07ms
  2026-04-22 17:35:58 /health ...................................... ~ 0.09ms
  2026-04-22 17:36:08 /health ...................................... ~ 0.10ms
  2026-04-22 17:36:08 /health ...................................... ~ 0.07ms
  2026-04-22 17:36:18 /health ...................................... ~ 0.07ms
  2026-04-22 17:36:28 /health ...................................... ~ 0.09ms
  2026-04-22 17:36:28 /health ...................................... ~ 0.10ms
  2026-04-22 17:36:38 /health ...................................... ~ 0.08ms
  2026-04-22 17:36:48 /health ...................................... ~ 0.07ms
  2026-04-22 17:36:48 /health ...................................... ~ 0.07ms
  2026-04-22 17:36:58 /health ...................................... ~ 0.07ms
  2026-04-22 17:37:08 /health ...................................... ~ 0.07ms
  2026-04-22 17:37:08 /health ...................................... ~ 0.10ms
  2026-04-22 17:37:18 /health ...................................... ~ 0.09ms
  2026-04-22 17:37:28 /health ...................................... ~ 0.07ms
  2026-04-22 17:37:28 /health ...................................... ~ 0.07ms
  2026-04-22 17:37:38 /health ...................................... ~ 0.09ms
  2026-04-22 17:37:48 /health ...................................... ~ 0.09ms
  2026-04-22 17:37:48 /health ...................................... ~ 0.08ms
  2026-04-22 17:37:58 /health ...................................... ~ 0.09ms
  2026-04-22 17:38:08 /health ...................................... ~ 0.11ms
  2026-04-22 17:38:08 /health ...................................... ~ 0.07ms
  2026-04-22 17:38:18 /health ...................................... ~ 0.08ms
  2026-04-22 17:38:28 /health ...................................... ~ 0.13ms
  2026-04-22 17:38:28 /health ...................................... ~ 0.08ms
  2026-04-22 17:38:38 /health ...................................... ~ 0.07ms
  2026-04-22 17:38:48 /health ...................................... ~ 0.09ms
  2026-04-22 17:38:48 /health ...................................... ~ 0.09ms
  2026-04-22 17:38:58 /health ...................................... ~ 0.09ms
  2026-04-22 17:39:08 /health ...................................... ~ 0.09ms
  2026-04-22 17:39:08 /health ...................................... ~ 0.08ms
  2026-04-22 17:39:18 /health ...................................... ~ 0.10ms
  2026-04-22 17:39:28 /health ...................................... ~ 0.08ms
  2026-04-22 17:39:28 /health ...................................... ~ 0.09ms
  2026-04-22 17:39:38 /health ...................................... ~ 0.07ms
  2026-04-22 17:39:48 /health ...................................... ~ 0.08ms
  2026-04-22 17:39:48 /health ...................................... ~ 0.08ms
  2026-04-22 17:39:58 /health ...................................... ~ 0.08ms
  2026-04-22 17:40:08 /health ...................................... ~ 0.13ms
  2026-04-22 17:40:08 /health ...................................... ~ 0.08ms
  2026-04-22 17:40:18 /health ...................................... ~ 0.12ms
  2026-04-22 17:40:28 /health ...................................... ~ 0.08ms
  2026-04-22 17:40:28 /health ...................................... ~ 0.08ms
  2026-04-22 17:40:38 /health ...................................... ~ 0.08ms
  2026-04-22 17:40:48 /health ...................................... ~ 0.08ms
  2026-04-22 17:40:48 /health ...................................... ~ 0.08ms
  2026-04-22 17:40:58 /health ...................................... ~ 0.08ms
  2026-04-22 17:41:08 /health ...................................... ~ 0.07ms
```

## Logs deployment/audit-security-service

```text
Found 2 pods, using pod/audit-security-service-568984ff67-mmgg7
  2026-04-22 17:32:13 /health ...................................... ~ 0.07ms
  2026-04-22 17:32:23 /health ...................................... ~ 0.08ms
  2026-04-22 17:32:28 /health ...................................... ~ 0.07ms
  2026-04-22 17:32:33 /health ...................................... ~ 0.07ms
  2026-04-22 17:32:43 /health ...................................... ~ 0.07ms
  2026-04-22 17:32:48 /health ...................................... ~ 0.07ms
  2026-04-22 17:32:53 /health ...................................... ~ 0.07ms
  2026-04-22 17:33:03 /health ...................................... ~ 0.07ms
  2026-04-22 17:33:08 /health ...................................... ~ 0.07ms
  2026-04-22 17:33:13 /health ...................................... ~ 0.07ms
  2026-04-22 17:33:23 /health ...................................... ~ 0.08ms
  2026-04-22 17:33:28 /health ...................................... ~ 0.07ms
  2026-04-22 17:33:33 /health ...................................... ~ 0.07ms
  2026-04-22 17:33:43 /health ...................................... ~ 0.07ms
  2026-04-22 17:33:48 /health ...................................... ~ 0.16ms
  2026-04-22 17:33:53 /health ...................................... ~ 0.13ms
  2026-04-22 17:34:03 /health ...................................... ~ 0.08ms
  2026-04-22 17:34:08 /health ...................................... ~ 0.07ms
  2026-04-22 17:34:13 /health ...................................... ~ 0.09ms
  2026-04-22 17:34:23 /health ...................................... ~ 0.08ms
  2026-04-22 17:34:28 /health ...................................... ~ 0.07ms
  2026-04-22 17:34:33 /health ...................................... ~ 0.07ms
  2026-04-22 17:34:43 /health ...................................... ~ 0.07ms
  2026-04-22 17:34:48 /health ...................................... ~ 0.07ms
  2026-04-22 17:34:53 /health ...................................... ~ 0.07ms
  2026-04-22 17:35:03 /health ...................................... ~ 0.07ms
  2026-04-22 17:35:08 /health ...................................... ~ 0.07ms
  2026-04-22 17:35:13 /health ...................................... ~ 0.07ms
  2026-04-22 17:35:23 /health ...................................... ~ 0.07ms
  2026-04-22 17:35:28 /health ...................................... ~ 0.09ms
  2026-04-22 17:35:33 /health ...................................... ~ 0.07ms
  2026-04-22 17:35:43 /health ...................................... ~ 0.07ms
  2026-04-22 17:35:48 /health ...................................... ~ 0.08ms
  2026-04-22 17:35:53 /health ...................................... ~ 0.07ms
  2026-04-22 17:36:03 /health ...................................... ~ 0.08ms
  2026-04-22 17:36:08 /health ...................................... ~ 0.08ms
  2026-04-22 17:36:13 /health ...................................... ~ 0.07ms
  2026-04-22 17:36:23 /health ...................................... ~ 0.07ms
  2026-04-22 17:36:28 /health ...................................... ~ 0.07ms
  2026-04-22 17:36:33 /health ...................................... ~ 0.07ms
  2026-04-22 17:36:43 /health ...................................... ~ 0.07ms
  2026-04-22 17:36:48 /health ...................................... ~ 0.07ms
  2026-04-22 17:36:53 /health ...................................... ~ 0.07ms
  2026-04-22 17:37:03 /health ...................................... ~ 0.07ms
  2026-04-22 17:37:08 /health ...................................... ~ 0.10ms
  2026-04-22 17:37:13 /health ...................................... ~ 0.08ms
  2026-04-22 17:37:23 /health ...................................... ~ 0.07ms
  2026-04-22 17:37:28 /health ...................................... ~ 0.07ms
  2026-04-22 17:37:33 /health ...................................... ~ 0.15ms
  2026-04-22 17:37:43 /health ...................................... ~ 0.07ms
  2026-04-22 17:37:48 /health ...................................... ~ 0.07ms
  2026-04-22 17:37:53 /health ...................................... ~ 0.07ms
  2026-04-22 17:38:03 /health ...................................... ~ 0.07ms
  2026-04-22 17:38:08 /health ...................................... ~ 0.07ms
  2026-04-22 17:38:13 /health ...................................... ~ 0.07ms
  2026-04-22 17:38:23 /health ...................................... ~ 0.07ms
  2026-04-22 17:38:28 /health ...................................... ~ 0.07ms
  2026-04-22 17:38:33 /health ...................................... ~ 0.07ms
  2026-04-22 17:38:43 /health ...................................... ~ 0.07ms
  2026-04-22 17:38:48 /health ...................................... ~ 0.08ms
  2026-04-22 17:38:53 /health ...................................... ~ 0.07ms
  2026-04-22 17:39:03 /health ...................................... ~ 0.08ms
  2026-04-22 17:39:08 /health ...................................... ~ 0.07ms
  2026-04-22 17:39:13 /health ...................................... ~ 0.08ms
  2026-04-22 17:39:23 /health ...................................... ~ 0.08ms
  2026-04-22 17:39:28 /health ...................................... ~ 0.07ms
  2026-04-22 17:39:33 /health ...................................... ~ 0.07ms
  2026-04-22 17:39:43 /health ...................................... ~ 0.07ms
  2026-04-22 17:39:48 /health ...................................... ~ 0.07ms
  2026-04-22 17:39:53 /health ...................................... ~ 0.07ms
  2026-04-22 17:40:03 /health ...................................... ~ 0.07ms
  2026-04-22 17:40:08 /health ...................................... ~ 0.08ms
  2026-04-22 17:40:13 /health ...................................... ~ 0.07ms
  2026-04-22 17:40:23 /health ...................................... ~ 0.13ms
  2026-04-22 17:40:28 /health ...................................... ~ 0.09ms
  2026-04-22 17:40:33 /health ...................................... ~ 0.07ms
  2026-04-22 17:40:43 /health ...................................... ~ 0.07ms
  2026-04-22 17:40:48 /health ...................................... ~ 0.07ms
  2026-04-22 17:40:53 /health ...................................... ~ 0.07ms
  2026-04-22 17:41:03 /health ...................................... ~ 0.07ms
```

## Logs deployment/portal-web

```text
Found 3 pods, using pod/portal-web-6859f8c7b7-kjdgj
  2026-04-22 17:32:27 /health ...................................... ~ 0.07ms
  2026-04-22 17:32:28 /health ...................................... ~ 0.07ms
  2026-04-22 17:32:38 /health ...................................... ~ 0.07ms
  2026-04-22 17:32:47 /health ...................................... ~ 0.07ms
  2026-04-22 17:32:48 /health ...................................... ~ 0.07ms
  2026-04-22 17:32:58 /health ...................................... ~ 0.07ms
  2026-04-22 17:33:07 /health ...................................... ~ 0.07ms
  2026-04-22 17:33:08 /health ...................................... ~ 0.08ms
  2026-04-22 17:33:18 /health ...................................... ~ 0.07ms
  2026-04-22 17:33:27 /health ...................................... ~ 0.09ms
  2026-04-22 17:33:28 /health ...................................... ~ 0.07ms
  2026-04-22 17:33:38 /health ...................................... ~ 0.07ms
  2026-04-22 17:33:47 /health ...................................... ~ 0.09ms
  2026-04-22 17:33:48 /health ...................................... ~ 0.07ms
  2026-04-22 17:33:58 /health ...................................... ~ 0.07ms
  2026-04-22 17:34:07 /health ...................................... ~ 0.07ms
  2026-04-22 17:34:08 /health ...................................... ~ 0.08ms
  2026-04-22 17:34:18 /health ...................................... ~ 0.07ms
  2026-04-22 17:34:27 /health ...................................... ~ 0.07ms
  2026-04-22 17:34:28 /health ...................................... ~ 0.08ms
  2026-04-22 17:34:38 /health ...................................... ~ 0.10ms
  2026-04-22 17:34:47 /health ...................................... ~ 0.18ms
  2026-04-22 17:34:48 /health ...................................... ~ 0.08ms
  2026-04-22 17:34:58 /health ...................................... ~ 0.07ms
  2026-04-22 17:35:07 /health ...................................... ~ 0.08ms
  2026-04-22 17:35:08 /health .................................... ~ 500.36ms
  2026-04-22 17:35:18 /health .................................... ~ 500.38ms
  2026-04-22 17:35:27 /health ...................................... ~ 0.10ms
  2026-04-22 17:35:28 /health ...................................... ~ 0.08ms
  2026-04-22 17:35:38 /health ...................................... ~ 0.10ms
  2026-04-22 17:35:47 /health ...................................... ~ 0.09ms
  2026-04-22 17:35:48 /health ...................................... ~ 0.10ms
  2026-04-22 17:35:58 /health ...................................... ~ 0.07ms
  2026-04-22 17:36:07 /health ...................................... ~ 0.07ms
  2026-04-22 17:36:08 /health ...................................... ~ 0.07ms
  2026-04-22 17:36:18 /health ...................................... ~ 0.08ms
  2026-04-22 17:36:27 /health ...................................... ~ 0.07ms
  2026-04-22 17:36:28 /health ...................................... ~ 0.07ms
  2026-04-22 17:36:38 /health ...................................... ~ 0.11ms
  2026-04-22 17:36:47 /health ...................................... ~ 0.09ms
  2026-04-22 17:36:48 /health ...................................... ~ 0.08ms
  2026-04-22 17:36:58 /health ...................................... ~ 0.09ms
  2026-04-22 17:37:07 /health ...................................... ~ 0.08ms
  2026-04-22 17:37:08 /health ...................................... ~ 0.13ms
  2026-04-22 17:37:18 /health ...................................... ~ 0.08ms
  2026-04-22 17:37:27 /health ...................................... ~ 0.08ms
  2026-04-22 17:37:28 /health ...................................... ~ 0.08ms
  2026-04-22 17:37:38 /health ...................................... ~ 0.09ms
  2026-04-22 17:37:47 /health ...................................... ~ 0.07ms
  2026-04-22 17:37:48 /health ...................................... ~ 0.08ms
  2026-04-22 17:37:58 /health ...................................... ~ 0.08ms
  2026-04-22 17:38:07 /health ...................................... ~ 0.07ms
  2026-04-22 17:38:08 /health ...................................... ~ 0.08ms
  2026-04-22 17:38:18 /health ...................................... ~ 0.07ms
  2026-04-22 17:38:27 /health ...................................... ~ 0.08ms
  2026-04-22 17:38:28 /health ...................................... ~ 0.07ms
  2026-04-22 17:38:38 /health ...................................... ~ 0.07ms
  2026-04-22 17:38:47 /health .................................... ~ 500.35ms
  2026-04-22 17:38:48 /health ...................................... ~ 0.07ms
  2026-04-22 17:38:58 /health ...................................... ~ 0.08ms
  2026-04-22 17:39:07 /health ...................................... ~ 0.09ms
  2026-04-22 17:39:08 /health ...................................... ~ 0.07ms
  2026-04-22 17:39:18 /health ...................................... ~ 0.09ms
  2026-04-22 17:39:27 /health ...................................... ~ 0.07ms
  2026-04-22 17:39:28 /health ...................................... ~ 0.07ms
  2026-04-22 17:39:38 /health ...................................... ~ 0.09ms
  2026-04-22 17:39:47 /health ...................................... ~ 0.07ms
  2026-04-22 17:39:48 /health ...................................... ~ 0.07ms
  2026-04-22 17:39:58 /health ...................................... ~ 0.07ms
  2026-04-22 17:40:07 /health ...................................... ~ 0.09ms
  2026-04-22 17:40:08 /health ...................................... ~ 0.08ms
  2026-04-22 17:40:18 /health ...................................... ~ 0.07ms
  2026-04-22 17:40:27 /health ...................................... ~ 0.08ms
  2026-04-22 17:40:28 /health ...................................... ~ 0.07ms
  2026-04-22 17:40:38 /health ...................................... ~ 0.07ms
  2026-04-22 17:40:47 /health ...................................... ~ 0.07ms
  2026-04-22 17:40:48 /health ...................................... ~ 0.07ms
  2026-04-22 17:40:58 /health ...................................... ~ 0.07ms
  2026-04-22 17:41:07 /health ...................................... ~ 0.07ms
  2026-04-22 17:41:08 /health ...................................... ~ 0.07ms
```
