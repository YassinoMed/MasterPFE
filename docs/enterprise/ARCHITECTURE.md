# SecureRAG Hub — Enterprise Architecture (Factual Scope)

## Overview

SecureRAG Hub is a DevSecOps platform built on a secure cloud-native infrastructure. The official active runtime consists of **5 PHP/Laravel microservices** deploying standard Kubernetes workloads. Advanced features such as the Python AI agent layer, the Qdrant vector store, local LLM orchestration via Ollama, and progressive delivery (Argo Rollouts) are defined as **conceptual prototypes and perspectives**.

---

## 1. Real vs. Target Architecture Layers

```
┌─────────────────────────────────────────────────────────────┐
│                    USER / CI/CD TRIGGER                      │
│                    Exposed via NodePort/ClusterIP            │
├─────────────────────────────────────────────────────────────┤
│                REAL APPLICATION LAYER (Laravel-first)       │
│  ┌──────────┐ ┌───────────┐ ┌──────────────┐ ┌───────────┐ │
│  │portal-web│ │auth-users │ │chatbot-mgr   │ │conversation│ │
│  │(Laravel) │ │(Laravel)  │ │(Laravel)     │ │(Laravel)    │ │
│  └──────────┘ └───────────┘ └──────────────┘ └───────────┘ │
│  ┌────────────────────────┐                                  │
│  │audit-security-service  │ ← CRUD Log/Evidence storage      │
│  │(Laravel)               │                                  │
│  └────────────────────────┘                                  │
├─────────────────────────────────────────────────────────────┤
│                DATA LAYER                                    │
│  PostgreSQL (auth-users) │ SQLite (Local container file db) │
├─────────────────────────────────────────────────────────────┤
│                SECURITY & INFRASTRUCTURE LAYER               │
│  Vault (secrets) │ Kyverno (policies) │ Harbor (registry)   │
│  Cosign (signing)│ SBOM (Syft)        │ SLSA (provenance)   │
│  ESO (injection) │ NetworkPolicies    │ Velero (backup)     │
├─────────────────────────────────────────────────────────────┤
│                OBSERVABILITY LAYER                           │
│  Prometheus │ Grafana │ Loki │ Tempo │ OTel │ AlertManager  │
├─────────────────────────────────────────────────────────────┤
│                GITOPS LAYER                                  │
│  ArgoCD (sync)  │ Kustomize (dev, demo, production overlays)│
└─────────────────────────────────────────────────────────────┘
```

### Perspectives & Roadmap Components (Target Architecture only)
- **AI Governance Layer**: AI Security Orchestrator, Planner Agent, Threat Modeler, Risk Engine, Consensus Engine, Decision Engine (uncompiled python prototypes under `/services/` and `scripts/ai-agents/` fallbacks).
- **Vector DB & LLM**: Qdrant vector database, Ollama local LLM execution.
- **Progressive Delivery**: Argo Rollouts (Canary/Blue-Green), KEDA (autoscaling).
- **Admission Controls**: OPA Gatekeeper (Kyverno acts as the sole active Admission Controller).
- **Intrusion Detection**: Falco & Falco Talon (DaemonSet configured but currently inactive on cluster nodes).

---

## 2. Microservices Registry

### Real & Operational Microservices (Laravel-first)

| Service | Language | Port (Internal) | Description | Deployment Status |
|---------|----------|-----------------|-------------|-------------------|
| **portal-web** | PHP/Laravel | 8000 | Web frontend interface | ✅ Synced & Running |
| **auth-users-service** | PHP/Laravel | 8000 | User registration, authentication, Sanctum RBAC | ✅ Synced & Running |
| **chatbot-manager-service** | PHP/Laravel | 8000 | Chat orchestrator & RAG interface | ✅ Synced & Running |
| **conversation-service** | PHP/Laravel | 8000 | Conversation sessions management | ✅ Synced & Running |
| **audit-security-service** | PHP/Laravel | 8000 | CRUD storage of incident/compliance logs | ✅ Synced & Running |

### Requalified Microservices (Perspectives / Prototypes under `/services/`)

| Service | Language | Port | Requalification Category | Technical Justification |
|---------|----------|------|──────────────────────────|─────────────────────────|
| **security-auditor** | Python/FastAPI | 8082 | Prototype / Perspective | Codebase exists as FastAPI skeleton; excluded from CI/CD compilation and K8s manifests. |
| **ai-orchestrator** | Python/FastAPI | 8091 | Prototype / Perspective | Conceptual AI planner; mocked via Jenkinsfile fallback curls. |
| **ai-risk-engine** | Python/FastAPI | 8092 | Prototype / Perspective | Conceptual risk scorer; mocked via Jenkinsfile fallback curls. |
| **ai-security-orchestrator** | Python/FastAPI | 8100 | Prototype / Perspective | Concept; codebase contains skeletal logic. |
| **ai-knowledge-graph** | Python/FastAPI | 8110 | Prototype / Perspective | Concept; uncompiled. |
| **rag-service** | Python/FastAPI | 8000 | Prototype / Perspective | Concept RAG pipeline. |
| **knowledge-hub** | Python/FastAPI | 8000 | Prototype / Perspective | Concept document loader. |
| **llm-orchestrator** | Python/FastAPI | 8000 | Prototype / Perspective | Excluded due to Ollama local weight. |

---

## 3. Security Architecture

### Zero Trust Principles
1. **Never trust, always verify** — NetworkPolicies restrict ingress/egress between namespaces.
2. **Least privilege** — Custom ServiceAccounts with read-only RBAC where applicable.
3. **Verify explicitly** — Image validation via Kyverno checking Cosign signatures and SLSA provenance.

### Supply Chain Security (SLSA v1.0 Framework)
1. **Image Signature**: Jenkins signs all built Laravel OCI images using Cosign keypairs.
2. **SBOM Generation**: Syft scans the images and generates CycloneDX JSON software bill of materials.
3. **SBOM Vulnerability Scan**: Grype scans SBOMs for vulnerabilities during CI/CD.
4. **Admission Control**: Kyverno enforces image verification, blocking unsigned or unattested images.

---

## 4. GitOps & Progressive Delivery

### ArgoCD Setup
ArgoCD manages application deployment via GitOps using overlays:
- **dev**: Local development overlay.
- **demo**: Official defense (soutenance) overlay.
- **production**: Hardened multi-replica production overlay.

### Progressive Delivery status
- **Progressive Delivery (Argo Rollouts)** is **not implemented** in the active cluster. Deployments utilize standard rolling updates. Canary/Blue-Green configuration manifests are kept under `/infra/k8s/argo-rollouts/` as **Roadmap perspectives**.
