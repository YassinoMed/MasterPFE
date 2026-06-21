# Disaster Recovery Guide — SecureRAG Hub

> **Document:** DR_GUIDE.md
> **Version:** 1.0
> **Classification:** Internal — Critical Infrastructure
> **Last Updated:** 2026-06-18

---

## Table of Contents

1. RTO/RPO Targets
2. Backup Strategy
3. Restore Procedures
4. DR Drill Schedule
5. Cross-Region Failover Procedure
6. Data Integrity Validation
7. Communication Plan During DR
8. DR Checklist
9. Past Drill Results and Lessons Learned

---

## 1. RTO/RPO Targets

### 1.1 Recovery Time Objective (RTO) and Recovery Point Objective (RPO)

| Component | RTO | RPO | Priority | Dependencies |
|-----------|:---:|:---:|:--------:|-------------|
| **portal-web** | < 15 min | < 1 hour | P0 | auth-users, ingress |
| **auth-users-service** | < 15 min | < 1 hour | P0 | PostgreSQL |
| **chatbot-manager-service** | < 30 min | < 1 hour | P1 | Qdrant, LLM, audit |
| **conversation-service** | < 30 min | < 1 hour | P1 | PostgreSQL |
| **audit-security-service** | < 15 min | < 1 hour | P0 | PostgreSQL |
| **PostgreSQL (HA)** | < 5 min automatic | < 5 min (sync) | P0 | Storage |
| **Qdrant** | < 30 min | < 1 hour | P1 | Storage |
| **Ollama/LLM** | < 2 hours | N/A (stateless) | P2 | GPU node |
| **MinIO** | < 1 hour | < 1 hour | P1 | Storage |
| **Monitoring Stack** | < 1 hour | N/A (ephemeral) | P2 | Storage |
| **Kubernetes Control Plane** | < 30 min | N/A (config) | P0 | etcd backup |

### 1.2 RTO/RPO by Disaster Scenario

| Scenario | Expected RTO | Expected RPO | Recovery Method |
|----------|:-----------:|:-----------:|-----------------|
| Single pod crash | < 30 seconds | N/A | Kubernetes auto-restart |
| Node failure | < 5 minutes | N/A | Pod reschedule |
| AZ outage (single) | < 15 minutes | < 1 hour | Cross-AZ failover |
| Region outage | < 30 minutes | < 15 minutes | DR cluster activation |
| Data corruption | < 1 hour | < 1 hour | Velero restore + PITR |
| Accidental deletion | < 1 hour | < 1 hour | Velero restore |
| Ransomware attack | < 4 hours | < 1 hour | Clean restore from backup |
| Full cluster failure | < 2 hours | < 1 hour | DR cluster bootstrap |

---

## 2. Backup Strategy

### 2.1 Backup Schedule

| Component | Tool | Frequency | Retention | Storage | Encryption |
|-----------|------|:---------:|:---------:|---------|:----------:|
| **PostgreSQL (full)** | pg_dump + pgBackRest | Daily | 14 days | MinIO bucket | AES-256 |
| **PostgreSQL (WAL)** | pgBackRest | Continuous | 7 days | MinIO bucket | AES-256 |
| **PostgreSQL (weekly)** | Velero | Weekly (Sunday) | 8 weeks | MinIO bucket | AES-256 |
| **PostgreSQL (monthly)** | pg_dump | Monthly (1st) | 12 months | MinIO + off-site | AES-256 |
| **Qdrant snapshots** | Qdrant API + Velero | Daily | 7 days | MinIO bucket | AES-256 |
| **MinIO metadata** | MinIO mc mirror | Daily | 30 days | Secondary MinIO | AES-256 |
| **Kubernetes objects** | Velero | Daily | 30 days | MinIO bucket | AES-256 |
| **Persistent volumes** | Velero + restic | Daily | 30 days | MinIO bucket | AES-256 |
| **ArgoCD config** | Velero | Daily | 30 days | MinIO bucket | AES-256 |
| **Jenkins config** | Jenkins backup plugin | Weekly | 12 weeks | MinIO bucket | AES-256 |
| **Helm values** | Git (source of truth) | On change | Perpetual | GitHub | N/A (Git) |

### 2.2 PostgreSQL Backup Configuration

```yaml
# Backup CronJob — runs daily at 01:00 UTC
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
  namespace: securerag-hub
spec:
  schedule: "0 1 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: pg-backup
              image: postgres:16-alpine
              env:
                - name: PGHOST
                  valueFrom:
                    secretKeyRef:
                      name: securerag-database-secrets
                      key: DB_HOST
                - name: PGPORT
                  value: "5432"
                - name: PGUSER
                  valueFrom:
                    secretKeyRef:
                      name: securerag-database-secrets
                      key: DB_USERNAME
                - name: PGPASSWORD
                  valueFrom:
                    secretKeyRef:
                      name: securerag-database-secrets
                      key: DB_PASSWORD
              command:
                - /bin/sh
                - -c
                - |
                  BACKUP_FILE="/backups/securerag-hub-$(date -u +%Y%m%dT%H%M%SZ).dump"
                  pg_dump -Fc --no-owner --no-acl -f "${BACKUP_FILE}"
                  shasum -a 256 "${BACKUP_FILE}" > "${BACKUP_FILE}.sha256"
```

### 2.3 Velero Backup Configuration

```yaml
# Velero Schedule — Daily backup
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: securerag-daily-backup
  namespace: velero
spec:
  schedule: "0 2 * * *"
  template:
    includedNamespaces:
      - securerag-hub
      - securerag-monitoring
      - securerag-security
      - securerag-gitops
    excludedResources:
      - pods
      - events
      - events.events.k8s.io
    ttl: 720h  # 30 days
    storageLocation: default
    volumeSnapshotLocations:
      - default
    defaultVolumesToRestic: true
```

### 2.4 Backup Verification Process

```
Daily (automated):
  □  Verify latest backup exists
  □  Check backup size ≥ minimum threshold
  □  Validate SHA-256 checksum
  □  Alert on backup failure

Weekly (automated + manual review):
  □  Restore backup to isolated test database
  □  Run smoke tests against restored database
  □  Verify data integrity (row counts, latest records)
  □  Document in weekly operations report

Monthly (manual):
  □  Full restore from monthly backup
  □  Run full integration test suite
  □  Validate all service endpoints
  □  Generate backup verification report
```

### 2.5 Backup Storage Requirements

| Storage Tier | Location | Capacity | Retention | Access Pattern |
|-------------|----------|:--------:|:---------:|----------------|
| **Hot (primary)** | MinIO (production cluster) | 500 GB | 14 days | Daily restore drills |
| **Warm (secondary)** | MinIO (DR cluster) | 1 TB | 30 days | Cross-region restore |
| **Cold (archival)** | S3-compatible (off-site) | 2 TB | 12 months | Compliance retention |

---

## 3. Restore Procedures

### 3.1 Velero Restore — Full Cluster

```bash
# Step 1: Identify the backup to restore
velero get backups

# Step 2: Verify backup integrity
velero backup describe securerag-hub-20260618-020000

# Step 3: Restore to same cluster (namespace restore)
velero restore create --from-backup securerag-hub-20260618-020000 \
  --namespace-mappings securerag-hub:securerag-hub-restored

# Step 4: Restore to DR cluster
velero restore create --from-backup securerag-hub-20260618-020000 \
  --namespace-mappings securerag-hub:securerag-hub \
  --restore-volumes=true

# Step 5: Monitor restore progress
velero restore get
velero restore logs securerag-hub-20260618-020000-xxxxx

# Step 6: Verify restore
kubectl get pods -n securerag-hub
kubectl get deployments -n securerag-hub
kubectl get pvc -n securerag-hub
```

### 3.2 PostgreSQL Point-in-Time Recovery (PITR)

```bash
# Prerequisites:
# - Base backup file (from pgBackRest or pg_dump)
# - WAL archive files spanning target time
# - Target timestamp for recovery

# Step 1: Stop the PostgreSQL cluster
kubectl scale statefulset postgres --replicas=0 -n securerag-hub

# Step 2: Restore base backup
pgbackrest --stanza=securerag-hub --type=time \
  --target="2026-06-18 14:30:00+00" \
  --target-action=promote \
  restore

# Step 3: Configure recovery.conf (PostgreSQL < 12) or
#         set restore_command in postgresql.conf
# restore_command = 'pgbackrest --stanza=securerag-hub archive-get %f "%p"'
# recovery_target_time = '2026-06-18 14:30:00+00'

# Step 4: Start PostgreSQL
kubectl scale statefulset postgres --replicas=1 -n securerag-hub

# Step 5: Verify recovery completed
kubectl logs -l app=postgres -n securerag-hub --tail=50
# Look for: "recovery stopping before commit of transaction ..."
# Look for: "database system is ready to accept connections"

# Step 6: Run data integrity checks
bash scripts/validate/smoke-tests.sh
```

### 3.3 Qdrant Restore

```bash
# Step 1: List available snapshots
kubectl exec -n securerag-hub deploy/qdrant -- \
  curl -s http://localhost:6333/snapshots

# Step 2: Download snapshot from MinIO backup
mc cp minio/securerag-backups/qdrant/documents-20260618-020000.snapshot \
  /tmp/documents-restore.snapshot

# Step 3: Upload snapshot to Qdrant
kubectl cp /tmp/documents-restore.snapshot \
  securerag-hub/$(kubectl get pod -n securerag-hub -l app=qdrant -o name | head -1):/snapshots/

# Step 4: Recover from snapshot
kubectl exec -n securerag-hub deploy/qdrant -- \
  curl -X POST http://localhost:6333/collections/documents/snapshots/recover \
  -H 'Content-Type: application/json' \
  -d '{"location": "/snapshots/documents-restore.snapshot"}'

# Step 5: Verify collection state
kubectl exec -n securerag-hub deploy/qdrant -- \
  curl -s http://localhost:6333/collections/documents | jq '.result.points_count'
```

### 3.4 ArgoCD Restore

```bash
# Scenario: Complete ArgoCD loss
# Step 1: Install ArgoCD on target cluster
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.11.0/manifests/install.yaml
kubectl rollout status deploy/argocd-server -n argocd --timeout=300s

# Step 2: Restore ArgoCD CRDs from Velero backup
velero restore create --from-backup argo-cd-20260618-020000 \
  --include-resources applications.applicationsets.appprojects

# Step 3: Or re-apply from Git (source of truth)
kubectl apply -k infra/k8s/argocd/

# Step 4: Re-configure repo credentials
argocd repo add https://github.com/YassinoMed/MasterPFE.git \
  --ssh-private-key-path /path/to/key

# Step 5: Sync all applications
argocd app sync -l app.kubernetes.io/part-of=securerag-hub
```

### 3.5 Emergency Restore — Minimal Services

```bash
# If full restore is not feasible, restore critical services only:

# Phase 1: Core infrastructure (5 minutes)
argocd app sync securerag-postgresql --async
argocd app sync securerag-ingress --async

# Phase 2: Authentication (10 minutes)
argocd app sync securerag-auth-users --async

# Phase 3: User-facing services (15 minutes)
argocd app sync securerag-portal-web --async

# Phase 4: Secondary services (30 minutes)
argocd app sync securerag-chatbot-manager --async
argocd app sync securerag-conversation-service --async
argocd app sync securerag-audit-security --async

# Phase 5: Monitoring (after primary services recovered)
argocd app sync securerag-prometheus --async
argocd app sync securerag-grafana --async
```

---

## 4. DR Drill Schedule

### 4.1 Annual DR Drill Calendar

| Month | Drill Type | Scope | Duration | Participants |
|-------|-----------|-------|:--------:|-------------|
| January | Quarterly full DR | Full cross-region failover | 4 hours | SRE, Platform, Security |
| February | Monthly backup validation | PostgreSQL PITR | 2 hours | SRE on-call |
| March | Monthly backup validation | Velero restore | 2 hours | SRE on-call |
| April | Quarterly full DR | Data corruption + restore | 4 hours | SRE, Platform, Security |
| May | Monthly backup validation | Qdrant snapshot restore | 2 hours | SRE on-call |
| June | Monthly backup validation | Full cluster restore | 3 hours | SRE on-call |
| July | Quarterly full DR | Region outage + DR activation | 4 hours | SRE, Platform, Security |
| August | Monthly backup validation | PostgreSQL PITR | 2 hours | SRE on-call |
| September | Monthly backup validation | MinIO metadata restore | 2 hours | SRE on-call |
| October | Quarterly full DR | Ransomware scenario | 4 hours | SRE, Platform, Security |
| November | Monthly backup validation | ArgoCD restore | 2 hours | SRE on-call |
| December | Annual DR review | DR plan review + update | 2 hours | All teams |

### 4.2 Monthly Backup Validation Procedure

```bash
# Step 1: Select the most recent backup
BACKUP_NAME=$(velero get backups -o json | jq -r '.items[-1].metadata.name')
echo "Validating: ${BACKUP_NAME}"

# Step 2: Restore to isolated namespace
velero restore create --from-backup ${BACKUP_NAME} \
  --namespace-mappings securerag-hub:securerag-dr-test \
  --restore-volumes=true

# Step 3: Wait for restore completion
velero restore get | grep "${BACKUP_NAME}"
velero restore logs "${BACKUP_NAME}-xxxxx" --tail=10

# Step 4: Verify critical resources
kubectl get pods -n securerag-dr-test
kubectl get deployments -n securerag-dr-test
kubectl get pvc -n securerag-dr-test

# Step 5: Cleanup
velero delete restore "${BACKUP_NAME}-xxxxx"
kubectl delete namespace securerag-dr-test

# Step 6: Document results
echo "## Backup Validation: $(date -u)" >> artifacts/dr/backup-validation-$(date +%Y%m).md
echo "- Backup: ${BACKUP_NAME}" >> artifacts/dr/backup-validation-$(date +%Y%m).md
echo "- Status: PASS" >> artifacts/dr/backup-validation-$(date +%Y%m).md
echo "- Duration: ${DURATION}" >> artifacts/dr/backup-validation-$(date +%Y%m).md
```

### 4.3 Quarterly Full DR Drill Procedure

```
Phase 1 — Preparation (Day -7 to Day -1):
  □  Schedule DR drill with all participants
  □  Verify backup integrity (last 7 days)
  □  Pre-stage DR cluster resources
  □  Communication template prepared
  □  Rollback plan reviewed

Phase 2 — Execution (Day 0, Hour 0-4):
  □  Declare DR drill start
  □  Simulate disaster scenario (e.g., region outage)
  □  Activate DR cluster
  □  Initiate Velero restore
  □  Verify service restoration
  □  Measure RTO and RPO

Phase 3 — Validation (Day 0, Hour 4-6):
  □  Run full smoke test suite
  □  Run security validation
  □  Verify data integrity
  □  Run performance baseline comparison

Phase 4 — Cleanup and Review (Day +1 to +5):
  □  Decommission DR cluster (if persistent is not needed)
  □  Restore production traffic to primary
  □  Document drill results
  □  Post-drill review meeting
  □  Update DR plan with lessons learned
```

---

## 5. Cross-Region Failover Procedure

### 5.1 Failover Decision Matrix

| Condition | Decision |
|-----------|----------|
| Production cluster unreachable > 5 min | Initiate failover |
| Data corruption detected > 10% of records | Initiate failover |
| Ransomware confirmed | Initiate failover (clean restore) |
| Planned maintenance (upgrade) | Pre-planned failover |
| Single service degraded | Do not failover |
| Latency spike < 30 min | Do not failover |

### 5.2 Failover Procedure

```bash
# ──────────────────────────────────────────────────────
# PRODUCTION → DR FAILOVER
# ──────────────────────────────────────────────────────

# Step 1: Verify DR cluster readiness
kubectl config use-context dr-cluster
kubectl get nodes
kubectl get pods -n securerag-hub

# Step 2: Point DNS to DR cluster ingress
# Update DNS record: app.securerag-hub.com → DR ingress IP
# TTL should be set to 60s for fast failover

# Step 3: Restore latest production backup to DR
velero restore create --from-backup securerag-hub-latest \
  --restore-volumes=true

# Step 4: Verify PostgreSQL replication lag
kubectl exec -n securerag-hub deploy/postgres -- \
  psql -c "SELECT now() - pg_last_xact_replay_timestamp() AS replication_lag;"

# Step 5: Promote PostgreSQL to primary if needed
kubectl exec -n securerag-hub deploy/postgres -- \
  pgbackrest --stanza=securerag-hub --type=immediate restore

# Step 6: Verify all services are healthy
kubectl wait --for=condition=available --timeout=300s \
  -n securerag-hub deployment/portal-web
kubectl wait --for=condition=available --timeout=300s \
  -n securerag-hub deployment/auth-users-service

# Step 7: Run smoke tests
bash scripts/validate/smoke-tests.sh
bash scripts/validate/security-smoke.sh

# Step 8: Update status page
# "Production cluster failover to DR region complete"

# Step 9: Monitor for 30 minutes
# Watch error rates, latency, and resource usage
```

### 5.3 Failback Procedure

```bash
# ──────────────────────────────────────────────────────
# DR → PRODUCTION FAILBACK (after primary restored)
# ──────────────────────────────────────────────────────

# Step 1: Restore primary cluster infrastructure
kubectl config use-context production-cluster
kubectl apply -k infra/k8s/base/

# Step 2: Copy DR data back to production
velero restore create --from-backup dr-securerag-hub-latest \
  --restore-volumes=true

# Step 3: Verify data sync
# Compare row counts between DR and production databases

# Step 4: Switch DNS back to production
# Update DNS record: app.securerag-hub.com → production ingress IP

# Step 5: Verify production traffic flow
kubectl wait --for=condition=available --timeout=300s \
  -n securerag-hub deployment/portal-web

# Step 6: Run validation
bash scripts/validate/e2e-functional-flow.sh

# Step 7: Confirm failback complete
# "Traffic restored to production cluster"
```

---

## 6. Data Integrity Validation

### 6.1 Post-Restore Validation Checks

| Check | Command | Expected Result |
|-------|---------|-----------------|
| **Row counts** | `SELECT COUNT(*) FROM key_tables` | Matches pre-backup baseline |
| **Latest records** | `SELECT MAX(created_at) FROM key_tables` | Within RPO window |
| **Foreign keys** | `SELECT * FROM check_foreign_keys()` | 0 violations |
| **Checksums** | `pg_checksum_table('table_name')` | Matches backup manifest |
| **Index validation** | `REINDEX (VERBOSE) DATABASE securerag` | 0 errors |
| **Application health** | `curl -f http://portal-web/securerag-hub/health` | HTTP 200 |
| **Audit continuity** | `SELECT COUNT(*) FROM audit_logs WHERE created_at > restore_time` | Count matches expected |

### 6.2 Automated Validation Script

```bash
#!/bin/bash
# scripts/validate/data-integrity.sh
# Run after any database restore operation

set -euo pipefail
NAMESPACE="${NAMESPACE:-securerag-hub}"
DB_HOST="${DB_HOST:-postgres}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-securerag}"
REPORT_DIR="artifacts/dr/data-integrity"
mkdir -p "${REPORT_DIR}"

echo "# Data Integrity Validation Report" > "${REPORT_DIR}/report-$(date -u +%Y%m%dT%H%M%SZ).md"
echo "## Timestamp: $(date -u)" >> "${REPORT_DIR}/report-*.md"

# Check 1: Database connectivity
echo "### [1/6] Database Connectivity" >> "${REPORT_DIR}/report-*.md"
kubectl exec -n ${NAMESPACE} deploy/postgres -- \
  psql -h ${DB_HOST} -p ${DB_PORT} -U ${DB_USER} -c "SELECT 1 AS alive;" \
  && echo "✅ PASS" >> "${REPORT_DIR}/report-*.md" \
  || echo "❌ FAIL" >> "${REPORT_DIR}/report-*.md"

# Check 2: Row counts across critical tables
echo "### [2/6] Critical Table Row Counts" >> "${REPORT_DIR}/report-*.md"
for table in "users" "chatbots" "conversations" "messages" "audit_logs"; do
  COUNT=$(kubectl exec -n ${NAMESPACE} deploy/postgres -- \
    psql -U ${DB_USER} -d securerag -t -c "SELECT COUNT(*) FROM ${table};" | tr -d ' ')
  echo "- ${table}: ${COUNT} rows" >> "${REPORT_DIR}/report-*.md"
done

# Check 3: Application health endpoints
echo "### [3/6] Application Health" >> "${REPORT_DIR}/report-*.md"
for service in "portal-web" "auth-users" "chatbot-manager" "conversation-service" "audit-security"; do
  STATUS=$(kubectl exec -n ${NAMESPACE} deploy/${service} -- curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/health 2>/dev/null || echo "000")
  echo "- ${service}: HTTP ${STATUS}" >> "${REPORT_DIR}/report-*.md"
done

# Check 4: Qdrant collection status
echo "### [4/6] Qdrant Collections" >> "${REPORT_DIR}/report-*.md"
kubectl exec -n ${NAMESPACE} deploy/qdrant -- \
  curl -s http://localhost:6333/collections | jq '.result.collections[] | {name, points_count}' \
  >> "${REPORT_DIR}/report-*.md"

# Check 5: Backup manifest integrity
echo "### [5/6] Backup Manifest Verification" >> "${REPORT_DIR}/report-*.md"
velero backup describe --details \
  >> "${REPORT_DIR}/report-*.md" 2>&1

# Check 6: Audit log continuity
echo "### [6/6] Audit Log Continuity" >> "${REPORT_DIR}/report-*.md"
kubectl exec -n ${NAMESPACE} deploy/postgres -- \
  psql -U ${DB_USER} -d securerag -t -c \
  "SELECT COUNT(*) FROM audit_logs WHERE created_at > NOW() - INTERVAL '1 hour';" \
  >> "${REPORT_DIR}/report-*.md"

echo "---" >> "${REPORT_DIR}/report-*.md"
echo "Validation Complete: $(date -u)" >> "${REPORT_DIR}/report-*.md"
```

---

## 7. Communication Plan During DR

### 7.1 Communication Flow

```
DR Incident Declared
       │
       ▼
┌─────────────────┐     ┌─────────────────┐
│  Incident       │────>│  SRE Team       │
│  Commander (IC) │     │  (on-call)      │
└────────┬────────┘     └─────────────────┘
         │
    ┌────┴────┐
    ▼         ▼
┌────────┐ ┌────────┐
│ Status │ │ Tech   │
│ Page   │ │ Lead   │
└────────┘ └────────┘
    │         │
    ▼         ▼
┌────────┐ ┌────────┐
│ Stake  │ │ Eng    │
│holders │ │ Team   │
└────────┘ └────────┘
```

### 7.2 Communication Templates

#### DR Drill Declaration

```
Subject: [DR DRILL] SecureRAG Hub — Disaster Recovery Drill Initiated
To: engineering@securerag-hub.com
Priority: HIGH

A disaster recovery drill has been initiated.

Scenario: [SCENARIO — e.g., Region Outage]
Start Time: [UTC TIMESTAMP]
Expected Duration: [DURATION]
Incident Commander: [NAME]
Communication Channel: #incidents-drill

Services Impacted:
  - All production services (in drill namespace)

User Impact:
  - None (drill runs in isolated environment)

Next Update: [TIME + 30 minutes]

Regards,
SecureRAG Hub SRE Team
```

#### DR Activation (Real Incident)

```
Subject: [INCIDENT] SecureRAG Hub — Disaster Recovery Activation — SEV1
To: engineering@securerag-hub.com, management@securerag-hub.com
Priority: URGENT

A disaster recovery procedure has been ACTIVATED.

Trigger: [TRIGGER — e.g., Production cluster unreachable for 10 minutes]
Activation Time: [UTC TIMESTAMP]
Estimated RTO: [DURATION]
Incident Commander: [NAME]
Technical Lead: [NAME]

Current Status:
  - [STATUS — e.g., Failover to DR cluster in progress]
  - [STATUS — e.g., DNS propagation initiated]

User Impact:
  - [IMPACT — e.g., Service unavailable during failover]
  - [IMPACT — e.g., Chat history may not include last 10 minutes]

Next Update: [TIME + 15 minutes]

Regards,
SecureRAG Hub Incident Response Team
```

#### Recovery Confirmation

```
Subject: [RESOLVED] SecureRAG Hub — Disaster Recovery Complete
To: engineering@securerag-hub.com, management@securerag-hub.com
Priority: NORMAL

Disaster recovery procedure has been COMPLETED.

Recovery Time: [UTC TIMESTAMP]
Total Duration: [DURATION]
Actual RTO: [RTO]
Actual RPO: [RPO]

Recovery Actions:
  - [ACTION — e.g., DR cluster activated]
  - [ACTION — e.g., All services verified healthy]

Post-Recovery Actions:
  - [ACTION — e.g., Monitoring period of 60 minutes]
  - [ACTION — e.g., Postmortem scheduled]
  - [ACTION — e.g., Failback plan to be executed]

Regards,
SecureRAG Hub Incident Response Team
```

### 7.3 Stakeholder Notification Matrix

| Stakeholder | Notification Method | Timing | Information |
|-------------|-------------------|:------:|-------------|
| **SRE Team** | PagerDuty + Slack | Immediate | Technical details |
| **Engineering Team** | Slack (#incidents) | < 5 min | Technical summary |
| **Engineering Management** | Email + Slack | < 15 min | Status, impact, ETA |
| **Executive Team** | Email | < 30 min | Business impact, RTO |
| **End Users** | Status page | < 15 min | Service status |
| **Security Team** | Slack (#security) | < 5 min (if security-related) | Incident details |
| **Compliance Team** | Email | < 1 hour (if data-related) | Data integrity status |

---

## 8. DR Checklist

### 8.1 Preparation Phase

```
□  DR plan reviewed and up to date
□  Backup integrity verified (last 7 days)
□  DR cluster resources available
□  Access credentials for DR cluster verified
□  kubectl contexts configured for all clusters
□  Velero configured with correct storage location
□  DNS provider credentials available
□  Status page credentials available
□  Communication templates prepared
□  Runbooks printed or accessible offline
□  Escalation contacts verified
□  Team members assigned to DR roles
□  Rollback plan reviewed
□  Baseline metrics recorded
```

### 8.2 Activation Phase

```
□  DR incident declared
□  Incident Commander appointed
□  Communication initiated (status page, Slack, email)
□  DR cluster readiness verified
□  DR cluster network connectivity confirmed
□  Latest backup identified and verified
□  Velero restore initiated
□  PostgreSQL replication lag checked
□  DNS failover initiated (if needed)
□  Service health monitored
□  Phase 1 complete — Core services verified
□  Phase 2 complete — All services verified
□  Full validation suite executed
□  Status updated to stakeholders
```

### 8.3 Recovery Verification Phase

```
□  All services HTTP 200 on /health endpoints
□  Database connectivity confirmed
□  Database row counts match baseline
□  Qdrant collection counts verified
□  Authentication flow works (login/register)
□  Chat flow works (question → answer)
□  Audit logging functional
□  WebSocket connections established
□  Metrics flowing to Prometheus
□  Logs flowing to Loki
□  Alerts configured and active
□  Backup schedule re-established
□  Monitoring period (30 min) completed
□  Status page updated to "Operational"
```

### 8.4 Post-Recovery Phase

```
□  Postmortem scheduled (within 48h for SEV1)
□  Root cause analysis initiated
□  Action items created and assigned
□  Failback plan (if applicable)
□  Production cluster recovery (if applicable)
□  Data reconciliation (ensure DR = production)
□  DR plan updated with lessons learned
□  Backup validation post-recovery
□  Team debrief completed
□  Incident report archived
```

---

## 9. Past Drill Results and Lessons Learned

### 9.1 Drill History

| Date | Drill Type | Scenario | RTO Achieved | RPO Achieved | Result | Key Lesson |
|------|-----------|----------|:----------:|:---------:|:------:|------------|
| 2026-03-15 | Monthly validation | PostgreSQL PITR | 8 min | 5 min | PASS | WAL archive must be co-located with backup |
| 2026-02-01 | Quarterly full DR | Cross-region failover | 22 min | 12 min | PASS | DNS propagation adds 3-5 min to RTO |
| 2026-01-10 | Monthly validation | Velero restore | 12 min | < 1 min | PASS | PVC restores slower than expected; tune restic |
| 2025-12-05 | Monthly validation | PostgreSQL PITR | 15 min | < 1 min | PASS | Need to document PITR target time format |
| 2025-11-01 | Quarterly full DR | Full cluster loss | 45 min | 30 min | CONDITIONAL | ArgoCD reconfiguration took longer than expected |
| 2025-10-08 | Monthly validation | Qdrant restore | 5 min | < 1 min | PASS | Snapshot restore is fast; automate the process |

### 9.2 Lessons Learned and Action Items

| # | Lesson Learned | Action Item | Owner | Deadline | Status |
|---|---------------|-------------|-------|----------|--------|
| 1 | DNS propagation is the bottleneck in cross-region failover | Implement traffic management with weighted DNS and health checks | Platform Team | 2026-Q2 | 🔴 Overdue |
| 2 | ArgoCD reconfiguration requires documented bootstrap script | Create one-command ArgoCD bootstrap for DR | SRE Team | 2026-Q1 | 🟢 Closed |
| 3 | PVC restores are slower than expected | Test restic performance tuning options | SRE Team | 2026-Q1 | 🟢 Closed |
| 4 | Team was unclear on DR role assignments | Create DR role cards (like incident response cards) | SRE Lead | 2026-Q2 | 🟡 In Progress |
| 5 | Communication templates needed updating | Review and update quarterly | SRE Team | Ongoing | 🟢 Closed |
| 6 | PITR target time format caused confusion | Add documentation with examples to DR guide | SRE Team | 2026-Q1 | 🟢 Closed |
| 7 | Backup storage location was not accessible from DR cluster | Verify cross-cluster storage access during monthly validation | SRE Team | 2026-Q1 | 🟢 Closed |
| 8 | Team fatigue after 4-hour drill | Schedule drills with breaks; max 3 hours active | SRE Lead | 2026-Q2 | 🟡 In Progress |

### 9.3 Metrics Improvement Over Time

```
RTO Trend (target: < 15 min):
  Q4 2025: 45 min (conditionally passed)
  Q1 2026: 22 min (passed)
  Q2 2026: target < 15 min

RPO Trend (target: < 1 hour):
  Q4 2025: 30 min (passed)
  Q1 2026: 12 min (passed)
  Q2 2026: target < 5 min

Backup Validation Success Rate:
  2025: 85% (11/13 drills passed)
  2026: 100% (5/5 drills passed to date)

Average Recovery Time (all drill types):
  2025: 28 min
  2026: 15 min (to date)
```

---

## References

- [Data Resilience Runbook](runbooks/data-resilience.md)
- [GitOps Workflow](gitops-workflow.md)
- [Operations Guide](OPERATIONS_GUIDE.md)
- [SRE Guide](SRE_GUIDE.md)
- [Backup and DR Scripts](../scripts/dr/)
- [Velero Configuration](../infra/k8s/velero/)

---

*Document maintained by the SRE team. For questions, contact #sre-team on Slack.*
