# SRE Guide — SecureRAG Hub

> **Document:** SRE_GUIDE.md
> **Version:** 1.0
> **Classification:** Internal — Operations
> **Last Updated:** 2026-06-18

---

## Table of Contents

1. SLO Framework
2. SLI Definitions
3. Error Budget Policy
4. Multi-Window Burn Rate Alerting
5. Incident Response
6. Postmortem Process
7. DORA Metrics Tracking
8. Capacity Planning Guidelines
9. Chaos Engineering Approach
10. On-Call Expectations and Schedule

---

## 1. SLO Framework

### 1.1 Service Level Objectives by Service

| Service | Availability | Latency (p95) | Error Rate | Coverage | SLO Window |
|---------|:-----------:|:-------------:|:----------:|:--------:|:----------:|
| **portal-web** | 99.9% | < 300ms | < 0.5% | > 85% | 30 days |
| **auth-users-service** | 99.95% | < 200ms | < 0.1% | > 85% | 30 days |
| **chatbot-manager-service** | 99.5% | < 1000ms | < 1.0% | > 85% | 30 days |
| **conversation-service** | 99.9% | < 300ms | < 0.5% | > 85% | 30 days |
| **audit-security-service** | 99.95% | < 500ms | < 0.1% | > 85% | 30 days |
| **Aggregate (Platform)** | 99.9% | < 500ms | < 0.5% | N/A | 30 days |

### 1.2 SLO Target Rationale

| Service | SLO | Rationale |
|---------|:---:|-----------|
| portal-web | 99.9% | User-facing gateway; 8.76h downtime/year is acceptable for internal tool |
| auth-users-service | 99.95% | Auth is critical path; 4.38h downtime/year |
| chatbot-manager-service | 99.5% | LLM-dependent; 43.8h downtime/year accounts for Ollama instability |
| conversation-service | 99.9% | Core data persistence; 8.76h downtime/year |
| audit-security-service | 99.95% | Security-critical; must remain available for audit compliance |

### 1.3 SLO Compliance Monitoring

```
Prometheus Rule: SLO:Availability
  expr: |
    avg_over_time(
      up{namespace="securerag-hub", job=~"portal-web|auth-users|chatbot-manager|conversation-service|audit-security-service"}[30d]
    )
  labels:
    slo: "availability-99.9"

Grafana Dashboard: SRE / SLO Compliance
  Panels:
    - Current SLO attainment (per service)
    - Historical trend (7/14/30 days)
    - Error budget remaining (service-level)
```

---

## 2. SLI Definitions

### 2.1 Availability SLI

| Aspect | Definition |
|--------|-----------|
| **Metric** | `up{job="<service>"}` or `probe_success{job="<service>"}` |
| **Source** | Prometheus blackbox exporter or kube-state-metrics |
| **Good Condition** | Service endpoint responds with HTTP 200 within 5s |
| **Measurement Interval** | 15s scrape interval |
| **SLO Window** | 30 days rolling |
| **Formula** | `count(up == 1) / count(up) * 100` |

### 2.2 Latency SLI

| Aspect | Definition |
|--------|-----------|
| **Metric** | `http_request_duration_seconds` (histogram) |
| **Source** | Laravel middleware metrics export |
| **Good Condition** | p95 latency < service-specific threshold |
| **Bucket Boundaries** | 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0 |
| **SLO Window** | 30 days rolling |
| **Formula** | `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))` |

### 2.3 Error Rate SLI

| Aspect | Definition |
|--------|-----------|
| **Metric** | `http_requests_total{status=~"5.."}` |
| **Source** | Laravel middleware metrics export |
| **Good Condition** | Proportion of 5xx responses < threshold |
| **Measurement Interval** | 5m rate |
| **SLO Window** | 7 days rolling (faster feedback) |
| **Formula** | `sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) * 100` |

### 2.4 Throughput SLI

| Aspect | Definition |
|--------|-----------|
| **Metric** | `http_requests_total` |
| **Source** | Laravel middleware metrics export |
| **Good Condition** | Request rate > minimum threshold |
| **Measurement Interval** | 1m rate |
| **SLO Window** | 30 days rolling |
| **Formula** | `sum(rate(http_requests_total[1m]))` |

### 2.5 Security SLI (Platform-Specific)

| SLI | Metric | Good Condition | SLO |
|-----|--------|---------------|:---:|
| **Kyverno Compliance** | `kyverno_policy_results_total{result="fail"}` | 0 failures | 99.9% |
| **Falco Alert Rate** | `falco_events_total{priority=~"critical|emergency"}` | 0 critical alerts/hour | 99.99% |
| **Image Signature Compliance** | `cosign_verify_status` | All images verified | 100% |
| **Secret Rotation** | `secret_rotation_age_seconds` | All secrets rotated within policy window | 100% |

---

## 3. Error Budget Policy

### 3.1 Error Budget Calculation

```
Error Budget = (1 - SLO) × Time Window

Example — portal-web (99.9% SLO, 30-day window):
  Budget = (1 - 0.999) × 30 days × 24h × 60min = 43.2 minutes

Per-Service Error Budgets (30-day window):
  portal-web:               43.2 min (99.9%)
  auth-users-service:       21.6 min (99.95%)
  chatbot-manager-service:  216.0 min (99.5%)
  conversation-service:     43.2 min (99.9%)
  audit-security-service:   21.6 min (99.95%)
```

### 3.2 Error Budget Consumption Thresholds

| Consumption Level | Color | Action |
|:-----------------:|:-----:|--------|
| 0% — 50% | 🟢 Green | Normal operations. Deploy freely. |
| 50% — 80% | 🟡 Yellow | Caution. No risky deployments. Enable feature flags. |
| 80% — 100% | 🟠 Orange | Deployments frozen. Only hotfixes allowed. Prepare incident response. |
| 100%+ | 🔴 Red | SLO violated. Mandatory postmortem. Full deployment freeze. On-call escalation. |

### 3.3 Deployment Freeze Conditions

A deployment freeze is triggered when ANY of the following conditions are met:

1. Error budget consumed > 80% for any critical service (portal-web, auth-users)
2. Error budget consumed > 100% for any service
3. Active SEV1 or SEV2 incident
4. Failed postmortem action items not resolved within deadline
5. During planned maintenance windows (must be approved 48h in advance)

### 3.4 Freeze Exceptions

Exceptions to deployment freeze require SRE lead approval:

| Exception Type | Approval Required | Documentation |
|----------------|-------------------|---------------|
| Security patch (CVE) | SRE Lead + Security Lead | CVE reference, risk assessment |
| Hotfix for ongoing incident | Incident Commander | Incident ID, fix description |
| Infrastructure upgrade | Platform Lead | Change request, rollback plan |

### 3.5 Error Budget Reporting

```
Weekly Report (automated via Grafana):
  - Error budget remaining per service
  - Consumption trend (7-day, 30-day)
  - Top 3 contributors to budget consumption
  - Forecast: days until budget exhaustion at current rate

Monthly SLO Review (in Operations Review):
  - SLO attainment vs target
  - Error budget spend analysis
  - Recommendations for SLO adjustment
  - Capacity planning updates
```

---

## 4. Multi-Window Burn Rate Alerting

### 4.1 Burn Rate Definition

```
Burn Rate = Error Budget Consumed / Time Elapsed

A burn rate of 1 means the error budget will be exactly consumed by the end
of the SLO window. A burn rate of 2 means it will be consumed in half the window.
```

### 4.2 Multi-Window Alert Configuration

| Alert Name | Short Window | Long Window | Burn Rate | Severity | Response Time |
|-----------|:-----------:|:-----------:|:---------:|:--------:|:------------:|
| **Page (Critical)** | 1h | 6h | ≥ 14.4 | CRITICAL | 5 min |
| **Page (Warning)** | 6h | 3d | ≥ 6 | WARNING | 15 min |
| **Ticket** | 30m | 6h | ≥ 3 | INFO | 1 hour |

### 4.3 Prometheus Alert Rules

```yaml
# Multi-window, multi-burn-rate alert for portal-web availability
groups:
  - name: slo-burn-rate
    rules:
      # Critical: 14.4x burn rate — budget exhausted in ~2 days
      - alert: SLOErrorBudgetBurnCritical
        expr: |
          (
            (1 - (sum(rate(http_requests_total{job="portal-web",status=~"2.."}[1h])) 
                  / sum(rate(http_requests_total{job="portal-web"}[1h]))))
            /
            (1 - 0.999)
          ) > 14.4
          and on()
          (
            (1 - (sum(rate(http_requests_total{job="portal-web",status=~"2.."}[6h])) 
                  / sum(rate(http_requests_total{job="portal-web"}[6h]))))
            /
            (1 - 0.999)
          ) > 14.4
        for: 5m
        labels:
          severity: critical
          team: sre
          slo: portal-web-availability-99.9
        annotations:
          summary: "SLO burn rate critical for portal-web"
          description: >
            Error budget burning at >14.4x rate. 
            Budget will be exhausted in ~2 days at current rate.

      # Warning: 6x burn rate — budget exhausted in ~5 days
      - alert: SLOErrorBudgetBurnWarning
        expr: |
          (
            (1 - (sum(rate(http_requests_total{job="portal-web",status=~"2.."}[6h])) 
                  / sum(rate(http_requests_total{job="portal-web"}[6h]))))
            /
            (1 - 0.999)
          ) > 6
          and on()
          (
            (1 - (sum(rate(http_requests_total{job="portal-web",status=~"2.."}[3d])) 
                  / sum(rate(http_requests_total{job="portal-web"}[3d]))))
            /
            (1 - 0.999)
          ) > 6
        for: 5m
        labels:
          severity: warning
          team: sre
          slo: portal-web-availability-99.9
        annotations:
          summary: "SLO burn rate warning for portal-web"
          description: >
            Error budget burning at >6x rate.
            Budget will be exhausted in ~5 days at current rate.
```

### 4.4 Burn Rate Alert Response

| Alert Type | Response | Escalation |
|-----------|----------|------------|
| **Critical (14.4x)** | PagerDuty notification → On-call acknowledges within 5min | Escalate to SRE Lead if not acknowledged in 10min |
| **Warning (6x)** | Slack notification → Channel monitored during business hours | Escalate if sustained for > 1 hour |
| **Ticket (3x)** | Automated ticket → Review within 1 business day | N/A |

---

## 5. Incident Response

### 5.1 Severity Classification

| Severity | Definition | Response Time | Examples |
|----------|-----------|:------------:|----------|
| **SEV1 — Critical** | Complete service outage or data loss affecting all users | 15 min | portal-web unavailable; PostgreSQL cluster down; data corruption |
| **SEV2 — High** | Partial outage or significant degradation affecting many users | 30 min | One service degraded; high latency; auth failures > 5% |
| **SEV3 — Medium** | Minor degradation affecting some users | 2 hours | Non-critical service; UI bug; slow report generation |
| **SEV4 — Low** | Cosmetic or non-urgent issues | 24 hours | Documentation errors; non-production issues; feature requests |

### 5.2 Incident Response Roles

| Role | Responsibility | Assigned To |
|------|---------------|-------------|
| **Incident Commander (IC)** | Overall coordination, communication, decision-making | On-call SRE |
| **Communications Lead** | Status updates, stakeholder communication, postmortem scheduling | SRE Lead |
| **Technical Lead** | Diagnosis, mitigation implementation, resolution | Service owner |
| **Scribe** | Timeline documentation, evidence collection | Rotating team member |

### 5.3 Incident Response Lifecycle

```
Detection ──> Triage ──> Mitigation ──> Resolution ──> Postmortem
   │            │            │              │              │
   ▼            ▼            ▼              ▼              ▼
 Alert    Classify     Stop the      Service        Blameless
 fires    severity     bleed         restored       analysis
          identify     (rollback,    verify         action items
          affected     scale up,     monitoring     track
          services     failover)     green
```

### 5.4 Escalation Path

```
Level 1: On-Call SRE Engineer (primary responder)
    │ 15 min acknowledge
    ▼
Level 2: SRE Lead (technical escalation)
    │ 30 min respond
    ▼
Level 3: Engineering Manager (organizational escalation)
    │ 60 min respond
    ▼
Level 4: VP of Engineering / CTO (executive escalation)
    │ Immediate for SEV1
```

### 5.5 Communication Channels

| Channel | Purpose | Audience |
|---------|---------|----------|
| **#incidents Slack** | Real-time incident coordination | Engineering team |
| **#incidents-prod** | Production incident notifications | All stakeholders |
| **Status page** | External status updates | End users (if applicable) |
| **Email** | Formal postmortem distribution | Engineering + Management |

### 5.6 Incident Response Checklist

```
□  SEV1/SEV2 page received
□  Acknowledge within response time
□  Declare incident in #incidents channel
□  Appoint Incident Commander
□  Assess severity and impact
□  Identify affected services
□  Apply mitigation (rollback, failover, scale)
□  Verify service recovery
□  Monitor for 15 min post-recovery
□  Document timeline
□  Declare incident resolved
□  Schedule postmortem (within 48h for SEV1/SEV2)
□  Update runbooks with lessons learned
```

---

## 6. Postmortem Process

### 6.1 Blameless Culture

SecureRAG Hub follows a strict **blameless postmortem** culture. The goal is to understand systemic causes, not to assign individual fault. All team members are encouraged to contribute openly.

```
Blameless Principles:
  1. Assume good intent from all parties
  2. Focus on system failures, not people failures
  3. Every action was rational given the information at the time
  4. Questions are about learning, not blaming
  5. Failure is a learning opportunity, not a career-limiting event
```

### 6.2 5 Whys Analysis

The 5 Whys technique is used to identify root causes:

| Level | Question | Example (PostgreSQL outage) |
|-------|----------|----------------------------|
| **Why 1** | What happened? | Database became unresponsive |
| **Why 2** | Why did it happen? | Connection pool exhausted |
| **Why 3** | Why was the pool exhausted? | Application not closing connections properly |
| **Why 4** | Why were connections not closed? | Missing timeout configuration in Laravel DB config |
| **Why 5** | Why was the timeout missing? | Not included in the production configuration review checklist |

**Root Cause:** Missing database connection timeout in production overlay configuration.

### 6.3 Postmortem Schedule

| Severity | Postmortem Required | Deadline | Participants |
|----------|:------------------:|:--------:|-------------|
| SEV1 | Yes | 48 hours post-resolution | All involved engineers, SRE lead, engineering manager |
| SEV2 | Yes | 5 business days | Incident team, service owner |
| SEV3 | Optional | 10 business days | Service owner |
| SEV4 | Optional | Next sprint review | Service owner |

### 6.4 Postmortem Template

See [docs/postmortems/template.md](postmortems/template.md) for the complete template.

### 6.5 Action Item Tracking

| Status | Definition |
|--------|-----------|
| 🟢 Closed | Action completed and verified |
| 🟡 In Progress | Work assigned, in development |
| 🔴 Overdue | Past deadline — requires escalation |
| ⚪ Not Started | Not yet assigned or prioritized |

Action items are tracked in the project management tool and reviewed during:
- Weekly SRE standup
- Monthly operations review
- Quarterly SLO review

---

## 7. DORA Metrics Tracking

### 7.1 DORA Metrics Definitions

| Metric | Definition | Elite | High | Medium | Low |
|--------|-----------|:-----:|:----:|:-----:|:---:|
| **Deployment Frequency** | How often code is deployed to production | Multiple deploys/day | Daily to weekly | Weekly to monthly | < Monthly |
| **Lead Time for Changes** | Time from commit to production | < 1 hour | 1 day — 1 week | 1 week — 1 month | > 1 month |
| **MTTR** | Time to restore service after incident | < 1 hour | < 1 day | < 1 week | > 1 week |
| **Change Failure Rate** | Percentage of deployments causing failure | < 5% | < 10% | < 15% | > 15% |

### 7.2 SecureRAG Hub Targets

| Metric | Current Target | Elite Benchmark | Measurement Method |
|--------|:-------------:|:---------------:|--------------------|
| Deployment Frequency | Daily (CI/CD automated) | Multiple/day | Jenkins build timestamps |
| Lead Time for Changes | < 2 hours | < 1 hour | Commit → Deploy time in CI/CD |
| MTTR | < 1 hour | < 1 hour | Incident resolution time in PagerDuty |
| Change Failure Rate | < 5% | < 5% | Deployments causing incidents / total deploys |

### 7.3 Metrics Collection

```yaml
# DORA metrics are collected via:
#
# 1. Deployment Frequency
#    Source: Jenkins API (build timestamps per service)
#    Query: count of successful deploys per week
#    Dashboard: DORA / Deployment Frequency
#
# 2. Lead Time for Changes
#    Source: GitHub API (commit timestamps) + Jenkins (deploy timestamps)
#    Query: p50/p95 time from merge to production deploy
#    Dashboard: DORA / Lead Time
#
# 3. MTTR
#    Source: PagerDuty (incident start/resolution timestamps)
#    Query: avg/median time from incident creation to resolution
#    Dashboard: DORA / MTTR
#
# 4. Change Failure Rate
#    Source: PagerDuty incidents linked to deployments
#    Query: incidents caused by deploy / total deploys * 100
#    Dashboard: DORA / Change Failure Rate
```

### 7.4 DORA Dashboard

```
Grafana Dashboard: DORA / Engineering Excellence

Row 1 — Deployment Frequency
  - Weekly deployment count (bar chart)
  - 4-week trend (line chart)
  - Target overlay (daily = 5 deploys/week)

Row 2 — Lead Time for Changes
  - p50 lead time (gauge, target < 2 hours)
  - p95 lead time (gauge, target < 1 day)
  - Lead time distribution (histogram)

Row 3 — MTTR
  - 30-day rolling MTTR (gauge, target < 1 hour)
  - Individual incident resolution times (bar chart)
  - Phase breakdown: detection, triage, mitigation, resolution

Row 4 — Change Failure Rate
  - 30-day rolling change failure rate (gauge, target < 5%)
  - Changes by result (success / failure) (pie chart)
```

---

## 8. Capacity Planning Guidelines

### 8.1 Resource Forecasting

| Resource | Current Usage | Growth Rate | Forecast (6 months) | Action Threshold |
|----------|:-----------:|:----------:|:-------------------:|:----------------:|
| CPU (namespace) | 12 cores | 15%/quarter | 18 cores | Alert at 70% (23 cores) |
| Memory (namespace) | 48 GB | 15%/quarter | 70 GB | Alert at 70% (89 GB) |
| Storage (PostgreSQL) | 100 GB | 10%/quarter | 133 GB | Alert at 75% (150 GB) |
| Storage (Qdrant) | 50 GB | 20%/quarter | 83 GB | Alert at 75% (100 GB) |
| Pod count | 45 pods | 10%/quarter | 60 pods | Alert at 80% (varies) |

### 8.2 Scaling Decision Framework

```
Metric:
  Average pod CPU > 70% for 24 hours
  ──> Consider HPA tuning or increasing pod limits

Metric:
  Average pod Memory > 80% for 24 hours
  ──> Review memory leaks, increase limits, add replicas

Metric:
  Any resource at 90% for 1 hour
  ──> Immediate investigation, potential incident

Metric:
  Storage at 70% capacity
  ──> Plan expansion, review retention policies

Metric:
  Storage at 85% capacity
  ──> Urgent expansion, possible data cleanup
```

### 8.3 HPA Configuration

| Service | Min Replicas | Max Replicas | CPU Target | Memory Target | Scale Up Behavior | Scale Down Behavior |
|---------|:----------:|:----------:|:---------:|:-----------:|:-----------------:|:------------------:|
| portal-web | 3 | 10 | 70% | 80% | 30s window, 2 pods/min | 5min window, 1 pod/2min |
| auth-users-service | 2 | 6 | 70% | 80% | 30s window, 1 pod/min | 5min window, 1 pod/2min |
| chatbot-manager-service | 2 | 8 | 70% | 80% | 30s window, 1 pod/min | 5min window, 1 pod/2min |
| conversation-service | 2 | 6 | 70% | 80% | 30s window, 1 pod/min | 5min window, 1 pod/2min |
| audit-security-service | 2 | 4 | 70% | 80% | 30s window, 1 pod/min | 5min window, 1 pod/2min |

### 8.4 Quarterly Capacity Review

```
Quarterly Capacity Review Checklist:
□  Review resource utilization trends (CPU, memory, storage, network)
□  Compare actual vs forecasted growth
□  Identify hotspots (namespaces, services, nodes)
□  Review HPA effectiveness and scaling events
□  Analyze cost trends and identify optimization opportunities
□  Update 6-month and 12-month capacity forecasts
□  Document findings and recommendations
□  Present to platform team and engineering management
```

---

## 9. Chaos Engineering Approach

### 9.1 Principles

```
Chaos Engineering Principles:
  1. Start with a hypothesis about system behavior
  2. Run experiments in staging first
  3. Minimize blast radius (start small)
  4. Automate experiments for repeatability
  5. Have a rollback plan before starting
  6. Document every experiment and its outcome
```

### 9.2 Chaos Experiment Catalog

| Experiment | Type | Target | Duration | Hypothesis | Schedule |
|-----------|------|--------|:--------:|------------|----------|
| **Pod Kill** | PodChaos | portal-web (staging) | 60s | K8s reschedules within 30s, no user impact | Weekly |
| **Network Partition** | NetworkChaos | chatbot-manager | 30s | Istio retry handles temporary partition | Bi-weekly |
| **CPU Stress** | StressChaos | portal-web | 120s | HPA scales up within 60s | Monthly |
| **Container Kill** | PodChaos | auth-users | 30s | Service mesh retries, no error rate increase | Bi-weekly |
| **Node Drain** | NodeChaos | worker node | 180s | Pods reschedule gracefully, PDB respected | Monthly |
| **Network Latency** | NetworkChaos | Qdrant | 60s | Chatbot timeout handled, user notified | Bi-weekly |
| **Database Failover** | PodChaos | PostgreSQL primary | 120s | Patroni/CNPG failover within 30s | Quarterly |

### 9.3 Experiment Execution

```bash
# Step 1: Prerequisites
export ENABLE_CHAOS_MESH=true
kubectl create ns chaos-mesh
helm repo add chaos-mesh https://charts.chaos-mesh.org
helm install chaos-mesh chaos-mesh/chaos-mesh --namespace=chaos-mesh --version 2.7.0

# Step 2: Take baseline measurements
kubectl get pods -n securerag-hub -o wide > /tmp/pre-chaos-baseline.txt
kubectl top pods -n securerag-hub > /tmp/pre-chaos-metrics.txt

# Step 3: Apply experiment
kubectl apply -f infra/k8s/chaos/experiments/pod-kill-portal-web.yaml

# Step 4: Monitor during experiment
kubectl get pods -n securerag-hub -w
kubectl describe pod portal-web-* -n securerag-hub | tail -30

# Step 5: Measure recovery
kubectl rollout status deploy/portal-web -n securerag-hub --timeout=120s

# Step 6: Compare post-experiment state
kubectl get pods -n securerag-hub -o wide > /tmp/post-chaos-baseline.txt
diff /tmp/pre-chaos-baseline.txt /tmp/post-chaos-baseline.txt

# Step 7: Cleanup
kubectl delete -f infra/k8s/chaos/experiments/pod-kill-portal-web.yaml
```

### 9.4 Blast Radius Controls

| Control | Implementation |
|---------|---------------|
| **Namespace isolation** | Experiments only run in staging namespace |
| **Feature flag** | `ENABLE_CHAOS_MESH=false` by default in production |
| **Label selectors** | Experiments target specific pods, not entire deployments |
| **Duration limits** | Maximum experiment duration enforced by ChaosMesh |
| **Automatic rollback** | ChaosMesh auto-cleans experiments after duration |

### 9.5 Chaos Day Schedule

```
Monthly Chaos Day:
  Week 1: Planning — Select experiments for the month
  Week 2: Preparation — Review runbooks, alert thresholds
  Week 3: Execution — Run experiment suite in staging
  Week 4: Review — Analyze results, update runbooks, plan improvements
```

---

## 10. On-Call Expectations and Schedule

### 10.1 On-Call Responsibilities

| Responsibility | Details |
|---------------|---------|
| **Primary responder** | First point of contact for all incidents (SEV1-SEV4) |
| **Acknowledge pages** | Within 5 minutes for CRITICAL, 15 minutes for WARNING |
| **Initial triage** | Assess severity, impact, affected services within 15 minutes |
| **Incident coordination** | Lead incident response until resolution or escalation |
| **Documentation** | Update incident timeline; provide handoff notes |
| **Handover** | Clear communication to next on-call during shift change |

### 10.2 On-Call Schedule

```
Primary / Secondary Rotation:
  - Rotating weekly (Monday 09:00 → Monday 09:00)
  - 2-person team: Primary + Secondary (backup)
  - Escalation path: Primary → Secondary → SRE Lead

Shift Patterns:
  - Business hours (09:00 — 18:00): Full team available
  - After hours (18:00 — 09:00): Primary + Secondary only
  - Weekends: Same rotation as after hours

Team Composition (5-person SRE rotation):
  - Week 1: Alice (P) / Bob (S)
  - Week 2: Bob (P) / Carol (S)
  - Week 3: Carol (P) / Dave (S)
  - Week 4: Dave (P) / Eve (S)
  - Week 5: Eve (P) / Alice (S)
```

### 10.3 On-Call Expectations

| Expectation | Detail |
|-------------|--------|
| **Response time** | CRITICAL: 5 min acknowledge, 15 min respond |
| **Device requirements** | Laptop with cluster access, reliable internet, phone for PagerDuty |
| **Quiet hours** | No on-call should handle > 12 hours of incidents in 24h period |
| **Handover** | 15-minute overlap during shift change for knowledge transfer |
| **Rest period** | 24-hour rest period after a week of on-call before next rotation |
| **Training** | All engineers complete incident response training before first on-call |
| **Runbook familiarity** | On-call must be familiar with all runbooks in `docs/runbooks/` |

### 10.4 On-Call Escalation

```
Primary not responding after 5 minutes (CRITICAL) / 15 minutes (WARNING):
  ──> Secondary receives escalation

Secondary not responding after 10 minutes:
  ──> SRE Lead receives escalation

SRE Lead not responding after 15 minutes:
  ──> Engineering Manager receives escalation

Engineering Manager not responding after 20 minutes:
  ──> VP Engineering / CTO receives escalation
```

### 10.5 On-Call Quality of Life

| Practice | Description |
|----------|-------------|
| **Compensation** | Time off in lieu for after-hours incidents (2x time) |
| **Secondary support** | Secondary handles acknowledge during primary's deep work |
| **Automated diagnostics** | Runbooks and automation reduce manual toil |
| **Incident reviews** | Weekly review of incidents to improve processes |
| **Rotation fairness** | Holidays and PTO are excluded from rotation tracking |
| **Wellness check** | Monthly 1:1 with SRE Lead to discuss on-call burden |

### 10.6 On-Call Readiness Checklist

```
Before first on-call shift:
□  Completed incident response training
□  Access to all monitoring tools (Grafana, Prometheus, Loki)
□  Access to PagerDuty (or equivalent)
□  Access to Slack channels (#incidents, #incidents-prod)
□  VPN configured (if applicable)
□  kubectl configured for all clusters
□  Reviewed all runbooks in docs/runbooks/
□  Familiar with common incident patterns
□  Knows escalation contacts
□  Tested alert receipt on personal device

Daily during on-call:
□  Review alert history for last 24 hours
□  Check Grafana dashboards for anomalies
□  Verify backup completion status
□  Review pending incident tickets
□  Update handover document for next on-call

End of shift:
□  Complete handover document
□  Review open incidents with incoming on-call
□  Update runbooks if any gaps identified
□  Log out of all shared sessions
```

---

## References

- [SLO Framework Details](runbooks/production-slo-and-alerting.md)
- [Incident Response Runbook](runbooks/sre-incident-response.md)
- [Postmortem Template](postmortems/template.md)
- [Chaos Engineering Experiments](chaos/README.md)
- [Observability Guide](runbooks/observability-guide.md)
- [Operations Guide](OPERATIONS_GUIDE.md)
- [DR Guide](DR_GUIDE.md)

---

*Document maintained by the SRE team. For questions, contact #sre-team on Slack.*
