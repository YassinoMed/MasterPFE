# Observability Snapshot - SecureRAG Hub

- Generated at: `2026-04-22T17:41:08Z`
- Namespace: `securerag-hub`
- Jenkins URL: `http://127.0.0.1:8085`

## Scope

This report captures runtime observability evidence without mutating the cluster. It complements, but does not replace, a full Prometheus/Grafana/Loki stack.

## Kubernetes context

```text
kind-securerag-prod
```

## Workloads

```text
NAME                                     READY   UP-TO-DATE   AVAILABLE   AGE    CONTAINERS               IMAGES                                                           SELECTOR
deployment.apps/audit-security-service   2/2     2            2           169m   audit-security-service   localhost:5001/securerag-hub-audit-security-service:production   app.kubernetes.io/name=audit-security-service,app.kubernetes.io/part-of=securerag-hub
deployment.apps/auth-users               2/2     2            2           169m   auth-users               localhost:5001/securerag-hub-auth-users:production               app.kubernetes.io/name=auth-users,app.kubernetes.io/part-of=securerag-hub
deployment.apps/chatbot-manager          2/2     2            2           169m   chatbot-manager          localhost:5001/securerag-hub-chatbot-manager:production          app.kubernetes.io/name=chatbot-manager,app.kubernetes.io/part-of=securerag-hub
deployment.apps/conversation-service     2/2     2            2           169m   conversation-service     localhost:5001/securerag-hub-conversation-service:production     app.kubernetes.io/name=conversation-service,app.kubernetes.io/part-of=securerag-hub
deployment.apps/portal-web               3/3     3            3           169m   portal-web               localhost:5001/securerag-hub-portal-web:production               app.kubernetes.io/name=portal-web,app.kubernetes.io/part-of=securerag-hub

NAME                                          READY   STATUS    RESTARTS   AGE    IP            NODE                     NOMINATED NODE   READINESS GATES
pod/audit-security-service-568984ff67-mmgg7   1/1     Running   0          169m   10.244.4.6    securerag-prod-worker2   <none>           <none>
pod/audit-security-service-568984ff67-pjtzt   1/1     Running   0          168m   10.244.2.8    securerag-prod-worker    <none>           <none>
pod/auth-users-58df94bcb8-2cbgb               1/1     Running   0          169m   10.244.3.6    securerag-prod-worker3   <none>           <none>
pod/auth-users-58df94bcb8-ncghs               1/1     Running   0          168m   10.244.4.9    securerag-prod-worker2   <none>           <none>
pod/chatbot-manager-659cdc7cdc-25cgq          1/1     Running   0          169m   10.244.2.6    securerag-prod-worker    <none>           <none>
pod/chatbot-manager-659cdc7cdc-db6dr          1/1     Running   0          168m   10.244.4.7    securerag-prod-worker2   <none>           <none>
pod/conversation-service-6c9f48ff84-tk7zx     1/1     Running   0          168m   10.244.4.8    securerag-prod-worker2   <none>           <none>
pod/conversation-service-6c9f48ff84-z8qhh     1/1     Running   0          169m   10.244.2.7    securerag-prod-worker    <none>           <none>
pod/portal-web-6859f8c7b7-k64rs               1/1     Running   0          168m   10.244.4.10   securerag-prod-worker2   <none>           <none>
pod/portal-web-6859f8c7b7-kjdgj               1/1     Running   0          169m   10.244.2.5    securerag-prod-worker    <none>           <none>
pod/portal-web-6859f8c7b7-lwthj               1/1     Running   0          168m   10.244.3.7    securerag-prod-worker3   <none>           <none>

NAME                             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE    SELECTOR
service/audit-security-service   ClusterIP   10.96.42.21     <none>        8000/TCP         169m   app.kubernetes.io/name=audit-security-service,app.kubernetes.io/part-of=securerag-hub
service/auth-users               ClusterIP   10.96.219.212   <none>        8000/TCP         169m   app.kubernetes.io/name=auth-users,app.kubernetes.io/part-of=securerag-hub
service/chatbot-manager          ClusterIP   10.96.48.130    <none>        8000/TCP         169m   app.kubernetes.io/name=chatbot-manager,app.kubernetes.io/part-of=securerag-hub
service/conversation-service     ClusterIP   10.96.110.74    <none>        8000/TCP         169m   app.kubernetes.io/name=conversation-service,app.kubernetes.io/part-of=securerag-hub
service/portal-web               NodePort    10.96.42.1      <none>        8000:30081/TCP   169m   app.kubernetes.io/name=portal-web,app.kubernetes.io/part-of=securerag-hub
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

## PDB

```text
NAME                         MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
audit-security-service-pdb   1               N/A               1                     169m
auth-users-pdb               1               N/A               1                     169m
chatbot-manager-pdb          1               N/A               1                     169m
conversation-service-pdb     1               N/A               1                     169m
portal-web-pdb               2               N/A               1                     169m
```

## Recent namespace events

```text
LAST SEEN   TYPE      REASON            OBJECT                              MESSAGE
45m         Warning   PolicyViolation   deployment/audit-security-service   policy securerag-require-workload-controls/require-container-health-probes fail: validation error: Every SecureRAG deployment container must declare readiness, liveness and startup probes. rule require-container-health-probes failed at path /spec/template/spec/containers/0/livenessProbe/
45m         Warning   PolicyViolation   deployment/auth-users               policy securerag-require-workload-controls/require-container-health-probes fail: validation error: Every SecureRAG deployment container must declare readiness, liveness and startup probes. rule require-container-health-probes failed at path /spec/template/spec/containers/0/livenessProbe/
45m         Warning   PolicyViolation   deployment/chatbot-manager          policy securerag-require-workload-controls/require-container-health-probes fail: validation error: Every SecureRAG deployment container must declare readiness, liveness and startup probes. rule require-container-health-probes failed at path /spec/template/spec/containers/0/livenessProbe/
45m         Warning   PolicyViolation   deployment/conversation-service     policy securerag-require-workload-controls/require-container-health-probes fail: validation error: Every SecureRAG deployment container must declare readiness, liveness and startup probes. rule require-container-health-probes failed at path /spec/template/spec/containers/0/livenessProbe/
45m         Warning   PolicyViolation   deployment/portal-web               policy securerag-require-workload-controls/require-container-health-probes fail: validation error: Every SecureRAG deployment container must declare readiness, liveness and startup probes. rule require-container-health-probes failed at path /spec/template/spec/containers/0/livenessProbe/
```

## Metrics API

```text
NAME                     SERVICE                      AVAILABLE   AGE
v1beta1.metrics.k8s.io   kube-system/metrics-server   True        167m
```

## Node metrics

```text
NAME                           CPU(cores)   CPU(%)   MEMORY(bytes)   MEMORY(%)   
securerag-prod-control-plane   135m         2%       1242Mi          5%          
securerag-prod-worker          29m          0%       700Mi           2%          
securerag-prod-worker2         25m          0%       673Mi           2%          
securerag-prod-worker3         36m          0%       583Mi           2%          
```

## Pod metrics

```text
NAME                                      CPU(cores)   MEMORY(bytes)   
audit-security-service-568984ff67-mmgg7   2m           58Mi            
audit-security-service-568984ff67-pjtzt   2m           58Mi            
auth-users-58df94bcb8-2cbgb               2m           57Mi            
auth-users-58df94bcb8-ncghs               1m           57Mi            
chatbot-manager-659cdc7cdc-25cgq          2m           57Mi            
chatbot-manager-659cdc7cdc-db6dr          1m           58Mi            
conversation-service-6c9f48ff84-tk7zx     2m           57Mi            
conversation-service-6c9f48ff84-z8qhh     2m           57Mi            
portal-web-6859f8c7b7-k64rs               2m           58Mi            
portal-web-6859f8c7b7-kjdgj               2m           57Mi            
portal-web-6859f8c7b7-lwthj               2m           57Mi            
```

## Kyverno policies

```text
NAME                                   ADMISSION   BACKGROUND   READY   AGE    FAILURE POLICY   VALIDATE   MUTATE   GENERATE   VERIFY IMAGES   MESSAGE
securerag-audit-cleartext-env-values   true        true         True    166m                    1          0        0          0               Ready
securerag-require-pod-security         true        true         True    166m                    2          0        0          0               Ready
securerag-require-workload-controls    true        true         True    166m                    2          0        0          0               Ready
securerag-restrict-image-references    true        true         True    166m                    3          0        0          0               Ready
securerag-restrict-service-exposure    true        true         True    166m                    1          0        0          0               Ready
securerag-restrict-volume-types        true        true         True    166m                    1          0        0          0               Ready
securerag-verify-cosign-images         true        false        True    166m                    0          0        0          1               Ready
```

## Policy reports

```text
NAMESPACE       NAME                                                               KIND         NAME                                      PASS   FAIL   WARN   ERROR   SKIP   AGE
securerag-hub   policyreport.wgpolicyk8s.io/03f73506-96ab-4300-8730-4d821bfe7eb2   Deployment   conversation-service                      5      1      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/08aec842-a907-42e6-8aa3-826491530446   ReplicaSet   auth-users-58df94bcb8                     4      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/08ed2f51-b714-41cd-82dc-17e93fb40b84   Pod          auth-users-58df94bcb8-2cbgb               6      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/10d2332e-d6f2-4d32-ba9c-4294d8f71275   Pod          portal-web-6859f8c7b7-kjdgj               6      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/1965aabc-b568-4845-bb12-dd5a04c6761f   ReplicaSet   portal-web-676676cbdf                     4      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/1ec40370-ef54-4025-9ecb-12d4d4de86eb   ReplicaSet   audit-security-service-568984ff67         4      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/1f4cfed8-f22c-49d5-9035-e3d7ecdb3795   Pod          conversation-service-6c9f48ff84-tk7zx     6      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/216004af-8d94-443c-bcd3-3aa436e568f1   ReplicaSet   conversation-service-749bb7fc99           4      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/44561ac1-9616-4527-b1ba-4f9d20f0a90f   Deployment   portal-web                                5      1      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/56bee8be-968d-4b51-b213-e9dac6f53c96   ReplicaSet   portal-web-6859f8c7b7                     4      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/6378e464-7319-45a5-bf23-f96f224c0cbc   Pod          chatbot-manager-659cdc7cdc-db6dr          6      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/65edc1f5-fb8a-4779-b942-bf7b2d350297   Pod          audit-security-service-568984ff67-mmgg7   6      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/6fc3a056-f3d6-4a7d-8485-f71252fd5a06   Pod          portal-web-6859f8c7b7-k64rs               6      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/7598095a-54b1-4f13-8b84-670356654408   ReplicaSet   audit-security-service-b6b5b766d          4      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/7bd50a1d-c515-4224-bb58-e8c285938307   Deployment   auth-users                                5      1      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/7de21b8d-7b2d-452d-89c1-227d45b7cac6   Pod          audit-security-service-568984ff67-pjtzt   6      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/89783974-2085-42f0-a2d5-b8a1001be76f   Deployment   chatbot-manager                           5      1      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/9eba446d-e217-403b-9ae4-8354f139fd3f   Pod          portal-web-6859f8c7b7-lwthj               6      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/a923338c-173d-4cb6-b2e0-308dc4c3596d   Pod          conversation-service-6c9f48ff84-z8qhh     6      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/adc5e9bf-b5dc-454f-a1b2-659f56800259   Service      audit-security-service                    1      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/af7a79fb-4fae-4c5c-99c4-c48f6f75c9d7   ReplicaSet   conversation-service-6c9f48ff84           4      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/b259dc35-8405-47f8-9dd7-a9f46cb1ffa5   Service      conversation-service                      1      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/b30550fa-4323-49f7-991b-7b2bc4a2645b   Pod          auth-users-58df94bcb8-ncghs               6      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/c817afc3-0cf7-4167-867e-79c0cef7559f   ReplicaSet   chatbot-manager-5fcdb45757                4      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/cb2ea73e-d98e-4e97-bf27-57d3aab7356d   Service      portal-web                                1      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/d218a986-d8d3-42ff-b2c9-af62855acc89   Deployment   audit-security-service                    5      1      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/d47a51cf-e4d5-413b-911e-7a97dc540695   Service      auth-users                                1      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/de9d6614-8d80-4b4f-a848-1a9c67bc5889   ReplicaSet   auth-users-697479f954                     4      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/e85d1e13-5f5d-4f88-ba41-93b2cc3d8fe5   Service      chatbot-manager                           1      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/ef190e8b-9559-4fb8-a1de-fc3f4e49aabd   Pod          chatbot-manager-659cdc7cdc-25cgq          6      0      0      0       0      166m
securerag-hub   policyreport.wgpolicyk8s.io/f6641f60-9055-4222-a9f1-9f2a9c93fa0c   ReplicaSet   chatbot-manager-659cdc7cdc                4      0      0      0       0      166m
```

## Jenkins login endpoint

```text
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
curl: (7) Failed to connect to 127.0.0.1 port 8085 after 0 ms: Could not connect to server
```

## Reading guide

- If `kubectl top` fails, metrics-server is not ready or not installed.
- If HPA targets are `<unknown>`, metrics-server is not feeding resource metrics.
- If Kyverno policy reports are absent, Kyverno is not installed or policies have not generated reports yet.
- For the official demo, this snapshot is enough for a factual runtime proof. Prometheus/Grafana/Loki remain an optional expert extension.
