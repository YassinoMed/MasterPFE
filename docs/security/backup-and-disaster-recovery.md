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
