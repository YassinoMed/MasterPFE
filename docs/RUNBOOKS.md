# Central Runbook Index — SecureRAG Hub

> **Document:** RUNBOOKS.md
> **Version:** 1.0
> **Classification:** Internal — Operations
> **Last Updated:** 2026-06-18

---

## Table of Contents

1. Quick Reference by Symptom
2. Severity Classification
3. Escalation Contacts
4. Runbook Inventory — Infrastructure
5. Runbook Inventory — Deployment & CI/CD
6. Runbook Inventory — Security
7. Runbook Inventory — Operations
8. Runbook Inventory — Observability
9. Runbook Inventory — Data & Storage
10. Runbook Inventory — Performance & SRE
11. Runbook Inventory — Environment-Specific
12. Runbook Index by Technology

---

## 1. Quick Reference by Symptom

### 1.1 Application Issues

| Symptom | Likely Cause | Runbook | Severity |
|---------|-------------|---------|:--------:|
| Portal-web returns 5xx errors | Application crash, database down | [troubleshooting.md](runbooks/troubleshooting.md) | SEV1 |
| Login failures | Auth service down, JWT issue | [troubleshooting.md](runbooks/troubleshooting.md) | SEV2 |
| Chat responses slow | LLM overload, Qdrant latency | [troubleshooting.md](runbooks/troubleshooting.md) | SEV2 |
| WebSocket disconnects | Conversation service issue | [troubleshooting.md](runbooks/troubleshooting.md) | SEV3 |
| Audit logs missing | Audit service down, Loki issue | [troubleshooting.md](runbooks/troubleshooting.md) | SEV2 |

### 1.2 Infrastructure Issues

| Symptom | Likely Cause | Runbook | Severity |
|---------|-------------|---------|:--------:|
| Pod crash loop | Resource limits, application error | [troubleshooting.md](runbooks/troubleshooting.md) | SEV2 |
| Node not ready | Resource pressure, network issue | [production-ha.md](runbooks/production-ha.md) | SEV1 |
| Persistent volume full | Logs, data growth | [production-readiness-roadmap.md](runbooks/production-readiness-roadmap.md) | SEV2 |
| Ingress not routing | nginx issue, cert-manager issue | [troubleshooting.md](runbooks/troubleshooting.md) | SEV1 |
| HPA not scaling | metrics-server down, missing metrics | [metrics-server.md](runbooks/metrics-server.md) | SEV3 |

### 1.3 CI/CD Issues

| Symptom | Likely Cause | Runbook | Severity |
|---------|-------------|---------|:--------:|
| Jenkins build fails | Code issue, test failure, dependency issue | [jenkins-setup.md](runbooks/jenkins-setup.md) | SEV3 |
| Jenkins unavailable | Container down, OOM, config issue | [jenkins-recovery.md](runbooks/jenkins-recovery.md) | SEV1 |
| Cosign signature fails | Key missing, password expired | [release-promotion.md](runbooks/release-promotion.md) | SEV2 |
| Trivy scan fails | CRITICAL CVE found | [release-promotion.md](runbooks/release-promotion.md) | SEV3 |
| ArgoCD sync fails | Configuration drift, permission issue | [final-campaign.md](runbooks/final-campaign.md) | SEV2 |

### 1.4 Data Issues

| Symptom | Likely Cause | Runbook | Severity |
|---------|-------------|---------|:--------:|
| Database connection refused | PostgreSQL down, credentials invalid | [data-resilience.md](runbooks/data-resilience.md) | SEV1 |
| Data corruption | Application bug, hardware failure | [data-resilience.md](runbooks/data-resilience.md) | SEV1 |
| Backup failed | Storage full, credential issue | [data-resilience.md](runbooks/data-resilience.md) | SEV2 |
| Qdrant query failures | Qdrant pod down, index corrupted | [data-resilience.md](runbooks/data-resilience.md) | SEV2 |

### 1.5 Security Issues

| Symptom | Likely Cause | Runbook | Severity |
|---------|-------------|---------|:--------:|
| Falco CRITICAL alert | Security event detected | [runtime-security-operations.md](runbooks/runtime-security-operations.md) | SEV-SEC-1 |
| Kyverno admission reject | Policy violation | [kyverno-install.md](runbooks/kyverno-install.md) | SEV3 |
| Secret rotation due | Expiration approaching | [secret-rotation.md](runbooks/secret-rotation.md) | SEV4 |
| Falco CRITICAL events high | Possible compromise | [runtime-security-operations.md](runbooks/runtime-security-operations.md) | SEV-SEC-1 |

### 1.6 Observability Issues

| Symptom | Likely Cause | Runbook | Severity |
|---------|-------------|---------|:--------:|
| No metrics in Grafana | Prometheus down, scrape config issue | [observability-guide.md](runbooks/observability-guide.md) | SEV2 |
| No logs in Loki | Loki down, Promtail config issue | [observability-guide.md](runbooks/observability-guide.md) | SEV2 |
| Alerts not firing | Alertmanager misconfigured | [observability-guide.md](runbooks/observability-guide.md) | SEV3 |
| No traces in Tempo | OTel collector down | [observability-guide.md](runbooks/observability-guide.md) | SEV3 |

---

## 2. Severity Classification

### 2.1 Incident Severities

| Severity | Definition | Response Time | Example |
|----------|-----------|:------------:|---------|
| **SEV1** | Complete service outage or critical data loss | 15 minutes | All services down, database unreachable |
| **SEV2** | Partial outage or significant degradation | 30 minutes | One service down, high latency |
| **SEV3** | Minor degradation, non-critical issue | 2 hours | UI bug, slow queries |
| **SEV4** | Cosmetic or non-urgent | 24 hours | Documentation, feature request |

### 2.2 Security Severities

| Severity | Definition | Response Time | Example |
|----------|-----------|:------------:|---------|
| **SEV-SEC-1** | Active compromise or data breach | Immediate | Unauthorized access, ransomware |
| **SEV-SEC-2** | Confirmed vulnerability | 1 hour | Exploitable CVE, secret leak |
| **SEV-SEC-3** | Suspicious activity | 4 hours | Falco alert, unusual traffic |
| **SEV-SEC-4** | Policy violation | 24 hours | Kyverno reject, non-compliant config |

---

## 3. Escalation Contacts

### 3.1 On-Call Contacts

| Role | Contact Method | Responsibility |
|------|---------------|----------------|
| **SRE Primary** | PagerDuty + Slack @sre-primary | First responder for all incidents |
| **SRE Secondary** | PagerDuty + Slack @sre-secondary | Backup to primary, handles escalation |
| **SRE Lead** | Slack @sre-lead | Technical escalation, postmortem approval |
| **Security Lead** | Slack @security-lead | Security incident escalation |

### 3.2 Engineering Contacts

| Role | Contact | Availability |
|------|---------|:------------:|
| **Platform Engineering Lead** | Slack @platform-lead | Business hours |
| **DevSecOps Engineer** | Slack @devsecops | Business hours |
| **Service Owner (portal-web)** | Slack @portal-web-owner | Business hours |
| **Service Owner (auth-users)** | Slack @auth-owner | Business hours |
| **Service Owner (chatbot-manager)** | Slack @chatbot-owner | Business hours |

### 3.3 Management Contacts

| Role | Contact | Escalation Level |
|------|---------|:----------------:|
| **Engineering Manager** | Slack @eng-mgr | Level 3 (after SRE Lead) |
| **VP Engineering** | Slack @vp-eng | Level 4 (SEV1 only) |
| **CTO** | Slack @cto | Executive (SEV1 with major impact) |

---

## 4. Runbook Inventory — Infrastructure

| # | Runbook | Path | Description | Audience | Last Updated |
|---|---------|------|-------------|----------|:------------:|
| 1 | **Local Kind Cluster** | [runbooks/local-kind.md](runbooks/local-kind.md) | Setup and manage local kind Kubernetes cluster | Developer | 2026-06 |
| 2 | **Production Cluster Clean** | [runbooks/production-cluster-clean.md](runbooks/production-cluster-clean.md) | Clean production cluster without legacy runtime | SRE | 2026-06 |
| 3 | **Production HA** | [runbooks/production-ha.md](runbooks/production-ha.md) | Production overlay configuration and HA setup | SRE | 2026-06 |
| 4 | **Production Readiness Roadmap** | [runbooks/production-readiness-roadmap.md](runbooks/production-readiness-roadmap.md) | Production readiness trajectory | Platform | 2026-06 |
| 5 | **Metrics Server** | [runbooks/metrics-server.md](runbooks/metrics-server.md) | Install and troubleshoot metrics-server | SRE | 2026-06 |
| 6 | **Kyverno Install** | [runbooks/kyverno-install.md](runbooks/kyverno-install.md) | Install and configure Kyverno admission controller | SRE | 2026-06 |
| 7 | **Cloud Debian 12 VPS** | [runbooks/cloud-debian12-vps.md](runbooks/cloud-debian12-vps.md) | Deploy on Debian 12 VPS from Git | Platform | 2026-06 |
| 8 | **Environment Freeze** | [runbooks/environment-freeze.md](runbooks/environment-freeze.md) | Environment freeze procedure | SRE | 2026-06 |

---

## 5. Runbook Inventory — Deployment & CI/CD

| # | Runbook | Path | Description | Audience | Last Updated |
|---|---------|------|-------------|----------|:------------:|
| 9 | **Jenkins Setup** | [runbooks/jenkins-setup.md](runbooks/jenkins-setup.md) | Jenkins local setup and configuration | Developer | 2026-06 |
| 10 | **Jenkins Recovery** | [runbooks/jenkins-recovery.md](runbooks/jenkins-recovery.md) | Recover Jenkins from failure | SRE | 2026-06 |
| 11 | **Jenkins GitHub Webhook** | [runbooks/jenkins-github-webhook.md](runbooks/jenkins-github-webhook.md) | Configure GitHub webhook for Jenkins | Developer | 2026-06 |
| 12 | **Jenkins Cloud Fallback** | [runbooks/jenkins-cloud-fallback.md](runbooks/jenkins-cloud-fallback.md) | Fallback procedure when Jenkins is unavailable | SRE | 2026-06 |
| 13 | **Jenkins CI Trigger Test** | [runbooks/jenkins-ci-trigger-test.md](runbooks/jenkins-ci-trigger-test.md) | How to test CI pipeline triggers | Developer | 2026-06 |
| 14 | **Jenkins CI Proof Smoke 01** | [runbooks/jenkins-ci-proof-smoke-01.md](runbooks/jenkins-ci-proof-smoke-01.md) | CI smoke test proof — batch 1 | SRE | 2026-06 |
| 15 | **Jenkins CI Proof Smoke 02** | [runbooks/jenkins-ci-proof-smoke-02.md](runbooks/jenkins-ci-proof-smoke-02.md) | CI smoke test proof — batch 2 | SRE | 2026-06 |
| 16 | **Jenkins CD Trigger Test** | [runbooks/jenkins-cd-trigger-test.md](runbooks/jenkins-cd-trigger-test.md) | How to test CD pipeline triggers | Developer | 2026-06 |
| 17 | **Jenkins CD Proof Smoke 01** | [runbooks/jenkins-cd-proof-smoke-01.md](runbooks/jenkins-cd-proof-smoke-01.md) | CD smoke test proof | SRE | 2026-06 |
| 18 | **Jenkins CD Smoke Test** | [runbooks/jenkins-cd-smoke-test.md](runbooks/jenkins-cd-smoke-test.md) | CD smoke test procedure | SRE | 2026-06 |
| 19 | **Jenkins Webhook Smoke Test** | [runbooks/jenkins-webhook-smoke-test.md](runbooks/jenkins-webhook-smoke-test.md) | Webhook connectivity smoke test | Developer | 2026-06 |
| 20 | **Jenkins Test Batch 01-03** | [runbooks/jenkins-test-batch-01.md](runbooks/jenkins-test-batch-01.md) | Jenkins test batch 01 | SRE | 2026-06 |
| 21 | **Jenkins Test Batch 01-03** | [runbooks/jenkins-test-batch-02.md](runbooks/jenkins-test-batch-02.md) | Jenkins test batch 02 | SRE | 2026-06 |
| 22 | **Jenkins Test Batch 01-03** | [runbooks/jenkins-test-batch-03.md](runbooks/jenkins-test-batch-03.md) | Jenkins test batch 03 | SRE | 2026-06 |
| 23 | **Release Promotion** | [runbooks/release-promotion.md](runbooks/release-promotion.md) | Image promotion by digest, no rebuild | SRE | 2026-06 |
| 24 | **Final Campaign** | [runbooks/final-campaign.md](runbooks/final-campaign.md) | End-to-end campaign execution | SRE | 2026-06 |
| 25 | **Final Proof** | [runbooks/final-proof.md](runbooks/final-proof.md) | Proof generation and support pack | SRE | 2026-06 |
| 26 | **DevSecOps Closure** | [runbooks/devsecops-closure.md](runbooks/devsecops-closure.md) | DevSecOps closure evidence | SRE | 2026-06 |
| 27 | **DevSecOps Final Proof** | [runbooks/devsecops-final-proof.md](runbooks/devsecops-final-proof.md) | Final DevSecOps proof | SRE | 2026-06 |
| 28 | **DevSecOps Remaining Validation** | [runbooks/devsecops-remaining-validation.md](runbooks/devsecops-remaining-validation.md) | Remaining DevSecOps validation items | SRE | 2026-06 |
| 29 | **Soutenance DevSecOps Script** | [runbooks/soutenance-devsecops-script.md](runbooks/soutenance-devsecops-script.md) | Defense presentation script | Presenter | 2026-06 |
| 30 | **Demo Checklist** | [runbooks/demo-checklist.md](runbooks/demo-checklist.md) | Pre-demo verification checklist | Presenter | 2026-06 |

---

## 6. Runbook Inventory — Security

| # | Runbook | Path | Description | Audience | Last Updated |
|---|---------|------|-------------|----------|:------------:|
| 31 | **Runtime Security Operations** | [runbooks/runtime-security-operations.md](runbooks/runtime-security-operations.md) | Falco alert triage, post-deploy security | SRE | 2026-06 |
| 32 | **Secret Rotation** | [runbooks/secret-rotation.md](runbooks/secret-rotation.md) | Secret rotation procedures (DB, API, Cosign) | SRE | 2026-06 |
| 33 | **Secrets Rotation** | [runbooks/secrets-rotation.md](runbooks/secrets-rotation.md) | Comprehensive secrets rotation (legacy) | SRE | 2026-06 |
| 34 | **AI-Assisted DevSecOps** | [runbooks/ai-assisted-devsecops.md](runbooks/ai-assisted-devsecops.md) | AI-assisted security operations | DevSecOps | 2026-06 |
| 35 | **Jenkins Proof Commit Playground** | [runbooks/jenkins-proof-commit-playground.md](runbooks/jenkins-proof-commit-playground.md) | Jenkins commit proof for security audit | SRE | 2026-06 |

---

## 7. Runbook Inventory — Operations

| # | Runbook | Path | Description | Audience | Last Updated |
|---|---------|------|-------------|----------|:------------:|
| 36 | **Troubleshooting** | [runbooks/troubleshooting.md](runbooks/troubleshooting.md) | Common issues and resolutions | All | 2026-06 |
| 37 | **SRE Incident Response** | [runbooks/sre-incident-response.md](runbooks/sre-incident-response.md) | Incident response procedures for SRE | SRE | 2026-06 |
| 38 | **Operations Guide** | [OPERATIONS_GUIDE.md](OPERATIONS_GUIDE.md) | Daily/weekly/monthly operations tasks | SRE | 2026-06 |
| 39 | **SRE Guide** | [SRE_GUIDE.md](SRE_GUIDE.md) | SLO framework, error budget, incident response | SRE | 2026-06 |
| 40 | **DR Guide** | [DR_GUIDE.md](DR_GUIDE.md) | Disaster recovery procedures | SRE | 2026-06 |
| 41 | **Security Guide** | [SECURITY_GUIDE.md](SECURITY_GUIDE.md) | Security architecture and procedures | Security | 2026-06 |
| 42 | **Architecture** | [ARCHITECTURE.md](ARCHITECTURE.md) | Enterprise architecture | All | 2026-06 |

---

## 8. Runbook Inventory — Observability

| # | Runbook | Path | Description | Audience | Last Updated |
|---|---------|------|-------------|----------|:------------:|
| 43 | **Observability Guide** | [runbooks/observability-guide.md](runbooks/observability-guide.md) | Prometheus/Grafana/Loki/Alertmanager | SRE | 2026-06 |
| 44 | **Observability Modernization** | [runbooks/observability-modernization.md](runbooks/observability-modernization.md) | Modernizing observability stack | SRE | 2026-06 |
| 45 | **Production SLO and Alerting** | [runbooks/production-slo-and-alerting.md](runbooks/production-slo-and-alerting.md) | SLO configuration and alert rules | SRE | 2026-06 |

---

## 9. Runbook Inventory — Data & Storage

| # | Runbook | Path | Description | Audience | Last Updated |
|---|---------|------|-------------|----------|:------------:|
| 46 | **Data Resilience** | [runbooks/data-resilience.md](runbooks/data-resilience.md) | Backup, restore, data resilience strategy | SRE | 2026-06 |

---

## 10. Runbook Inventory — Performance & SRE

| # | Runbook | Path | Description | Audience | Last Updated |
|---|---------|------|-------------|----------|:------------:|
| 47 | **Production Readiness Roadmap** | [runbooks/production-readiness-roadmap.md](runbooks/production-readiness-roadmap.md) | Production readiness trajectory and milestones | Platform | 2026-06 |
| 48 | **Production SLO and Alerting** | [runbooks/production-slo-and-alerting.md](runbooks/production-slo-and-alerting.md) | SLO configuration and alerting rules | SRE | 2026-06 |
| 49 | **Missing Phases Closure** | [runbooks/missing-phases-closure.md](runbooks/missing-phases-closure.md) | Closure of missing implementation phases | Platform | 2026-06 |

---

## 11. Runbook Inventory — Environment-Specific

| # | Runbook | Path | Description | Audience | Last Updated |
|---|---------|------|-------------|----------|:------------:|
| 50 | **Cloud Debian 12 VPS** | [runbooks/cloud-debian12-vps.md](runbooks/cloud-debian12-vps.md) | Full environment setup on Debian 12 VPS | Platform | 2026-06 |
| 51 | **Demo Checklist** | [runbooks/demo-checklist.md](runbooks/demo-checklist.md) | Pre-demo verification and checklist | Presenter | 2026-06 |
| 52 | **Final Campaign** | [runbooks/final-campaign.md](runbooks/final-campaign.md) | End-to-end final campaign execution | SRE | 2026-06 |

---

## 12. Runbook Index by Technology

### 12.1 Jenkins

| Runbook | Description |
|---------|-------------|
| [jenkins-setup.md](runbooks/jenkins-setup.md) | Setup and configuration |
| [jenkins-recovery.md](runbooks/jenkins-recovery.md) | Recovery from failures |
| [jenkins-github-webhook.md](runbooks/jenkins-github-webhook.md) | Webhook configuration |
| [jenkins-cloud-fallback.md](runbooks/jenkins-cloud-fallback.md) | Fallback procedures |
| [jenkins-ci-trigger-test.md](runbooks/jenkins-ci-trigger-test.md) | CI trigger testing |
| [jenkins-ci-proof-smoke-01.md](runbooks/jenkins-ci-proof-smoke-01.md) | CI proof batch 1 |
| [jenkins-ci-proof-smoke-02.md](runbooks/jenkins-ci-proof-smoke-02.md) | CI proof batch 2 |
| [jenkins-cd-trigger-test.md](runbooks/jenkins-cd-trigger-test.md) | CD trigger testing |
| [jenkins-cd-proof-smoke-01.md](runbooks/jenkins-cd-proof-smoke-01.md) | CD proof batch 1 |
| [jenkins-cd-smoke-test.md](runbooks/jenkins-cd-smoke-test.md) | CD smoke test |
| [jenkins-webhook-smoke-test.md](runbooks/jenkins-webhook-smoke-test.md) | Webhook smoke test |
| [jenkins-test-batch-01.md](runbooks/jenkins-test-batch-01.md) | Test batch 01 |
| [jenkins-test-batch-02.md](runbooks/jenkins-test-batch-02.md) | Test batch 02 |
| [jenkins-test-batch-03.md](runbooks/jenkins-test-batch-03.md) | Test batch 03 |
| [jenkins-proof-commit-playground.md](runbooks/jenkins-proof-commit-playground.md) | Commit proof playground |

### 12.2 Kubernetes

| Runbook | Description |
|---------|-------------|
| [local-kind.md](runbooks/local-kind.md) | Local kind cluster management |
| [production-cluster-clean.md](runbooks/production-cluster-clean.md) | Clean production cluster |
| [production-ha.md](runbooks/production-ha.md) | Production HA configuration |
| [metrics-server.md](runbooks/metrics-server.md) | Metrics server management |
| [kyverno-install.md](runbooks/kyverno-install.md) | Kyverno admission controller |

### 12.3 Security

| Runbook | Description |
|---------|-------------|
| [runtime-security-operations.md](runbooks/runtime-security-operations.md) | Runtime security operations |
| [secret-rotation.md](runbooks/secret-rotation.md) | Secret rotation procedures |
| [secrets-rotation.md](runbooks/secrets-rotation.md) | Legacy secrets rotation |

### 12.4 Data

| Runbook | Description |
|---------|-------------|
| [data-resilience.md](runbooks/data-resilience.md) | Data resilience and backup/restore |

### 12.5 Observability

| Runbook | Description |
|---------|-------------|
| [observability-guide.md](runbooks/observability-guide.md) | Observability stack operations |
| [observability-modernization.md](runbooks/observability-modernization.md) | Observability modernization |
| [production-slo-and-alerting.md](runbooks/production-slo-and-alerting.md) | SLO configuration and alerting |

### 12.6 Deployment & Release

| Runbook | Description |
|---------|-------------|
| [release-promotion.md](runbooks/release-promotion.md) | Image promotion by digest |
| [final-campaign.md](runbooks/final-campaign.md) | End-to-end final campaign |
| [final-proof.md](runbooks/final-proof.md) | Proof generation |
| [demo-checklist.md](runbooks/demo-checklist.md) | Pre-demo verification |

### 12.7 General

| Runbook | Description |
|---------|-------------|
| [troubleshooting.md](runbooks/troubleshooting.md) | Common issue resolution |
| [sre-incident-response.md](runbooks/sre-incident-response.md) | SRE incident response |
| [environment-freeze.md](runbooks/environment-freeze.md) | Environment freeze procedure |

---

## Quick Reference Card

```text
                    ╔═══════════════════════════════════════╗
                    ║        QUICK REFERENCE CARD           ║
                    ╠═══════════════════════════════════════╣
                    ║                                       ║
                    ║  SEV1 → 15 min response               ║
                    ║  SEV2 → 30 min response               ║
                    ║  SEV3 → 2 hour response               ║
                    ║  SEV4 → 24 hour response              ║
                    ║                                       ║
                    ║  SRE Primary: @sre-primary (PagerDuty)║
                    ║  SRE Secondary: @sre-secondary        ║
                    ║  SRE Lead: @sre-lead                  ║
                    ║  Security: @security-lead             ║
                    ║                                       ║
                    ║  First check runbook before escalating║
                    ╚═══════════════════════════════════════╝
```

---

## Maintenance

This index is automatically updated when runbooks are added or modified. Runbooks should be reviewed quarterly for accuracy.

**Next review date:** 2026-09-18

---

*Document maintained by the SRE team. For questions about specific runbooks, contact the respective runbook owner listed in the document.*
