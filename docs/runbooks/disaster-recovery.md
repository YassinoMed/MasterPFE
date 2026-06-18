# Disaster Recovery Runbook — SecureRAG Hub

> **Scope:** Recovery procedures for catastrophic failures affecting the SecureRAG Hub platform.
> **RTO (Recovery Time Objective):** 4 hours for critical services.
> **RPO (Recovery Point Objective):** 1 hour for critical data.

---

## 1. Cluster Failure

### RTO / RPO Targets

| Service | RTO | RPO |
|---------|-----|-----|
| Auth Service | 1h | 15min |
| Portal Web | 2h | N/A (stateless) |
| Chatbot API | 2h | N/A (stateless) |
| PostgreSQL | 4h | 1h |
| Redis Cache | 4h | 1h |

### Symptoms
- `kubectl cluster-info` returns connection failure
- All Kubernetes API calls timeout
- Nodes unreachable via SSH
- Complete loss of cluster management capabilities

### Pre-Recovery Checks

```bash
# Confirm cluster state
kubectl cluster-info 2>&1 || echo "Cluster unreachable"

# Check if kubeconfig is valid
kubectl config view --minify

# Verify infrastructure provider status (if cloud)
# Check cloud console for node/control plane health
```

### Step-by-Step Recovery

#### Phase 1: Assess & Decide (RTO: 30 min)

1. [ ] Determine if cluster is recoverable (control plane intact?)
2. [ ] If control plane failed: attempt control plane restoration
3. [ ] If total loss: proceed to rebuild from backups
4. [ ] Notify stakeholders of estimated RTO

#### Phase 2: Rebuild Control Plane (RTO: 1h)

```bash
# Option A: If using kind
kind delete cluster --name securerag
kind create cluster --config infra/kind/config.yaml

# Option B: If cloud-managed
# Re-provision using your IaC tool
terraform apply -target=module.eks -auto-approve

# Verify control plane
kubectl cluster-info
kubectl get nodes
```

#### Phase 3: Restore Workloads (RTO: 2h)

```bash
# Apply platform base components
kubectl apply -f infra/k8s/namespaces/
kubectl apply -f infra/k8s/rbac/

# Restore observability stack
kubectl apply -f infra/k8s/observability/

# Restore storage infrastructure
kubectl apply -f infra/k8s/storage/

# Restore application workloads
kubectl apply -f k8s/securerag-hub/

# Restore network policies
kubectl apply -f infra/k8s/network-policies/
```

#### Phase 4: Restore Data (RTO: 4h)

See *Backup Restoration Procedure* below.

#### Phase 5: Verify Recovery

```bash
# Run validation suite
bash scripts/validate/generate-final-validation-summary.sh

# Verify all services health
kubectl get pods -n securerag-hub
kubectl get svc -n securerag-hub

# Test critical endpoints
curl -f http://portal-web.securerag-hub.svc.cluster.local:8080/health
curl -f http://auth-service.securerag-hub.svc.cluster.local:8080/health
```

---

## 2. Regional Outage

### Symptoms
- All nodes in a region/availability zone become unavailable
- Cloud provider status page shows region degradation
- Persistent volume claims stuck in `Pending`
- Cross-region replication fails

### Pre-Recovery Checks

```bash
# Check node status across regions
kubectl get nodes -o wide --all-contexts

# Check PV status
kubectl get pv -o wide

# Verify DNS resolution for multi-region endpoints
nslookup api.securerag.io
```

### Step-by-Step Recovery

#### Phase 1: Failover (RTO: 30 min)

1. [ ] Confirm primary region is unavailable
2. [ ] Activate DNS failover to secondary region
3. [ ] Verify secondary region cluster is operational
4. [ ] Check data replication lag

#### Phase 2: Route Traffic (RTO: 1h)

```bash
# Update DNS records to point to secondary region
# Example: Route53 failover
aws route53 change-resource-record-sets --hosted-zone-id ZONE_ID \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "api.securerag.io",
        "Type": "A",
        "SetIdentifier": "secondary",
        "Failover": "PRIMARY",
        "AliasTarget": {
          "HostedZoneId": "SECONDARY_LB_ZONE",
          "DNSName": "secondary-lb.elb.amazonaws.com",
          "EvaluateTargetHealth": true
        }
      }
    }]
  }'

# Verify traffic routing
curl -I https://api.securerag.io
```

#### Phase 3: Scale Secondary (RTO: 2h)

```bash
# Scale services in secondary region
kubectl scale deploy/portal-web --replicas=3 -n securerag-hub
kubectl scale deploy/auth-service --replicas=3 -n securerag-hub
kubectl scale deploy/chatbot --replicas=3 -n securerag-hub

# Verify capacity
kubectl top pods -n securerag-hub
```

#### Phase 4: Restore Primary (RTO: 4h+)

1. Wait for primary region restoration
2. Re-sync data from secondary to primary
3. Fail back DNS when primary is verified healthy
4. Monitor for data consistency

---

## 3. Data Corruption

### Symptoms
- Application returns incorrect, inconsistent, or garbled data
- Database consistency check failures
- Checksum/validation errors on stored data
- Users report missing or corrupted records

### Pre-Recovery Checks

```bash
# Identify scope of corruption
kubectl logs -n securerag-hub -l app.kubernetes.io/name=database --tail=500 | \
  grep -iE "corruption|checksum|invalid page|WAL"

# Check database integrity
kubectl exec <db-pod> -n securerag-hub -- psql -U <user> -d <db> -c \
  "SELECT schemaname, tablename, n_live_tup, n_dead_tup FROM pg_stat_user_tables;"

# Run pgAdmin check (if available)
kubectl exec <db-pod> -n securerag-hub -- pg_checksums -c -D /var/lib/postgresql/data 2>&1
```

### Step-by-Step Recovery

#### Phase 1: Containment (RTO: 15 min)

1. [ ] **STOP ALL WRITE OPERATIONS** to affected database
2. [ ] Scale down application deployments: `kubectl scale deploy --all --replicas=0 -n securerag-hub`
3. [ ] Enable read-only mode on database if supported
4. [ ] Snapshot current corrupted state for investigation

#### Phase 2: Assessment (RTO: 1h)

```bash
# Identify last known good backup
ls -la artifacts/backups/database/
cat artifacts/backups/backup-manifest.json

# Check WAL archive status
kubectl exec <db-pod> -n securerag-hub -- ls -la /var/lib/postgresql/data/pg_wal/

# Determine PITR target time (last known good state)
echo "Last known good: 2025-01-01 14:30:00 UTC"
echo "Corruption detected: 2025-01-01 15:45:00 UTC"
```

#### Phase 3: Restore from Backup (RTO: 2h)

```bash
# Option A: Full restore from latest backup
bash scripts/data/restore-postgres.sh \
  --backup-file artifacts/backups/database/securerag-hub-latest.sql.gz \
  --target-namespace securerag-hub

# Option B: Point-in-Time Recovery (PITR)
# Requires WAL archive and base backup
PITR_TARGET="2025-01-01 14:30:00 UTC"
kubectl exec <db-pod> -n securerag-hub -- \
  pg_ctl stop -D /var/lib/postgresql/data
kubectl exec <db-pod> -n securerag-hub -- \
  pg_ctl start -D /var/lib/postgresql/data \
  -o "-r recovery.conf" \
  -o "-c recovery_target_time='${PITR_TARGET}'"
```

#### Phase 4: Verification (RTO: 3h)

```bash
# Data integrity check
kubectl exec <db-pod> -n securerag-hub -- \
  psql -U <user> -d <db> -c "SELECT count(*) FROM information_schema.tables;"

# Application smoke test
kubectl scale deploy/portal-web --replicas=1 -n securerag-hub
kubectl scale deploy/auth-service --replicas=1 -n securerag-hub

# Test critical queries
kubectl run verify-data --image=postgres:16-alpine -it --rm -- \
  psql -h <svc> -U <user> -d <db> -c "SELECT * FROM <critical-table> LIMIT 5;"
```

#### Phase 5: Restore Writes (RTO: 4h)

1. [ ] Scale application back to normal replicas
2. [ ] Re-enable write operations
3. [ ] Monitor for corruption recurrence
4. [ ] Initiate root cause investigation

---

## 4. Backup Restoration Procedure

### Available Backups

| Type | Location | Retention | Frequency |
|------|----------|-----------|-----------|
| Database SQL dump | `artifacts/backups/database/` | 7 days | Daily |
| Database WAL archive | `artifacts/backups/wal/` | 14 days | Continuous |
| Kubernetes manifests | Git repository | Full history | Per commit |
| Persistent volumes | Provider backup service | 30 days | Daily |

### Restoration Steps

#### Step 1: Select Backup

```bash
# List available database backups
ls -lh artifacts/backups/database/

# Check backup manifest
cat artifacts/backups/backup-manifest.json | jq .
```

#### Step 2: Deploy Recovery Instance

```bash
# Deploy temporary recovery database
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: database-restore
  namespace: securerag-hub
spec:
  replicas: 1
  selector:
    matchLabels:
      app: database-restore
  template:
    metadata:
      labels:
        app: database-restore
    spec:
      containers:
        - name: postgres
          image: postgres:16-alpine
          env:
            - name: POSTGRES_DB
              value: securerag_hub
            - name: POSTGRES_USER
              valueFrom:
                secretKeyRef:
                  name: database-credentials
                  key: username
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: database-credentials
                  key: password
          volumeMounts:
            - name: data
              mountPath: /var/lib/postgresql/data
      volumes:
        - name: data
          emptyDir: {}
EOF
```

#### Step 3: Restore Data

```bash
# Wait for recovery database to start
kubectl wait --for=condition=ready pod/database-restore-0 -n securerag-hub --timeout=120s

# Copy backup file into pod
kubectl cp artifacts/backups/database/securerag-hub-latest.sql.gz \
  database-restore-0:/tmp/restore.sql.gz -n securerag-hub

# Decompress and restore
kubectl exec database-restore-0 -n securerag-hub -- \
  bash -c "gunzip -c /tmp/restore.sql.gz | psql -U \${POSTGRES_USER} -d \${POSTGRES_DB}"

# Verify restoration
kubectl exec database-restore-0 -n securerag-hub -- \
  psql -U \${POSTGRES_USER} -d \${POSTGRES_DB} -c "SELECT count(*) FROM information_schema.tables;"
```

#### Step 4: Cut Over to Restored Data

```bash
# Option A: Swap service to recovery instance
kubectl patch svc database -n securerag-hub -p '{"spec":{"selector":{"app":"database-restore"}}}'

# Option B: Promote recovery to production
kubectl delete statefulset database -n securerag-hub
kubectl rename statefulset database-restore database -n securerag-hub
kubectl delete svc database -n securerag-hub
kubectl apply -k infra/k8s/database/
```

#### Step 5: Validate and Monitor

```bash
# Application connectivity test
kubectl run app-test --image=curlimages/curl:latest -it --rm -- \
  curl -f http://auth-service.securerag-hub.svc.cluster.local:8080/health

# Monitor for errors
kubectl logs -n securerag-hub -l app.kubernetes.io/name=database --tail=100 -f &

# Run validation suite
bash scripts/validate/generate-final-validation-summary.sh
```

---

## 5. Recovery Verification Checklist

After any DR scenario, complete all checks:

- [ ] All pods in `Running` or `Completed` state
- [ ] All services accessible internally
- [ ] Ingress/gateway health checks pass
- [ ] Database connectivity verified
- [ ] Application smoke tests pass
- [ ] Monitoring stack operational
- [ ] Alertmanager routing active
- [ ] Backup schedule resumed
- [ ] Incident postmortem initiated
- [ ] Action items tracked

---

## 6. DR Contact Tree

| Role | Contact | Backup Contact |
|------|---------|----------------|
| SRE Lead | `@sre-lead` | `@sre-oncall` |
| Engineering Manager | Phone | Email |
| Security Lead | `@security-lead` | `@devsecops-oncall` |
| VP Engineering | Phone | Email |
| CTO | Phone | Email |

---

## 7. Post-Recovery Actions

1. **Root cause investigation** — determine what caused the failure
2. **Runbook update** — document any gaps in recovery procedures
3. **DR drill schedule** — add quarterly test if not already scheduled
4. **Backup verification** — validate backup integrity and RPO compliance
5. **RTO/RPO review** — adjust targets based on actual recovery time
