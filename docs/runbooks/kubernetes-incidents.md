# Kubernetes Incidents Runbook — SecureRAG Hub

> **Scope:** Kubernetes infrastructure incidents affecting cluster stability.
> **Namespace:** `securerag-hub` unless specified otherwise.

---

## 1. Pod CrashLoopBackOff

### Symptoms
- `kubectl get pods` shows `CrashLoopBackOff`
- `kubectl describe pod` shows `Back-off restarting failed container`
- Application logs show startup failure

### Diagnosis

```bash
# Check pod status
kubectl get pods -n securerag-hub | grep CrashLoopBackOff

# Describe pod for events
kubectl describe pod <pod-name> -n securerag-hub

# Check container logs (previous crashed instance)
kubectl logs <pod-name> -n securerag-hub --previous

# Check resource limits
kubectl describe pod <pod-name> -n securerag-hub | grep -A5 Limits

# Verify configmap and secret mounts
kubectl describe pod <pod-name> -n securerag-hub | grep -A10 Volumes

# Check if image exists
kubectl get pod <pod-name> -n securerag-hub -o jsonpath='{.spec.containers[*].image}'
```

### Resolution

1. **Get previous logs:** `kubectl logs <pod> --previous` — identify crash reason
2. **If OOMKilled:** Increase memory limits in deployment manifest
3. **If ImagePullBackOff:** Verify image tag/digest exists in registry
4. **If config error:** Check ConfigMap and Secret names match mount paths
5. **If dependency unavailable:** Check dependent services (DB, Redis, API)
6. **Restart:** `kubectl rollout restart deploy/<name> -n securerag-hub`
7. **Rollback:** `kubectl rollout undo deploy/<name> -n securerag-hub`

---

## 2. Node NotReady / Node Failure

### Symptoms
- `kubectl get nodes` shows `NotReady`
- Node conditions show `DiskPressure`, `MemoryPressure`, or `PIDPressure`
- Pods stuck in `Pending` or `Unknown` state

### Diagnosis

```bash
# List nodes and status
kubectl get nodes -o wide

# Describe failed node
kubectl describe node <node-name>

# Check node conditions
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}'

# Check node resource usage
kubectl top node <node-name>

# Check kubelet logs (requires SSH to node)
# journalctl -u kubelet -n 100 --no-pager

# List pods on failing node
kubectl get pods -n securerag-hub --field-selector spec.nodeName=<node-name>
```

### Resolution

1. **If DiskPressure:**
   - Free space on node: `df -h`
   - Clean old images: `docker image prune -a` or `crictl rmi --prune`
   - Increase `--eviction-hard` threshold if needed
2. **If MemoryPressure:**
   - Reduce resource requests on colocated pods
   - Evict non-critical pods: `kubectl drain <node> --ignore-daemonsets`
3. **If kubelet stopped:**
   - SSH to node: `sudo systemctl restart kubelet`
   - Check kubelet logs for errors
4. **If node unreachable:**
   - Cordon node: `kubectl cordon <node>`
   - Evict pods: `kubectl drain <node> --ignore-daemonsets --delete-emptydir-data`
   - Remove node from cluster if unrecoverable

---

## 3. HPA Failure (Horizontal Pod Autoscaler)

### Symptoms
- HPA unable to scale or read metrics
- `kubectl describe hpa` shows `FailedGetResourceMetric` or `FailedGetPodsMetric`
- Pods not scaling despite high load

### Diagnosis

```bash
# List HPAs
kubectl get hpa -n securerag-hub

# Describe HPA for events
kubectl describe hpa <hpa-name> -n securerag-hub

# Check if metrics-server is running
kubectl get deployment metrics-server -n kube-system

# Check metrics API availability
kubectl get --raw /apis/metrics.k8s.io/v1beta1

# Verify metrics-server logs
kubectl logs deployment/metrics-server -n kube-system

# Check pod resource requests (required for HPA)
kubectl get pod <pod> -n securerag-hub -o jsonpath='{.spec.containers[*].resources.requests}'
```

### Resolution

1. **If metrics-server down:**
   - Restart: `kubectl rollout restart deployment/metrics-server -n kube-system`
   - Check metrics-server flags: `--kubelet-insecure-tls` for self-signed certs
2. **If resource requests missing:**
   - Add `resources.requests.cpu/memory` to all container specs
   - HPA requires resource requests to calculate target utilization
3. **If custom metrics unavailable:**
   - Check Prometheus adapter deployment
   - Verify metric names match HPA configuration
4. **If target threshold unreachable:**
   - Adjust target average utilization
   - Set min/max replicas per service capacity planning

---

## 4. Persistent Volume Issues

### Symptoms
- Pods stuck in `Pending` or `ContainerCreating`
- Events show `FailedAttachVolume`, `FailedMount`, or `VolumeBinding`
- Application logs show I/O errors or read-only filesystem

### Diagnosis

```bash
# List PVCs
kubectl get pvc -n securerag-hub

# List PVs
kubectl get pv

# Describe PVC for events
kubectl describe pvc <pvc-name> -n securerag-hub

# Describe PV for details
kubectl describe pv <pv-name>

# Check pod volume mounts
kubectl describe pod <pod> -n securerag-hub | grep -A5 "Mounts:"
```

### Resolution

1. **If PVC pending:**
   - Check StorageClass exists: `kubectl get storageclass`
   - Verify provisioner pod is running (e.g., CSI driver)
2. **If PV mount fails:**
   - Check node has required CSI driver
   - Verify NFS/cloud storage endpoint accessible from nodes
3. **If filesystem full:**
   - Scale to 0, increase PV size, scale back
   - Or use `kubectl edit pvc` (if storage class supports expansion)
4. **If ReadOnlyMany conflict:**
   - Ensure concurrent pods use `ReadWriteMany` or `ReadOnlyMany` correctly
5. **Force delete stuck pod:** `kubectl delete pod <pod> --grace-period=0 --force`

**Recovery:** Restore from backup if data corruption suspected (see DR runbook).

---

## 5. Network Policy Blocks

### Symptoms
- Service-to-service connectivity failures
- `curl: (28) Connection timed out` between pods
- DNS resolution succeeds but connection refused
- `NetworkPolicy` events in `kubectl describe pod`

### Diagnosis

```bash
# List network policies
kubectl get networkpolicy -n securerag-hub

# Describe specific policy
kubectl describe networkpolicy <policy-name> -n securerag-hub

# Test connectivity with debug pod
kubectl run net-test --image=nicolaka/netshoot:latest -it --rm -- /bin/bash
# Inside pod: curl -v http://<service>:<port>

# Check DNS resolution
kubectl run dns-test --image=busybox:1.36 -it --rm -- nslookup <service>

# Check kube-proxy status
kubectl get pods -n kube-system -l k8s-app=kube-proxy
```

### Resolution

1. **Identify which policy blocks traffic:**
   - Use `kubectl describe networkpolicy` to examine rules
   - Check pod labels match policy selectors
2. **Temporarily disable policy (audit mode):**
   - Do NOT delete — policies are GitOps-controlled
   - Create an exception policy with correct pod/namespace selectors
3. **Fix common issues:**
   - `podSelector.matchLabels` must match target pod labels exactly
   - `ipBlock` rules must cover all egress paths
   - `namespaceSelector` must use correct namespace labels
4. **Verify:**
   - Re-run connectivity test
   - Check `kubectl get networkpolicy` shows expected policies

---

## 6. Certificate Expiry

### Symptoms
- TLS handshake errors in application logs
- Ingress/Gateway returns 502 or connection reset
- `certificate has expired` or `x509: certificate has expired` errors
- Prometheus shows `kube_certificate_expiry_days_seconds` approaching 0

### Diagnosis

```bash
# Check certificate expiry via OpenSSL
echo | openssl s_client -connect <hostname>:443 -servername <hostname> 2>/dev/null | openssl x509 -noout -dates

# List TLS secrets
kubectl get secret -n securerag-hub | grep tls

# Check certificate expiry from secrets
for secret in $(kubectl get secret -n securerag-hub -o name | grep tls); do
  cert=$(kubectl get $secret -n securerag-hub -o jsonpath='{.data.tls\.crt}')
  echo "$secret:"
  echo "$cert" | base64 -d | openssl x509 -noout -subject -dates 2>/dev/null
done

# Check cert-manager certificate resources
kubectl get certificate -A
kubectl describe certificate <cert-name> -n securerag-hub

# Check cert-manager logs
kubectl logs deployment/cert-manager -n cert-manager --tail=50
```

### Resolution

1. **If using cert-manager:**
   - Ensure `cert-manager` Issuer/ClusterIssuer is correctly configured
   - Check DNS propagation for ACME challenges
   - Force renewal: `kubectl cert-manager renew <cert-name>`
   - Or delete and re-create certificate resource
2. **If self-managed secrets:**
   - Generate new cert: `openssl req -x509 -newkey rsa:4096 -keyout tls.key -out tls.crt -days 365 -nodes`
   - Update secret: `kubectl create secret tls <name> --cert=tls.crt --key=tls.key -n securerag-hub --dry-run=client -o yaml | kubectl apply -f -`
3. **If ingress controller misconfigured:**
   - Verify ingress/gateway references correct secret name
   - Check `tls` section in Ingress/Gateway resource

---

## 7. Resource Exhaustion (CPU / Memory)

### Symptoms
- Pods restarting with OOMKilled status
- `kubectl top nodes` shows near-capacity usage
- Scheduler fails to place new pods — `0/2 nodes are available`
- Application latency increases gradually

### Diagnosis

```bash
# Node resource usage
kubectl top nodes

# Pod resource usage
kubectl top pods -n securerag-hub

# Check resource requests/limits
kubectl describe node <node> | grep -A10 "Allocated resources"

# Check for memory leaks
kubectl top pods -n securerag-hub --sort-by=memory

# List pods by QoS class
kubectl get pods -n securerag-hub -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass

# Check for non-critical pods consuming resources
kubectl get pods --all-namespaces --field-selector status.phase=Running
```

### Resolution

1. **Immediate (scale/relieve pressure):**
   - Increase HPA replicas or adjust resource limits
   - Cord non-critical pods: `kubectl scale deploy/<non-critical> --replicas=0`
   - Add node if cluster supports auto-scaling
2. **Short-term:**
   - Profile application for memory leaks
   - Adjust resource requests/limits based on actual usage patterns
   - Enable VPA (Vertical Pod Autoscaler) for batch workloads
3. **Long-term:**
   - Implement proper resource requests/limits across all deployments
   - Set up ResourceQuotas and LimitRanges per namespace
   - Add cluster-level monitoring and capacity planning

### Resource Sizing Guidelines

| Workload | CPU Request | CPU Limit | Memory Request | Memory Limit |
|----------|-------------|-----------|----------------|--------------|
| Portal Web | 100m | 500m | 128Mi | 512Mi |
| Auth Service | 100m | 300m | 128Mi | 256Mi |
| Chatbot API | 200m | 1000m | 256Mi | 1Gi |
| PostgreSQL | 500m | 2000m | 1Gi | 4Gi |
| Redis | 100m | 500m | 256Mi | 1Gi |

---

## 8. General Kubernetes Diagnostic Commands

```bash
# Cluster overview
kubectl cluster-info
kubectl get nodes -o wide
kubectl get namespaces

# Pod diagnostics
kubectl get pods -n securerag-hub -o wide
kubectl describe pod <name> -n securerag-hub
kubectl logs <name> -n securerag-hub --tail=100 -f

# Event monitoring
kubectl get events -n securerag-hub --sort-by='.lastTimestamp'

# Service diagnostics
kubectl get svc -n securerag-hub
kubectl get endpoints -n securerag-hub

# Config diagnostics
kubectl get configmap -n securerag-hub
kubectl get secret -n securerag-hub
```
