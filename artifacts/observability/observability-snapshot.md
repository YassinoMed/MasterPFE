# Observability Snapshot - SecureRAG Hub

<<<<<<< HEAD
- Generated at: `2026-04-12T22:48:10Z`
=======
- Generated at: `2026-04-12T22:25:48Z`
>>>>>>> 5af92bc (securité)
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
NAME                               READY   UP-TO-DATE   AVAILABLE   AGE    CONTAINERS         IMAGES                                               SELECTOR
deployment.apps/api-gateway        1/1     1            1           2d4h   api-gateway        localhost:5001/securerag-hub-api-gateway:demo        app.kubernetes.io/name=api-gateway,app.kubernetes.io/part-of=securerag-hub
deployment.apps/auth-users         1/1     1            1           2d4h   auth-users         localhost:5001/securerag-hub-auth-users:demo         app.kubernetes.io/name=auth-users,app.kubernetes.io/part-of=securerag-hub
deployment.apps/chatbot-manager    1/1     1            1           2d4h   chatbot-manager    localhost:5001/securerag-hub-chatbot-manager:demo    app.kubernetes.io/name=chatbot-manager,app.kubernetes.io/part-of=securerag-hub
deployment.apps/knowledge-hub      1/1     1            1           2d4h   knowledge-hub      localhost:5001/securerag-hub-knowledge-hub:demo      app.kubernetes.io/name=knowledge-hub,app.kubernetes.io/part-of=securerag-hub
deployment.apps/llm-orchestrator   1/1     1            1           2d4h   llm-orchestrator   localhost:5001/securerag-hub-llm-orchestrator:demo   app.kubernetes.io/name=llm-orchestrator,app.kubernetes.io/part-of=securerag-hub
deployment.apps/ollama             1/1     1            1           2d4h   ollama             python:3.12-alpine                                   app.kubernetes.io/name=ollama,app.kubernetes.io/part-of=securerag-hub
deployment.apps/portal-web         1/1     1            1           2d4h   portal-web         localhost:5001/securerag-hub-portal-web:demo         app.kubernetes.io/name=portal-web,app.kubernetes.io/part-of=securerag-hub
deployment.apps/security-auditor   1/1     1            1           2d4h   security-auditor   localhost:5001/securerag-hub-security-auditor:demo   app.kubernetes.io/name=security-auditor,app.kubernetes.io/part-of=securerag-hub

NAME                      READY   AGE    CONTAINERS   IMAGES
statefulset.apps/qdrant   1/1     2d4h   qdrant       qdrant/qdrant:v1.16.3-unprivileged

NAME                                   READY   STATUS    RESTARTS   AGE    IP            NODE                   NOMINATED NODE   READINESS GATES
pod/api-gateway-6f9857c756-6mtmn       1/1     Running   0          2d2h   10.244.1.14   securerag-dev-worker   <none>           <none>
pod/auth-users-75756b67fb-slc98        1/1     Running   0          2d2h   10.244.1.15   securerag-dev-worker   <none>           <none>
pod/chatbot-manager-656f6dcb99-wkttd   1/1     Running   0          2d2h   10.244.1.17   securerag-dev-worker   <none>           <none>
pod/knowledge-hub-7d9bf9c97d-7fwrj     1/1     Running   0          2d2h   10.244.1.16   securerag-dev-worker   <none>           <none>
pod/llm-orchestrator-7c47b8775-ldlt9   1/1     Running   0          2d2h   10.244.1.20   securerag-dev-worker   <none>           <none>
pod/ollama-59d7478db-96dq8             1/1     Running   0          2d2h   10.244.1.19   securerag-dev-worker   <none>           <none>
pod/portal-web-5d5bd9464b-p2cmv        1/1     Running   0          2d2h   10.244.1.18   securerag-dev-worker   <none>           <none>
pod/qdrant-0                           1/1     Running   0          2d2h   10.244.1.22   securerag-dev-worker   <none>           <none>
pod/security-auditor-d669ff498-q2zw6   1/1     Running   0          2d2h   10.244.1.21   securerag-dev-worker   <none>           <none>

NAME                       TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE    SELECTOR
service/api-gateway        NodePort    10.96.245.35    <none>        8080:30080/TCP   2d4h   app.kubernetes.io/name=api-gateway,app.kubernetes.io/part-of=securerag-hub
service/auth-users         ClusterIP   10.96.180.250   <none>        8080/TCP         2d4h   app.kubernetes.io/name=auth-users,app.kubernetes.io/part-of=securerag-hub
service/chatbot-manager    ClusterIP   10.96.179.130   <none>        8080/TCP         2d4h   app.kubernetes.io/name=chatbot-manager,app.kubernetes.io/part-of=securerag-hub
service/knowledge-hub      ClusterIP   10.96.105.219   <none>        8080/TCP         2d4h   app.kubernetes.io/name=knowledge-hub,app.kubernetes.io/part-of=securerag-hub
service/llm-orchestrator   ClusterIP   10.96.54.104    <none>        8080/TCP         2d4h   app.kubernetes.io/name=llm-orchestrator,app.kubernetes.io/part-of=securerag-hub
service/ollama             ClusterIP   10.96.132.220   <none>        11434/TCP        2d4h   app.kubernetes.io/name=ollama,app.kubernetes.io/part-of=securerag-hub
service/portal-web         NodePort    10.96.139.118   <none>        8000:30081/TCP   2d4h   app.kubernetes.io/name=portal-web,app.kubernetes.io/part-of=securerag-hub
service/qdrant             ClusterIP   10.96.203.140   <none>        6333/TCP         2d4h   app.kubernetes.io/name=qdrant,app.kubernetes.io/part-of=securerag-hub
service/security-auditor   ClusterIP   10.96.104.199   <none>        8080/TCP         2d4h   app.kubernetes.io/name=security-auditor,app.kubernetes.io/part-of=securerag-hub
```

## HPA

```text
NAME          REFERENCE                TARGETS              MINPODS   MAXPODS   REPLICAS   AGE
api-gateway   Deployment/api-gateway   cpu: <unknown>/70%   1         3         1          2d4h
portal-web    Deployment/portal-web    cpu: <unknown>/70%   1         3         1          2d4h
```

## PDB

```text
NAME                   MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
api-gateway-pdb        1               N/A               0                     2d4h
llm-orchestrator-pdb   1               N/A               0                     2d4h
portal-web-pdb         1               N/A               0                     2d4h
qdrant-pdb             1               N/A               0                     2d4h
```

## Recent namespace events

```text
LAST SEEN   TYPE      REASON                    OBJECT                                MESSAGE
105s        Warning   FailedGetResourceMetric   horizontalpodautoscaler/api-gateway   failed to get cpu utilization: unable to get metrics for resource cpu: unable to fetch metrics from resource metrics API: the server could not find the requested resource (get pods.metrics.k8s.io)
105s        Warning   FailedGetResourceMetric   horizontalpodautoscaler/portal-web    failed to get cpu utilization: unable to get metrics for resource cpu: unable to fetch metrics from resource metrics API: the server could not find the requested resource (get pods.metrics.k8s.io)
```

## Metrics API

```text
Error from server (NotFound): apiservices.apiregistration.k8s.io "v1beta1.metrics.k8s.io" not found
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
error: the server doesn't have a resource type "clusterpolicy"
```

## Policy reports

```text
error: the server doesn't have a resource type "policyreport"
```

## Jenkins login endpoint

```text
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
HTTP/1.1 200 OK
Server: Jetty(12.1.5)
Date: Sun, 12 Apr 2026 22:48:11 GMT
X-Content-Type-Options: nosniff
Reporting-Endpoints: content-security-policy: http://localhost:8085/content-security-policy-reporting-endpoint/YfNyZzPQmj2ZD1fibOv_WPlMt3k2GYgK9eYPXreI688=:YW5vbnltb3Vz:aHVkc29uLm1vZGVsLkh1ZHNvbg==:bG9naW4=
Content-Security-Policy-Report-Only: base-uri 'none'; default-src 'self'; form-action 'self'; frame-ancestors 'self'; img-src 'self' data:; script-src 'report-sample' 'self' usage.jenkins.io; style-src 'report-sample' 'self' 'unsafe-inline'; report-to content-security-policy; report-uri http://localhost:8085/content-security-policy-reporting-endpoint/YfNyZzPQmj2ZD1fibOv_WPlMt3k2GYgK9eYPXreI688=:YW5vbnltb3Vz:aHVkc29uLm1vZGVsLkh1ZHNvbg==:bG9naW4=
Content-Type: text/html;charset=utf-8
Expires: Thu, 01 Jan 1970 00:00:00 GMT
Cache-Control: no-cache,no-store,must-revalidate
X-Hudson: 1.395
X-Jenkins: 2.541.3
X-Jenkins-Session: 22c28945
X-Frame-Options: sameorigin
X-Instance-Identity: MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAzWWZNdkJ8g4D8S2iaGz3iwqm9NX4l1CIyeTMfjvU9iqrYNPmivgR4BO4FNEzjxBwBBYkMZGoDqu5Ucd6GL3T9la+05h8tbiWpcaTyag2f2k6A2RelaMSjNdAGK+ijmb/QMJnG8nlWWjFcQOnwF18eZV0V3QuxRk/1vm82opzj3Dh1XjvUMEh/FrmxITq1BPsFcQ1EwR7km3kE8XV9Au34lnblMUuG2+1Mp98A/M5s6OcvKnTOIIUkhDUVd/4oxchgWjJ522UNieWdBQRZ2TOjhvub9vdEBtSUPWx2Mh98zF11dh/iYyskhYuk+PPn3ZTOPHbeAJN0z8Bp2MUJdFprwIDAQAB
Set-Cookie: JSESSIONID.811b5843=node0jrnhsdfsfa4x18ehc9xgu0p013515.node0; Path=/; HttpOnly; SameSite=Lax
Transfer-Encoding: chunked

```

## Reading guide

- If `kubectl top` fails, metrics-server is not ready or not installed.
- If HPA targets are `<unknown>`, metrics-server is not feeding resource metrics.
- If Kyverno policy reports are absent, Kyverno is not installed or policies have not generated reports yet.
- For the official demo, this snapshot is enough for a factual runtime proof. Prometheus/Grafana/Loki remain an optional expert extension.
