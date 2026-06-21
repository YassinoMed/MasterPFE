# PostgreSQL HA — CloudNativePG

## Architecture
- **Opérateur** : CloudNativePG (recommandé) ou Patroni
- **Réplication** : Streaming replication synchrone
- **Failover** : Automatique (< 30s)
- **PITR** : WAL archiving + base backups
- **Backup** : Barman ou pgBackRest (complète Velero)

## Feature Flag
`ENABLE_POSTGRESQL_HA=false` (défaut)

## Installation
```bash
kubectl apply -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.24/releases/cnpg-1.24.0.yaml
kubectl apply -f infra/k8s/postgresql-ha/
```

## Cluster PostgreSQL HA
```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: securerag-postgres-ha
  namespace: securerag-hub
spec:
  instances: 3
  storage:
    size: 20Gi
  bootstrap:
    initdb:
      database: securerag
      owner: securerag
  backup:
    barmanObjectStore:
      destinationPath: s3://securerag-backups/
```

## Validation
```bash
kubectl get cluster -n securerag-hub
kubectl get pods -n securerag-hub -l cnpg.io/cluster=securerag-postgres-ha

# Test failover : supprimer le pod primaire
kubectl delete pod securerag-postgres-ha-1 -n securerag-hub
# Observer la promotion automatique
kubectl get pods -n securerag-hub -l cnpg.io/cluster=securerag-postgres-ha -w
```

## RTO/RPO
| Scénario | RTO | RPO |
|----------|:---:|:---:|
| Pod primaire down | < 30s | 0 (synchrone) |
| Nœud complet down | < 60s | < 5s |
| Restauration PITR | < 15 min | Point-in-time |

## Rollback
```bash
kubectl delete cluster securerag-postgres-ha -n securerag-hub
kubectl delete -f infra/k8s/postgresql-ha/
# Restaurer le Deployment postgres-auth original
kubectl apply -k infra/k8s/base/postgres-auth
```

## Risques
| Risque | Probabilité | Impact | Mitigation |
|--------|:----------:|:------:|------------|
| Split-brain | Faible | Critique | Pas de multi-master |
| Corruption WAL | Faible | Élevé | PITR + backups |
| PVC indisponible | Faible | Élevé | StorageClass répliquée |
