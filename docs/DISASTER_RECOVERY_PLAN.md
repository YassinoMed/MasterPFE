# Disaster Recovery Plan (SecureRAG Hub)

Ce document décrit la procédure formelle de reprise d'activité (Disaster Recovery) en cas de perte partielle ou totale du cluster Kubernetes `securerag-hub`.

## 1. Récupération des Sauvegardes
Toutes les sauvegardes critiques sont expédiées sur un bucket S3 externe (ex: `securerag-backups`). 
Elles sont chiffrées symétriquement avec GPG en utilisant la variable `ENCRYPTION_PASSWORD`.

Pour initier une restauration, vous devez d'abord télécharger et déchiffrer les archives depuis un poste sécurisé :
```bash
# Téléchargement
aws s3 cp s3://securerag-backups/etcd/etcd-snapshot-LATEST.db.gpg .

# Déchiffrement
gpg --decrypt etcd-snapshot-LATEST.db.gpg > etcd-snapshot.db
```

## 2. Restauration du "Cerveau" (etcd)
Si le cluster Kubernetes est détruit, la première étape consiste à restaurer l'état du Control Plane via `etcd`.
1. Transférez le fichier `etcd-snapshot.db` sur le nouveau nœud master.
2. Arrêtez le composant etcd et l'apiserver.
3. Exécutez la restauration :
   ```bash
   etcdctl snapshot restore etcd-snapshot.db \
     --data-dir /var/lib/etcd-restored
   ```
4. Pointez la configuration Kubelet/etcd vers le nouveau dossier `/var/lib/etcd-restored` et redémarrez les services.

## 3. Restauration de HashiCorp Vault
Vault stocke les secrets critiques. Sa perte entraîne le blocage des microservices.
1. Vault doit être redéployé (via l'opérateur ou Helm) et initialisé, ou en attente (unsealed).
2. Transférez le snapshot Vault déchiffré (`vault-snapshot.snap`) vers le pod `vault-0`.
3. Exécutez la restauration Raft :
   ```bash
   vault operator raft snapshot restore vault-snapshot.snap
   ```
4. Effectuez la procédure de `unseal` avec vos clés de récupération Vault existantes.

## 4. Restauration du Moteur GitOps (ArgoCD)
ArgoCD maintient l'état des déploiements.
1. Réinstallez ArgoCD via les manifests d'amorçage.
2. Appliquez le snapshot exporté (préalablement déchiffré) :
   ```bash
   argocd admin import < argocd-export.yaml
   ```
3. ArgoCD reprendra instantanément la synchronisation GitOps avec les dépôts distants.

## 5. Restauration des Données Applicatives (PostgreSQL & Volumes via Velero)
1. **Velero** : Une fois le cluster remonté, reconnectez Velero au bucket S3.
   ```bash
   velero restore create --from-schedule securerag-daily-full
   ```
2. **PostgreSQL** : Si une base de données spécifique est corrompue, utilisez l'archive `securerag-*.dump` générée par le cronjob `pg-backup` :
   ```bash
   pg_restore --clean --dbname=auth_users securerag-auth_users-LATEST.dump
   ```

> [!WARNING]
> **Sécurité de la clé GPG** : Le Disaster Recovery Plan est inutile si la clé de déchiffrement (`ENCRYPTION_PASSWORD`) est perdue en même temps que le cluster. Elle **doit** être stockée offline de manière sécurisée (ex: coffre physique, KeePass d'entreprise, solution PAM externe).
