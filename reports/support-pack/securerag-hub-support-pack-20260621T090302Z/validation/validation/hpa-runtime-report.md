# HPA Runtime Report - SecureRAG Hub

- Generated at UTC: `2026-06-21T09:00:23Z`
- Namespace: `securerag-hub`
- Strict mode: `true`
- Status: `PARTIEL`

| Component | Check | Status | Evidence |
|---|---|---:|---|
| Kubernetes API | reachable | TERMINÉ | API server reachable |
| metrics-server | Metrics APIService Available | PARTIEL | APIService exists but is not Available |
| metrics-server | Deployment Ready | PARTIEL | ready=0/1 |
| kubectl top | nodes | PARTIEL | node metrics unavailable |
| kubectl top | pods | PARTIEL | pod metrics unavailable for securerag-hub |
| `portal-web` | HPA exists | TERMINÉ | HorizontalPodAutoscaler present |
| `portal-web` | runtime metrics populated | PARTIEL | missing=cpu |
| `portal-web` | HPA metric condition | PARTIEL | ScalingActive=FailedGetResourceMetric |
| `auth-users` | HPA exists | PARTIEL | missing |
| `chatbot-manager` | HPA exists | PARTIEL | missing |
| `conversation-service` | HPA exists | PARTIEL | missing |
| `audit-security-service` | HPA exists | PARTIEL | missing |

## Kubernetes context

```text
kind-securerag-dev
```

## Metrics APIService

```text
NAME                     SERVICE                      AVAILABLE                  AGE
v1beta1.metrics.k8s.io   kube-system/metrics-server   False (MissingEndpoints)   10m
```

## metrics-server deployment

```text
NAME             READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS       IMAGES                                                 SELECTOR
metrics-server   0/1     1            0           10m   metrics-server   registry.k8s.io/metrics-server/metrics-server:v0.8.0   k8s-app=metrics-server
```

## metrics-server pods

```text
NAME                              READY   STATUS             RESTARTS      AGE   IP            NODE                   NOMINATED NODE   READINESS GATES
metrics-server-65f5d57595-jtm5d   0/1     CrashLoopBackOff   7 (75s ago)   10m   10.244.1.13   securerag-dev-worker   <none>           <none>
```

## Node metrics

```text
error: Metrics API not available
```

## Pod metrics

```text
error: Metrics API not available
```

## HPA wide

```text
NAME         REFERENCE               TARGETS              MINPODS   MAXPODS   REPLICAS   AGE
portal-web   Deployment/portal-web   cpu: <unknown>/70%   1         3         1          10m
```

## HPA describe

```text
Name:                                                  portal-web
Namespace:                                             securerag-hub
Labels:                                                app.kubernetes.io/part-of=securerag-hub
Annotations:                                           kube-score/ignore:
                                                         pod-probes, container-security-context-user-group-id, deployment-replicas, networkpolicy-targets-pod, container-image-pull-policy, pod-net...
CreationTimestamp:                                     Sun, 21 Jun 2026 08:49:51 +0000
Reference:                                             Deployment/portal-web
Metrics:                                               ( current / target )
  resource cpu on pods  (as a percentage of request):  <unknown> / 70%
Min replicas:                                          1
Max replicas:                                          3
Deployment pods:                                       1 current / 0 desired
Conditions:
  Type           Status  Reason                   Message
  ----           ------  ------                   -------
  AbleToScale    True    SucceededGetScale        the HPA controller was able to get the target's current scale
  ScalingActive  False   FailedGetResourceMetric  the HPA was unable to compute the replica count: failed to get cpu utilization: unable to get metrics for resource cpu: unable to fetch metrics from resource metrics API: the server is currently unable to handle the request (get pods.metrics.k8s.io)
Events:
  Type     Reason                        Age                   From                       Message
  ----     ------                        ----                  ----                       -------
  Warning  FailedGetResourceMetric       10m                   horizontal-pod-autoscaler  failed to get cpu utilization: unable to get metrics for resource cpu: unable to fetch metrics from resource metrics API: the server could not find the requested resource (get pods.metrics.k8s.io)
  Warning  FailedComputeMetricsReplicas  10m                   horizontal-pod-autoscaler  invalid metrics (1 invalid out of 1), first error is: failed to get cpu resource metric value: failed to get cpu utilization: unable to get metrics for resource cpu: unable to fetch metrics from resource metrics API: the server could not find the requested resource (get pods.metrics.k8s.io)
  Warning  FailedComputeMetricsReplicas  7m53s (x11 over 10m)  horizontal-pod-autoscaler  invalid metrics (1 invalid out of 1), first error is: failed to get cpu resource metric value: failed to get cpu utilization: unable to get metrics for resource cpu: unable to fetch metrics from resource metrics API: the server is currently unable to handle the request (get pods.metrics.k8s.io)
  Warning  FailedGetResourceMetric       38s (x40 over 10m)    horizontal-pod-autoscaler  failed to get cpu utilization: unable to get metrics for resource cpu: unable to fetch metrics from resource metrics API: the server is currently unable to handle the request (get pods.metrics.k8s.io)
```

## Reading guide

- `TERMINÉ` means the command succeeded and runtime metrics are populated.
- `PARTIEL` means Kubernetes answered but metrics or HPA status are incomplete.
- `DÉPENDANT_DE_L_ENVIRONNEMENT` means a reachable cluster or metrics-server is required.
