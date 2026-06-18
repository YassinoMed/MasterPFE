# Zero Trust Network Architecture — SecureRAG Hub

**Version:** 1.0  
**Last updated:** June 2026  
**Component:** `infra/k8s/cilium/network-policies/`

---

## Architecture Overview

The SecureRAG Hub implements a Zero Trust Network Architecture (ZTNA) using CiliumNetworkPolicy CRDs. The core principle is **default-deny** — all traffic is blocked unless explicitly allowed by a policy.

```
                         ┌─────────────────────────┐
                         │   Internet / Ingress     │
                         │   (API Gateway / Nginx)  │
                         └────────────┬────────────┘
                                      │
                         ┌────────────▼────────────┐
                         │   Default-Deny Ingress   │
                         │   (CiliumClusterwide)    │
                         └────────────┬────────────┘
                                      │
              ┌───────────────────────┼───────────────────────┐
              │                       │                       │
     ┌────────▼────────┐   ┌─────────▼────────┐   ┌─────────▼────────┐
     │  securerag-hub   │   │   monitoring     │   │    istio-system  │
     │  Micro-segmented │   │  Prom scraping   │   │   Service Mesh   │
     │  per-service     │   │  limited egress  │   │   control plane  │
     └────────┬────────┘   └─────────┬────────┘   └─────────┬────────┘
              │                      │                      │
     ┌────────▼────────┐   ┌─────────▼────────┐   ┌─────────▼────────┐
     │    spire        │   │    vault         │   │    velero        │
     │  SPIFFE mTLS    │   │  secrets access  │   │  backup traffic  │
     │  ingress only   │   │  limited clients │   │  to MinIO        │
     └─────────────────┘   └──────────────────┘   └──────────────────┘
```

### Principles

| Principle | Implementation | Enforcement |
|-----------|---------------|-------------|
| **Default-deny** | CiliumClusterwideNetworkPolicy | All ingress/egress denied unless permitted |
| **Micro-segmentation** | Per-service CiliumNetworkPolicy | Only required service-to-service traffic |
| **Least privilege** | Minimal port/protocol scoping | TCP/UDP only on required ports |
| **Identity-aware** | SPIFFE + labels | Policies match on pod labels, not IPs |
| **Continuous verification** | Cilium + Hubble | Every connection is authenticated & authorized |
| **Lateral movement prevention** | Per-namespace isolation | No cross-namespace traffic without explicit policy |

---

## Default-Deny Ingress/Egress

### Cluster-Wide Default Deny

A CiliumClusterwideNetworkPolicy enforces default-deny across the entire cluster:

```yaml
# infra/k8s/cilium/network-policies/00-default-deny.yaml
apiVersion: cilium.io/v2
kind: CiliumClusterwideNetworkPolicy
metadata:
  name: default-deny-ingress-egress
spec:
  description: "Default-deny all ingress and egress traffic cluster-wide"
  endpointSelector:
    matchLabels: {}
  ingress:
    - fromEndpoints:
        - matchLabels: {}
      # Empty — no ingress rules means deny all
  egress:
    - toEndpoints:
        - matchLabels: {}
      # Empty — no egress rules means deny all
---
apiVersion: cilium.io/v2
kind: CiliumClusterwideNetworkPolicy
metadata:
  name: allow-dns-egress
spec:
  description: "Allow DNS resolution for all pods"
  endpointSelector:
    matchLabels: {}
  egress:
    - toPorts:
        - ports:
            - port: "53"
              protocol: UDP
          rules:
            dns:
              - matchPattern: "*"
      toEndpoints:
        - matchLabels:
            k8s-app: kube-dns
      # Also allow DNS on TCP for large responses
    - toPorts:
        - ports:
            - port: "53"
              protocol: TCP
      toEndpoints:
        - matchLabels:
            k8s-app: kube-dns
```

### Namespace Isolation

Each namespace gets its own default-deny policy:

```yaml
# infra/k8s/cilium/network-policies/01-namespace-isolation.yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: default-deny
  namespace: securerag-hub
spec:
  description: "Default-deny all traffic in securerag-hub namespace"
  endpointSelector:
    matchLabels: {}
  ingress:
    - fromEndpoints:
        - matchLabels: {}
  egress:
    - toEndpoints:
        - matchLabels: {}
```

### Verification

```bash
# Verify default-deny is active
kubectl get ciliumclusterwidenetworkpolicies
kubectl get ciliumnetworkpolicies -A

# Test connectivity (should fail without explicit policy)
kubectl exec -n securerag-hub deploy/portal-web -- \
  curl -m 3 http://auth-users.securerag-hub:8000/health
# Expected: connection timeout / refused
```

---

## Per-Service Micro-Segmentation

### Service Topology

```
     portal-web ──────────────────────────────────┐
        │                                          │
        │  (health)                                │
        │                                          │
        ├──auth-users:8000 ──── vault:8200 ────────┤
        │                                          │
        ├──chatbot-manager:50051 ──┐               │
        │                          │               │
        │                   conversation:50051 ────┤
        │                                          │
        └──audit-security:8001 ────────────────────┘
                             postgresql-ha:5432
```

### Service-to-Service Policies

**portal-web** — Frontend gateway; ingress from nginx, egress to auth-users & chatbot:

```yaml
# infra/k8s/cilium/network-policies/portal-web.yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: portal-web-network-policy
  namespace: securerag-hub
spec:
  description: "Network policy for portal-web"
  endpointSelector:
    matchLabels:
      app.kubernetes.io/name: portal-web
      app.kubernetes.io/component: frontend
  ingress:
    - fromEndpoints:
        - matchLabels:
            app.kubernetes.io/name: nginx-ingress
            app.kubernetes.io/component: controller
      toPorts:
        - ports:
            - port: "8080"
              protocol: TCP
  egress:
    - toEndpoints:
        - matchLabels:
            app.kubernetes.io/name: auth-users
      toPorts:
        - ports:
            - port: "8000"
              protocol: TCP
    - toEndpoints:
        - matchLabels:
            app.kubernetes.io/name: chatbot-manager
      toPorts:
        - ports:
            - port: "50051"
              protocol: TCP
    - toEndpoints:
        - matchLabels:
            app.kubernetes.io/name: audit-security-service
      toPorts:
        - ports:
            - port: "8001"
              protocol: TCP
```

**auth-users** — Authentication service; ingress from portal-web, egress to vault & postgresql:

```yaml
# infra/k8s/cilium/network-policies/auth-users.yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: auth-users-network-policy
  namespace: securerag-hub
spec:
  description: "Network policy for auth-users"
  endpointSelector:
    matchLabels:
      app.kubernetes.io/name: auth-users
  ingress:
    - fromEndpoints:
        - matchLabels:
            app.kubernetes.io/name: portal-web
      toPorts:
        - ports:
            - port: "8000"
              protocol: TCP
  egress:
    - toEndpoints:
        - matchLabels:
            app.kubernetes.io/name: vault
        - matchLabels:
            app.kubernetes.io/instance: vault
        - matchLabels:
            app.kubernetes.io/name: vault-agent-injector
      toPorts:
        - ports:
            - port: "8200"
              protocol: TCP
    - toEndpoints:
        - matchLabels:
            app.kubernetes.io/name: postgresql-ha
            app.kubernetes.io/component: database
      toPorts:
        - ports:
            - port: "5432"
              protocol: TCP
```

**chatbot-manager** — gRPC orchestrator; ingress from portal-web, egress to conversation:

```yaml
# infra/k8s/cilium/network-policies/chatbot-manager.yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: chatbot-manager-network-policy
  namespace: securerag-hub
spec:
  description: "Network policy for chatbot-manager"
  endpointSelector:
    matchLabels:
      app.kubernetes.io/name: chatbot-manager
  ingress:
    - fromEndpoints:
        - matchLabels:
            app.kubernetes.io/name: portal-web
      toPorts:
        - ports:
            - port: "50051"
              protocol: TCP
  egress:
    - toEndpoints:
        - matchLabels:
            app.kubernetes.io/name: conversation-service
      toPorts:
        - ports:
            - port: "50051"
              protocol: TCP
```

**conversation-service** — Chat logic; ingress from chatbot-manager:

```yaml
# infra/k8s/cilium/network-policies/conversation-service.yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: conversation-network-policy
  namespace: securerag-hub
spec:
  description: "Network policy for conversation-service"
  endpointSelector:
    matchLabels:
      app.kubernetes.io/name: conversation-service
  ingress:
    - fromEndpoints:
        - matchLabels:
            app.kubernetes.io/name: chatbot-manager
      toPorts:
        - ports:
            - port: "50051"
              protocol: TCP
```

**audit-security-service** — Audit logging; ingress from portal-web:

```yaml
# infra/k8s/cilium/network-policies/audit-security-service.yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: audit-network-policy
  namespace: securerag-hub
spec:
  description: "Network policy for audit-security-service"
  endpointSelector:
    matchLabels:
      app.kubernetes.io/name: audit-security-service
  ingress:
    - fromEndpoints:
        - matchLabels:
            app.kubernetes.io/name: portal-web
      toPorts:
        - ports:
            - port: "8001"
              protocol: TCP
```

### Policy Verification Matrix

| Source | Destination | Port | Protocol | Allowed |
|--------|-------------|:----:|:--------:|:-------:|
| `nginx-ingress` | `portal-web` | 8080 | TCP | ✅ |
| `portal-web` | `auth-users` | 8000 | TCP | ✅ |
| `portal-web` | `chatbot-manager` | 50051 | TCP | ✅ |
| `portal-web` | `audit-security-service` | 8001 | TCP | ✅ |
| `auth-users` | `vault` | 8200 | TCP | ✅ |
| `auth-users` | `postgresql-ha` | 5432 | TCP | ✅ |
| `chatbot-manager` | `conversation-service` | 50051 | TCP | ✅ |
| Any service | Any service | any | any | ❌ (default) |
| Any pod | Internet | any | any | ❌ (default) |

---

## Service Mesh Integration (Istio)

### Architecture

Istio is integrated with CiliumNetworkPolicy for defense-in-depth. Cilium enforces L3/L4 policies at the kernel level (eBPF), while Istio enforces L7 policies at the sidecar proxy.

```
┌─────────────────────────────────────────────────────────────┐
│                      Pod                                    │
│  ┌─────────────────────────────────────┐                    │
│  │  Application Container              │                    │
│  └──────────────┬──────────────────────┘                    │
│                 │ localhost:15000                           │
│  ┌──────────────▼──────────────────────┐                    │
│  │  Istio Proxy (Envoy sidecar)        │                    │
│  │  - L7 auth (JWT, mTLS)             │                    │
│  │  - HTTP routing, retries           │                    │
│  └──────────────┬──────────────────────┘                    │
│                 │                                           │
│  ┌──────────────▼──────────────────────┐                    │
│  │  Cilium eBPF (kernel)               │                    │
│  │  - L3/L4 enforcement                │                    │
│  │  - identity-aware (labels)          │                    │
│  │  - default-deny                     │                    │
│  └─────────────────────────────────────┘                    │
└─────────────────────────────────────────────────────────────┘
```

### Istio mTLS Configuration

```yaml
# PeerAuthentication for strict mTLS
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: securerag-hub-mtls
  namespace: securerag-hub
spec:
  mtls:
    mode: STRICT
```

### Cilium + Istio Compatibility

CiliumNetworkPolicies reference the Istio sidecar proxy ports:

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: portal-web-istio-compat
  namespace: securerag-hub
spec:
  endpointSelector:
    matchLabels:
      app.kubernetes.io/name: portal-web
  ingress:
    - fromEndpoints:
        - matchLabels:
            app.kubernetes.io/name: nginx-ingress
      toPorts:
        - ports:
            - port: "8080"   # Application port
              protocol: TCP
            - port: "15006"  # Istio inbound
              protocol: TCP
            - port: "15001"  # Istio outbound
              protocol: TCP
```

### Traffic Flow with Istio

1. **Inbound**: Nginx → Istio IngressGateway → `portal-web:8080` (via sidecar)
2. **Service-to-service**: `portal-web` sidecar (15001) → `auth-users` sidecar (15006) → `auth-users:8000`
3. **mTLS handshake**: Istio proxies negotiate mTLS using SPIFFE identities (via SPIRE)
4. **Cilium validates**: L3/L4 policy check on the encrypted tunnel

---

## DNS and Monitoring Exceptions

### DNS Resolution

All pods require DNS resolution. The `allow-dns-egress` CiliumClusterwideNetworkPolicy ensures DNS always works:

```yaml
# Already applied in default-deny section
- egress:
    - toPorts:
        - ports:
            - port: "53"
              protocol: UDP
            - port: "53"
              protocol: TCP
      toEndpoints:
        - matchLabels:
            k8s-app: kube-dns
```

### NodeLocal DNSCache

For low-latency DNS, use NodeLocal DNSCache:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/kubernetes/master/cluster/addons/dns/nodelocaldns/nodelocaldns.yaml
```

### Monitoring Exceptions

Prometheus scraping requires ingress access to `/metrics` endpoints:

```yaml
# infra/k8s/cilium/network-policies/monitoring-exceptions.yaml
apiVersion: cilium.io/v2
kind: CiliumClusterwideNetworkPolicy
metadata:
  name: allow-prometheus-scraping
spec:
  description: "Allow Prometheus to scrape /metrics from all namespaces"
  endpointSelector:
    matchLabels:
      prometheus.io/scrape: "true"
  ingress:
    - fromEndpoints:
        - matchLabels:
            app.kubernetes.io/name: prometheus
            app.kubernetes.io/component: server
          matchNamespaces:
            - monitoring
      toPorts:
        - ports:
            - port: "9090"   # Prometheus default
              protocol: TCP
            - port: "8080"   # Common metrics port
              protocol: TCP
            - port: "9100"   # Node exporter
              protocol: TCP
            - port: "10250"  # kubelet metrics
              protocol: TCP
---
apiVersion: cilium.io/v2
kind: CiliumClusterwideNetworkPolicy
metadata:
  name: allow-grafana-ingress
spec:
  description: "Allow ingress to Grafana dashboard"
  endpointSelector:
    matchLabels:
      app.kubernetes.io/name: grafana
  ingress:
    - fromEndpoints:
        - matchLabels:
            app.kubernetes.io/name: nginx-ingress
      toPorts:
        - ports:
            - port: "3000"   # Grafana port
              protocol: TCP
```

### Hubble UI

Allow Hubble UI for network observability:

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-hubble-ui
  namespace: kube-system
spec:
  description: "Allow ingress to Hubble UI"
  endpointSelector:
    matchLabels:
      k8s-app: hubble-ui
  ingress:
    - fromEndpoints:
        - matchLabels:
            app.kubernetes.io/name: nginx-ingress
      toPorts:
        - ports:
            - port: "12000"
              protocol: TCP
```

---

## Prometheus Scraping Allowances

### Cluster-Level Monitoring

The monitoring infrastructure has specific network allowances:

```yaml
# infra/k8s/cilium/network-policies/prometheus-egress.yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: prometheus-egress
  namespace: monitoring
spec:
  description: "Allow Prometheus to scrape targets across namespaces"
  endpointSelector:
    matchLabels:
      app.kubernetes.io/name: prometheus
  egress:
    - toEndpoints:
        - matchLabels:
            app.kubernetes.io/name: trivy-operator
      toPorts:
        - ports:
            - port: "8080"
              protocol: TCP
    - toEndpoints:
        - matchLabels:
            app.kubernetes.io/name: opensearch
      toPorts:
        - ports:
            - port: "9200"
              protocol: TCP
    - toEndpoints:
        - matchLabels:
            app.kubernetes.io/name: ratify
      toPorts:
        - ports:
            - port: "6001"
              protocol: TCP
    # Scrape all pods with prometheus.io/scrape=true label
    - toEndpoints:
        - matchLabels:
            prometheus.io/scrape: "true"
      toPorts:
        - ports:
            - port: "9090"
              protocol: TCP
            - port: "8080"
              protocol: TCP
            - port: "9100"
              protocol: TCP
```

### Node Exporter

```yaml
apiVersion: cilium.io/v2
kind: CiliumClusterwideNetworkPolicy
metadata:
  name: allow-node-exporter
spec:
  description: "Allow Prometheus to scrape node-exporter on all nodes"
  endpointSelector:
    matchLabels:
      app.kubernetes.io/name: prometheus-node-exporter
  ingress:
    - fromEndpoints:
        - matchLabels:
            app.kubernetes.io/name: prometheus
            app.kubernetes.io/component: server
      toPorts:
        - ports:
            - port: "9100"
              protocol: TCP
```

### kubelet Metrics

```yaml
apiVersion: cilium.io/v2
kind: CiliumClusterwideNetworkPolicy
metadata:
  name: allow-kubelet-metrics
spec:
  description: "Allow Prometheus to scrape kubelet metrics"
  endpointSelector:
    matchLabels:
      app.kubernetes.io/name: prometheus
  egress:
    - toEntities:
        - host
      toPorts:
        - ports:
            - port: "10250"
              protocol: TCP
```

### Alertmanager

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: alertmanager-ingress
  namespace: monitoring
spec:
  description: "Allow ingress to Alertmanager from Prometheus"
  endpointSelector:
    matchLabels:
      app.kubernetes.io/name: alertmanager
  ingress:
    - fromEndpoints:
        - matchLabels:
            app.kubernetes.io/name: prometheus
      toPorts:
        - ports:
            - port: "9093"
              protocol: TCP
    - fromEndpoints:
        - matchLabels:
            app.kubernetes.io/name: nginx-ingress
      toPorts:
        - ports:
            - port: "9093"
              protocol: TCP
```

---

## Vault and Velero Access

### Vault Network Policy

```yaml
# infra/k8s/cilium/network-policies/vault-policy.yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: vault-network-policy
  namespace: vault
spec:
  description: "Network policy for Vault — only auth-users should access"
  endpointSelector:
    matchLabels:
      app.kubernetes.io/name: vault
  ingress:
    - fromEndpoints:
        - matchLabels:
            app.kubernetes.io/name: auth-users
          matchNamespaces:
            - securerag-hub
      toPorts:
        - ports:
            - port: "8200"
              protocol: TCP
  egress:
    - toEndpoints:
        - matchLabels:
            app.kubernetes.io/name: vault
            app.kubernetes.io/component: ha
      toPorts:
        - ports:
            - port: "8201"
              protocol: TCP
    - toEndpoints:
        - matchLabels:
            k8s-app: kube-dns
      toPorts:
        - ports:
            - port: "53"
              protocol: UDP
```

### Velero Network Policy

Velero needs egress to the backup storage (MinIO/S3) and ingress for restore operations:

```yaml
# infra/k8s/cilium/network-policies/velero-policy.yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: velero-network-policy
  namespace: velero
spec:
  description: "Network policy for Velero backup/restore"
  endpointSelector:
    matchLabels:
      app.kubernetes.io/name: velero
  egress:
    - toFQDNs:
        - matchName: "minio.securerag-hub.svc.cluster.local"
      toPorts:
        - ports:
            - port: "9000"
              protocol: TCP
    - toFQDNs:
        - matchPattern: "*.s3.*.amazonaws.com"
      toPorts:
        - ports:
            - port: "443"
              protocol: TCP
    - toEndpoints:
        - matchLabels:
            k8s-app: kube-dns
      toPorts:
        - ports:
            - port: "53"
              protocol: UDP
  ingress:
    - fromEndpoints:
        - matchLabels:
            app.kubernetes.io/name: portal-web
      toPorts:
        - ports:
            - port: "8080"
              protocol: TCP
```

---

## Network Policy Management

### Policy Lifecycle

```
CREATE (git push)
  → CI validates YAML with conftest
  → CD applies via kubectl / ArgoCD
  → Hubble shows policy in effect
  → Verify with connectivity test

MODIFY (git push)
  → CI validates changed policy
  → CD applies update
  → Old policy replaced

DELETE (git push)
  → CI validates no orphaned policies
  → CD removes policy
  → Verify connectivity regressions
```

### Policy Auditing with Hubble

```bash
# Monitor all flows in securerag-hub
hubble observe --namespace securerag-hub

# Watch flows for a specific pod
hubble observe --pod portal-web-7d8f9-abc12

# Show dropped packets only
hubble observe --verdict DROPPED

# Export flows to JSON for analysis
hubble observe --output jsonf \
  -o json | jq 'select(.verdict == "DROPPED") | {source, destination, port: .l4}'
```

### Policy Validation in CI

The CI pipeline validates all network policies:

```bash
# scripts/ci/validate-network-policies.sh
#!/bin/bash
set -euo pipefail

echo "=== Validating CiliumNetworkPolicies ==="

# Validate YAML syntax
for f in infra/k8s/cilium/network-policies/*.yaml; do
  echo "Checking $f..."
  kubectl apply --validate=true --dry-run=client -f "$f"
done

# Check for overlapping policies
# Check for unused policies
echo "=== Validation complete ==="
```

### Policy Management Commands

```bash
# Apply all network policies
kubectl apply -f infra/k8s/cilium/network-policies/

# List all policies
kubectl get ciliumnetworkpolicies -A
kubectl get ciliumclusterwidenetworkpolicies

# Describe a specific policy
kubectl describe ciliumnetworkpolicy -n securerag-hub portal-web-network-policy

# Delete a policy
kubectl delete ciliumnetworkpolicy -n securerag-hub portal-web-network-policy

# Check policy enforcement status
kubectl get ciliumendpoints -n securerag-hub

# View policy verdict metrics
kubectl exec -n kube-system ds/cilium -- cilium endpoint list
kubectl exec -n kube-system ds/cilium -- cilium policy trace \
  --src-k8s-pod securerag-hub:portal-web-7d8f9-abc12 \
  --dst-k8s-pod securerag-hub:auth-users-6b5fc-xyz34 \
  --dport 8000
```

---

## Troubleshooting Connectivity

### Common Issues and Solutions

#### Problem: Pod cannot reach another service

**Symptoms:**
- Connection timed out or refused
- `curl: (28) Connection timed out` / `Connection refused`

**Diagnosis:**

```bash
# Step 1: Verify policy exists
kubectl get ciliumnetworkpolicies -n securerag-hub

# Step 2: Check endpoint identity
kubectl exec -n kube-system ds/cilium -- cilium endpoint list \
  | grep -E "portal-web|auth-users"

# Step 3: Trace policy decision
kubectl exec -n kube-system ds/cilium -- cilium policy trace \
  --src-k8s-pod securerag-hub:portal-web-<pod-id> \
  --dst-k8s-pod securerag-hub:auth-users-<pod-id> \
  --dport 8000

# Step 4: Check Hubble flows
hubble observe --namespace securerag-hub --verdict DROPPED
```

**Common Causes and Resolutions:**

| Cause | Check | Fix |
|-------|-------|-----|
| Missing policy | `kubectl get ciliumnetworkpolicies` | Create/apply the policy YAML |
| Wrong label selector | `kubectl get pod -n securerag-hub --show-labels` | Fix `matchLabels` in policy |
| Wrong port | Check actual container port | Update `toPorts.ports[].port` |
| Namespace mismatch | `kubectl get ns` | Ensure `matchNamespaces` includes source/dest |
| Cilium agent not running | `kubectl get pod -n kube-system -l k8s-app=cilium` | Restart Cilium daemonset |

#### Problem: DNS not resolving

```bash
# Check DNS policy is applied
kubectl get ciliumclusterwidenetworkpolicy allow-dns-egress

# Verify DNS resolution
kubectl exec -n securerag-hub deploy/portal-web -- \
  nslookup auth-users.securerag-hub.svc.cluster.local

# Check kube-dns is up
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Restart coredns if needed
kubectl rollout restart -n kube-system deployment/coredns
```

#### Problem: Prometheus cannot scrape metrics

```bash
# Verify ServiceMonitor exists
kubectl get servicemonitor -A

# Check Prometheus is running
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus

# Test scrape target
kubectl exec -n monitoring deploy/prometheus -- \
  wget -qO- http://trivy-operator.trivy-system.svc:8080/metrics | head

# Verify network policy allows scraping
kubectl exec -n kube-system ds/cilium -- cilium policy trace \
  --src-k8s-pod monitoring:prometheus-<pod-id> \
  --dst-k8s-pod trivy-system:trivy-operator-<pod-id> \
  --dport 8080
```

#### Problem: Vault access denied

```bash
# Trace auth-users → vault traffic
kubectl exec -n kube-system ds/cilium -- cilium policy trace \
  --src-k8s-pod securerag-hub:auth-users-<pod-id> \
  --dst-k8s-pod vault:vault-<pod-id> \
  --dport 8200

# Verify Vault pod labels
kubectl get pods -n vault --show-labels

# Check Vault ingress policy
kubectl describe ciliumnetworkpolicy -n vault vault-network-policy
```

### Hubble Troubleshooting Commands

```bash
# Real-time flow monitoring
hubble observe --namespace securerag-hub --since 5m

# Filter by verdict
hubble observe --verdict DROPPED

# Filter by service
hubble observe --pod portal-web
hubble observe --namespace securerag-hub --pod auth-users --verdict FORWARDED

# Show HTTP layer (requires Istio)
hubble observe --protocol http

# Export to analyze
hubble observe --output json > /tmp/hubble-flows.json
```

### Reset Network Policies

In emergency situations (e.g., policy bug blocking critical traffic):

```bash
# WARNING: This opens all traffic temporarily
# Delete all CiliumNetworkPolicies
kubectl delete ciliumnetworkpolicies --all-namespaces --all
kubectl delete ciliumclusterwidenetworkpolicies --all

# Traffic resumes with Kubernetes default (allow all)

# Re-apply from Git
kubectl apply -f infra/k8s/cilium/network-policies/
```

---

## Policy Compliance Matrix

| Requirement | Cilium | Kubernetes NetworkPolicy | Status |
|-------------|--------|-------------------------|:------:|
| Default-deny ingress/egress | ✅ CiliumClusterwideNetworkPolicy | ❌ Per-namespace only | **Enforced** |
| Identity-aware (labels) | ✅ Native | ✅ matchLabels | **Enforced** |
| DNS-based egress | ✅ toFQDNs | ❌ Not supported | **Enforced** |
| Layer 7 filtering | ✅ Via Envoy | ❌ | Future |
| Cluster-wide policies | ✅ CiliumClusterwideNetworkPolicy | ❌ | **Enforced** |
| Logging & observability | ✅ Hubble | ❌ | **Active** |
| Policy tracing | ✅ cilium policy trace | ❌ | **Available** |
| Network policy audit | ✅ Hubble UI | ❌ | **Available** |
| Per-namespace isolation | ✅ | ✅ | **Enforced** |

### Policy Coverage

| Namespace | Ingress Policies | Egress Policies | Default Deny |
|-----------|:----------------:|:---------------:|:------------:|
| `securerag-hub` | 5 (per-service) | 5 (per-service) | ✅ |
| `monitoring` | 3 | 2 | ✅ |
| `vault` | 1 | 1 | ✅ |
| `velero` | 1 | 1 | ✅ |
| `spire` | 1 | 1 | ✅ |
| `istio-system` | 1 | 1 | ✅ |
| Cluster-wide | 2 | 1 | ✅ |

---

## Reference

### Key Files

| File | Purpose |
|------|---------|
| `infra/k8s/cilium/network-policies/00-default-deny.yaml` | Cluster-wide default deny |
| `infra/k8s/cilium/network-policies/01-namespace-isolation.yaml` | Per-namespace default deny |
| `infra/k8s/cilium/network-policies/portal-web.yaml` | portal-web ingress/egress |
| `infra/k8s/cilium/network-policies/auth-users.yaml` | auth-users ingress/egress |
| `infra/k8s/cilium/network-policies/chatbot-manager.yaml` | chatbot-manager ingress/egress |
| `infra/k8s/cilium/network-policies/conversation-service.yaml` | conversation-service ingress |
| `infra/k8s/cilium/network-policies/audit-security-service.yaml` | audit-security-service ingress |
| `infra/k8s/cilium/network-policies/vault-policy.yaml` | Vault ingress restrictions |
| `infra/k8s/cilium/network-policies/velero-policy.yaml` | Velero backup egress |
| `infra/k8s/cilium/network-policies/monitoring-exceptions.yaml` | Prometheus/Grafana exceptions |
| `scripts/ci/validate-network-policies.sh` | CI validation script |

### Quick Reference Commands

```bash
# Apply policies
kubectl apply -f infra/k8s/cilium/network-policies/

# List policies
kubectl get ciliumnetworkpolicies -A
kubectl get ciliumclusterwidenetworkpolicies

# Trace a connection
kubectl exec -n kube-system ds/cilium -- cilium policy trace \
  --src-k8s-pod <ns>:<pod> --dst-k8s-pod <ns>:<pod> --dport <port>

# Monitor dropped traffic
hubble observe --verdict DROPPED

# View Hubble UI
kubectl port-forward -n kube-system svc/hubble-ui 12000:12000
# Open http://localhost:12000
```
