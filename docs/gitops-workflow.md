# GitOps Workflow — SecureRAG Hub

## Architecture

SecureRAG Hub implements a **GitOps** deployment model using **ArgoCD** as the continuous delivery engine. The architecture follows a strict **pull-based** model where ArgoCD is the sole component authorized to modify cluster state.

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌────────────────┐
│   Developer   │     │   GitHub     │     │   Jenkins    │     │    ArgoCD      │
│   (git push)  │────>│  (source of  │────>│  (CI build,  │────>│ (pull-based CD)│
│               │     │   truth)     │     │  scan, push) │     │                │
└──────────────┘     └──────────────┘     └──────────────┘     └───────┬────────┘
                                                                       │
                                                                       v
                                                              ┌────────────────┐
                                                              │  Kubernetes    │
                                                              │   Cluster      │
                                                              │ (desired state)│
                                                              └────────────────┘
```

### Flow

1. **Developer pushes code** to GitHub (feature branch → PR → `main`)
2. **Jenkins CI** builds, scans (Trivy), signs (Cosign), and pushes the image to **Harbor** (private OCI registry)
3. **Jenkins CD** updates `infra/k8s/overlays/<env>/kustomization.yaml` with the new image digest and commits to `main`
4. **ArgoCD** detects the drift between Git (new digest) and cluster (old digest) and auto-syncs
5. **Kubernetes** performs a rolling update to replace pods with the new image
6. **ArgoCD Image Updater** continuously monitors Harbor for new digests and updates Application parameters

## App of Apps Pattern

The entire SecureRAG Hub infrastructure is managed via the **App of Apps** pattern. A single root Application (`securerag-root`) deploys all child Applications and ApplicationSets:

```
securerag-root (wave 1)
├── securerag-project (AppProject — RBAC boundaries)
├── ApplicationSets:
│   ├── securerag-platform-core (cert-manager, kyverno, secrets, wave 3-15)
│   ├── securerag-platform (observability, backup, runtime-detection, wave 30-50)
│   ├── securerag-observability (Prometheus/Grafana/Loki stack, wave 30-35)
│   ├── securerag-runtime-security (Falco/Falcosidekick/Talon, wave 50-55)
│   ├── securerag-data-backup (Velero, chaos, wave 40-60)
│   ├── securerag-multi-cluster (staging + DR clusters, wave 25-30)
│   └── securerag-all-services (microservices × environments, wave 0-5/60-65/70-75)
├── Individual Helm Apps:
│   ├── securerag-cert-manager (wave 3)
│   ├── securerag-vault (wave 20)
│   ├── securerag-harbor (wave 25)
│   ├── securerag-velero (wave 35)
│   └── securerag-falco-talon (wave 55)
├── Environment Overlays:
│   ├── securerag-demo (wave 10)
│   └── securerag-production (wave 20)
└── securerag-image-updater (wave 2)
```

### Bootstrap

```bash
# 1. Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.10.7/manifests/install.yaml

# 2. Wait for ArgoCD to be ready
kubectl rollout status deploy/argocd-server -n argocd --timeout=300s

# 3. Apply the Root Application (triggers the entire App of Apps tree)
kubectl apply -k infra/k8s/argocd
```

## Sync Waves Strategy

ArgoCD **Sync Waves** control the order in which Applications are deployed. Applications in lower waves deploy before applications in higher waves. SecureRAG Hub uses the following wave mapping:

| Wave | Component                          | Purpose                          |
|------|------------------------------------|----------------------------------|
| 1    | securerag-root                     | Root Application bootstrap       |
| 2    | securerag-image-updater            | Automatic image update controller|
| 3    | cert-manager                       | TLS certificate management       |
| 5-6  | kyverno, kyverno-policies          | Admission control & policy engine |
| 10   | metrics-server                     | Resource metrics                  |
| 15   | secrets (External Secrets)         | Secret injection                  |
| 20   | vault                              | Secrets management                |
| 25   | harbor                             | Private OCI registry              |
| 30-35| observability stack                | Monitoring & dashboards           |
| 40   | backup (Velero)                    | Backup & restore                  |
| 50-55| runtime detection (Falco + Talon)  | Runtime security                  |
| 60   | chaos (Litmus)                     | Chaos engineering                 |
| **Microservices (per environment):** |                                |                                   |
| 0-5  | Dev/Staging services               | portal-web (0), auth-users (1), chatbot-manager (2), conversation-service (3), audit-security-service (4), validation (5) |
| 60-65| Production services                | Same order, offset for platform deps |
| 70-75| DR services                        | Same order, DR-specific tuning    |

Within each environment, microservices are deployed **progressively**:
- **Wave 0**: `portal-web` — frontend gateway (deployed first)
- **Wave 1**: `auth-users` — authentication dependency
- **Wave 2**: `chatbot-manager` — AI chat orchestration
- **Wave 3**: `conversation-service` — conversation persistence
- **Wave 4**: `audit-security-service` — audit logging (deployed last)
- **Wave 5**: `canary-validation` — post-deployment smoke tests

## Self-Heal and Auto-Sync

### Automated Sync Policy

All SecureRAG Applications are configured with:

```yaml
syncPolicy:
  automated:
    prune: true          # Remove resources not in Git
    selfHeal: true       # Revert manual changes to match Git
    allowEmpty: false    # Fail if no resources would be created
  syncOptions:
    - CreateNamespace=true
    - ApplyOutOfSyncOnly=true  # Only apply changed resources
    - ServerSideApply=true     # Server-side apply (SSA)
    - PrunePropagationPolicy=foreground
  retry:
    limit: 5
    backoff:
      duration: 10s
      factor: 2
      maxDuration: 5m
```

### Self-Healing Behavior

| Scenario                                    | ArgoCD Action                                          |
|---------------------------------------------|--------------------------------------------------------|
| Admin manually scales a Deployment          | Reverts replicas to Git-defined value                  |
| ConfigMap deleted via `kubectl delete`      | Recreates ConfigMap from Git                           |
| Image tag changed via `kubectl edit`        | Reverts image tag to Git-specified digest              |
| Entire Deployment deleted                   | Recreation from Git manifests                          |

### Drift Detection

ArgoCD continuously monitors for drift (default: 3-minute poll interval). When drift is detected:
1. If `selfHeal: true`, ArgoCD **automatically corrects** the drift
2. Notifications are sent via Slack webhook (configured in `notifications-cm.yaml`)
3. Drift events are logged with full details

To manually check drift:

```bash
# List all apps with sync status
kubectl get applications -n argocd -o wide

# Force a refresh (re-evaluate manifests)
kubectl annotate application securerag-portal-web-production -n argocd \
  argocd.argoproj.io/refresh=hard --overwrite

# Use the sync script
./scripts/gitops/sync-argocd.sh
```

## Progressive Delivery

SecureRAG Hub implements **progressive delivery** across environments using a combination of:
- **Sync Waves** (gradual rollout order)
- **Environment promotion** (dev → staging → production → DR)
- **Manual approval gates** for production

### Environment Promotion Flow

```
┌─────┐     ┌─────────┐     ┌────────────┐     ┌──────┐
│ Dev │────>│ Staging │────>│ Production │────>│  DR  │
│auto │     │ auto    │     │  manual    │     │manual│
│sync │     │ sync    │     │  approval  │     │ sync │
└─────┘     └─────────┘     └────────────┘     └──────┘
```

- **Dev**: Auto-sync with `selfHeal: true`. Immediate deployment on Git push.
- **Staging**: Auto-sync with `selfHeal: true`. Mirrors production configuration.
- **Production**: Manual sync (`automated.sync: false`). Requires platform-team approval via ArgoCD UI or CLI.
- **DR**: Manual sync with `selfHeal: false`. Cold standby — minimal replicas.

### Canary Validation

Wave 5 in each environment runs a `canary-validation` Application that executes post-deployment smoke tests:
- Health check endpoints reachable
- Database connectivity
- Service-to-service communication
- Security policy compliance (Kyverno validation)

## Multi-Environment Management

### Per-Environment Overlays

Each environment has a dedicated Kustomize overlay under `infra/k8s/overlays/<env>/`:

```
infra/k8s/overlays/
├── dev/                    # Development — NodePort, debug logging
│   ├── kustomization.yaml  # Inherits from ../../base
│   └── configmap-env.env   # APP_ENV=dev, LOG_LEVEL=debug
├── staging/                # Staging — mirrors production config
│   ├── kustomization.yaml  # Inherits from ../dev + kyverno
│   └── configmap-env.env
├── production/             # Production — HA, HPA, PDB, resource quotas
│   ├── kustomization.yaml
│   ├── configmap-env.env   # APP_ENV=production, audit chain enabled
│   └── patches/            # HA patches (replicas, PDB, HPA)
├── demo/                   # Demo overlay — single replica, demo images
│   ├── kustomization.yaml
│   └── configmap-env.env
└── recette/                 # QA overlay
    └── kustomization.yaml
```

### Per-Microservice Applications

The `applicationset-all.yaml` generates one ArgoCD Application per microservice per environment using a **matrix generator**:

```yaml
generators:
  - matrix:
      generators:
        - list:          # Environments
            elements:
              - env: dev
                imageTag: dev
                waveOffset: "0"
              - env: production
                imageTag: production
                waveOffset: "60"
        - list:          # Microservices
            elements:
              - name: portal-web
                wave: "0"
              - name: auth-users
                wave: "1"
```

This generates Applications named: `securerag-portal-web-dev`, `securerag-portal-web-production`, etc.

### Image Management per Environment

Each environment uses environment-specific image tags via the ApplicationSet template:

| Environment | Image Tag   | Wave Offset | Sync Mode   |
|-------------|-------------|-------------|-------------|
| dev         | dev         | 0           | auto        |
| staging     | staging     | 0           | auto        |
| production  | production  | 60          | manual      |
| dr          | dr          | 70          | manual      |

## Rollback Procedures

### Rollback via ArgoCD

```bash
# List deployment history
argocd app history securerag-production

# Rollback to a specific revision
argocd app rollback securerag-production <REVISION>

# Verify rollback status
argocd app get securerag-production
```

### Rollback via Git Revert

```bash
# Revert the Git commit that changed the image digest
git revert <COMMIT_HASH>
git push origin main

# ArgoCD will detect the revert and auto-sync (for auto-sync apps)
# For manual-sync apps, trigger sync:
argocd app sync securerag-production
```

### Rollback Script

```bash
# Use the existing rollback script
./scripts/gitops/rollback-deployment.sh production portal-web <REVISION>
```

### Revision History Limits

| Application                   | Retained Revisions |
|-------------------------------|-------------------|
| securerag-demo                | 10                |
| securerag-production          | 20                |
| Per-microservice apps (dev)   | 10                |
| Per-microservice apps (prod)  | 20                |

## Disaster Recovery for ArgoCD

### Prerequisites

ArgoCD itself is managed as an ArgoCD Application (`securerag-root` → `application-root.yaml`). This ensures ArgoCD's configuration is fully declared in Git.

### DR Strategy

| Scenario                              | Recovery Procedure                                                                 |
|---------------------------------------|------------------------------------------------------------------------------------|
| ArgoCD pod failure                    | Kubernetes automatically restarts the pod (Deployment)                             |
| ArgoCD configuration corruption       | `kubectl replace -f infra/k8s/argocd/` — restore ConfigMaps from Git               |
| Complete ArgoCD loss (namespace gone) | Reinstall ArgoCD + reapply root Application (see bootstrap instructions)            |
| Cluster failure                       | DR cluster: apply ArgoCD manifests, point to same Git repo, trigger sync           |
| Git repository corruption             | Restore from Velero backup of CRDs, or re-push from local mirror                   |

### ArgoCD Backup

ArgoCD stores its state in:
1. **Kubernetes CRDs** (Applications, AppProjects, ApplicationSets) — backed up by Velero
2. **Git repository** (the source of truth) — backed up by GitHub
3. **ArgoCD secrets** (admin password, repo credentials) — backed up by Velero + External Secrets

### Full Recovery Procedure

```bash
# 1. Ensure the DR cluster has kubectl access
kubectl config use-context dr-cluster

# 2. Install ArgoCD on DR cluster
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.10.7/manifests/install.yaml
kubectl rollout status deploy/argocd-server -n argocd --timeout=300s

# 3. Apply SecureRAG GitOps configuration
kubectl apply -k infra/k8s/argocd/

# 4. Verify all Applications are syncing
./scripts/gitops/sync-argocd.sh

# 5. For production DR, manually approve sync:
argocd app sync securerag-production
argocd app sync securerag-portal-web-production
argocd app sync securerag-auth-users-production
# ... (all production microservice apps)
```

### Velero-based DR

The existing Velero backup infrastructure (wave 40) automatically backs up:
- All Application CRDs in `argocd` namespace
- Application configuration data
- Secrets

```bash
# Trigger an on-demand backup
velero backup create argocd-dr-backup --include-namespaces argocd

# Restore on DR cluster
velero restore create --from-backup argocd-dr-backup
```

## RBAC Model

SecureRAG Hub's ArgoCD RBAC follows the principle of least privilege:

| Role          | Permissions                                         | Assigned To                |
|---------------|-----------------------------------------------------|----------------------------|
| admin         | Full access to all projects and Applications        | SRE / Platform leads       |
| auditor       | Read-only access to all Applications, logs, clusters| Compliance / Security team |
| developer     | CRUD + sync for dev/staging Applications            | Feature team developers    |
| platform-team | Full management of production Applications          | Platform engineers         |

RBAC is configured in `infra/k8s/argocd/rbac-cm.yaml` and enforced via ArgoCD's built-in policy engine.

## Verification Commands

```bash
# --- Check ArgoCD Application Status ---
kubectl get applications -n argocd
kubectl get applications -n argocd -o wide

# --- Detailed Status ---
kubectl describe application securerag-production -n argocd

# --- CLI Checks ---
argocd app list
argocd app get securerag-production
argocd app sync securerag-demo

# --- Automated Sync Script ---
./scripts/gitops/sync-argocd.sh                    # Text summary
./scripts/gitops/sync-argocd.sh --output json       # JSON output
./scripts/gitops/sync-argocd.sh --sync              # Force sync all
./scripts/gitops/sync-argocd.sh --watch             # Continuous monitoring
./scripts/gitops/sync-argocd.sh --app portal-web    # Single service
./scripts/gitops/sync-argocd.sh --env production    # Single environment

# --- Image Update Verification ---
./scripts/gitops/update-image-digest.sh dev portal-web sha256:abc123...

# --- Disaster Recovery ---
./scripts/gitops/disaster-recovery.sh
```

## Key Configuration Files

| File                                         | Purpose                                    |
|----------------------------------------------|--------------------------------------------|
| `infra/k8s/argocd/application-root.yaml`     | Root App of Apps entry point               |
| `infra/k8s/argocd/project.yaml`              | AppProject with RBAC boundaries            |
| `infra/k8s/argocd/applicationset-all.yaml`   | Per-microservice per-environment apps      |
| `infra/k8s/argocd/applicationset-platform.yaml` | Platform infrastructure apps            |
| `infra/k8s/argocd/argocd-cm.yaml`            | Global ArgoCD configuration                |
| `infra/k8s/argocd/rbac-cm.yaml`              | RBAC roles and policies                    |
| `infra/k8s/argocd/application-image-updater.yaml` | Automatic image updates          |
| `infra/k8s/argocd/notifications-cm.yaml`     | Slack notifications for drift/sync events  |
| `infra/k8s/argocd/kustomization.yaml`        | Kustomize aggregation of all argocd files  |

## Image Update Flow (CI → GitOps)

```
Jenkins CI builds image
        │
        v
Trivy scan + Cosign sign
        │
        v
Push image to Harbor registry
        │
        v
Jenkins runs update-image-digest.sh:
  → updates overlay/kustomization.yaml with new digest
  → commits and pushes to main
        │
        v
ArgoCD detects drift (Git ≠ cluster)
        │
        v
ArgoCD auto-syncs (or waits for manual approval in production)
        │
        v
Kubernetes RollingUpdate replaces pods
        │
        v
ArgoCD Image Updater continues monitoring
```

## Sync Waves Visualization

```
Timeline →
───────────────────────────────────────────────────────────
Wave 0:  portal-web
Wave 1:  auth-users
Wave 2:  chatbot-manager
Wave 3:  conversation-service
Wave 4:  audit-security-service
Wave 5:  canary-validation
───────────────────────────────────────────────────────────
Wave 3:  cert-manager (platform)
Wave 5:  kyverno (platform)
Wave 10: metrics-server (platform)
Wave 15: secrets (platform)
───────────────────────────────────────────────────────────
Wave 20: vault + production overlay
Wave 25: harbor
Wave 30: observability
Wave 35: observability-dashboards
Wave 40: backup (Velero)
Wave 50: runtime-detection (Falco)
Wave 55: falco-talon
Wave 60: chaos (Litmus)
```

Each wave must complete successfully (sync + health) before the next wave begins. If a wave fails, subsequent waves are blocked until the failure is resolved.
