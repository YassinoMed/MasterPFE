# Security Guide — SecureRAG Hub

> **Document:** SECURITY_GUIDE.md
> **Version:** 1.0
> **Classification:** Confidential — Security Team
> **Last Updated:** 2026-06-18

---

## Table of Contents

1. Security Architecture Overview
2. Supply Chain Security
3. Secrets Management
4. Container Security
5. Kubernetes Security
6. Network Security
7. Runtime Security
8. SAST/DAST/SCA Tools
9. Vulnerability Management Process
10. Security Incident Response
11. Compliance Mapping

---

## 1. Security Architecture Overview

### 1.1 Defense in Depth Layers

SecureRAG Hub implements a comprehensive **defense in depth** strategy spanning eight layers of security controls:

```
Layer 1: Application Security
  └── SAST (Semgrep), secret scanning (Gitleaks), Laravel security features,
      input validation (Form Requests), output encoding, CSRF protection,
      rate limiting, audit logging

Layer 2: Supply Chain Security
  └── Image signing (Cosign), SBOM (Syft), provenance (SLSA L3),
      vulnerability scanning (Trivy), dependency audit (Composer)

Layer 3: Container Security
  └── Distroless base images, non-root execution, read-only root filesystem,
      seccomp profiles, capability drop, no privilege escalation

Layer 4: Kubernetes Security
  └── Pod Security Standards (Restricted), Kyverno admission policies,
      OPA Gatekeeper (planned), ResourceQuotas, LimitRanges, PDBs

Layer 5: Network Security
  └── Default-deny NetworkPolicies (Cilium), Istio mTLS, egress restrictions,
      API Gateway WAF, rate limiting

Layer 6: Runtime Security
  └── Falco (intrusion detection), Tetragon (eBPF monitoring),
      Falcosidekick (alert enrichment), audit logging

Layer 7: Secrets Management
  └── HashiCorp Vault, External Secrets Operator, SOPS + age encryption,
      Gitleaks (pre-commit), Jenkins credentials

Layer 8: Identity and Access Management
  └── Laravel Sanctum JWT, RBAC (USER/ADMIN/AUDITOR), Kubernetes RBAC,
      ArgoCD RBAC, service accounts
```

### 1.2 Security Posture Summary

| Domain | Status | Coverage | Verification |
|--------|:------:|:--------:|--------------|
| SAST | ✅ Enforce | 37 PHP rules, 14 K8s rules | Semgrep CI gate |
| Secret Detection | ✅ Enforce | 150+ patterns | Gitleaks CI gate |
| Container Scanning | ✅ Enforce | Trivy CRITICAL block | CD gate |
| Image Signing | ✅ Enforce | Cosign key-based | Kyverno verify |
| SBOM Generation | ✅ Enforce | CycloneDX JSON | CD gate |
| SLSA Provenance | ✅ Enforce | Level 3 attestation | CD gate |
| Pod Security | ✅ Enforce | PSS Restricted | Kyverno + static |
| Network Policies | ✅ Enforce | Default-deny, per-service | Static audit |
| Runtime Detection | ✅ Enforce | Falco DaemonSet | Real-time alerts |
| mTLS (Istio) | 🔄 In Progress | Planned for production | — |
| Secrets (Vault) | 🔄 In Progress | Vault + ESO roadmap | — |
| DAST | 🔄 In Progress | ZAP integration planned | — |

### 1.3 Security Metrics and KPIs

| Metric | Target | Current | Measurement |
|--------|:------:|:-------:|-------------|
| Time to patch CRITICAL CVE | < 24 hours | — | From CVE disclosure to deploy |
| SAST findings per release | < 5 | — | Semgrep report |
| Secret leaks in CI | 0 | 0 | Gitleaks report |
| Container CRITICAL vulnerabilities | 0 | 0 | Trivy report |
| Falco CRITICAL alerts per day | < 1 | — | Loki query |
| Failed admission requests | < 1% | — | Kyverno report |
| Time to rotate secrets | < 90 days | — | Secret rotation log |
| Security training completion | 100% | — | HR records |

---

## 2. Supply Chain Security

### 2.1 Software Supply Chain Controls

```
┌─────────────────────────────────────────────────────────────────────┐
│                     SUPPLY CHAIN SECURITY                            │
│                                                                     │
│  Build Phase:                                                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────────┐   │
│  │ Trivy    │  │ Cosign   │  │ Syft     │  │ SLSA Provenance  │   │
│  │ Image    │  │ Sign     │  │ SBOM     │  │ (in-toto)        │   │
│  │ Scan     │  │ Image    │  │ Generate │  │ Generate         │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────────────┘   │
│       │              │              │                 │            │
│       ▼              ▼              ▼                 ▼            │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                   Immutable Artifact                          │   │
│  │   Image: ghcr.io/securerag-hub/portal-web@sha256:abc...      │   │
│  │   Signed: YES (Cosign key abc123)                            │   │
│  │   SBOM: attached (CycloneDX)                                 │   │
│  │   Provenance: SLSA L3 (in-toto attestation)                  │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  Deploy Phase:                                                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                         │
│  │ Kyverno  │  │ Digest   │  │ Runtime  │                         │
│  │ verify   │  │ Promotion│  │ Image    │                         │
│  │ Images   │  │ Check    │  │ Proof    │                         │
│  └──────────┘  └──────────┘  └──────────┘                         │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.2 Cosign Signing

```bash
# Key generation (done once, stored securely)
cosign generate-key-pair
# Outputs: cosign.key (private), cosign.pub (public)

# Private key encrypted and stored:
# - Jenkins credential: 'cosign-private-key' (file)
# - Backup: SOPS-encrypted in infra/secrets/
# - Not in Git, not on developer machines

# Signing process (CD pipeline stage 3)
cosign sign --key cosign.key \
  ghcr.io/securerag-hub/portal-web@sha256:abc123

# Verification (CD pipeline stage 4, Kyverno admission)
cosign verify --key cosign.pub \
  ghcr.io/securerag-hub/portal-web@sha256:abc123

# Expected output:
# Verification for ghcr.io/securerag-hub/portal-web@sha256:abc123 --
# The following checks were performed on each of these signatures:
#   - The cosign claims were validated
#   - The signatures were verified against the specified public key
#   - Any certificate transparency log presences were verified
```

### 2.3 SBOM Generation and Attestation

```bash
# SBOM generation (CD pipeline stage 6)
syft ghcr.io/securerag-hub/portal-web:release \
  -o cyclonedx-json=artifacts/sbom/portal-web-sbom.cdx.json

# SBOM attestation (CD pipeline stage 7)
cosign attest --key cosign.key \
  --type cyclonedx \
  --predicate artifacts/sbom/portal-web-sbom.cdx.json \
  ghcr.io/securerag-hub/portal-web@sha256:abc123

# SBOM verification (post-deploy)
cosign verify-attestation --key cosign.pub \
  --type cyclonedx \
  ghcr.io/securerag-hub/portal-web@sha256:abc123

# SBOM validation
make sbom-validate
# → Validates CycloneDX schema
# → Checks all dependencies are listed
# → Verifies attestation signature
```

### 2.4 SLSA Provenance

```yaml
# SLSA Level 3 requirements met:
# 1. Build service: Jenkins (automated, not developer machines)
# 2. Build isolation: Jenkins agents run as K8s pods (ephemeral)
# 3. Build as code: Jenkinsfile.cd versioned in Git
# 4. Parameterless: Same build for same commit
# 5. Provenance: in-toto attestation generated
# 6. Non-falsifiable: Cosign-signed provenance

# Provenance attestation generated at:
artifacts/release/provenance.slsa.json

# Contains:
# - Build configuration (Jenkinsfile.cd commit)
# - Source repository (GitHub commit SHA)
# - Build dependencies (base image digests)
# - Build outputs (image digest, SBOM hash)
# - Build metadata (builder ID, build timestamp)
```

---

## 3. Secrets Management

### 3.1 Secrets Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   SECRETS MANAGEMENT                          │
│                                                               │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐   │
│  │  SOPS + age  │    │  HashiCorp   │    │  External    │   │
│  │  (Git        │    │  Vault       │    │  Secrets     │   │
│  │   storage)   │    │  (runtime)   │    │  Operator    │   │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘   │
│         │                   │                   │            │
│         ▼                   ▼                   ▼            │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              Kubernetes Secrets (encrypted)           │   │
│  │  securerag-database-secrets                          │   │
│  │  securerag-jwt-secrets                               │   │
│  │  securerag-api-keys                                  │   │
│  │  securerag-cosign-key                                │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌──────────────┐    ┌──────────────┐                       │
│  │  Jenkins     │    │  ArgoCD      │                       │
│  │  Credentials │    │  Vault Plugin│                       │
│  └──────────────┘    └──────────────┘                       │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 Secret Classification

| Classification | Examples | Storage | Access | Rotation |
|---------------|---------|---------|--------|:--------:|
| **CRITICAL** | Cosign private key, Vault root token, DB master password | Vault + SOPS | SRE Lead only | 365 days or compromise |
| **HIGH** | DB application passwords, JWT signing key, API keys | SOPS + Vault | SRE team | 90 days |
| **MEDIUM** | SMTP credentials, monitoring tokens | SOPS + Jenkins credentials | Engineering team | 180 days |
| **LOW** | Test credentials, dev API keys | .env files (local only) | Individual developers | On demand |

### 3.3 Secrets Flow

```
# Development:
  .env.example (placeholders) → .env.local (developer-created)
  → Not committed (Gitleaks enforce)

# Staging/Production (SOPS path):
  Developer: sops infra/secrets/production/db.enc.yaml
  → Commit encrypted file to Git
  → ArgoCD syncs to cluster
  → External Secrets Operator (or argocd-vault-plugin) decrypts
  → Kubernetes Secret created

# Production (Vault path — planned):
  Vault server stores encrypted secrets
  → External Secrets Operator syncs to K8s Secret
  → Pods mount secrets as env vars or volumes
  → Automatic rotation via Vault agent
```

### 3.4 SOPS Configuration

```yaml
# .sops.yaml — Root encryption configuration
creation_rules:
  - path_regex: infra/secrets/production/.*\.enc\.yaml
    age: age1abc123def456...
  - path_regex: infra/secrets/demo/.*\.enc\.yaml
    age: age1def789ghi012...
  - path_regex: infra/secrets/dev/.*\.enc\.yaml
    age: age1ghi345jkl678...
```

### 3.5 Key Rotation Procedures

See [Secret Rotation Runbook](runbooks/secret-rotation.md) for detailed procedures.

Summary of rotation schedule:

| Secret Type | Rotation Period | Automation |
|-------------|:--------------:|:----------:|
| DB passwords | 90 days | Semi-automated (SOPS + rollout) |
| JWT signing keys | 90 days | Semi-automated (SOPS + rollout) |
| API keys | 60 days | Manual (provider-dependent) |
| Cosign key | 365 days | Manual (requires CI update) |
| age keys (SOPS) | 365 days | Manual (multi-step) |
| Service tokens | 30 days (auto JWT TTL) | Automatic |

---

## 4. Container Security

### 4.1 Dockerfile Hardening

```dockerfile
# Multi-stage build pattern used by all services

# Stage 1: Build
FROM php:8.2-cli AS builder
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --optimize-autoloader --no-interaction
COPY . .

# Stage 2: Production image (distroless)
FROM gcr.io/distroless/php:8.2-debug AS production
# ^ Distroless: no shell, no package manager, no utilities

WORKDIR /app

COPY --from=builder /app /app
COPY --from=builder /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/

# Security hardening
USER 33:33                          # www-data user (non-root)
WORKDIR /app/public

# Container security context (set in deployment, not just Dockerfile)
# These are enforced at the Kubernetes level:
#   runAsNonRoot: true
#   runAsUser: 33
#   runAsGroup: 33
#   fsGroup: 33
#   allowPrivilegeEscalation: false
#   readOnlyRootFilesystem: true
#   capabilities.drop: ["ALL"]
#   seccompProfile: RuntimeDefault

EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ["php", "artisan", "health:check"]

CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=8000"]
```

### 4.2 Container Hardening Checklist

```
□  Distroless or scratch base image (no shell, no package manager)
□  Non-root user (UID 33 or 65532)
□  Read-only root filesystem (write to tmpfs or emptyDir only)
□  No privilege escalation (allowPrivilegeEscalation: false)
□  All Linux capabilities dropped (capabilities.drop: ["ALL"])
□  Default seccomp profile (RuntimeDefault)
□  Health check defined (liveness + readiness probes)
□  Resource limits set (CPU, memory, ephemeral storage)
□  No setuid/setgid binaries
□  No SSH server or debugging tools
□  Single process per container (no supervisord)
□  Immutable image tag (digest-based, no :latest)
```

### 4.3 Image Scanning Policy

| Severity | CI Action | CD Action | Deploy Gate |
|----------|:---------:|:---------:|:-----------:|
| CRITICAL | Block CI | Block CD | Block deploy |
| HIGH | Warn, document | Warn, document | Document only |
| MEDIUM | Warn | Warn | No action |
| LOW | Informational | Informational | No action |

```bash
# Trivy scanning commands
# Filesystem scan (CI stage)
trivy fs --severity CRITICAL,HIGH --exit-code 1 .

# Image scan (CD stage)
trivy image --severity CRITICAL --exit-code 1 \
  ghcr.io/securerag-hub/portal-web:release

# Image scan with output
trivy image --severity CRITICAL,HIGH \
  --format json \
  --output artifacts/security/reports/trivy-image-portal-web.json \
  ghcr.io/securerag-hub/portal-web@sha256:abc123
```

---

## 5. Kubernetes Security

### 5.1 Kyverno Policy Suite

The platform enforces 7 Kyverno policies for admission control:

| # | Policy Name | Mode | Description | MITRE ATT&CK |
|---|-------------|:----:|-------------|:-----------:|
| 1 | `restrict-image-references` | Audit | Block `:latest`, enforce registry whitelist | T1525 |
| 2 | `restrict-volume-types` | Audit | Block `hostPath`, restrict `nfs` | T1611 |
| 3 | `require-pod-security` | Audit | PSS Restricted: no privileged, non-root, drop all caps | T1610 |
| 4 | `require-workload-controls` | Audit | Require resources, probes, and replicas | T1496 |
| 5 | `restrict-service-exposure` | Audit | Block unapproved NodePort/LoadBalancer | T1020 |
| 6 | `verify-cosign-images` | Audit | Verify Cosign signature before admission | T1525 |
| 7 | `audit-cleartext-env-values` | Audit | Detect plaintext secrets in env vars | T1552 |

### 5.2 Pod Security Standards (Restricted)

All pods in the `securerag-hub` namespace comply with PSS Restricted profile:

| Control | Requirement | Our Implementation |
|---------|-------------|-------------------|
| **privileged** | `privileged: false` | Explicitly set in pod spec |
| **hostPID / hostIPC** | Not shared | Omitted from all specs |
| **hostNetwork** | Not used | ClusterIP services only |
| **hostPorts** | Not used | Ingress handles external traffic |
| **Volume types** | Only configMap, secret, emptyDir, PVC | Kyverno restricts volume types |
| **runAsNonRoot** | `true` | All pods set `runAsNonRoot: true` |
| **runAsUser** | Must not be 0 | Set to 33 or 65532 |
| **capabilities** | `DROP ALL` required | Explicit in all deployments |
| **seccomp** | `RuntimeDefault` or `Localhost` | Set in pod securityContext |
| **allowPrivilegeEscalation** | `false` | Explicit in all deployments |
| **readOnlyRootFilesystem** | `true` | All services configured |

### 5.3 Kubernetes RBAC Model

```yaml
# Minimal service account permissions — per-service
# Only audit-security-service needs additional permissions

apiVersion: v1
kind: ServiceAccount
metadata:
  name: sa-portal-web
  namespace: securerag-hub
automountServiceAccountToken: false
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: sa-audit-security-service
  namespace: securerag-hub
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: runtime-readonly
rules:
  - apiGroups: [""]
    resources: ["pods", "services", "configmaps", "events"]
    verbs: ["get", "list", "watch"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: runtime-readonly-binding
subjects:
  - kind: ServiceAccount
    name: sa-audit-security-service
    namespace: securerag-hub
roleRef:
  kind: ClusterRole
  name: runtime-readonly
  apiGroup: rbac.authorization.k8s.io
```

### 5.4 Resource Quotas and Limit Ranges

```yaml
# Namespace-level resource protection
apiVersion: v1
kind: ResourceQuota
metadata:
  name: securerag-hub-quota
  namespace: securerag-hub
spec:
  hard:
    requests.cpu: "16"
    requests.memory: "32Gi"
    limits.cpu: "32"
    limits.memory: "64Gi"
    persistentvolumeclaims: "20"
    pods: "50"
    services: "30"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: securerag-hub-limits
  namespace: securerag-hub
spec:
  limits:
    - default:
        cpu: "500m"
        memory: "256Mi"
      defaultRequest:
        cpu: "50m"
        memory: "64Mi"
      type: Container
```

---

## 6. Network Security

### 6.1 Default-Deny Network Policy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: securerag-hub
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

### 6.2 Per-Service Network Policies

```yaml
# portal-web ingress (allow ingress controller)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-portal-web-ingress
  namespace: securerag-hub
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: portal-web
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: ingress-nginx
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: securerag-monitoring
      ports:
        - port: 8000
---
# portal-web egress (to other services)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-portal-web-egress
  namespace: securerag-hub
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: portal-web
  egress:
    - to:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: auth-users-service
      ports:
        - port: 8000
    - to:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: chatbot-manager-service
      ports:
        - port: 8000
    - to:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: conversation-service
      ports:
        - port: 8000
    - to:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: audit-security-service
      ports:
        - port: 8000
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - port: 53
          protocol: UDP
```

### 6.3 Allowed Network Flows

```
Source                        Destination                   Port    Protocol
─────────────────────────────────────────────────────────────────────────────
ingress-nginx                 portal-web                     8000   TCP
portal-web                    auth-users-service             8000   TCP
portal-web                    chatbot-manager-service        8000   TCP
portal-web                    conversation-service           8000   TCP
portal-web                    audit-security-service         8000   TCP
chatbot-manager-service       Qdrant                         6333   TCP (gRPC)
chatbot-manager-service       Ollama                         11434  TCP
chatbot-manager-service       audit-security-service         8000   TCP
auth-users-service            PostgreSQL                     5432   TCP
conversation-service          PostgreSQL                     5432   TCP
audit-security-service        PostgreSQL                     5432   TCP
All pods                      kube-dns (CoreDNS)             53     UDP
All pods                      Prometheus scrape              9090   TCP (monitoring ns)
```

### 6.4 Istio mTLS (Planned)

```yaml
# Istio PeerAuthentication (planned for production)
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: strict-mtls
  namespace: securerag-hub
spec:
  mtls:
    mode: STRICT  # All traffic must use mTLS

# Istio AuthorizationPolicy (planned)
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: portal-web-authz
  namespace: securerag-hub
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: portal-web
  rules:
    - from:
        - source:
            principals: ["cluster.local/ns/istio-system/sa/ingress-gateway"]
      to:
        - operation:
            methods: ["GET", "POST", "PUT", "DELETE"]
            paths: ["/*"]
```

---

## 7. Runtime Security

### 7.1 Falco Configuration

```yaml
# Falco rules — custom rules for SecureRAG Hub
# Priority levels: EMERGENCY > ALERT > CRITICAL > ERROR > WARNING > NOTICE > INFO > DEBUG

- rule: Laravel Shell Execution
  desc: Detect shell execution attempts from Laravel containers
  condition: evt.type = execve and proc.vpid != 1 and container.image contains "securerag-hub" and (proc.name in (sh, bash, dash, zsh, python, perl, php))
  output: "Shell execution detected in container (user=%user.name command=%proc.cmdline container=%container.name image=%container.image)"
  priority: CRITICAL
  tags: [mitre_execution, T1059]

- rule: Read SSH Keys from Pod
  desc: Attempt to read SSH private keys
  condition: open_write and fd.name startswith /root/.ssh and container.image contains "securerag-hub"
  output: "SSH key access attempt in container (user=%user.name file=%fd.name container=%container.name)"
  priority: CRITICAL
  tags: [mitre_credential_access, T1552]

- rule: Write Outside Allowed Directories
  desc: Write attempts to directories outside /tmp and /var/www
  condition: evt.type = write and container.image contains "securerag-hub" and not fd.name startswith /tmp and not fd.name startswith /proc and not fd.name startswith /var/www
  output: "Unauthorized write attempt (file=%fd.name container=%container.name)"
  priority: WARNING
  tags: [mitre_defense_evasion, T1562]

- rule: Cryptominer Detection
  desc: Detect cryptominer processes running in containers
  condition: proc.name in (xmrig, miner, cpuminer, ccminer, ethminer) and container.image contains "securerag-hub"
  output: "Cryptominer process detected (proc=%proc.name container=%container.name)"
  priority: EMERGENCY
  tags: [mitre_impact, T1496]
```

### 7.2 Falco Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    FALCO ARCHITECTURE                          │
│                                                                │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  Worker Node 1                                       │    │
│  │  ┌────────────────────────────────────────────────┐  │    │
│  │  │  Falco DaemonSet                                │  │    │
│  │  │  ├── Kernel module (or eBPF probe)              │  │    │
│  │  │  ├── Rules: custom-rules.yaml + falco_rules.yaml│  │    │
│  │  │  └── Output: stdout (JSON)                     │  │    │
│  │  └────────────────────────────────────────────────┘  │    │
│  │                  │                                    │    │
│  └──────────────────┼────────────────────────────────────┘    │
│                     │ stdout                                  │
│                     ▼                                          │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  Promtail (DaemonSet)                                │    │
│  │  └── Ships Falco logs to Loki                        │    │
│  └──────────────────────┬───────────────────────────────┘    │
│                         │                                     │
│                         ▼                                     │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  Loki                                                │    │
│  │  └── Indexed Falco events available in Grafana       │    │
│  └──────────────────────┬───────────────────────────────┘    │
│                         │                                     │
│                         ▼                                     │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  Prometheus Alertmanager                             │    │
│  │  └── FalcoEventsHigh alert → PagerDuty               │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                                │
│  Optional: Falcosidekick                                      │
│  └── Enriches Falco alerts → sends to Slack, email, webhook   │
└──────────────────────────────────────────────────────────────┘
```

### 7.3 Tetragon eBPF Monitoring

Tetragon provides deep eBPF-based observability for security events:

| Feature | Capability | Use Case |
|---------|-----------|----------|
| Process execution monitoring | Track all execve calls | Detect unauthorized binary execution |
| Network flow monitoring | Track all socket operations | Detect unexpected outbound connections |
| File access monitoring | Track open/read/write operations | Detect unauthorized data access |
| Capability usage monitoring | Track capability use | Detect privilege escalation attempts |
| Container identity | All events tagged with container metadata | Correlate security events to workloads |

---

## 8. SAST/DAST/SCA Tools

### 8.1 Tool Matrix

| Tool | Category | Language/Target | CI Integration | Coverage |
|------|----------|----------------|:--------------:|:--------:|
| **Semgrep** | SAST | PHP, YAML, Dockerfile | Jenkins (blocking) | 37 custom rules |
| **Gitleaks** | Secret Detection | All text files | Jenkins (blocking) | 150+ patterns |
| **Trivy** | SCA + Container | Filesystem, Images, Repos | Jenkins (blocking CRITICAL) | CVE database |
| **Composer Audit** | Dependency | PHP (Composer) | Jenkins (blocking) | Packagist advisories |
| **kube-score** | K8s Lint | Kubernetes manifests | Jenkins (blocking) | 50+ checks |
| **Kyverno CLI** | Policy Check | Kubernetes manifests | Jenkins (blocking) | 7 custom policies |
| **SonarQube** | SAST + Quality | PHP, JS, YAML | Jenkins (optional) | Custom quality gate |
| **OWASP ZAP** | DAST | Web Applications | Planned | — |

### 8.2 Semgrep Rules

```yaml
# security/semgrep/semgrep.yml — Custom rules for SecureRAG Hub

rules:
  - id: laravel-sql-injection
    patterns:
      - pattern: DB::raw(...)
      - pattern-not: DB::raw("...")  # Static strings only
    message: "Potential SQL injection via DB::raw() with dynamic content"
    severity: ERROR
    languages: [php]
    paths:
      exclude:
        - "*/database/migrations/*"
        - "*/tests/*"

  - id: laravel-command-injection
    patterns:
      - pattern: shell_exec(...)
      - pattern: exec(...)
      - pattern: system(...)
      - pattern: passthru(...)
    message: "Command execution detected. Use Symfony Process instead."
    severity: ERROR
    languages: [php]

  - id: k8s-privileged-container
    patterns:
      - pattern: |
          spec:
            ...
            privileged: true
    message: "Privileged container not allowed"
    severity: ERROR
    languages: [yaml]
    paths:
      include:
        - "infra/k8s/**"

  - id: hardcoded-secret
    patterns:
      - pattern: |
          $VAR = "..."
      - metavariable-regex:
          metavariable: $VAR
          regex: (password|secret|token|key|credential)
    severity: ERROR
    languages: [php, yaml, python]
    paths:
      exclude:
        - "*/tests/*"
        - "*/.env.example"
```

### 8.3 Gitleaks Configuration

```toml
# .gitleaks.toml
title = "SecureRAG Hub Gitleaks Configuration"

[extend]
useDefault = true

[[rules]]
id = "securerag-db-password"
description = "SecureRAG Hub database password"
regex = '''DB_PASSWORD\s*=\s*['"][^'"]+['"]'''
tags = ["securerag", "database"]

[[rules]]
id = "securerag-jwt-secret"
description = "SecureRAG Hub JWT secret"
regex = '''JWT_SECRET\s*=\s*['"][^'"]+['"]'''
tags = ["securerag", "jwt"]

[[rules]]
id = "securerag-api-key"
description = "SecureRAG Hub API key"
regex = '''API_KEY\s*=\s*['"][^'"]+['"]'''
tags = ["securerag", "api"]

[allowlist]
description = "Allowlisted files"
paths = [
  ".env.example",
  "*/tests/*",
  "docs/**",
]
```

### 8.4 DAST Roadmap

OWASP ZAP integration is planned for the next phase:

| Stage | Activity | Timeline |
|-------|---------|:--------:|
| 1 | ZAP baseline scan in CI (passive) | Q2 2026 |
| 2 | ZAP active scan in staging (weekly) | Q3 2026 |
| 3 | ZAP API scan (OpenAPI-based) | Q3 2026 |
| 4 | Authentication integration (API tokens) | Q4 2026 |
| 5 | Full DAST in CD pipeline (blocking) | Q4 2026 |

---

## 9. Vulnerability Management Process

### 9.1 Vulnerability Lifecycle

```
Discovery ──> Triage ──> Remediation ──> Verification ──> Closure
   │           │           │               │               │
   ▼           ▼           ▼               ▼               ▼
 Trivy    Assess      Patch          Re-scan        Report
 Semgrep  Severity    Update         Validate       archived
 Gitleaks Scope       Deploy         Monitor
```

### 9.2 Vulnerability Severity Classification

| Severity | CVSS Score | Response Time | Remediation SLA | Escalation |
|----------|:----------:|:-------------:|:---------------:|------------|
| **CRITICAL** | 9.0 — 10.0 | Immediate | < 24 hours | CTO + Security Lead |
| **HIGH** | 7.0 — 8.9 | < 4 hours | < 7 days | Security Lead |
| **MEDIUM** | 4.0 — 6.9 | < 24 hours | < 30 days | Engineering Manager |
| **LOW** | 0.1 — 3.9 | < 7 days | < 90 days | Service Owner |

### 9.3 Vulnerability Sources

| Source | Type | Frequency | Tool |
|--------|------|:---------:|------|
| **CI pipeline** | SAST/SCA | Per commit | Semgrep, Trivy, Gitleaks |
| **CD pipeline** | Container scan | Per release | Trivy image |
| **Scheduled scan** | Full system | Weekly | Trivy repo scan |
| **Runtime scan** | Running images | Daily | Trivy + Falco |
| **Dependency updates** | Library scan | Continuous | Renovate bot |
| **Security advisories** | CVE notifications | Real-time | GitHub Advisory DB |

### 9.4 Remediation SLAs by Component

| Component | CRITICAL | HIGH | MEDIUM | LOW |
|-----------|:-------:|:----:|:------:|:---:|
| **Application code** | 24 hours | 7 days | 30 days | 90 days |
| **Third-party library** | 24 hours | 7 days | 30 days | Next release |
| **Base image** | 24 hours | 7 days | 30 days | Next release |
| **Kubernetes infrastructure** | 24 hours | 7 days | 30 days | 90 days |
| **Security tooling** | 24 hours | 14 days | 60 days | 90 days |

---

## 10. Security Incident Response

### 10.1 Security Incident Classification

| Severity | Definition | Examples | Response Team |
|----------|-----------|----------|---------------|
| **SEV-SEC-1** | Active compromise or data breach | Unauthorized cluster access; data exfiltration; ransomware | SRE + Security + Legal |
| **SEV-SEC-2** | Confirmed security vulnerability | Exploitable CVE in production; secret leak; malware detected | SRE + Security |
| **SEV-SEC-3** | Suspicious activity | Falco alert; unusual traffic pattern; failed auth spike | SRE on-call |
| **SEV-SEC-4** | Policy violation | Kyverno admission reject; non-compliant config | Service owner |

### 10.2 Security Incident Response Flow

```
Detection (Falco, Kyverno, Prometheus, User Report)
    │
    ▼
Initial Triage (On-call SRE, < 5 min)
    │
    ├── False positive → Close, adjust rules
    │
    └── True positive → Continue to assessment
            │
            ▼
Severity Assessment (SRE + Security, < 15 min)
    │
    ├── SEV-SEC-3/4 → Standard incident process
    │
    └── SEV-SEC-1/2 → Security incident process
            │
            ▼
Containment (Immediate)
    ├── Cordon compromised nodes
    ├── Scale down affected deployments
    ├── Revoke exposed credentials
    ├── Enable network isolation
    └── Capture forensic evidence
            │
            ▼
Eradication (< 4 hours for SEV-SEC-1)
    ├── Remove malicious artifacts
    ├── Patch vulnerabilities
    ├── Rotate all affected secrets
    └── Rebuild from clean base
            │
            ▼
Recovery (< 8 hours for SEV-SEC-1)
    ├── Restore from clean backup
    ├── Verify no persistence mechanisms
    └── Gradual traffic restoration
            │
            ▼
Postmortem (< 48 hours)
    ├── Root cause analysis
    ├── Timeline documentation
    ├── Action items
    └── Lessons learned
```

### 10.3 Forensic Evidence Collection

```bash
# Step 1: Pod state capture
kubectl get pods -n securerag-hub -o yaml > evidence/forensic/pod-state-$(date -u +%Y%m%dT%H%M%SZ).yaml
kubectl describe pod -n securerag-hub > evidence/forensic/pod-describe-$(date -u +%Y%m%dT%H%M%SZ).txt

# Step 2: Container logs
kubectl logs -n securerag-hub -l app.kubernetes.io/name=portal-web \
  --all-containers --since=24h > evidence/forensic/portal-web-logs-24h.txt

# Step 3: Falco events
kubectl logs -n securerag-security -l app.kubernetes.io/name=falco \
  --since=24h > evidence/forensic/falco-events-24h.txt

# Step 4: Kubernetes audit logs
kubectl logs -n kube-system -l component=kube-apiserver \
  --since=24h > evidence/forensic/k8s-audit-24h.txt

# Step 5: Network flow logs
# (if Cilium Hubble enabled)
hubble observe --since=24h > evidence/forensic/network-flows-24h.txt

# Step 6: Image digest verification
kubectl get pods -n securerag-hub -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}' \
  > evidence/forensic/running-images.txt

# Step 7: Package evidence
tar czf evidence/forensic-bundle-$(date -u +%Y%m%dT%H%M%SZ).tar.gz evidence/forensic/
```

### 10.4 Security Contacts

| Role | Name | Contact | Availability |
|------|------|---------|:------------:|
| Security Lead | — | #security-lead | 24/7 |
| SRE Lead | — | #sre-lead | 24/7 |
| Engineering Lead | — | #eng-lead | Business hours |
| CISO | — | #ciso | Escalation only |
| Legal Counsel | — | #legal | Business hours |

---

## 11. Compliance Mapping

### 11.1 CIS Kubernetes Benchmark

| CIS Control | Status | Implementation |
|------------|:------:|----------------|
| **1.1** — RBAC default deny | ✅ | Default-deny RBAC policies |
| **1.2** — Service account tokens | ✅ | `automountServiceAccountToken: false` |
| **2.1** — Pod security | ✅ | PSS Restricted via Kyverno |
| **2.2** — Container security | ✅ | Distroless, non-root, read-only FS |
| **3.1** — Network policies | ✅ | Default-deny + per-service allow |
| **4.1** — Secrets encryption | ✅ | SOPS + Vault (planned) |
| **5.1** — API server audit | ✅ | Audit log forwarded to Loki |
| **5.2** — Admission control | ✅ | Kyverno policies |

### 11.2 NIST 800-53 Controls

| Control ID | Control Name | Implementation |
|------------|--------------|----------------|
| **AC-2** | Account Management | Laravel RBAC + K8s ServiceAccounts |
| **AC-3** | Access Enforcement | JWT authentication, RBAC authorization |
| **AC-6** | Least Privilege | Minimal K8s RBAC, dropped capabilities |
| **AU-2** | Audit Events | Falco, audit-security-service, Loki |
| **AU-3** | Content of Audit Records | Structured JSON audit logs |
| **AU-6** | Audit Review, Analysis, Reporting | Grafana dashboards, automated alerts |
| **CM-2** | Baseline Configuration | GitOps + Kyverno policy enforcement |
| **CM-6** | Configuration Settings | Kyverno admission policies |
| **IA-2** | Identification and Authentication | Sanctum JWT, service accounts |
| **IR-4** | Incident Handling | Incident response runbook |
| **RA-5** | Vulnerability Scanning | Trivy, Semgrep, Gitleaks |
| **SC-7** | Boundary Protection | NetworkPolicies, Istio mTLS |
| **SC-8** | Transmission Confidentiality and Integrity | HTTPS, mTLS |
| **SC-12** | Cryptographic Key Establishment | Cosign signing, SOPS encryption |
| **SC-13** | Cryptographic Protection | AES-256 for backups, SHA-256 for audit |
| **SC-28** | Protection of Information at Rest | Encrypted volumes, encrypted backups |
| **SI-4** | System Monitoring | Prometheus, Falco, Tetragon |
| **SI-7** | Software, Firmware, and Integrity Checks | Cosign verify, SBOM attestation |

### 11.3 ISO 27001:2022 Controls

| Annex A Control | Title | Implementation |
|----------------|-------|----------------|
| **5.15** | Access Control | RBAC (app + K8s + ArgoCD) |
| **5.17** | Authentication | JWT + bcrypt + service accounts |
| **5.19** | Information Security in Supplier Relationships | SBOM verification, dependency audit |
| **5.20** | Addressing Security Within Supplier Agreements | Cosign signature verification |
| **5.24** | Information Security Incident Management | Incident response runbook |
| **5.25** | Assessment of Information Security Incidents | Postmortem process |
| **5.29** | Security During Business Continuity | DR guide, backup/restore procedures |
| **5.33** | Protection of Records | Audit log integrity, Loki append-only |
| **5.35** | Information Security Review | Quarterly security review |
| **5.36** | Compliance with Policies | Kyverno policy enforcement |
| **6.8** | Information Security Event Logging | Falco, audit-security-service |
| **7.10** | Storage Security | Encrypted backups, MinIO encryption |
| **8.8** | Management of Technical Vulnerabilities | Trivy, Renovate, vulnerability SLAs |
| **8.9** | Configuration Management | GitOps, Kyverno admission |
| **8.10** | Information Deletion | Data retention policies |
| **8.12** | Data Leakage Prevention | Gitleaks, secret rotation, RBAC filtering |
| **8.16** | Monitoring Activities | Prometheus, Grafana, Loki |
| **8.20** | Networks Security | NetworkPolicies, Istio mTLS |
| **8.24** | Use of Cryptography | Cosign, SOPS, HTTPS |
| **8.25** | Secure Development Lifecycle | CI/CD gates, SAST/DAST/SCA |
| **8.28** | Secure Coding | Semgrep rules, Laravel best practices |
| **8.29** | Security Testing in Development and Acceptance | Smoke tests, admission tests |
| **8.30** | Outsourced Development | SBOM verification, supply chain checks |

### 11.4 SOC 2 Trust Services Criteria

| Category | Criteria | Implementation |
|----------|----------|----------------|
| **Security** | Unauthorized access prevention | NetworkPolicies, mTLS, RBAC, Falco |
| **Availability** | System availability for operations | HPA, PDB, multi-replica, DR plan |
| **Processing Integrity** | Complete/accurate/authorized processing | Audit logging, integrity checks |
| **Confidentiality** | Information protection | Secrets management, RBAC, encryption |
| **Privacy** | Personal data protection | Audit logging, data retention, RBAC |

---

## References

- [Kubernetes Security](kubernetes-security.md)
- [Threat Model](threat-model.md)
- [Secrets Management](secrets-management.md)
- [Runtime Security Operations](runbooks/runtime-security-operations.md)
- [DevSecOps Pipeline](devsecops-pipeline.md)
- [Compliance Matrix](SECURITY-COMPLIANCE-MATRIX.md)
- [MITRE ATT&CK Mapping](security/mitre-attack-k8s-mapping.md)
- [Security Readiness Report](security/security-readiness-report.md)

---

*Document maintained by the Security team. For questions, contact #security-team on Slack.*
