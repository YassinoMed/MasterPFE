# Backup & Disaster Recovery — SecureRAG Hub

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    BACKUP & DR LAYER                          │
│                                                               │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐               │
│  │  Velero  │◄───│   MinIO  │    │  S3/GCS  │               │
│  │  Schedules│   │  Object  │    │  Remote  │               │
│  │          │    │  Store   │    │  Replica │               │
│  └────┬─────┘    └──────────┘    └──────────┘               │
│       │                                                      │
│       ▼                                                      │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Backup Schedules                                      │   │
│  │  ┌─────────────┐ ┌────────────┐ ┌──────────────┐    │   │
│  │  │ Daily       │ │ Weekly     │ │ Monthly      │    │   │
│  │  │ Apps+Config │ │ Vault      │ │ ArgoCD       │    │   │
│  │  │ TTL: 30d    │ │ TTL: 90d   │ │ TTL: 365d    │    │   │
│  │  └─────────────┘ └────────────┘ └──────────────┘    │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Jenkins Backup* (nightly)                            │   │
│  │  JENKINS_HOME → /tmp/jenkins-backup/*.tar.gz          │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
│  * Jenkins backup est un tar.gz local. Pour DR complet,       │
│    il doit être copié vers MinIO ou S3.                       │
└──────────────────────────────────────────────────────────────┘
```

## Déploiement

```bash
bash scripts/deploy/deploy-velero.sh
```

Ce script :
1. Déploie MinIO (namespace minio)
2. Installe Velero via Helm
3. Configure BackupStorageLocation → MinIO
4. Crée les schedules daily/weekly/monthly
5. Lance un backup initial

## Schedules

| Schedule | Fréquence | Rétention | Contenu |
|----------|:---------:|:---------:|---------|
| daily-securerag-backup | Quotidien 2h | 30 jours | Apps, Vault, Observabilité |
| weekly-vault-backup | Hebdo dimanche 3h | 90 jours | Vault uniquement |
| monthly-argocd-backup | Mensuel 1er 4h | 365 jours | ArgoCD uniquement |

## Tests

### Backup
```bash
bash scripts/dr/backup-test.sh
```

### Restore
```bash
bash scripts/dr/restore-test.sh <backup-name>
```

### Validation
```bash
bash scripts/dr/validate-restore.sh
```

### Pipeline
Le stage `CI: Backup Validation` (nightly) exécute automatiquement :
1. Validate des backups existants
2. Vérifie l'intégrité
3. Échoue si un backup est invalide

## Jenkins Backup

```bash
# Backup
bash scripts/jenkins/backup-jenkins.sh

# Restore
bash scripts/jenkins/restore-jenkins.sh /tmp/jenkins-backup/jenkins-backup-<date>.tar.gz
```

Le stage `CI: Jenkins Backup` (nightly) sauvegarde automatiquement JENKINS_HOME.

## Restauration complète (DR)

```bash
# 1. Restore Velero
velero restore create --from-backup <backup-name>

# 2. Restore Vault
kubectl exec -n vault vault-0 -- vault operator unseal <key1>
kubectl exec -n vault vault-0 -- vault operator unseal <key2>
kubectl exec -n vault vault-0 -- vault operator unseal <key3>

# 3. Restore Jenkins
bash scripts/jenkins/restore-jenkins.sh <backup-file>

# 4. Verify
bash scripts/dr/validate-restore.sh
```

---

## Immutable Backups (WORM Storage)

### Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    IMMUTABLE BACKUP LAYER                      │
│                                                               │
│  ┌──────────┐    ┌──────────────────┐    ┌───────────────┐  │
│  │  Velero  │───▶│   MinIO Object   │───▶│  WORM Lock    │  │
│  │ Schedule │    │   Lock Enabled   │    │  Compliance   │  │
│  │ imm-daily│    │   Bucket:        │    │  Retention    │  │
│  │          │    │   securerag-     │    │  30 days min  │  │
│  │          │    │   immutable-     │    │               │  │
│  │          │    │   backups        │    │               │  │
│  └──────────┘    └──────────────────┘    └───────────────┘  │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Object Lock Properties                               │   │
│  │  • Mode: COMPLIANCE (no override by any user)        │   │
│  │  • Retention: 30 days (configurable)                 │   │
│  │  • Versioning: Enabled                               │   │
│  │  • Access: ReadWrite (write-once, read-many)         │   │
│  └──────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
```

### WORM Storage Architecture

Immutable backups use **Write Once Read Many (WORM)** storage through MinIO Object Lock in Compliance mode. This ensures that backup data cannot be modified, deleted, or overwritten by any user (including root or cloud provider administrators) during the retention period.

| Property | Standard Backup | Immutable Backup |
|:---|:---|:---|
| **Object Lock** | Not enabled | Enabled (Compliance mode) |
| **Retention** | TTL-based (soft) | Hard lock (30 days minimum) |
| **Deletion** | Possible (with permissions) | Impossible until retention expires |
| **Versioning** | Optional | Required |
| **WORM Compliant** | No | Yes |
| **Regulatory Standard** | — | SEC 17a-4, FINRA, CFTC |

### Compliance Mode vs Governance Mode

MinIO Object Lock supports two retention modes:

| Aspect | Compliance Mode | Governance Mode |
|:---|:---|:---|
| **Lock Strength** | Absolute — no user can bypass | Bypassable by users with `s3:BypassGovernanceRetention` permission |
| **Deletion** | Denied for all users | Denied except users with bypass permission |
| **Retention Shortening** | Impossible | Possible with bypass permission |
| **Use Case** | Regulatory compliance (SEC, FINRA) | Internal data governance |
| **SecureRAG Hub** | ✅ Default mode | Not used |

### Retention Periods

| Policy | Retention | Mode | Rationale |
|:---|:---:|:---:|:---|
| **Immutable daily backup** | 30 days | Compliance | Regulatory minimum + operational recovery window |
| **Monthly snapshots** | 365 days (via standard backup) | Governance | Long-term archival with admin override |
| **Quarterly compliance** | 7 years | Compliance | SEC 17a-4 requirement |

### Velero Immutable Integration

The immutable backup schedule uses a dedicated `BackupStorageLocation` pointing to the MinIO bucket with Object Lock enabled.

#### Resources

| Resource | File | Description |
|:---|:---|:---|
| `BackupStorageLocation` | `infra/k8s/velero/immutable-backup-location.yaml` | MinIO bucket with Object Lock |
| `Schedule` | `infra/k8s/velero/immutable-schedule.yaml` | Daily immutable backup schedule |

#### BackupStorageLocation Configuration

```yaml
apiVersion: velero.io/v1
kind: BackupStorageLocation
metadata:
  name: immutable
  namespace: velero
spec:
  provider: aws
  objectStorage:
    bucket: securerag-immutable-backups
  config:
    region: minio-default
    s3ForcePathStyle: "true"
    s3Url: "http://minio.velero.svc:9000"
  accessMode: ReadWrite
  backupSyncInterval: 5m
  default: false
  tag: immutable
```

#### Schedule Configuration

```yaml
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: immutable-daily
  namespace: velero
spec:
  schedule: "0 2 * * *"
  template:
    includedNamespaces:
      - securerag-hub
      - vault
      - velero
    storageLocation: immutable
    ttl: 720h
    defaultVolumesToRestic: true
    uploaderConfig:
      writeSparseFiles: true
    snapshotVolumes: true
```

### Scripts

| Script | Purpose |
|:---|:---|
| `scripts/dr/immutable-backups.sh` | Configure MinIO Object Lock, create bucket, set retention, create Velero backup |
| `scripts/dr/validate-immutable.sh` | Validate WORM compliance — check lock, retention, deletion prevention |

### Usage

```bash
# 1. Configure immutable backups (create bucket, enable lock, set retention)
bash scripts/dr/immutable-backups.sh

# 2. Validate WORM compliance
bash scripts/dr/validate-immutable.sh

# 3. Validate with custom bucket name
bash scripts/dr/immutable-backups.sh --bucket securerag-immutable-backups --retention 30

# 4. Validate only (no backup creation)
bash scripts/dr/validate-immutable.sh --bucket securerag-immutable-backups

# 5. CI mode (exit non-zero on failure)
bash scripts/dr/immutable-backups.sh --ci
```

### Validation Procedures

The `validate-immutable.sh` script performs six checks:

1. **Object Lock Enabled** — Verifies the MinIO bucket has Object Lock enabled
2. **Retention Mode** — Confirms retention mode is COMPLIANCE (not Governance)
3. **Versioning Enabled** — Checks versioning is active on bucket
4. **Write Test** — Creates a test object to verify write access
5. **Read Test** — Reads the test object back and verifies content
6. **Deletion Prevention** — Attempts to delete a locked object (MUST be denied)

### WORM Compliance Test

```bash
# Run full validation
bash scripts/dr/validate-immutable.sh

# Expected output for deletion prevention test:
# ✅ [PASS] Deletion prevention: object locked in compliance mode — deletion denied
# ❌ [FAIL] Deletion prevention: object was deleted despite compliance lock! (if broken)
```

### Compliance Reporting

Reports are generated in `artifacts/dr/reports/`:

| Report | Description |
|:---|:---|
| `immutable-backups-report.md` | Immutable backup configuration and setup |
| `immutable-validation/immutable-validation-report.md` | WORM compliance validation |

### Regulatory Compliance

Immutable backups with MinIO Object Lock in Compliance mode satisfy:

| Regulation | Requirement | SecureRAG Compliance |
|:---|:---|---:|
| **SEC Rule 17a-4** | Electronic records non-erasable, non-rewritable | ✅ Compliance mode |
| **FINRA Rule 4511** | Retention of books and records | ✅ 30-day minimum retention |
| **CFTC Regulation 1.31** | Records retention in WORM format | ✅ Object Lock enabled |
| **GDPR Article 32** | Security of processing | ✅ Immutable audit trails |
| **SOC 2** | Protection of data | ✅ WORM storage |
| **PCI DSS** | Secure backup and recovery | ✅ Immutable backups |
