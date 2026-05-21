# Runbook — Rotation des secrets SecureRAG Hub

> **Audience** : SRE / DevSecOps. **Périmètre** : tous les Secrets Kubernetes
> du namespace `securerag-hub` gérés via SOPS+age (ou ESO+Vault).

## Périodicité cible

| Type de secret | Période rotation | Trigger immédiat |
|----------------|-----------------:|------------------|
| Mot de passe DB applicatif | 90 j | Compromission, départ d'un opérateur ayant eu accès |
| API keys externes (LLM, OCR, Mailgun…) | 60 j | Idem |
| Cosign signing key | 365 j | Compromission **uniquement** (sinon stable) |
| age private keys (SOPS) | 365 j ou compromission | Compromission |
| Service-to-service tokens internes | 30 j (auto via JWT court) | N/A |
| Sanctum / API user tokens | 7 j max (court par design) | N/A |

## Pré-requis

- `sops` ≥ 3.8, `age` ≥ 1.1, `kubectl` access namespace cible
- Clé age privée actuelle (vérifier via `sops --decrypt` sur 1 fichier)
- Sur Jenkins : credential `sops-age-key` à jour ; sur cluster : Secret
  `sops-age` (namespace `argocd`) lisible par `argocd-vault-plugin`.

## Procédure standard (rotation d'un secret applicatif)

### 1. Générer la nouvelle valeur

```bash
NEW_DB_PASSWORD="$(openssl rand -base64 32 | tr -d '/+=' | cut -c1-32)"
echo "${NEW_DB_PASSWORD}" >/tmp/.new-pwd  # ne pas committer
```

### 2. Mettre à jour le secret SOPS

```bash
# Fichier source : infra/secrets/production/db.enc.yaml
sops infra/secrets/production/db.enc.yaml
# → modifier le champ `data.DB_PASSWORD` (base64) ou `stringData.DB_PASSWORD` (clair)
```

Vérifier la cohérence :

```bash
sops --decrypt infra/secrets/production/db.enc.yaml | yq '.stringData.DB_PASSWORD'
```

### 3. Pré-déployer le secret côté DB **avant** le rolling restart

```bash
# Mettre à jour la base PG en parallèle (les apps continuent avec l'ancien mot de passe).
# Méthode recommandée : ALTER USER (zero-downtime) — l'ancien mdp reste valide
# tant que la session est ouverte ; les nouvelles connexions doivent voir le nouveau.
kubectl exec -n securerag-hub deploy/postgres-primary -- \
  psql -U postgres -c "ALTER USER securerag WITH PASSWORD '${NEW_DB_PASSWORD}';"
```

### 4. Push + sync GitOps

```bash
git add infra/secrets/production/db.enc.yaml
git commit -m "secrets(prod): rotate db password $(date -I)"
git push
argocd app sync securerag-production
```

### 5. Rolling restart contrôlé

```bash
kubectl -n securerag-hub rollout restart deploy/portal-web
kubectl -n securerag-hub rollout status deploy/portal-web --timeout=120s
# Itérer pour chaque deployment concerné
```

### 6. Validation

```bash
bash scripts/validate/smoke-tests.sh
# + check absence d'erreurs auth dans les logs des dernières 5 min
kubectl -n securerag-hub logs -l app.kubernetes.io/name=portal-web --since=5m \
  | grep -iE 'authentication|password|denied' && echo "INVESTIGATE" || echo "OK"
```

### 7. Archive de preuve

```bash
mkdir -p artifacts/security/rotations
cat > "artifacts/security/rotations/$(date -u +%Y%m%dT%H%M%SZ)-db-password.md" <<EOF
# Rotation: db.password
- Date UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Operator: $(git config user.email)
- Git commit: $(git rev-parse HEAD)
- Method: SOPS + age + Argo CD sync
- Validation: smoke-tests OK, 0 auth errors post-rotation
EOF
```

## Test automatisé (drill mensuel)

Le script `scripts/secrets/rotate-and-verify.sh` (ci-dessous) **rejoue
le cycle complet en namespace de test** sans toucher prod.

```bash
NS=securerag-rotation-drill bash scripts/secrets/rotate-and-verify.sh
```

Sortie attendue :

```
[OK] new password generated
[OK] sops re-encrypted
[OK] secret applied
[OK] pod rolled out
[OK] db reachable with new password
ROTATION_DRILL: PASS
```

## Cas d'urgence — compromission

1. **Stop the bleed** : révoquer immédiatement la clé compromise côté origine
   (ex: `REVOKE` user PG, supprimer API key chez le provider, `cosign generate-key-pair` neuf).
2. Procédure standard (étapes 1→6) **avec** option `--force-restart-all`.
3. Audit logs : extraire toutes les opérations sur 24 h précédant la détection,
   archiver dans `artifacts/security/incidents/`.
4. Post-mortem : documenter sous `docs/incidents/YYYYMMDD-secret-leak.md`.

## Procédure spéciale — rotation de la clé age elle-même

> Risque maximal — coordonner sur Jenkins, cluster et tous les ops.

1. `age-keygen -o ~/.config/sops/age/keys-new.txt`
2. Récupérer la clé publique nouvelle.
3. Ajouter la nouvelle clé dans `.sops.yaml` `creation_rules.age` (en plus de l'ancienne, **temporairement** en double-recipient).
4. Re-encrypter tous les fichiers :
   ```bash
   for f in $(grep -rl '^sops:' infra/secrets/ --include='*.enc.yaml'); do
     sops updatekeys "${f}"
   done
   git add infra/secrets/ && git commit -m "secrets: dual-encrypt for age key rotation"
   ```
5. Distribuer la nouvelle clé privée (Jenkins credential, secret cluster `sops-age`).
6. Vérifier que tout décrypte avec la nouvelle.
7. Retirer l'ancienne clé de `.sops.yaml`, re-encrypter, push.
8. Détruire l'ancienne clé privée.

## Critères de complétion

Un cycle de rotation est `TERMINÉ` si **tous** les critères ci-dessous sont vrais :

- [ ] Le commit GitOps existe et référence la rotation
- [ ] Argo CD montre l'app `Synced/Healthy`
- [ ] `kubectl rollout status` est OK pour tous les deployments concernés
- [ ] Smoke tests passent
- [ ] Logs des 5 min post-rotation : 0 erreur d'auth
- [ ] Fichier d'archive sous `artifacts/security/rotations/` créé
- [ ] L'ancien secret est expiré ou révoqué chez l'origine

## Références

- Repo SOPS : <https://github.com/getsops/sops>
- age : <https://github.com/FiloSottile/age>
- argocd-vault-plugin : <https://github.com/argoproj-labs/argocd-vault-plugin>
- `.sops.yaml` du projet : [`/.sops.yaml`](../../.sops.yaml)
- Script drill : [`scripts/secrets/rotate-and-verify.sh`](../../scripts/secrets/rotate-and-verify.sh)
