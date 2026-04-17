# Data Resilience Runbook - SecureRAG Hub

## Objectif

Sortir SecureRAG Hub d'un stockage local fragile pour les usages production, sans casser le mode `demo` qui reste compatible SQLite local.

## Etat actuel

| Element | Etat | Lecture |
|---|---:|---|
| Mode demo SQLite | TERMINÉ | Suffisant pour soutenance et execution locale |
| Images Laravel avec `pdo_mysql` / `pdo_pgsql` | TERMINÉ | Les images peuvent parler a MySQL ou PostgreSQL apres rebuild |
| Externalisation DB production | PRÊT_NON_EXÉCUTÉ | Necessite endpoint, secret et migration runtime |
| Backup / restore runtime | DÉPENDANT_DE_L_ENVIRONNEMENT | Necessite DB cible, credentials et cluster actif |

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

Exemple de secret a creer hors Git :

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

## Backup

Action mutative externe : lit la base cible et produit un dump.

PostgreSQL :

```bash
PGPASSWORD='<password>' pg_dump \
  --host='<postgres-host>' \
  --port=5432 \
  --username='<user>' \
  --dbname='<database>' \
  --format=custom \
  --file="artifacts/backup/<service>-$(date -u +%Y%m%dT%H%M%SZ).dump"
shasum -a 256 artifacts/backup/*.dump > artifacts/backup/checksums.txt
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

PostgreSQL :

```bash
createdb '<restore_database>'
PGPASSWORD='<password>' pg_restore \
  --host='<postgres-host>' \
  --port=5432 \
  --username='<user>' \
  --dbname='<restore_database>' \
  --clean \
  --if-exists \
  artifacts/backup/<service>.dump
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

- Tant que l'overlay production rendu contient `DB_CONNECTION=sqlite`, la resilience donnees reste `PARTIEL`.
- Le passage a une base externe ne doit etre declare `TERMINÉ` qu'apres preuve de migration, backup et restore.
- Le mode `demo` reste volontairement simple et ne doit pas etre confondu avec la strategie production.
