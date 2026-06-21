# Gestion des secrets — SecureRAG Hub

> Source détaillée : [`docs/security/secrets-management-hardening.md`](security/secrets-management-hardening.md).
> Runbook rotation : [`docs/runbooks/secret-rotation.md`](runbooks/secret-rotation.md).

## Règles d'or

1. **Aucun secret réel ne va dans Git.** Jamais. Pas même temporairement.
2. Tout secret applicatif passe par **SOPS + age** dans `infra/secrets/*.enc.yaml`.
3. Les secrets pipeline (Cosign, GitHub token) passent par **Jenkins
   credentials** (jamais en clair sur disque).
4. Le fichier `.env.example` à la racine contient **uniquement des
   placeholders**, jamais de valeurs réelles.
5. **Gitleaks** est bloquant en CI (stage `CI_SECURITY_STATIC`).

## Comment créer un nouveau secret

### Cas A — Secret applicatif (DB password, JWT key, API key)

```bash
# 1. Générer la valeur
NEW_VALUE=$(openssl rand -base64 32 | head -c 32)

# 2. Éditer le fichier SOPS approprié
sops infra/secrets/production/<service>.enc.yaml
# Ajouter ou modifier la clé dans stringData

# 3. Valider la syntaxe
sops --decrypt infra/secrets/production/<service>.enc.yaml | yq

# 4. Commit + push
git add infra/secrets/production/<service>.enc.yaml
git commit -m "secrets(prod): add <key> $(date -I)"
```

### Cas B — Secret pipeline (Cosign, registry token)

```bash
# Ajouter via UI Jenkins :
#   Manage Jenkins → Credentials → System → Global
#   Type : Secret file (Cosign key) ou Secret text (token)
# Référencer dans Jenkinsfile via :
#   withCredentials([file(credentialsId: 'cosign-private-key', variable: 'COSIGN_KEY')])
```

**Ne jamais** committer ces credentials dans le repo, même chiffrés.

## Procédure de rotation

Voir le runbook complet : [`docs/runbooks/secret-rotation.md`](runbooks/secret-rotation.md).

Résumé :

```bash
# 1. Nouvelle valeur
NEW_PWD=$(openssl rand -base64 32 | tr -d '/+=' | cut -c1-32)

# 2. Pre-déployer côté DB (zero-downtime)
kubectl exec -n securerag-hub deploy/postgres-primary -- \
  psql -c "ALTER USER ... PASSWORD '${NEW_PWD}'"

# 3. SOPS update
sops infra/secrets/production/db.enc.yaml   # modifier
git add -A && git commit -m "secrets(prod): rotate db password $(date -I)"
git push

# 4. Argo CD sync
argocd app sync securerag-production

# 5. Rolling restart
kubectl -n securerag-hub rollout restart deploy/portal-web
kubectl -n securerag-hub rollout status deploy/portal-web --timeout=120s

# 6. Validation
bash scripts/validate/smoke-tests.sh

# 7. Archive de preuve
mkdir -p artifacts/security/rotations
echo "rotation: db.password, op: $(git config user.email), date: $(date -u)" \
  > "artifacts/security/rotations/$(date -u +%Y%m%d)-db-password.md"
```

## Périodicité de rotation

| Secret | Période cible | Forcer immédiatement si |
|--------|--------------:|-------------------------|
| DB application password | 90j | Compromission, départ opérateur |
| JWT signing key | 90j | id |
| API keys externes | 60j | id |
| Cosign signing key | 365j | **Compromission uniquement** |
| age private keys (SOPS) | 365j ou compromission | id |
| Service-to-service tokens | 30j (auto) | N/A |
| Sanctum tokens utilisateur | 1h (auto par TTL) | N/A |

## Contrôles bloquants Gitleaks

Si un secret est poussé par erreur :

1. **Pre-commit** local recommandé (à installer côté dev :
   `pre-commit install` avec hook gitleaks).
2. **Jenkins CI** : stage `CI_SECURITY_STATIC` → Gitleaks → fail si match.
3. **Kyverno** : `audit-cleartext-env-values` détecte les ENV suspects
   à l'admission Pod (mode Audit aujourd'hui, Enforce planifié).

## Configuration SOPS

Voir [`.sops.yaml`](../.sops.yaml) à la racine.

Convention :

- `infra/secrets/production/*.enc.yaml` → clé age prod
- `infra/secrets/{demo,dev}/*.enc.yaml` → clé age dev
- Catch-all → refuse (oblige à passer par les règles ci-dessus)

## Vérification "0 secret dans Git"

```bash
# Scan Gitleaks complet de l'historique
docker run --rm -v "$PWD:/repo" -w /repo \
  ghcr.io/gitleaks/gitleaks:v8.30.1 \
  detect --source=/repo --report-format=json

# Doit retourner 0 findings
```

## Drill rotation testable

```bash
make secret-rotation-drill
# → artifacts/security/rotations/drill-<ts>.log
# → sortie "ROTATION_DRILL: PASS"
```

Voir [`artifacts/validation/secret-rotation-proof.md`](../artifacts/validation/secret-rotation-proof.md).
