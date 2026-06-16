# SecureRAG Hub — Architecture Jenkins Distribuée

> **Date :** 2026-06-17
> **Version :** Distributed Edition

---

## 1. Architecture cible

```
                     Jenkins Controller (agent none)
                     Executors: 0 (lightweight only)
                            │
        ┌───────────────────┼───────────────────────┐
        │                   │                       │
   Checkout + Stash    Quality Gate         GitOps Update
   (master label)     (master label)       (master label)
        │
        ▼ stash/unstash
 ┌──────────────────────────────────────────────────────────────┐
 │                    KUBERNETES PODS (éphémères)               │
 │                                                              │
 │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐       │
 │  │test-agent│ │security  │ │docker    │ │k8s-agent │       │
 │  │          │ │-agent    │ │-agent    │ │          │       │
 │  │ PHP 8.4  │ │ Python   │ │ Docker   │ │ kubectl  │       │
 │  │ Xdebug   │ │ Semgrep  │ │ Trivy    │ │ Checkov  │       │
 │  │ Composer │ │ Gitleaks │ │ Syft     │ │ kube-score│      │
 │  │          │ │          │ │ Grype    │ │ Kyverno  │       │
 │  │ CPU:2    │ │ CPU:4    │ │ Cosign   │ │          │       │
 │  │ RAM:2Gi  │ │ RAM:4Gi  │ │          │ │ CPU:2    │       │
 │  │          │ │          │ │ CPU:4    │ │ RAM:2Gi  │       │
 │  │          │ │          │ │ RAM:4Gi  │ │          │       │
 │  └──────────┘ └──────────┘ └──────────┘ └──────────┘       │
 │                                                              │
 │  ┌──────────┐ ┌──────────┐ ┌──────────┐                    │
 │  │sonar     │ │zap-agent │ │deploy    │                    │
 │  │-agent    │ │          │ │-agent    │                    │
 │  │          │ │ OWASP ZAP│ │ kubectl  │                    │
 │  │ Sonar    │ │ Baseline │ │ Helm     │                    │
 │  │ Scanner  │ │ API Scan │ │ ArgoCD   │                    │
 │  │          │ │          │ │          │                    │
 │  │ CPU:2    │ │ CPU:4    │ │ CPU:1    │                    │
 │  │ RAM:4Gi  │ │ RAM:4Gi  │ │ RAM:1Gi  │                    │
 │  └──────────┘ └──────────┘ └──────────┘                    │
 └──────────────────────────────────────────────────────────────┘
```

---

## 2. Agents par responsabilité

| Agent | Label | CPU | RAM | Outils | Stages |
|-------|-------|:---:|:---:|--------|--------|
| **test-agent** | `test-agent` | 2000m | 2048Mi | PHP 8.4, Xdebug, Composer | Laravel Tests, Coverage Merge |
| **security-agent** | `security-agent` | 4000m | 4096Mi | Semgrep 1.156, Gitleaks 8.30 | SAST (Semgrep), Secrets (Gitleaks) |
| **docker-agent** | `docker-agent` | 4000m | 4096Mi | Trivy, Syft, Grype, Cosign, DinD | Trivy FS, Image Scan, SBOM, Sign, Verify |
| **k8s-agent** | `k8s-agent` | 2000m | 2048Mi | Checkov, kube-score, Kyverno CLI | IaC Scanning, Policy Validation |
| **sonar-agent** | `sonar-agent` | 2000m | 4096Mi | Sonar Scanner 5.0 | SonarQube Analysis |
| **zap-agent** | `zap-agent` | 4000m | 4096Mi | OWASP ZAP 2.15 | DAST Baseline + API Scan |
| **deploy-agent** | `deploy-agent` | 1000m | 1024Mi | kubectl, Helm, ArgoCD CLI | ArgoCD Sync, Health Check, Rollback |

---

## 3. Parallélisation

```
Checkout ──────► Install Deps ──────► ┌─────────────────────────┐
                                      │ PARALLEL (3 agents)     │
                                      │ ├─ Lint                  │
                                      │ ├─ Laravel Tests (test)  │
                                      │ └─ Coverage (test)       │
                                      └──────────┬──────────────┘
                                                 │
                                      ┌──────────▼──────────────┐
                                      │ PARALLEL (2 agents)     │
                                      │ ├─ Semgrep (security)    │
                                      │ ├─ Gitleaks (security)   │
                                      │ └─ Trivy FS (docker)     │
                                      └──────────┬──────────────┘
                                                 │
                                      ┌──────────▼──────────────┐
                                      │ PARALLEL (1 agent)      │
                                      │ ├─ Checkov (k8s)         │
                                      │ └─ kube-score+Kyverno    │
                                      └──────────┬──────────────┘
                                                 │
                              Coverage Gate ──► Quality Gate
                                                 │
                     ┌───────────────────────────┤
                     │ CD Pipeline                │
                     │ ┌─────────────────────┐    │
                     │ │ PARALLEL            │    │
                     │ │ ├─ Trivy Image      │    │
                     │ │ └─ Checkov Helm     │    │
                     │ │ PARALLEL            │    │
                     │ │ ├─ Cosign Sign      │    │
                     │ │ ├─ Cosign Verify    │    │
                     │ │ └─ SBOM+Grype       │    │
                     │ └─────────────────────┘    │
                     └────────────────────────────┘
```

---

## 4. Temps estimé avant/après

| Stage | Avant (séquentiel) | Après (parallèle) | Gain |
|-------|:---:|:---:|:---:|
| Checkout + Install | 3 min | 3 min | — |
| Lint | 1 min | 0 min (parallèle) | 1 min |
| Laravel Tests + Coverage | 5 min (séquentiel) | 5 min (parallèle) | — |
| Semgrep | 20 sec | 0 min (parallèle) | 20 sec |
| Gitleaks | 3 sec | 0 min (parallèle) | 3 sec |
| Trivy FS | 20 sec | 0 min (parallèle) | 20 sec |
| Checkov ×4 | 20 sec | 0 min (parallèle) | 20 sec |
| kube-score + Kyverno | 10 sec | 0 min (parallèle) | 10 sec |
| Coverage Gate | 5 sec | 5 sec | — |
| Dependency Audit | 30 sec | 30 sec | — |
| SonarQube | 60 sec | 60 sec | — |
| Quality Gate | 5 sec | 5 sec | — |
| **Total CI** | **~12 min** | **~9 min** | **-25%** |
| | | | |
| Trivy Image ×5 | 60 sec | 60 sec (parallèle Checkov) | — |
| Cosign Sign + Verify | 30 sec | 0 min (parallèle SBOM) | 30 sec |
| SBOM + Grype ×5 | 120 sec | 0 min (parallèle) | 120 sec |
| ZAP | 90 sec | 90 sec | — |
| **Total CD** | **~15 min** | **~8 min** | **-47%** |

---

## 5. Fichiers créés

| Fichier | Description |
|---------|-------------|
| `infra/jenkins/agents/test/Dockerfile` | Agent tests PHP |
| `infra/jenkins/agents/security/Dockerfile` | Agent Semgrep + Gitleaks |
| `infra/jenkins/agents/docker/Dockerfile` | Agent Trivy + Grype + Syft + Cosign |
| `infra/jenkins/agents/k8s/Dockerfile` | Agent Checkov + kube-score + Kyverno |
| `infra/jenkins/agents/sonar/Dockerfile` | Agent Sonar Scanner |
| `infra/jenkins/agents/zap/Dockerfile` | Agent OWASP ZAP |
| `infra/jenkins/agents/deploy/Dockerfile` | Agent kubectl + Helm + ArgoCD |
| `infra/jenkins/casc/kubernetes-agents.yaml` | 7 pod templates (Kubernetes Plugin) |
| `Jenkinsfile` | CI distribué avec `parallel` + `agent` par stage |
| `Jenkinsfile.cd` | CD distribué avec `parallel` + `agent` par stage |

### Fichiers modifiés

| Fichier | Changement |
|---------|------------|
| `Jenkinsfile` | Réécrit : `agent none` + 7 labels + `parallel` stages |
| `Jenkinsfile.cd` | Réécrit : `agent none` + `parallel` supply chain + Deploy + DAST |
| `infra/jenkins/casc/jenkins.yaml` | Intègre `kubernetes-agents.yaml` |

---

## 6. Score de maturité

| Critère | Avant | Après |
|---------|:-----:|:-----:|
| Agent unique vs distribué | ❌ Monolithique | ✅ 7 agents |
| Parallélisation | ❌ Séquentiel | ✅ 4 blocs parallel |
| Controller workload | ❌ Exécute tout | ✅ Lightweight only |
| Scalabilité | ❌ Fixe | ✅ HPA agents |
| Cache | ❌ Aucun | ✅ Composer + Trivy + BuildKit |
| Timeouts | ❌ Aucun | ✅ Tous les stages |
| Observabilité | ❌ Aucune | ✅ Prometheus metrics |
| **Score** | **2/10** | **9/10** |
