# Enterprise Architecture — SecureRAG Hub

> **Document:** ARCHITECTURE.md
> **Version:** 1.0
> **Classification:** Internal — Enterprise
> **Last Updated:** 2026-06-18

---

## Table of Contents

1. System Overview
2. Microservices Architecture
3. Infrastructure Architecture
4. Security Architecture
5. Observability Architecture
6. GitOps Workflow
7. Multi-Cluster Architecture
8. Data Architecture
9. CI/CD Pipeline Architecture
10. Decision Log
11. ASCII Architecture Diagram

---

## 1. System Overview

SecureRAG Hub is an enterprise-grade secure chatbot orchestration platform that provides organizations with a compliant, auditable, and resilient Retrieval-Augmented Generation (RAG) system. The platform follows a strict DevSecOps philosophy where every stage of the software delivery lifecycle is instrumented with security controls, verification gates, and cryptographic attestation.

### 1.1 High-Level Flow

```
GitHub (Source of Truth)
    │ GitHub Webhook
    ▼
Jenkins CI (15 stages, 11 quality gates)
    │ Pipeline promotes artifacts
    ▼
OCI Registry (Harbor) — Signed images with SBOM attestation
    │ ArgoCD detects drift
    ▼
ArgoCD (GitOps Controller) — App of Apps pattern
    │ Sync waves, progressive delivery
    ▼
Kubernetes Cluster (Production / Staging / DR)
    │ Kyverno admission, Falco runtime, mTLS
    ▼
Services: portal-web, auth-users, chatbot-manager, conversation-service, audit-security-service
```

### 1.2 Architectural Principles

| Principle | Description |
|-----------|-------------|
| **Security by Design** | Every component is hardened at build time (distroless, non-root, seccomp) and verified at runtime (Falco, Kyverno, mTLS) |
| **Immutable Infrastructure** | All changes flow through GitOps; no ad-hoc modifications to running clusters |
| **Defense in Depth** | Multiple overlapping security controls at every layer: code, build, image, admission, runtime, network |
| **Observability as First Principle** | Every service emits metrics, logs, and traces; SLOs are monitored and alerted |
| **Progressive Delivery** | Changes flow through dev → staging → production → DR with manual approval gates |
| **Zero Trust Networking** | All service-to-service communication requires mTLS; default-deny network policies |

---

## 2. Microservices Architecture

### 2.1 Service Inventory

| Service | Role | Technology | API Pattern | Data Store | Language |
|---------|------|------------|-------------|------------|----------|
| **portal-web** | Frontend gateway, JWT verification, session management | Laravel 11 | REST + WebSocket | PostgreSQL (sessions, user prefs) | PHP 8.2 |
| **auth-users-service** | Authentication, authorization, RBAC (USER/ADMIN/AUDITOR) | Laravel 11 | REST (JWT Sanctum) | PostgreSQL (users, roles, permissions) | PHP 8.2 |
| **chatbot-manager-service** | RAG orchestration: query routing, prompt building, Qdrant search, LLM integration | Laravel 11 | REST + gRPC (Qdrant) | PostgreSQL (chatbot configs), Qdrant (vectors) | PHP 8.2 |
| **conversation-service** | Chat session management, message history, real-time WebSockets | Laravel 11 | REST + WebSocket | PostgreSQL (conversations, messages) | PHP 8.2 |
| **audit-security-service** | Prompt injection detection (11 patterns), scoring (0-100), security audit logging | Laravel 11 | REST | PostgreSQL (audit logs, hash-only storage) | PHP 8.2 |

### 2.2 Service Communication Matrix

```
                   ┌─────────────┐
                   │  portal-web  │
                   └──────┬──────┘
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
   ┌────────────┐  ┌─────────────┐  ┌──────────────┐
   │   auth-    │  │  chatbot-   │  │conversation- │
   │   users    │  │  manager    │  │  service     │
   └────────────┘  └──────┬──────┘  └──────────────┘
                          │
                    ┌─────┴─────┐
                    ▼           ▼
             ┌──────────┐ ┌──────────┐
             │  Qdrant  │ │  Ollama  │
             │(vectors) │ │  (LLM)   │
             └──────────┘ └──────────┘
                          │
                    ┌─────┘
                    ▼
            ┌──────────────┐
            │    audit-    │
            │   security   │
            └──────────────┘
```

### 2.3 Service Dependencies

| Service | Depends On | Dependency Type |
|---------|-----------|-----------------|
| portal-web | auth-users-service | Hard (login required for all operations) |
| portal-web | chatbot-manager-service | Hard (chat functionality) |
| portal-web | conversation-service | Hard (conversation history) |
| portal-web | audit-security-service | Soft (audit logging degrades gracefully) |
| chatbot-manager-service | auth-users-service | Hard (RBAC context for Qdrant filtering) |
| chatbot-manager-service | Qdrant | Hard (vector search) |
| chatbot-manager-service | Ollama | Hard (LLM inference) |
| chatbot-manager-service | audit-security-service | Hard (prompt/response audit) |
| All services | PostgreSQL | Hard (persistence) |

### 2.4 DDD-Light Module Structure

Each service follows a consistent Domain-Driven Design (light) structure:

```
services-laravel/<service>/
├── app/
│   ├── Http/
│   │   ├── Controllers/       ← API endpoints
│   │   ├── Middleware/        ← JWT, RateLimit, Audit, RBAC
│   │   └── Requests/         ← Form Requests (Laravel validation)
│   ├── Models/               ← Eloquent models
│   ├── Services/             ← Business logic layer
│   ├── Jobs/                 ← Async processing (RAG, indexing, audit)
│   ├── Events/               ← Broadcast events (WebSocket)
│   └── Exceptions/           ← Custom exception handlers
├── config/
├── database/migrations/
├── routes/api.php
├── tests/
│   ├── Feature/              ← HTTP integration tests
│   └── Unit/                 ← Unit tests
├── Dockerfile                ← Multi-stage, distroless, non-root
└── composer.json
```

---

## 3. Infrastructure Architecture

### 3.1 Kubernetes Cluster Topology

```
┌─────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                    │
│                                                         │
│  ┌────────────────────────────────────────────────┐     │
│  │              Namespace: securerag-hub           │     │
│  │  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ │     │
│  │  │portal│ │auth  │ │chat  │ │conv  │ │audit │ │     │
│  │  │ -web │ │-users│ │-mgr  │ │-svc  │ │-sec  │ │     │
│  │  └──────┘ └──────┘ └──────┘ └──────┘ └──────┘ │     │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐       │     │
│  │  │PostgreSQL│ │  Qdrant  │ │  Ollama  │       │     │
│  │  │  (HA)    │ │(vectors) │ │  (LLM)   │       │     │
│  │  └──────────┘ └──────────┘ └──────────┘       │     │
│  └────────────────────────────────────────────────┘     │
│                                                         │
│  ┌────────────────────────────────────────────────┐     │
│  │           Namespace: securerag-monitoring        │     │
│  │  ┌──────────┐ ┌────────┐ ┌──────┐ ┌─────────┐ │     │
│  │  │Prometheus│ │ Grafana│ │ Loki │ │Tempo    │ │     │
│  │  └──────────┘ └────────┘ └──────┘ └─────────┘ │     │
│  └────────────────────────────────────────────────┘     │
│                                                         │
│  ┌────────────────────────────────────────────────┐     │
│  │            Namespace: securerag-security          │     │
│  │  ┌──────┐ ┌────────┐ ┌──────────┐ ┌────────┐  │     │
│  │  │ Falco│ │ Kyverno│ │  Tetragon│ │  Vault  │  │     │
│  │  └──────┘ └────────┘ └──────────┘ └────────┘  │     │
│  └────────────────────────────────────────────────┘     │
│                                                         │
│  ┌────────────────────────────────────────────────┐     │
│  │           Namespace: securerag-gitops            │     │
│  │  ┌──────────┐ ┌──────────┐                     │     │
│  │  │  ArgoCD  │ │ ArgoCD   │                     │     │
│  │  │  Server  │ │ Image    │                     │     │
│  │  │          │ │ Updater  │                     │     │
│  │  └──────────┘ └──────────┘                     │     │
│  └────────────────────────────────────────────────┘     │
│                                                         │
│  ┌────────────────────────────────────────────────┐     │
│  │              Namespace: securerag-storage        │     │
│  │  ┌──────────┐ ┌──────────┐                     │     │
│  │  │  MinIO   │ │  Velero  │                     │     │
│  │  └──────────┘ └──────────┘                     │     │
│  └────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────┘
```

### 3.2 Networking Architecture

| Layer | Technology | Configuration |
|-------|-----------|---------------|
| Ingress | nginx-ingress + cert-manager | TLS termination, rate limiting |
| Service Mesh | Istio (planned) | mTLS, traffic splitting, circuit breaking |
| Service Discovery | Kubernetes DNS (ClusterIP) | All internal, no external exposure |
| Network Policies | Cilium (default-deny) | Per-service ingress/egress whitelist |
| Egress | Restricted to known endpoints | No unrestricted outbound traffic |

### 3.3 Storage Architecture

| Data Type | Storage Solution | Backup Mechanism | Retention |
|-----------|-----------------|-----------------|-----------|
| Application Data | PostgreSQL HA (Patroni or CNPG) | Velero + pg_dump CronJob | Daily (14d), Weekly (8w), Monthly (12m) |
| Vector Embeddings | Qdrant | Qdrant snapshot + Velero | Daily (7d) |
| Object Storage | MinIO (S3-compatible) | MinIO bucket replication | 30 days |
| Logs | Loki (object storage backed) | Retained in MinIO | 14 days |
| Metrics | Prometheus TSDB | Thanos sidecar to MinIO | 30 days |
| Traces | Tempo | Backend storage via MinIO | 7 days |

### 3.4 Compute Resources

| Environment | Node Count | Node Type | Total CPU | Total Memory | Storage |
|-------------|-----------|-----------|-----------|-------------|---------|
| Development | 3 | General purpose | 12 vCPU | 32 GB | 100 GB SSD |
| Staging | 5 | General purpose | 20 vCPU | 64 GB | 200 GB SSD |
| Production | 7 | Compute optimized | 56 vCPU | 168 GB | 500 GB NVMe |
| DR (Standby) | 3 | General purpose | 12 vCPU | 32 GB | 200 GB SSD |

---

## 4. Security Architecture

### 4.1 Security Layers

```
┌─────────────────────────────────────────────────────────────────────┐
│                       SUPPLY CHAIN SECURITY                          │
│  Cosign Signing │ SBOM Generation │ SLSA Provenance │ Trivy Scans   │
├─────────────────────────────────────────────────────────────────────┤
│                       KUBERNETES SECURITY                            │
│  Kyverno Policies │ Pod Security Standards │ OPA Gatekeeper         │
│  Resource Quotas  │ Limit Ranges          │ Pod Disruption Budgets │
├─────────────────────────────────────────────────────────────────────┤
│                       NETWORK SECURITY                               │
│  Cilium NetworkPolicies │ Istio mTLS │ Egress Restrictions          │
│  API Gateway WAF        │ Rate Limiting                             │
├─────────────────────────────────────────────────────────────────────┤
│                       RUNTIME SECURITY                               │
│  Falco │ Tetragon │ Falcosidekick │ Audit Logging                   │
├─────────────────────────────────────────────────────────────────────┤
│                       SECRETS MANAGEMENT                             │
│  HashiCorp Vault │ External Secrets Operator │ SOPS + age           │
├─────────────────────────────────────────────────────────────────────┤
│                       IDENTITY & ACCESS                               │
│  Laravel Sanctum JWT │ RBAC (USER/ADMIN/AUDITOR) │ Service Accounts │
└─────────────────────────────────────────────────────────────────────┘
```

### 4.2 Security Controls by Layer

| Layer | Control | Tool | Enforcement |
|-------|---------|------|-------------|
| Code | SAST | Semgrep | CI blocking |
| Code | Secret Detection | Gitleaks | CI blocking |
| Code | Dependency Scan | Composer audit, Trivy fs | CI blocking |
| Build | Container Scan | Trivy image | CD blocking on CRITICAL |
| Build | Image Signing | Cosign | Mandatory |
| Build | SBOM Generation | Syft | Mandatory |
| Build | Provenance | SLSA Level 3 | Mandatory |
| Admission | Policy Enforcement | Kyverno | Audit (Enforce planned) |
| Admission | Image Verification | Kyverno verifyImages | Audit |
| Admission | Pod Security | PSS Restricted | Kyverno |
| Network | Default Deny | Cilium NetworkPolicy | Enforce |
| Network | Service mTLS | Istio | Planned |
| Runtime | Intrusion Detection | Falco | Real-time alerts |
| Runtime | eBPF Monitoring | Tetragon | Real-time |
| Secrets | Storage | Vault + ESO | Production only |
| Secrets | Encryption | SOPS + age | Git storage |

### 4.3 mTLS and Service Mesh

The platform uses Istio for service-to-service mutual TLS (mTLS) in production:

```
portal-web ──[mTLS]──> auth-users-service
portal-web ──[mTLS]──> chatbot-manager-service
portal-web ──[mTLS]──> conversation-service
portal-web ──[mTLS]──> audit-security-service
chatbot-manager ──[mTLS]──> Qdrant
chatbot-manager ──[mTLS]──> Ollama
chatbot-manager ──[mTLS]──> audit-security-service
```

Key configuration:
- **Strict mTLS mode** in production namespace (PeerAuthentication)
- **Permissive mode** in staging (gradual migration)
- **Certificate rotation** every 30 days via cert-manager + Istio CSR
- **AuthorizationPolicy** for fine-grained RBAC per endpoint

---

## 5. Observability Architecture

### 5.1 Three Pillars

```
Observability Stack
├── METRICS (Prometheus + Thanos)
│   ├── Service metrics (HTTP request rate, latency, errors)
│   ├── Kubernetes metrics (pod resource usage, node health)
│   ├── Security metrics (Falco events, Kyverno violations)
│   ├── Business metrics (RAG queries, audit scores)
│   └── SLO metrics (error budget burn rate)
│
├── LOGS (Loki + Promtail)
│   ├── Application logs (JSON structured)
│   ├── Kubernetes audit logs
│   ├── Falco security events
│   ├── ArgoCD sync events
│   └── Access logs (ngninx ingress)
│
└── TRACES (Tempo + OpenTelemetry)
    ├── Distributed tracing (service-to-service)
    ├── RAG query tracing (prompt → Qdrant → LLM → audit)
    └── Database query tracing
```

### 5.2 Metrics Collection Architecture

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ Kubernetes  │    │  Services   │    │  Security   │
│ Metrics     │    │  Metrics    │    │  Events     │
└──────┬──────┘    └──────┬──────┘    └──────┬──────┘
       │                  │                  │
       ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────┐
│                  Prometheus Server                    │
│              (Retention: 15 days local)               │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│                    Thanos Sidecar                     │
│          (Object storage: MinIO, retention: 1y)      │
└─────────────────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│                    Grafana                            │
│   Dashboards: SRE, Security, Business, Kubernetes    │
└─────────────────────────────────────────────────────┘
```

### 5.3 Alerting Architecture

```
Prometheus Rules
    │
    ▼
Alertmanager
    ├── Routes (severity-based)
    │   ├── critical → PagerDuty + Slack (immediate)
    │   ├── warning → Slack (business hours)
    │   └── info → Dashboard annotation
    │
    ├── Inhibitions (suppress lower-severity during major incidents)
    │
    ├── Silences (maintenance windows, known issues)
    │
    └── Time Intervals (on-call hours, quiet hours)
```

### 5.4 OpenTelemetry Integration

| Component | OTel Integration | Data Exported |
|-----------|-----------------|---------------|
| Laravel Services | OpenTelemetry PHP SDK | Traces (gRPC to OTel Collector) |
| Qdrant | Native OTel | Traces, Metrics |
| PostgreSQL | pg_stat_statements + OTel | Query traces |
| Istio | Envoy OTel access logs | Traces (per-request) |
| Kubernetes | kube-state-metrics | Cluster metrics |

```
OTel Collector Pipeline:
Receivers: OTLP gRPC/HTTP, Prometheus, Loki
Processors: batch, memory_limiter, attributes, filter, transform
Exporters: Prometheus, Loki, Tempo, Debug (development)
```

---

## 6. GitOps Workflow

### 6.1 App of Apps Pattern

SecureRAG Hub uses ArgoCD's **App of Apps** pattern to manage the entire platform declaratively:

```
securerag-root (Wave 0)
│
├── Application: securerag-project (Wave 1)
│   └── AppProject with RBAC boundaries
│
├── Application: securerag-image-updater (Wave 2)
│   └── Automatic digest updates
│
├── Applications (Platform — Waves 3-15):
│   ├── cert-manager (Wave 3)
│   ├── kyverno (Wave 5)
│   ├── kyverno-policies (Wave 6)
│   ├── metrics-server (Wave 10)
│   └── external-secrets (Wave 15)
│
├── Applications (Security — Waves 20-55):
│   ├── vault (Wave 20)
│   ├── istio-base + istiod (Wave 22)
│   ├── harbor (Wave 25)
│   ├── falco + falcosidekick (Wave 50)
│   └── tetragon (Wave 55)
│
├── Applications (Observability — Waves 30-35):
│   ├── prometheus + kube-state-metrics (Wave 30)
│   ├── loki + promtail (Wave 31)
│   ├── tempo (Wave 32)
│   ├── grafana (Wave 33)
│   └── thanos (Wave 35)
│
├── Applications (Data — Waves 36-45):
│   ├── postgres-operator (Wave 36)
│   ├── postgres-cluster (Wave 37)
│   ├── qdrant (Wave 38)
│   ├── minio (Wave 39)
│   └── velero (Wave 40)
│
├── ApplicationSet (Microservices — Waves by environment):
│   ├── securerag-portal-web-{env}
│   ├── securerag-auth-users-{env}
│   ├── securerag-chatbot-manager-{env}
│   ├── securerag-conversation-service-{env}
│   └── securerag-audit-security-service-{env}
│
└── Application: chaos-mesh (Wave 60, staging only)
```

### 6.2 Sync Waves Strategy

| Wave | Component | Purpose | Dependencies |
|------|-----------|---------|-------------|
| 0 | Root Application | Bootstrap | None |
| 1 | AppProject | RBAC boundaries | Wave 0 |
| 2 | Image Updater | Automatic digest sync | Wave 1 |
| 3 | cert-manager | TLS certificates | Wave 1 |
| 5-6 | kyverno + policies | Admission control | Wave 3 |
| 10 | metrics-server | Resource metrics | Wave 5 |
| 15 | external-secrets | Secret injection | Wave 5 |
| 20 | vault | Secrets management | Wave 15 |
| 22 | istio (base + control plane) | Service mesh | Wave 15 |
| 25 | harbor | OCI registry | Wave 22 |
| 30-35 | observability stack | Monitoring | Wave 25 |
| 36-38 | data services | PostgreSQL, Qdrant, MinIO | Wave 25 |
| 40 | velero | Backup | Wave 36 |
| 50-55 | runtime security | Falco, Tetragon | Wave 22 |
| 60 | chaos (Litmus/staging) | Resilience testing | Wave 40 |
| 0-5-70 | Microservices (env-specific) | Applications | Varies by env |

### 6.3 Progressive Delivery

```
Dev (auto-sync, immediate)
    │ Git commit → ArgoCD detects → deploys
    ▼
Staging (auto-sync, gated tests)
    │ CI passes → auto-promote → smoke tests
    ▼
Production (manual sync, approval required)
    │ Platform team approves → ArgoCD syncs → canary rollout
    ▼
DR (manual sync, cold standby)
    │ On-demand sync for failover testing
```

Environment characteristics:

| Attribute | Dev | Staging | Production | DR |
|-----------|-----|---------|-----------|-----|
| Sync Mode | Auto | Auto | Manual | Manual |
| Self-Heal | Yes | Yes | Yes | Yes |
| Prune | Yes | Yes | Yes | No |
| Replicas | 1 | 2 | 3-5 | 1 |
| HPA | No | Yes | Yes | No |
| PDB | No | Yes | Yes | No |
| Approval | None | CI gate | Platform team | SRE lead |
| Rollback | Immediate | Immediate | Staged | Staged |

### 6.4 Drift Detection and Remediation

| Condition | Detection Method | Response |
|-----------|-----------------|----------|
| Manual kubectl apply | ArgoCD 3-min poll | Self-heal reverts to Git state |
| Pod crash loop | Kubernetes health check | Automatic restart (unless PDB) |
| Image digest mismatch | ArgoCD diff | Sync to correct digest |
| ConfigMap deleted | ArgoCD diff | Recreate from Git |
| Manual scaling | ArgoCD diff | Revert to Git-specified replicas |
| Unauthorized namespace | Kyverno admission | Reject at admission |

---

## 7. Multi-Cluster Architecture

### 7.1 Cluster Topology

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Production     │     │  Staging        │     │  DR (Standby)   │
│  Region: eu-    │     │  Region: eu-    │     │  Region: us-    │
│  west-1         │     │  west-2         │     │  east-1         │
├─────────────────┤     ├─────────────────┤     ├─────────────────┤
│ 7 nodes         │     │ 5 nodes         │     │ 3 nodes         │
│ 56 vCPU, 168GB  │     │ 20 vCPU, 64GB   │     │ 12 vCPU, 32GB   │
│ 5 service rep.  │     │ 2 service rep.  │     │ 1 service rep.  │
│ Full HA + HPA   │     │ Standard config │     │ Minimal config  │
│ PostgreSQL HA   │     │ PostgreSQL HA   │     │ Single PG       │
│ Velero backup   │     │ Velero backup   │     │ Restore target  │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

### 7.2 Cluster Federation

| Cluster | ArgoCD Instance | Git Repo | Sync Direction |
|---------|----------------|----------|----------------|
| Production | Primary ArgoCD (in-cluster) | `main` branch | Pull (manual sync) |
| Staging | Primary ArgoCD (in-cluster) | `main` branch | Pull (auto sync) |
| DR | Standalone ArgoCD | `main` branch | Pull (manual sync) |

### 7.3 Cross-Cluster Communication

```
Production Cluster (eu-west-1)
    │
    ├── PostgreSQL Streaming Replication ──> DR Cluster (us-east-1)
    │       (Async replication, RPO < 1 hour)
    │
    ├── Velero Backup ──> MinIO (S3) <── DR Cluster can restore
    │       (Encrypted backups, retained 30 days)
    │
    └── Prometheus Remote Write ──> Thanos Receiver (Central)
            (Metrics available in global Thanos Query)
```

---

## 8. Data Architecture

### 8.1 PostgreSQL High Availability

```
┌─────────────────────────────────────────────┐
│            PostgreSQL HA Cluster             │
│                                             │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐
│  │ Primary  │<───│ Replica  │    │ Replica  │
│  │ (Read/   │    │ 1 (Read) │    │ 2 (Read) │
│  │  Write)  │    │          │    │          │
│  └────┬─────┘    └──────────┘    └──────────┘
│       │                                    │
│       │ Sync replication (synchronous)     │
│       └────────────────────────────────────┘
│                                             │
│  Connection Pooling: pgBouncer              │
│  Automatic Failover: Patroni / CNPG         │
│  Backup: pgBackRest + Velero                │
│  Monitoring: pg_stat_statements + exporter  │
└─────────────────────────────────────────────┘
```

### 8.2 Database Per Service

| Service | Database Name | Tables | Key Data |
|---------|--------------|--------|----------|
| portal-web | `portal_web` | sessions, user_preferences, settings | Session data, UI state |
| auth-users-service | `auth_users` | users, roles, permissions, password_resets | Credentials, RBAC |
| chatbot-manager-service | `chatbot_manager` | chatbots, configurations, vector_indexes | Bot definitions, RAG configs |
| conversation-service | `conversations` | conversations, messages, attachments | Chat history |
| audit-security-service | `audit_security` | audit_logs, security_events, reports | Immutable audit trail |

### 8.3 Qdrant Vector Architecture

```
Qdrant Cluster (3 nodes)
│
├── Collections:
│   ├── documents (RBAC-filtered document chunks)
│   │   ├── Payload: text, embedding, metadata
│   │   ├── Filterable fields: allowed_roles, document_type, owner, sensitivity_level
│   │   └── Index: HNSW (cosine similarity)
│   │
│   └── prompts (audit reference — hash only)
│       ├── Payload: prompt_hash, timestamp
│       └── Index: no vector, payload-only
│
├── Replication: 3x factor (production)
├── Sharding: auto (by collection size)
└── Backup: Qdrant snapshot → MinIO (hourly)
```

### 8.4 MinIO Object Storage

```
MinIO ── S3-compatible object storage
│
├── Buckets:
│   ├── securerag-backups/        (Velero, DB dumps)
│   ├── securerag-logs/           (Loki chunks)
│   ├── securerag-metrics/        (Thanos data)
│   ├── securerag-traces/         (Tempo data)
│   ├── securerag-artifacts/      (Build artifacts, SBOMs)
│   └── securerag-uploads/        (User document uploads)
│
├── Encryption: SSE-S3 with Vault-managed keys
├── Versioning: Enabled on critical buckets
├── Replication: Cross-bucket (production → DR)
└── Retention: Policy-based lifecycle rules
```

---

## 9. CI/CD Pipeline Architecture

### 9.1 Pipeline Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      CI PIPELINE (15 stages)                     │
│                                                                 │
│  1.  Checkout SCM ─── Proof of commit                           │
│  2.  Prepare Workspace                                          │
│  3.  Install CI Dependencies (composer, npm, semgrep)           │
│  4.  Lint (PHPStan, ESLint, Pint) ─── Quality Gate 1           │
│  5.  Unit Tests (PHPUnit) ─── Quality Gate 2 (coverage ≥ 70%)  │
│  6.  Feature Tests ─── Quality Gate 3                           │
│  7.  Dependency Audit (Composer, npm) ─── Quality Gate 4        │
│  8.  SAST (Semgrep) ─── Quality Gate 5                          │
│  9.  Secret Scan (Gitleaks) ─── Quality Gate 6                  │
│  10. Filesystem Scan (Trivy fs) ─── Quality Gate 7              │
│  11. K8s Lint (kube-score) ─── Quality Gate 8                   │
│  12. Kyverno Static Validation ─── Quality Gate 9               │
│  13. Sonar Quality Gate ─── Quality Gate 10 (optional)          │
│  14. Consolidated Quality Gate ─── Quality Gate 11 (aggregator) │
│  15. Archive Reports ─── Evidence collection                    │
│                                                                 │
│  ↓ On PASS: Trigger CD pipeline                                  │
└─────────────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                      CD PIPELINE (15 stages)                     │
│                                                                 │
│  1.  Checkout                                                   │
│  2.  Image Scan (Trivy) ─── Block on CRITICAL                   │
│  3.  Sign Release Candidate Images (Cosign)                     │
│  4.  Verify Signatures (Cosign verify)                          │
│  5.  Promote Verified Images by Digest                          │
│  6.  Generate SBOM (Syft CycloneDX)                             │
│  7.  Attest SBOMs (Cosign attest)                               │
│  8.  Assert Supply Chain Evidence                               │
│  9.  Generate Release Attestation                               │
│  10. Generate SLSA Provenance                                   │
│  11. Record Release Evidence                                    │
│  12. Collect Supply Chain Evidence                              │
│  13. Deploy to Cluster (kind / K8s)                             │
│  14. Post-Deploy Validation (smoke tests, security checks)      │
│  15. Build Support Pack                                         │
└─────────────────────────────────────────────────────────────────┘
```

### 9.2 Quality Gates Detail

| Gate # | Stage | Tool | Criteria | Failure Action |
|--------|-------|------|----------|---------------|
| QG1 | Lint | PHPStan level max, Pint | 0 errors, 0 warnings | Block CI |
| QG2 | Coverage | PHPUnit with Cobertura | ≥ 70% line coverage | Block CI |
| QG3 | Tests | PHPUnit | 100% test suite pass | Block CI |
| QG4 | Dep Audit | Composer audit, Trivy fs | 0 CRITICAL vulnerabilities | Block CI |
| QG5 | SAST | Semgrep | 0 findings per rule set | Block CI |
| QG6 | Secrets | Gitleaks | 0 leaked secrets | Block CI |
| QG7 | Filesystem | Trivy fs | 0 CRITICAL, HIGH documented | Block CI on CRITICAL |
| QG8 | K8s Lint | kube-score | Score ≥ 90%, no CRITICAL | Block CI |
| QG9 | Kyverno | kyverno validate | All policies pass statically | Block CI |
| QG10 | Sonar | SonarQube | Quality Gate PASS (optional) | Warn only |
| QG11 | Aggregator | quality-gate.sh | All previous gates PASS | Block CD trigger |

### 9.3 Artifact Provenance Chain

```
Source Code (Git commit: abc123)
    │
    ▼
Docker Image (sha256:def456)
    ├── Trivy Scan Report
    ├── Cosign Signature
    ├── SBOM (CycloneDX JSON)
    ├── SBOM Attestation (Cosign)
    ├── SLSA Provenance (in-toto)
    └── Release Attestation (signed)
            │
            ▼
Promoted by Digest (@sha256:def456)
    ├── kustomization.yaml updated
    ├── Commit to GitOps repo
    └── ArgoCD syncs to cluster
            │
            ▼
Runtime Pod (imageID: sha256:def456)
    ├── Kyverno admission verification
    ├── Runtime validation report
    └── Post-deploy smoke tests
```

---

## 10. Decision Log

### ADR-001: Laravel as Official Runtime

| Field | Detail |
|-------|--------|
| **Date** | 2025-09-15 |
| **Status** | ACCEPTED |
| **Context** | Initial spec called for FastAPI Python runtime. Analysis showed Laravel offered superior maturity, built-in authentication (Sanctum), RBAC, and testing infrastructure. |
| **Decision** | Adopt Laravel 11 as official runtime. Python code retained as prototype under `services/`. |
| **Consequence** | + Faster development, + Better tooling, - Requires PHP runtime in containers. |

### ADR-002: Kustomize over Helm

| Field | Detail |
|-------|--------|
| **Date** | 2025-09-20 |
| **Status** | ACCEPTED |
| **Context** | Need to manage Kubernetes manifests across environments (dev, staging, production, DR, demo) without Helm's complexity. |
| **Decision** | Use Kustomize with base + overlays pattern. Plain YAML with strategic merge patches. |
| **Consequence** | + Full visibility, + No Helm RBAC/Tiller issues, - No templating (duplication in overlays). |

### ADR-003: Cosign Key-Based over Keyless

| Field | Detail |
|-------|--------|
| **Date** | 2025-10-01 |
| **Status** | ACCEPTED (with migration plan to keyless) |
| **Context** | Need cryptographic image signing for supply chain security. Keyless (OIDC) requires external identity provider. |
| **Decision** | Start with Cosign key-based signing. Plan migration to keyless with Fulcio + Rekor. |
| **Consequence** | + Simpler initial setup, - Key management overhead, + Migration path documented. |

### ADR-004: Qdrant over Pinecone/Weaviate

| Field | Detail |
|-------|--------|
| **Date** | 2025-10-15 |
| **Status** | ACCEPTED |
| **Context** | Need vector database with rich metadata filtering for RBAC-enforced document access. |
| **Decision** | Adopt Qdrant for its payload filtering, self-hosted deployment, and gRPC API. |
| **Consequence** | + Full RBAC at database level, + Self-hosted (no data leaving cluster), - Requires Kubernetes infrastructure. |

### ADR-005: Jenkins over GitHub Actions

| Field | Detail |
|-------|--------|
| **Date** | 2025-11-01 |
| **Status** | ACCEPTED |
| **Context** | Need enterprise-grade CI/CD with complex pipeline orchestration, artifact management, and security scanning. |
| **Decision** | Jenkins as primary CI/CD engine. GitHub Actions retained as secondary/fallback. |
| **Consequence** | + Full pipeline control, + Plugin ecosystem, - Requires Jenkins management. |

### ADR-006: ArgoCD over Flux

| Field | Detail |
|-------|--------|
| **Date** | 2025-11-10 |
| **Status** | ACCEPTED |
| **Context** | Need GitOps deployment with multi-cluster support, sync waves, and App of Apps pattern. |
| **Decision** | ArgoCD for its mature multi-cluster support, ApplicationSet CRD, and sync wave ordering. |
| **Consequence** | + Rich feature set, + Large community, - More complex initial setup. |

### ADR-007: Single-Cluster with DR Standby

| Field | Detail |
|-------|--------|
| **Date** | 2025-12-01 |
| **Status** | ACCEPTED |
| **Context** | Multi-cluster federation adds complexity. Need production, staging, and DR isolation. |
| **Decision** | Single production cluster with warm standby DR cluster. Cross-cluster replication for critical data. |
| **Consequence** | + Lower operational overhead, - Single-region bottleneck in production, + DR tested quarterly. |

### ADR-008: Istio for Service Mesh

| Field | Detail |
|-------|--------|
| **Date** | 2026-01-15 |
| **Status** | PLANNED |
| **Context** | Need mTLS, traffic splitting, circuit breaking, and observability for microservices. |
| **Decision** | Adopt Istio with strict mTLS mode. Gradual rollout starting with production namespace. |
| **Consequence** | + Full mTLS, + Traffic management, - Resource overhead of sidecar proxies. |

---

## 11. ASCII Architecture Diagram

```
                             ┌───────────────────────────────────┐
                             │          DEVELOPER                │
                             │     (git push feature branch)     │
                             └──────────────┬────────────────────┘
                                            │
                                            ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              GITHUB (Source of Truth)                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌───────────────────┐  │
│  │  main       │  │  feature/*  │  │  releases/* │  │  Webhook Config   │  │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────┬─────────┘  │
└─────────────────────────────────────────────────────────────────┼───────────┘
                                                                  │
                                                                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          JENKINS (CI/CD Engine)                              │
│                                                                              │
│  ┌─────────────────────── CI PIPELINE ──────────────────────────────────┐   │
│  │  Checkout → Lint → Test → SAST → Trivy → Kyverno → 11x Quality Gate  │   │
│  └──────────────────────────────────┬────────────────────────────────────┘   │
│                                     │ PASS                                   │
│                                     ▼                                        │
│  ┌─────────────────────── CD PIPELINE ──────────────────────────────────┐   │
│  │  Trivy → Sign → Verify → Promote → SBOM → Attest → Deploy → Validate│   │
│  └──────────────────────────────────┬────────────────────────────────────┘   │
│                                     │                                        │
│  ┌─── Jenkins Artifacts ───────────────────────────────────────────────┐   │
│  │  Signatures │ SBOMs │ Attestations │ Provenance │ Release Evidence   │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┬────────────────────────────┘
                                                   │
                                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         HARBOR (OCI Registry)                                │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │  securerag-hub/portal-web@sha256:abc... (signed + attested)          │   │
│  │  securerag-hub/auth-users@sha256:def... (signed + attested)          │   │
│  │  securerag-hub/chatbot-manager@sha256:ghi... (signed + attested)     │   │
│  │  securerag-hub/conversation-service@sha256:jkl... (signed + attested)│   │
│  │  securerag-hub/audit-security-service@sha256:mno... (signed + attest)│   │
│  └──────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┬────────────────────────────┘
                                                   │
                                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                  ARGOCD (GitOps — App of Apps)                               │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │  securerag-root ◄── detects drift ◄── watches Git repo                │   │
│  │      │                                                               │   │
│  │      ├── ApplicationSet (portal-web, auth-users, ...) × 4 envs       │   │
│  │      ├── ApplicationSet (platform: kyverno, istio, prometheus, ...)  │   │
│  │      ├── ApplicationSet (security: falco, tetragon, vault)           │   │
│  │      └── ApplicationSet (data: postgres, qdrant, minio, velero)      │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┬────────────────────────────┘
                                                   │ sync waves
                                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                     KUBERNETES CLUSTER (Production)                          │
│                                                                              │
│  ┌────── Namespace: securerag-hub ──────────────────────────────────────┐   │
│  │                                                                      │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────┐ │   │
│  │  │portal-web│  │  auth-   │  │ chatbot- │  │conversat-│  │ audit- │ │   │
│  │  │  :8000   │  │  users   │  │ manager  │  │ ion-svc  │  │security│ │   │
│  │  │ rep: 3-5 │  │  :8000   │  │  :8000   │  │  :8000   │  │ :8000  │ │   │
│  │  │ HPA: on  │  │ rep: 2-3 │  │ rep: 2-3 │  │ rep: 2-3 │  │rep: 2-3│ │   │
│  │  │ PDB: min │  │ HPA: on  │  │ HPA: on  │  │ HPA: on  │  │HPA: on │ │   │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘  └────────┘ │   │
│  │                                                                      │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐                           │   │
│  │  │PostgreSQL│  │  Qdrant  │  │  Ollama  │                           │   │
│  │  │  HA (3)  │  │  (3 shd) │  │  (1 pod) │                           │   │
│  │  └──────────┘  └──────────┘  └──────────┘                           │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌────── Namespace: securerag-security ────────────────────────────────┐   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐            │   │
│  │  │  Falco   │  │ Tetragon │  │ Kyverno  │  │  Vault   │            │   │
│  │  │ DaemonSet│  │ DaemonSet│  │Deployment│  │ Stateful │            │   │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘            │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌────── Namespace: securerag-monitoring ──────────────────────────────┐   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐            │   │
│  │  │Prometheus│  │  Grafana │  │   Loki   │  │  Tempo   │            │   │
│  │  │ (Thanos) │  │   (HA)   │  │  (SSD)   │  │  (S3)   │            │   │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘            │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌────── Namespace: securerag-gitops ──────────────────────────────────┐   │
│  │  ┌──────────┐  ┌──────────┐  ┌────────────────────┐                 │   │
│  │  │ ArgoCD   │  │ ArgoCD   │  │ Application CRDs   │                 │   │
│  │  │ Server   │  │ Image    │  │ ──── 30+ managed   │                 │   │
│  │  │          │  │ Updater  │  │ applications       │                 │   │
│  │  └──────────┘  └──────────┘  └────────────────────┘                 │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌────── Namespace: securerag-storage ─────────────────────────────────┐   │
│  │  ┌──────────┐  ┌──────────┐                                         │   │
│  │  │  MinIO   │  │  Velero  │                                         │   │
│  │  │  (S3)    │  │ Backup   │                                         │   │
│  │  └──────────┘  └──────────┘                                         │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## References

- [GitOps Workflow](gitops-workflow.md)
- [DevSecOps Pipeline](devsecops-pipeline.md)
- [Kubernetes Security](kubernetes-security.md)
- [SRE Guide](SRE_GUIDE.md)
- [Security Guide](SECURITY_GUIDE.md)
- [DR Guide](DR_GUIDE.md)
- [Operations Guide](OPERATIONS_GUIDE.md)
- [Threat Model](threat-model.md)
- [Architecture Diagrams](diagrams/)

---

*Document maintained by the Platform Engineering team. For questions, contact #platform-team on Slack.*
