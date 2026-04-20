# Data Resilience Runbook - SecureRAG Hub

## Objectif

Sortir SecureRAG Hub d'un stockage local fragile pour les usages production, sans casser le mode `demo` qui reste compatible SQLite local.

## Etat actuel

| Element | Etat | Lecture |
|---|---:|---|
| Mode demo SQLite | TERMINÉ | Suffisant pour soutenance et execution locale |
| Images Laravel avec `pdo_mysql` / `pdo_pgsql` | TERMINÉ | Les images peuvent parler a MySQL ou PostgreSQL apres rebuild |
| Overlay production kind SQLite | PRÊT_NON_EXÉCUTÉ | Conserve SQLite pour ne pas casser la demo kind existante |
| Overlay `production-external-db` | TERMINÉ statique | Rend les workloads sans SQLite et avec `securerag-database-secrets` |
| Backup / restore runtime | PRÊT_NON_EXÉCUTÉ | Necessite DB cible, credentials et execution reelle |

## Strategie production recommandee

1. Utiliser une base externe par environnement, idealement PostgreSQL managé.
2. Utiliser un schema ou une base separee par service critique :
   - `portal_web`
   - `auth_users`
   - `chatbot_manager`
   - `conversation_service`
   - `audit_security`
3. Injecter les variables DB via un secret non versionne :
   - `DB_CONNECTION=pgsql`
   - `DB_HOST`
   - `DB_PORT=5432`
   - `DB_DATABASE`
   - `DB_USERNAME`
   - `DB_PASSWORD`
   - `DB_SSLMODE=require` si la cible le supporte
4. Executer les migrations avant exposition trafic.
5. Sauvegarder regulierement, archiver les checksums et tester la restauration.

## Variables attendues

Exemple de secret a creer hors Git avant `production-external-db` :

```bash
kubectl create secret generic securerag-database-secrets \
  -n securerag-hub \
  --from-literal=DB_CONNECTION=pgsql \
  --from-literal=DB_HOST='<postgres-host>' \
  --from-literal=DB_PORT='5432' \
  --from-literal=DB_USERNAME='<user>' \
  --from-literal=DB_PASSWORD='<password>' \
  --from-literal=DB_SSLMODE='require'
```

Deploiement avec DB externe :

```bash
KUSTOMIZE_OVERLAY=infra/k8s/overlays/production-external-db \
REGISTRY_HOST=localhost:5001 \
IMAGE_PREFIX=securerag-hub \
IMAGE_TAG=release-local \
IMAGE_DIGEST_FILE=artifacts/release/promotion-digests.txt \
REQUIRE_DIGEST_DEPLOY=true \
bash scripts/deploy/deploy-kind.sh
```

## Backup

Action mutative externe : lit la base cible et produit un dump.

PostgreSQL avec le script versionne :

```bash
SERVICE_NAME=portal-web \
DB_HOST='<postgres-host>' \
DB_PORT=5432 \
DB_USERNAME='<user>' \
DB_PASSWORD='<password>' \
DB_DATABASE='portal_web' \
DB_SSLMODE=require \
make data-backup
```

MySQL :

```bash
mysqldump \
  --host='<mysql-host>' \
  --port=3306 \
  --user='<user>' \
  --password='<password>' \
  '<database>' > "artifacts/backup/<service>-$(date -u +%Y%m%dT%H%M%SZ).sql"
shasum -a 256 artifacts/backup/*.sql > artifacts/backup/checksums.txt
```

## Restore

Action destructive si elle cible une base existante. Pour les tests, restaurer dans une base isolee.

PostgreSQL avec le script versionne :

```bash
BACKUP_FILE='artifacts/backup/portal-web-portal_web-<timestamp>.dump' \
DB_HOST='<postgres-host>' \
DB_PORT=5432 \
DB_USERNAME='<user>' \
DB_PASSWORD='<password>' \
DB_DATABASE='portal_web' \
RESTORE_DB_DATABASE='portal_web_restore_test' \
DB_SSLMODE=require \
make data-restore
```

MySQL :

```bash
mysql \
  --host='<mysql-host>' \
  --port=3306 \
  --user='<user>' \
  --password='<password>' \
  '<restore_database>' < artifacts/backup/<service>.sql
```

## Preuve minimale attendue

- dump backup present sous `artifacts/backup/` ;
- checksum SHA-256 ;
- base de restauration isolee creee ;
- migrations ou requetes de verification executees apres restore ;
- rapport `artifacts/security/production-data-resilience.md`.

## Limites honnetes

- L'overlay `production` garde SQLite volontairement pour la demonstration kind locale.
- L'overlay `production-external-db` est la trajectoire production-grade.
- Le passage a une base externe ne doit etre declare `TERMINÉ` qu'apres preuve de migration, backup et restore.
- Le mode `demo` reste volontairement simple et ne doit pas etre confondu avec la strategie production.
