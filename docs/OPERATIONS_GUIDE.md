# Operations Guide — SecureRAG Hub

> **Document:** OPERATIONS_GUIDE.md
> **Version:** 1.0
> **Classification:** Internal — Operations
> **Last Updated:** 2026-06-18

---

## Table of Contents

1. Daily Operations Checklist
2. Weekly Operations Tasks
3. Monthly Operations Review
4. Deployment Procedures
5. Backup Verification
6. Capacity Review
7. Cost Review
8. Incident Review (Past 30 Days)
9. Chaos Day Scheduling
10. Upgrade Procedures

---

## 1. Daily Operations Checklist

### 1.1 Morning Checks (09:00 UTC)

```
□  Check incident status from overnight (PagerDuty, Slack)
□  Review Grafana dashboards for anomalies:
    - SRE / Global Performance & SLO
    - Kubernetes / Cluster Overview
    - Security / Runtime Security
□  Verify all pods are Running/Ready:
    kubectl get pods -n securerag-hub -o wide
    kubectl get pods -n securerag-monitoring -o wide
    kubectl get pods -n securerag-security -o wide
□  Check Prometheus targets are UP:
    kubectl port-forward svc/prometheus-k8s -n securerag-monitoring 9090:9090
    → http://localhost:9090/targets
□  Verify database connectivity:
    kubectl exec -n securerag-hub deploy/postgres -- pg_isready
□  Check Qdrant collection health:
    kubectl exec -n securerag-hub deploy/qdrant -- curl -s http://localhost:6333/health
□  Verify backup completion (check Velero):
    velero get backups | grep -E "Completed|Failed"
□  Check certificate expiry:
    kubectl get certificates -A
    kubectl get certificaterequests -A
□  Review alert history (last 24h)
□  Check available disk space on nodes:
    kubectl top nodes
    kubectl describe nodes | grep -A 5 "Conditions:"
```

### 1.2 Afternoon Checks (14:00 UTC)

```
□  Verify CI/CD pipeline health:
    - Last Jenkins CI build status
    - Last Jenkins CD build status
    - ArgoCD sync status
□  Check for pending security updates (Renovate PRs):
    gh pr list --label dependencies
□  Review Falco alerts (last 8 hours):
    kubectl logs -n securerag-security -l app.kubernetes.io/name=falco --since=8h | \
      grep -E "CRITICAL|EMERGENCY"
□  Verify HPA is working:
    kubectl get hpa -n securerag-hub
□  Check resource usage trends:
    kubectl top pods -n securerag-hub
    kubectl top nodes
□  Verify all services respond to health checks:
    for svc in portal-web auth-users chatbot-manager conversation-service audit-security; do
      curl -sf http://$svc.securerag-hub:8000/health && echo "$svc: OK" || echo "$svc: FAIL"
    done
```

### 1.3 End of Day Checks (18:00 UTC)

```
□  Document any incidents or anomalies in operations log
□  Update handover document for next on-call
□  Ensure monitoring and alerting are active
□  Verify backup log for the day
□  Check for any scheduled maintenance windows
□  Review any pending incident tickets
□  Update status page if needed (production incident only)
```

---

## 2. Weekly Operations Tasks

### 2.1 Monday — Security Review

```
□  Review and triage all Falco alerts from the past week
□  Check Kyverno PolicyReports for new violations:
    kubectl get policyreport -A -o wide
□  Verify all running images are signed:
    for pod in $(kubectl get pods -n securerag-hub -o name); do
      IMAGE=$(kubectl get $pod -n securerag-hub -o jsonpath='{.spec.containers[0].image}')
      cosign verify --key cosign.pub $IMAGE && echo "$IMAGE: VERIFIED" || echo "$IMAGE: NOT VERIFIED"
    done
□  Review secret rotation schedule:
    - Check upcoming expiration dates
    - Initiate any rotations due within 2 weeks
□  Run weekly Trivy scan:
    trivy repo --severity CRITICAL,HIGH https://github.com/YassinoMed/MasterPFE.git
□  Update Semgrep rules if new patterns discovered
□  Verify Gitleaks has no new findings:
    gitleaks detect --source . --report-format json --report-path artifacts/security/gitleaks-weekly.json
```

### 2.2 Tuesday — Performance Review

```
□  Review application latency trends (p50, p95, p99):
    - Grafana dashboard: SRE / Global Performance & SLO
    - Compare week-over-week
□  Analyze HPA scaling events:
    kubectl describe hpa -n securerag-hub > /tmp/hpa-events.txt
□  Check resource utilization trends:
    - Pod CPU/Memory usage vs limits
    - Node resource pressure
    - Storage growth rates
□  Review database query performance:
    kubectl exec -n securerag-hub deploy/postgres -- \
      psql -c "SELECT * FROM pg_stat_activity WHERE state = 'active';"
    kubectl exec -n securerag-hub deploy/postgres -- \
      psql -c "SELECT query, calls, total_time FROM pg_stat_statements ORDER BY total_time DESC LIMIT 10;"
□  Identify and document performance bottlenecks
```

### 2.3 Wednesday — Backup Validation

```
□  Restore latest backup to isolated test namespace:
    velero restore create --from-backup securerag-hub-latest \
      --namespace-mappings securerag-hub:securerag-restore-test
□  Run smoke tests against restored data:
    kubectl wait --for=condition=available --timeout=120s \
      -n securerag-restore-test deployment/portal-web
    bash scripts/validate/smoke-tests.sh \
      -n securerag-restore-test
□  Verify data integrity:
    - Compare row counts with baseline
    - Check latest records are within RPO window
    - Validate foreign key integrity
□  Clean up test namespace:
    kubectl delete namespace securerag-restore-test
□  Document backup validation results
```

### 2.4 Thursday — Capacity Planning

```
□  Review this week's capacity metrics:
    - CPU utilization trend (7-day average)
    - Memory utilization trend (7-day average)
    - Storage growth rate
    - Pod count growth
□  Compare against forecasts:
    - Actual vs predicted resource usage
    - Update 6-month forecast
□  Identify any services approaching capacity thresholds:
    - Alert if any resource > 70% capacity
    - Plan expansion for resources > 80%
□  Review HPA configuration effectiveness:
    - Check if HPA is scaling appropriately
    - Adjust thresholds if needed
□  Document recommendations for next capacity review
```

### 2.5 Friday — Release & Planning

```
□  Review deployment activity for the week:
    - Number of successful deployments
    - Number of failed deployments
    - Change failure rate
□  Review DORA metrics (weekly update):
    - Deployment frequency
    - Lead time for changes
    - MTTR
    - Change failure rate
□  Update runbooks with lessons learned
□  Plan next week's operations tasks
□  Schedule any required maintenance windows
□  Update operations log with weekly summary
□  Send weekly operations report to engineering team
```

---

## 3. Monthly Operations Review

### 3.1 Monthly Review Agenda

```
Monthly Operations Review (typically last Thursday of month)
Duration: 60 minutes
Attendees: SRE team, Platform Engineering, Engineering Manager

Agenda:
  1. Incident review (past 30 days) — 15 min
  2. SLO attainment review — 10 min
  3. Capacity review — 10 min
  4. Cost review — 10 min
  5. Security posture update — 5 min
  6. Improvement action items — 10 min
```

### 3.2 Monthly Metrics Report

```
Generate monthly report:
  bash scripts/operations/monthly-report.sh
  → artifacts/operations/monthly-report-YYYY-MM.md

Report includes:
  - SLO attainment by service (30-day rolling)
  - Error budget consumption
  - DORA metrics (30-day rolling)
  - Incident summary
  - Capacity metrics and trends
  - Cost analysis
  - Backup validation results
  - Security metrics
  - Improvement action items status
```

### 3.3 Monthly Security Review

```
□  Review and update Falco rules:
    - Analyze false positive rate
    - Add new rules for emerging threats
    - Tune rule priorities
□  Review Kyverno policy effectiveness:
    - Check policy violation trends
    - Consider moving Audit policies to Enforce
    - Update policies for new compliance requirements
□  Run full vulnerability scan:
    trivy repo --scanners vuln,secret,misconfig --severity CRITICAL,HIGH,MEDIUM .
□  Review dependency update status (Renovate):
    - Merge automated PRs if tests pass
    - Manually review any blocked updates
□  Verify all secrets are within rotation window:
    - Check age of each secret
    - Initiate rotations for upcoming expirations
□  Update threat model if architecture changed
```

### 3.4 Monthly Testing

```
□  Run full smoke test suite:
    bash scripts/validate/smoke-tests.sh
    bash scripts/validate/security-smoke.sh
    bash scripts/validate/e2e-functional-flow.sh
    bash scripts/validate/rag-smoke.sh
□  Execute disaster recovery drill (see DR_GUIDE.md):
    - Restore from backup to isolated namespace
    - Verify all services functional
    - Document RTO and RPO achieved
□  Run performance baseline test:
    - Measure current latency baselines
    - Compare against previous month
□  Test alerting pipeline:
    - Verify all alert rules fire correctly
    - Check Alertmanager routing
    - Verify notification delivery (PagerDuty, Slack)
```

---

## 4. Deployment Procedures

### 4.1 Standard Deployment Flow

```bash
# Step 1: Prepare release
git checkout main
git pull origin main

# Step 2: Run local validation (optional but recommended)
make lint
make test
make kyverno-policy-check

# Step 3: Trigger CI pipeline
# Push to main triggers Jenkins CI automatically
# Or manually trigger: Jenkins → securerag-hub-ci → Build with Parameters

# Step 4: Verify CI pipeline passes
# Check Jenkins console output
# Verify all quality gates pass

# Step 5: Trigger CD pipeline
# Jenkins → securerag-hub-cd → Build with Parameters
# Parameters: SOURCE_IMAGE_TAG=dev, TARGET_IMAGE_TAG=production

# Step 6: Verify CD pipeline passes
# Check image scan, signing, promotion, and deploy stages

# Step 7: Verify deployment
kubectl rollout status deployment/portal-web -n securerag-hub --timeout=300s
kubectl rollout status deployment/auth-users-service -n securerag-hub --timeout=300s
kubectl rollout status deployment/chatbot-manager-service -n securerag-hub --timeout=300s
kubectl rollout status deployment/conversation-service -n securerag-hub --timeout=300s
kubectl rollout status deployment/audit-security-service -n securerag-hub --timeout=300s

# Step 8: Run post-deploy validation
make validate
make security-posture
make final-source-of-truth
```

### 4.2 Emergency Hotfix Deployment

```bash
# Step 1: Create hotfix branch
git checkout main
git checkout -b hotfix/SEV-1234-critical-fix

# Step 2: Apply fix, commit, push
git add .
git commit -m "fix: critical security vulnerability in auth service"
git push origin hotfix/SEV-1234-critical-fix

# Step 3: Create PR with expedited approval
gh pr create --title "HOTFIX: SEV-SEC-1 Critical fix" \
  --body "Emergency fix for active security vulnerability." \
  --label "hotfix" \
  --assignee @sre-lead

# Step 4: Merge after expedited review (SRE Lead approves)
gh pr merge --squash

# Step 5: Monitor CI pipeline (expect it to pass quickly)
# If CI passes, trigger CD manually with hotfix tag

# Step 6: Skip non-essential quality gates if needed
# Set environment variable: HOTFIX_MODE=true
# This skips: Sonar, coverage gates (NOT security gates)

# Step 7: Post-deployment monitoring
# Monitor error rates, latency, and security alerts for 30 min

# Step 8: Postmortem within 48 hours
```

### 4.3 Deployment Freeze

```
Conditions for deployment freeze:
  1. Error budget > 80% consumed (any critical service)
  2. Active SEV1 or SEV-SEC-1 incident
  3. Failed postmortem action items not closed by deadline
  4. Planned maintenance window (48h advance notice)

During freeze:
  - Only security patches and hotfixes deployed
  - All deployments require SRE Lead approval
  - No new features or non-critical changes

Lifting freeze:
  - SRE Lead approves based on conditions met
  - Post-incident: after postmortem complete
  - Planned: after maintenance window ends
```

### 4.4 Rollback Procedure

```bash
# Option 1: ArgoCD rollback (recommended)
argocd app list | grep securerag
argocd app history securerag-portal-web-production
argocd app rollback securerag-portal-web-production <REVISION>
kubectl rollout status deployment/portal-web -n securerag-hub

# Option 2: Git revert
git revert HEAD~1  # Revert the last commit
git push origin main
# ArgoCD auto-syncs (or manual sync for production)

# Option 3: kubectl rollout undo (emergency only)
kubectl rollout undo deployment/portal-web -n securerag-hub
kubectl rollout status deployment/portal-web -n securerag-hub

# Option 4: Manual (if ArgoCD and GitOps unavailable)
kubectl set image deployment/portal-web -n securerag-hub \
  portal-web=ghcr.io/securerag-hub/portal-web@sha256:<previous-digest>
```

---

## 5. Backup Verification

### 5.1 Daily Backup Verification

```bash
# Verify Velero backup completed successfully
velero get backups | grep -E "securerag-hub-$(date -u +%Y%m%d)"
velero backup describe securerag-hub-$(date -u +%Y%m%d)-020000

# Expected output:
# Phase:  Completed
# Errors:  0
# Warnings: 0

# Verify backup size is reasonable
velero backup describe securerag-hub-$(date -u +%Y%m%d)-020000 | grep "Total bytes"

# Expected: > minimum threshold (e.g., > 100 MB)
```

### 5.2 Weekly Backup Restore Test

```bash
# Step 1: Create isolated test namespace
kubectl create namespace securerag-backup-test
kubectl label namespace securerag-backup-test purpose=backup-validation

# Step 2: Run weekly validation script
bash scripts/operations/weekly-backup-validation.sh

# Script performs:
#   - Restores latest backup to test namespace
#   - Waits for all deployments to be available
#   - Runs smoke tests
#   - Verifies data integrity
#   - Cleans up test namespace
#   - Generates validation report

# Step 3: Review report
cat artifacts/operations/backup-validation-$(date -u +%Y%m%d).md

# Expected result: "BACKUP_VALIDATION: PASS"
```

### 5.3 Monthly Full Restore Test

```bash
# Full DR drill (see DR_GUIDE.md for complete procedure)
bash scripts/dr/full-restore-drill.sh --monthly

# This performs:
#   - Full Velero restore
#   - PostgreSQL PITR test
#   - Qdrant snapshot restore
#   - Full smoke test suite
#   - Data integrity validation
#   - RTO/RPO measurement
#   - Cleanup

# Report generated at:
cat artifacts/dr/monthly-restore-drill-$(date -u +%Y%m).md
```

### 5.4 Backup Storage Verification

```bash
# Check MinIO backup bucket
mc ls minio/securerag-backups/

# Verify backup encryption
mc stat minio/securerag-backups/securerag-hub-$(date -u +%Y%m%d).dump | grep "Encryption"

# Expected: "Encryption: AES256"

# Verify backup checksums
sha256sum -c artifacts/backup/checksums-$(date -u +%Y%m%d).txt

# Expected: All files "OK"
```

---

## 6. Capacity Review

### 6.1 Weekly Capacity Check

```bash
# Check current resource usage
echo "=== Node Resources ==="
kubectl top nodes
echo "=== Namespace Resources ==="
kubectl top pods -n securerag-hub
echo "=== Storage Resources ==="
kubectl get pvc -n securerag-hub
echo "=== HPA Status ==="
kubectl get hpa -n securerag-hub

# Check for resource pressure
kubectl describe nodes | grep -E "Conditions:|MemoryPressure|DiskPressure|PIDPressure"
```

### 6.2 Monthly Capacity Review

```
Review the following metrics:
  1. CPU utilization (7-day average, 30-day trend)
  2. Memory utilization (7-day average, 30-day trend)
  3. Storage utilization per PVC (30-day growth rate)
  4. Pod count growth (30-day trend)
  5. Request volume growth (30-day trend)
  6. HPA scaling events (30-day count)
  7. Node resource pressure events

Compare against forecasts:
  - Actual vs predicted (from last month's review)
  - Update 6-month and 12-month forecasts
  - Highlight any services approaching thresholds

Thresholds:
  🟢 Green: < 50% utilization
  🟡 Yellow: 50-70% utilization (monitor)
  🟠 Orange: 70-85% utilization (plan expansion)
  🔴 Red: > 85% utilization (immediate action)

Document in monthly operations report:
  - Current utilization vs thresholds
  - Growth rate analysis
  - Recommended actions
  - Forecast for next quarter
```

### 6.3 Capacity Planning Triggers

| Trigger | Action | Lead Time |
|---------|--------|:---------:|
| Average pod CPU > 70% for 7 days | Increase HPA max replicas or CPU limit | 1 week |
| Average pod memory > 80% for 7 days | Review memory leaks, increase limits | 2 weeks |
| Node CPU > 70% for 7 days | Plan node pool expansion | 1 month |
| Node memory > 80% for 7 days | Plan node pool expansion | 1 month |
| Storage > 70% used | Increase PVC size or cleanup data | 2 weeks |
| Storage > 85% used | Immediate expansion or cleanup | 1 week |
| Pod count > 80% of quota | Request quota increase | 1 month |
| HPA scaling to max frequently | Increase max replicas or optimize | 2 weeks |

---

## 7. Cost Review

### 7.1 Weekly Cost Monitoring

```
Check cost trends:
  - Infrastructure cost (node hours, storage, network)
  - Third-party service costs (if applicable)
  - CI/CD runner costs (Jenkins agents)
  - Monitoring costs (Prometheus retention)

Review for anomalies:
  - Unusual traffic spikes
  - New services deployed
  - Storage consumption acceleration
  - Unexpected resource requests

Document in operations log:
  - Current weekly cost
  - Week-over-week change
  - Anomalies identified
```

### 7.2 Monthly Cost Review

```
Monthly cost analysis:
  1. Compute costs (node hours):
     - Production cluster
     - Staging cluster
     - DR cluster
     - CI/CD agents

  2. Storage costs:
     - Persistent volumes
     - Backup storage (MinIO)
     - Log storage (Loki)
     - Metric storage (Prometheus/Thanos)

  3. Network costs:
     - Cross-region traffic
     - Egress to external services
     - Load balancer hours

  4. Third-party services:
     - OCI registry (if external)
     - Monitoring service (if external)
     - DNS

Optimization opportunities:
  - Rightsizing requests/limits
  - Identifying unused resources
  - Storage tier optimization
  - Reserved instance planning
  - Spot instance feasibility

Report format:
  - Cost breakdown by category
  - Month-over-month trend
  - Year-over-year comparison
  - Optimization recommendations
  - Budget vs actual
```

### 7.3 Cost Optimization Checklist

```
□  Rightsizing:
    - Review pod resource requests vs actual usage
    - Adjust requests to match 90th percentile usage
    - Remove unused resource requests

□  Storage optimization:
    - Enable MinIO lifecycle policies
    - Review Loki retention period
    - Archive cold data to cheaper storage

□  Scaling optimization:
    - Review HPA minimums (are they too high?)
    - Enable cluster autoscaler
    - Consider spot instances for non-critical workloads

□  Waste elimination:
    - Remove unused PVCs
    - Delete old backup snapshots
    - Clean up untagged container images
    - Delete stale namespaces

□  Reserved capacity:
    - Evaluate reserved instance savings
    - Plan for growth with reservations
```

---

## 8. Incident Review (Past 30 Days)

### 8.1 Monthly Incident Summary

```
Incident review meeting (15 minutes during monthly operations review):

  1. Incidents this month:
     - Total incidents: N
     - SEV1: N
     - SEV2: N
     - SEV3: N
     - SEV4: N
     - SEV-SEC: N

  2. Incident metrics (30-day rolling):
     - MTTR (Mean Time to Resolution)
     - MTTD (Mean Time to Detection)
     - Top incident types
     - Services most affected

  3. Error budget consumption:
     - Budget consumed this month
     - Remaining budget
     - Services at risk

  4. Postmortem status:
     - Postmortems completed: N
     - Postmortems overdue: N
     - Action items open: N
     - Action items closed: N
```

### 8.2 Incident Trend Analysis

```
Analyze incident trends:
  - Are incidents increasing or decreasing?
  - Are there recurring incident patterns?
  - Are new incidents emerging?
  - Are postmortem actions effective?

Generate incident report:
  bash scripts/operations/incident-report.sh --days 30
  → artifacts/operations/incident-report-YYYY-MM-DD.md

Report includes:
  - Incident timeline (last 30 days)
  - Severity distribution
  - Service impact matrix
  - MTTR/MTTD trends
  - Top 5 root causes
  - Action item status
```

### 8.3 Postmortem Action Item Tracking

| # | Incident | Action Item | Owner | Deadline | Status |
|---|----------|-------------|-------|:--------:|:------:|
| — | — | — | — | — | — |

*Action items tracked in project management tool. Report generated at time of monthly review.*

---

## 9. Chaos Day Scheduling

### 9.1 Monthly Chaos Day

```
Chaos Day Schedule (monthly, typically Week 3):
  Week 1: Planning
    - Select 2-3 experiments from chaos catalog
    - Review blast radius controls
    - Notify team of scheduled experiments
    - Prepare rollback procedures

  Week 2: Preparation
    - Verify staging environment is ready
    - Check chaos-mesh is installed
    - Review alert thresholds and notification routing
    - Brief the team on expected experiments

  Week 3: Execution (Chaos Day)
    - Morning: Run first experiment (e.g., Pod Kill)
    - Afternoon: Run second experiment (e.g., Network Partition)
    - Document observations and metrics
    - Run regression tests

  Week 4: Review
    - Analyze experiment results
    - Update runbooks with findings
    - Identify system weaknesses
    - Plan improvements
```

### 9.2 Chaos Experiment Recording

```
Each experiment should be recorded:
  Date: YYYY-MM-DD
  Experiment: [Name]
  Target: [Service] in [Namespace]
  Duration: [time]
  Hypothesis: [expected behavior]
  Results:
    - System behavior: [observed]
    - RTO: [time to recovery]
    - Data integrity: [intact / affected]
    - Error budget consumed: [%
  Lessons learned:
    - [Lesson 1]
    - [Lesson 2]
  Action items:
    - [ ] [Action item 1]
    - [ ] [Action item 2]

Record in:
  artifacts/chaos/experiment-YYYY-MM-DD-NAME.md
```

### 9.3 Chaos Experiment Catalog

See [Chaos Engineering Guide](chaos/README.md) for the complete experiment catalog.

Standard experiments:

| Experiment | Target | Duration | Frequency | Purpose |
|-----------|--------|:--------:|:---------:|---------|
| Pod Kill | portal-web (staging) | 60s | Weekly | Verify Kubernetes rescheduling |
| Network Partition | chatbot-manager | 30s | Bi-weekly | Validate Istio retry |
| CPU Stress | portal-web | 120s | Monthly | Test HPA scaling |
| Container Kill | auth-users | 30s | Bi-weekly | Test service mesh retry |
| Node Drain | worker node | 180s | Monthly | Test pod graceful rescheduling |
| Network Latency | Qdrant | 60s | Bi-weekly | Test chatbot timeout handling |
| Database Failover | PostgreSQL primary | 120s | Quarterly | Test Patroni/CNPG failover |

---

## 10. Upgrade Procedures

### 10.1 Kubernetes Upgrade

```bash
# ──────────────────────────────────────────────────────
# Kubernetes Minor Version Upgrade (e.g., 1.28 → 1.29)
# ──────────────────────────────────────────────────────

# Phase 1: Pre-Upgrade (Day -14)
□  Review Kubernetes release notes for breaking changes
□  Check deprecated APIs used in manifests:
    kubectl api-resources --verbs=list --namespaced -o name | \
      xargs -n 1 kubectl get --show-kind --ignore-not-found -n securerag-hub
□  Verify all Deployments use non-deprecated API versions
□  Backup etcd (if self-managed):
    ETCDCTL_API=3 etcdctl snapshot save /backups/etcd-pre-upgrade.db
□  Backup all Kubernetes objects:
    velero backup create pre-upgrade-backup --include-namespaces securerag-hub,securerag-monitoring,securerag-security

# Phase 2: Staging Upgrade (Day -7)
□  Upgrade staging cluster:
    # Upgrade control plane
    kubeadm upgrade plan
    kubeadm upgrade apply v1.29.0
    # Upgrade nodes
    kubectl drain staging-node-1 --ignore-daemonsets
    kubeadm upgrade node
    kubectl uncordon staging-node-1
    # Repeat for all nodes
□  Run full validation suite
□  Monitor for 48 hours
□  Document any issues

# Phase 3: Production Upgrade (Day 0)
□  Announce maintenance window (48h advance notice)
□  Set status page to "Under Maintenance"
□  Enable deployment freeze
□  Upgrade control plane (one node at a time):
    kubeadm upgrade plan
    kubeadm upgrade apply v1.29.0
□  Upgrade worker nodes (one at a time):
    kubectl drain prod-node-1 --ignore-daemonsets --delete-emptydir-data
    kubeadm upgrade node
    kubectl uncordon prod-node-1
    # Wait 5 min between nodes
□  Verify cluster health:
    kubectl get nodes
    kubectl get pods -A
□  Run validation suite:
    bash scripts/validate/smoke-tests.sh
    bash scripts/validate/security-smoke.sh
□  Monitor for 1 hour
□  Update status page to "Operational"

# Phase 4: Post-Upgrade (Day +1 to +7)
□  Remove deprecated API usage warnings
□  Update CI/CD tooling versions (kubectl, kube-score)
□  Update upgrade runbook with lessons learned
□  Verify all applications running normally
□  Monitor error rates and performance for 7 days
```

### 10.2 Istio Upgrade

```bash
# ──────────────────────────────────────────────────────
# Istio Upgrade (e.g., 1.21 → 1.22)
# ──────────────────────────────────────────────────────

# Phase 1: Preparation
□  Review Istio release notes
□  Verify current version:
    istioctl version
□  Download new version:
    curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.22.0 sh -
□  Canary upgrade of control plane:
    istioctl install --set revision=1-22 \
      -f infra/k8s/istio/profile.yaml

# Phase 2: Canary (staging)
□  Label staging namespace for new revision:
    kubectl label namespace securerag-staging istio.io/rev=1-22
□  Restart deployments (rolling update):
    kubectl rollout restart deployment -n securerag-staging
□  Verify sidecar injection with new version
□  Run full test suite
□  Monitor for 48 hours

# Phase 3: Production upgrade
□  Label production namespace:
    kubectl label namespace securerag-hub istio.io/rev=1-22
□  Restart deployments (gradual rollout):
    kubectl rollout restart deployment/portal-web -n securerag-hub
    sleep 300
    kubectl rollout restart deployment/auth-users-service -n securerag-hub
    # Continue for each service
□  Verify mTLS still working:
    istioctl authz check pod/portal-web-xxx -n securerag-hub
□  Run validation suite
□  Remove old control plane:
    istioctl uninstall --revision 1-21
```

### 10.3 PostgreSQL Upgrade

```bash
# ──────────────────────────────────────────────────────
# PostgreSQL Upgrade (e.g., 15 → 16)
# ──────────────────────────────────────────────────────

# Requires logical replication or pg_upgrade

# Option A: Blue-Green (recommended)
□  Deploy PostgreSQL 16 cluster in parallel
□  Set up logical replication from PG15 primary to PG16 primary
□  Wait for replication lag to reach near-zero
□  Switch application connection strings to PG16
    kubectl edit secret securerag-database-secrets -n securerag-hub
□  Monitor applications for errors
□  Remove old PG15 cluster after 48h

# Option B: pg_upgrade (downtime required)
□  Announce maintenance window
□  Stop applications:
    kubectl scale deployment -n securerag-hub --all --replicas=0
□  Backup PG15:
    pg_dumpall -c -f /backups/pg15-full-backup.sql
□  Run pg_upgrade:
    pg_upgrade -b /usr/lib/postgresql/15/bin \
               -B /usr/lib/postgresql/16/bin \
               -d /var/lib/postgresql/15/data \
               -D /var/lib/postgresql/16/data
□  Start PostgreSQL 16
□  Verify data integrity
□  Start applications:
    kubectl scale deployment -n securerag-hub --all --replicas=1
□  Monitor for errors
□  Update backup scripts for PG16
```

### 10.4 Component Version Mappings

| Component | Current Version | Next Version | Upgrade Window | Risk |
|-----------|:--------------:|:------------:|:-------------:|:----:|
| Kubernetes | 1.28 | 1.29 | Q3 2026 | Medium |
| Istio | 1.21 | 1.22 | Q3 2026 | Medium |
| PostgreSQL | 15 | 16 | Q4 2026 | High |
| Qdrant | 1.9 | 1.10 | Q3 2026 | Low |
| Prometheus | 2.50 | 2.51 | Q2 2026 | Low |
| Loki | 2.9 | 3.0 | Q3 2026 | Medium |
| Velero | 1.13 | 1.14 | Q3 2026 | Low |
| Jenkins | 2.440 | 2.450 | Q2 2026 | Low |
| ArgoCD | 2.10 | 2.11 | Q2 2026 | Low |
| Falco | 0.37 | 0.38 | Q3 2026 | Low |

### 10.5 General Upgrade Best Practices

```
1. Always test upgrades in staging before production
2. Take full backup before any upgrade
3. Have rollback plan documented before starting
4. Schedule upgrades during low-traffic periods
5. Announce maintenance windows 48h in advance
6. Involve service owners in upgrade testing
7. Monitor metrics and alerts during and after upgrade
8. Document any issues encountered
9. Update runbooks with upgrade-specific procedures
10. Run post-upgrade validation suite
```

---

## References

- [SRE Guide](SRE_GUIDE.md)
- [DR Guide](DR_GUIDE.md)
- [Security Guide](SECURITY_GUIDE.md)
- [RUNBOOKS.md](RUNBOOKS.md)
- [Chaos Engineering](chaos/README.md)
- [Observability Guide](runbooks/observability-guide.md)
- [Data Resilience](runbooks/data-resilience.md)

---

*Document maintained by the SRE team. For questions, contact #sre-team on Slack.*
