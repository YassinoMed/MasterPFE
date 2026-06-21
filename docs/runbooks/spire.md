# SPIRE Runbook — Workload Identity Operations

**Component:** SPIRE / SPIFFE  
**Namespace:** `spire`  
**Key files:** `infra/k8s/spire/`, `scripts/spire/`  
**Version:** 1.9.x

---

## 1. Checking SPIRE Health

### Server Health

```bash
# Check pod status
kubectl get pods -n spire -l app.kubernetes.io/name=spire-server

# Run health check from server pod
kubectl exec -n spire deploy/spire-server -- \
  /opt/spire/bin/spire-server healthcheck

# Expected output:
# Server is healthy

# Check leader election (HA mode)
kubectl logs -n spire -l app.kubernetes.io/name=spire-server --tail=10 | grep "leadership"
```

### Agent Health

```bash
# Check all agents are running
kubectl get pods -n spire -l app.kubernetes.io/name=spire-agent

# Run health check from each agent
kubectl exec -n spire ds/spire-agent -- \
  /opt/spire/bin/spire-agent healthcheck

# List attested agents on server
kubectl exec -n spire deploy/spire-server -- \
  /opt/spire/bin/spire-server agent list

# Expected output:
# Agent ID                                     SVID serial number  Expiration
# spiffe://securerag-hub.securerag.dev/node/...  abc123             2026-07-18 12:00:00 +0000 UTC
```

### CSI Driver Health

```bash
kubectl get pods -n spire -l app.kubernetes.io/name=spire-csi-driver
kubectl logs -n spire -l app.kubernetes.io/name=spire-csi-driver --tail=10
```

### Automated Health Check

```bash
# Run the validation script
bash scripts/spire/validate-spire.sh
```

### Prometheus Metrics

SPIRE server exposes metrics on port `8080`:

```bash
# Port-forward and check metrics
kubectl port-forward -n spire svc/spire-server 8080:8080 &
curl http://localhost:8080/metrics | grep spire_

# Key metrics to monitor
# spire_server_ca_expiry -- time until CA certificate expires
# spire_server_svid_count -- total SVIDs issued
# spire_server_agent_count -- attested agents
# spire_server_registration_entry_count -- registration entries
```

### Health Alert

If SPIRE health checks fail, a Prometheus alert fires:

```yaml
# Alert: SpireServerUnhealthy or SpireAgentNotAttested
- alert: SpireServerUnhealthy
  expr: up{job="spire-server"} == 0
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "SPIRE server is unhealthy"
```

---

## 2. Registering New Workloads

### Prerequisites

Before registering a workload, ensure:
1. The workload's ServiceAccount exists in the target namespace
2. The workload pod has consistent labels
3. The SPIFFE ID follows the naming convention

### Manual Registration

```bash
# Step 1: Create a registration entry
kubectl exec -n spire deploy/spire-server -- \
  /opt/spire/bin/spire-server entry create \
  --spiffeID "spiffe://securerag-hub.securerag.dev/new-service" \
  --parentID "spiffe://securerag-hub.securerag.dev/k8s-workload-registrar" \
  --selector "k8s:sa:securerag-hub:new-service-sa" \
  --ttl 3600

# Expected output:
# Entry ID: abcdef12-3456-7890-abcd-ef1234567890
```

### Automated Registration Script

```bash
# Edit the registration script to add the new service
vim scripts/spire/register-workloads.sh

# Add the new service entry:
/opt/spire/bin/spire-server entry create \
  --spiffeID "spiffe://securerag-hub.securerag.dev/new-service" \
  --parentID "spiffe://securerag-hub.securerag.dev/k8s-workload-registrar" \
  --selector "k8s:sa:securerag-hub:new-service-sa" \
  --ttl 3600

# Run the script
bash scripts/spire/register-workloads.sh
```

### Registration Entry Selectors

| Selector Type | Example | Description |
|--------------|---------|-------------|
| `k8s:sa` | `k8s:sa:securerag-hub:portal-web` | ServiceAccount match |
| `k8s:ns` | `k8s:ns:securerag-hub` | Namespace match |
| `k8s:container-image` | `k8s:container-image:nginx:1.25` | Container image match |
| `k8s:label` | `k8s:label:app.kubernetes.io/name:portal-web` | Label match |
| `k8s:node-name` | `k8s:node-name:worker-1` | Node match |

### Verifying Registration

```bash
# List all registration entries
kubectl exec -n spire deploy/spire-server -- \
  /opt/spire/bin/spire-server entry show

# Filter by SPIFFE ID
kubectl exec -n spire deploy/spire-server -- \
  /opt/spire/bin/spire-server entry show \
  --spiffeID "spiffe://securerag-hub.securerag.dev/new-service"

# Delete an entry (if misconfigured)
kubectl exec -n spire deploy/spire-server -- \
  /opt/spire/bin/spire-server entry delete \
  --entryID <entry-id>
```

### Batch Registration

For registering multiple workloads at once:

```bash
#!/bin/bash
# batch-register.sh
SERVICES=("service-a" "service-b" "service-c")

for service in "${SERVICES[@]}"; do
  kubectl exec -n spire deploy/spire-server -- \
    /opt/spire/bin/spire-server entry create \
    --spiffeID "spiffe://securerag-hub.securerag.dev/${service}" \
    --parentID "spiffe://securerag-hub.securerag.dev/k8s-workload-registrar" \
    --selector "k8s:sa:securerag-hub:${service}-sa" \
    --ttl 3600
done
```

---

## 3. Rotating CA Certificates

### Automatic Rotation

SPIRE handles CA rotation automatically with these defaults:

| Setting | Value | Description |
|---------|-------|-------------|
| `CA_svid_ttl` | 720h (30 days) | CA certificate validity |
| `default_svid_ttl` | 1h | Workload SVID validity |
| `ca_rotation_check_interval` | 5m | How often to check for rotation |

The rotation is seamless: SPIRE generates a new CA key while keeping the old one valid for overlapping period. All SVIDs signed with the old CA remain valid until they expire naturally.

### Manual CA Rotation

Force immediate CA rotation:

```bash
# Step 1: Trigger CA rotation on spire-server
kubectl exec -n spire deploy/spire-server -- \
  /opt/spire/bin/spire-server rotate \
  --signal

# Step 2: Verify new CA is in use
kubectl exec -n spire deploy/spire-server -- \
  /opt/spire/bin/spire-server bundle show \
  | openssl x509 -text -noout | head -20

# Step 3: Check agents have updated bundle
kubectl exec -n spire deploy/spire-server -- \
  /opt/spire/bin/spire-server bundle list
```

### Upstream CA Rotation (if using Vault PKI)

If SPIRE is configured with an upstream CA (e.g., Vault PKI):

```bash
# Step 1: Rotate the upstream CA in Vault
vault write -f pki/root/rotate \
  -format=json > /tmp/new-ca.json

# Step 2: Update SPIRE server config
kubectl edit configmap -n spire spire-server-config

# Update the upstream_authority plugin section
# upstream_authority:
#   vault:
#     ... updated config ...

# Step 3: Restart spire-server
kubectl rollout restart -n spire deploy/spire-server

# Step 4: Verify bundle
kubectl exec -n spire deploy/spire-server -- \
  /opt/spire/bin/spire-server bundle show
```

### Post-Rotation Verification

```bash
# Check CA expiry date
kubectl exec -n spire deploy/spire-server -- \
  /opt/spire/bin/spire-server bundle show \
  | openssl x509 -noout -enddate

# Expected: new expiry date (30 days from now)

# Verify workloads can still fetch SVIDs
kubectl exec -n securerag-hub deploy/portal-web -- \
  ls -la /var/run/secrets/spiffe/svid.crt

# Verify mTLS still works
kubectl exec -n securerag-hub deploy/portal-web -- \
  curl -s https://auth-users.securerag-hub:8000/health
```

---

## 4. Troubleshooting SVID Issuance

### Problem: Workload Cannot Fetch SVID

**Symptoms:**
- Pod logs: `"failed to dial SPIFFE Workload API"`
- Pod logs: `"no SPIFFE identity found"`
- `cat /var/run/secrets/spiffe/svid.crt` → empty or file not found

**Diagnosis Steps:**

```bash
# Step 1: Check SPIFFE socket exists
kubectl exec -n securerag-hub deploy/portal-web -- \
  ls -la /run/spire/agent-sockets/

# Step 2: Check workload attributes
kubectl get pod -n securerag-hub -l app.kubernetes.io/name=portal-web \
  -o jsonpath='{.items[0].spec.serviceAccount}'
# Expected: portal-web (or correct SA name)

# Step 3: Verify registration entry exists
kubectl exec -n spire deploy/spire-server -- \
  /opt/spire/bin/spire-server entry show \
  --spiffeID "spiffe://securerag-hub.securerag.dev/portal-web"

# Step 4: Check agent logs for attestation errors
kubectl logs -n spire -l app.kubernetes.io/name=spire-agent --tail=50 | grep -i error
```

**Common Causes and Resolutions:**

| Cause | Indicator | Resolution |
|-------|-----------|------------|
| Missing registration entry | `entry show` returns empty | Create entry via `entry create` |
| Wrong selector | SA mismatch | Fix selector in entry or pod SA |
| Agent not attested | `agent list` empty | Check agent → server connectivity |
| Socket permission denied | `Permission denied` on socket | Set `allowPrivilegeEscalation: true` in pod |
| CSI driver not running | `get pods` shows no CSI | Rollout restart CSI daemonset |

### Problem: Agent Fails to Attest to Server

**Symptoms:**
- Agent logs: `"failed to attest node"`
- Server logs: `"agent attestation failed"`
- `agent list` shows no agents

**Diagnosis:**

```bash
# Step 1: Check agent logs
kubectl logs -n spire -l app.kubernetes.io/name=spire-agent --tail=100

# Step 2: Check server logs
kubectl logs -n spire -l app.kubernetes.io/name=spire-server --tail=50

# Step 3: Verify network connectivity
kubectl exec -n spire ds/spire-agent -- \
  curl -s spire-server.spire.svc.cluster.local:8081/healthz

# Step 4: Check agent configuration
kubectl get configmap -n spire spire-agent-config -o yaml

# Step 5: Verify RBAC permissions
kubectl get clusterrole spire-agent -o yaml
# Must include: tokenreviews, pods, nodes, serviceaccounts
```

**Resolutions:**

```bash
# Fix RBAC
kubectl apply -f infra/k8s/spire/rbac-agent.yaml

# Restart agent
kubectl rollout restart -n spire ds/spire-agent

# If server is unreachable: check DNS and network policy
kubectl exec -n spire ds/spire-agent -- nslookup spire-server.spire.svc.cluster.local
```

### Problem: SVID Certificate Expired

**Symptoms:**
- mTLS handshake failures: `"certificate has expired"`
- Pod logs: `"x509: certificate has expired or is not yet valid"`

**Diagnosis:**

```bash
# Check SVID expiry
kubectl exec -n securerag-hub deploy/portal-web -- \
  openssl x509 -in /var/run/secrets/spiffe/svid.crt -noout -enddate

# Check agent SVID cache
kubectl exec -n spire deploy/spire-server -- \
  /opt/spire/bin/spire-server agent list
```

**Resolution:**

SVIDs are automatically rotated every hour (default\_svid\_ttl). If rotation fails:

```bash
# Restart the agent to force re-attestation
kubectl rollout restart -n spire ds/spire-agent

# After restart, verify new SVID
sleep 30
kubectl exec -n spire ds/spire-agent -- \
  /opt/spire/bin/spire-agent api fetch x509 -write /tmp/svid
openssl x509 -in /tmp/svid/svid.crt -noout -enddate
```

---

## 5. Debugging Agent Connectivity

### Agent Log Levels

```bash
# Check current log level
kubectl exec -n spire ds/spire-agent -- cat /etc/spire/agent/agent.conf | grep log_level

# Change to DEBUG (temporarily)
kubectl edit configmap -n spire spire-agent-config
# log_level: DEBUG

# Restart agent to pick up changes
kubectl rollout restart -n spire ds/spire-agent

# After debugging, revert to INFO
```

### Server-Agent Connectivity Test

```bash
# Test gRPC connectivity from agent to server
kubectl exec -n spire ds/spire-agent -- \
  /opt/spire/bin/spire-agent healthcheck --verbose

# Expected output:
# Connecting to SPIRE server...
# Connected to SPIRE server at spire-server.spire.svc.cluster.local:8081
# Agent is healthy

# If connection fails:
kubectl exec -n spire ds/spire-agent -- \
  curl -v spire-server.spire.svc.cluster.local:8081
```

### Network Policy Issues

If CiliumNetworkPolicy blocks SPIRE traffic:

```bash
# Check CiliumNetworkPolicy allows spire communication
kubectl get ciliumnetworkpolicies -n spire

# Verify agent → server flow
kubectl exec -n kube-system ds/cilium -- cilium policy trace \
  --src-k8s-pod spire:spire-agent-<pod-id> \
  --dst-k8s-pod spire:spire-server-<pod-id> \
  --dport 8081

# If blocked, allow API server access for k8s_psat
# SPIRE agent needs to reach Kubernetes API server
kubectl exec -n kube-system ds/cilium -- cilium policy trace \
  --src-k8s-pod spire:spire-agent-<pod-id> \
  --dst-k8s-pod kube-system:kube-apiserver-<pod-id> \
  --dport 6443
```

### Debugging Bundle Distribution

```bash
# Check bundle on server
kubectl exec -n spire deploy/spire-server -- \
  /opt/spire/bin/spire-server bundle show

# Check bundle on agent
kubectl exec -n spire ds/spire-agent -- \
  cat /var/run/spire/bundle.crt

# Force bundle push
kubectl exec -n spire deploy/spire-server -- \
  /opt/spire/bin/spire-server bundle set \
  --format=spiffe2 \
  --bundle-path=/tmp/bundle.crt
```

---

## 6. Common Issues and Solutions

### Issue: "no identity found" Error

**Cause:** The workload's ServiceAccount does not match any registration entry selector.

**Solution:**

```bash
# 1. Check what ServiceAccount the pod uses
kubectl get pod -n securerag-hub <pod-name> -o yaml | grep serviceAccount

# 2. Check existing registration entries
kubectl exec -n spire deploy/spire-server -- \
  /opt/spire/bin/spire-server entry show

# 3. Create matching entry if missing
kubectl exec -n spire deploy/spire-server -- \
  /opt/spire/bin/spire-server entry create \
  --spiffeID "spiffe://securerag-hub.securerag.dev/<service>" \
  --selector "k8s:sa:securerag-hub:<sa-name>" \
  --ttl 3600
```

### Issue: Agent Not Attesting

**Cause:** spire-agent cannot communicate with spire-server or lacks RBAC permissions.

**Solution:**

```bash
# 1. Verify server is running
kubectl get pod -n spire -l app.kubernetes.io/name=spire-server

# 2. Check RBAC
kubectl get clusterrole spire-agent -o yaml | grep -A5 rules

# 3. Check network
kubectl exec -n spire ds/spire-agent -- ping -c 3 spire-server.spire.svc

# 4. Restart both
kubectl rollout restart -n spire deploy/spire-server
kubectl rollout restart -n spire ds/spire-agent
```

### Issue: CSI Volume Mount Failure

**Cause:** CSI driver not installed or misconfigured.

**Solution:**

```bash
# 1. Check CSIDriver
kubectl get csidriver spiffe.csi.csi-driver

# 2. Check CSI driver pods
kubectl get pods -n spire -l app.kubernetes.io/name=spire-csi-driver

# 3. Check CSI node-registrar
kubectl logs -n spire -l app.kubernetes.io/name=spire-csi-driver -c node-driver-registrar

# 4. Re-apply CSI driver
kubectl apply -f infra/k8s/spire/csi-driver.yaml

# 5. If using Istio: ensure CSI driver has correct node selector
```

### Issue: High SVID Rotation Rate

**Cause:** `default_svid_ttl` too short for workload churn.

**Solution:**

```yaml
# Increase default_svid_ttl in spire-server ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: spire-server-config
  namespace: spire
data:
  server.conf: |
    server:
      default_svid_ttl: "4h"  # Default is 1h
```

### Issue: Server OOM / High Memory

**Cause:** Too many registration entries or agent connections.

**Solution:**

```bash
# 1. Check memory usage
kubectl top pod -n spire -l app.kubernetes.io/name=spire-server

# 2. Increase resource limits
kubectl edit statefulset -n spire spire-server
# resources:
#   limits:
#     memory: 512Mi
#   requests:
#     memory: 256Mi

# 3. Reduce unused registration entries
kubectl exec -n spire deploy/spire-server -- \
  /opt/spire/bin/spire-server entry list | grep -c "entry"

# 4. Consider horizontal scaling
```

### Issue: "failed to parse registration entry" Error

**Cause:** Invalid selector syntax in registration entry.

**Solution:**

```bash
# Check the correct syntax
kubectl exec -n spire deploy/spire-server -- \
  /opt/spire/bin/spire-server entry create \
  --help | grep selector

# Valid formats:
# k8s:sa:<namespace>:<sa-name>
# k8s:ns:<namespace>
# k8s:container-image:<image>
# k8s:label:<key>:<value>
```

### Issue: Clock Skew

**Symptoms:**
- SVID validation errors
- Certificate expiry errors despite valid dates

**Solution:**

```bash
# Check time sync on all nodes
kubectl get nodes -o wide | awk '{print $1}' | xargs -I {} \
  kubectl node-shell {} -- date

# Ensure NTP is configured
kubectl apply -f infra/k8s/chrony-daemonset.yaml

# Restart SPIRE components after clock sync
kubectl rollout restart -n spire deploy/spire-server
kubectl rollout restart -n spire ds/spire-agent
```

---

## Quick Reference

```bash
# Health checks
kubectl exec -n spire deploy/spire-server -- /opt/spire/bin/spire-server healthcheck
kubectl exec -n spire ds/spire-agent -- /opt/spire/bin/spire-agent healthcheck

# List agents
kubectl exec -n spire deploy/spire-server -- /opt/spire/bin/spire-server agent list

# List entries
kubectl exec -n spire deploy/spire-server -- /opt/spire/bin/spire-server entry show

# Create entry
kubectl exec -n spire deploy/spire-server -- \
  /opt/spire/bin/spire-server entry create \
  --spiffeID "spiffe://securerag-hub.securerag.dev/<service>" \
  --selector "k8s:sa:securerag-hub:<sa>" \
  --ttl 3600

# Delete entry
kubectl exec -n spire deploy/spire-server -- \
  /opt/spire/bin/spire-server entry delete --entryID <id>

# Fetch x509 SVID
kubectl exec -n spire ds/spire-agent -- \
  /opt/spire/bin/spire-agent api fetch x509

# Fetch JWT SVID
kubectl exec -n spire ds/spire-agent -- \
  /opt/spire/bin/spire-agent api fetch jwt -audience <audience>

# View logs
kubectl logs -n spire -l app.kubernetes.io/name=spire-server -f
kubectl logs -n spire -l app.kubernetes.io/name=spire-agent -f

# Restart
kubectl rollout restart -n spire deploy/spire-server
kubectl rollout restart -n spire ds/spire-agent
kubectl rollout restart -n spire ds/spire-csi-driver

# Full re-deploy
bash scripts/spire/deploy-spire.sh
```
