# Secrets Management Hardening - SecureRAG Hub

## Objectif

Définir une trajectoire crédible de gestion des secrets pour passer d'un mode `demo` maîtrisé vers une pré-production plus professionnelle.

## État actuel

- Aucun vrai secret ne doit être versionné.
- Les secrets applicatifs Kubernetes, Jenkins admin, Cosign et Sonar sont séparés.
- Gitleaks permet de détecter les fuites accidentelles.
- Les valeurs de démonstration doivent rester des placeholders.

## Règles immédiates

- Ne jamais commiter de kubeconfig réel, clé Cosign privée, token Jenkins ou token Sonar.
- Utiliser `.env.example` pour documenter les variables, jamais pour stocker des secrets.
- Générer le mot de passe admin Jenkins avec `scripts/jenkins/bootstrap-local-credentials.sh`.
- Stocker les credentials Jenkins/Cosign/Sonar dans `infra/jenkins/secrets/`, dossier local ignoré par Git, puis les injecter dans Jenkins Credentials.
- Générer `security/secrets/.env.local` avec `scripts/secrets/bootstrap-local-secrets.sh`; ne pas utiliser `.env.example` directement.
- Régénérer et révoquer tout secret accidentellement exposé.

## Cible pré-production réaliste

### Option légère

Utiliser des secrets Kubernetes créés au bootstrap :

```bash
bash scripts/secrets/bootstrap-local-secrets.sh
bash scripts/secrets/create-dev-secrets.sh
```

Valeur : simple, compatible kind, facile à expliquer.

### Option intermédiaire

Utiliser SOPS avec Age :

- secrets chiffrés dans Git ;
- déchiffrement contrôlé au déploiement ;
- bonne valeur pédagogique pour un Master DSIR.

Coût : gestion des clés Age, discipline Git, runbook supplémentaire.

Dans le dépôt, cette option est préparée sans être activée par défaut :

- `infra/secrets/sops/sops-age.example.yaml` : exemple de règle SOPS/age ;
- `infra/secrets/production/securerag-database-secrets.template.yaml` : modèle Kubernetes `Secret` sans valeur réelle ;
- `scripts/secrets/apply-sops-production-db-secret.sh` : déchiffrement et application contrôlée avec preuve redigée ;
- `infra/secrets/.gitignore` : empêche de versionner les fichiers plaintext, `.env` ou clés age locales.

L'état de cette option est `PRÊT_NON_EXÉCUTÉ` tant qu'aucun secret chiffré réel n'a été produit avec un destinataire age réel.

### Option avancée

Utiliser External Secrets Operator avec Vault ou un backend cloud.

Valeur : proche production.

Coût : plus lourd pour une démo locale, dépendances supplémentaires, risque de déstabiliser la soutenance.

Le dépôt contient maintenant les briques opérables suivantes :

- `infra/secrets/external-secrets/cluster-secret-store.vault.template.yaml` ;
- `infra/secrets/external-secrets/securerag-database.external-secret.template.yaml` ;
- `scripts/secrets/render-production-db-external-secret.sh` ;
- `scripts/secrets/validate-external-secrets-runtime.sh`.

## Politique de rotation

- Tokens Jenkins : rotation après soutenance ou changement de collaborateur.
- Token Sonar : rotation après soutenance, fuite suspectée ou changement de projet Sonar.
- Clés Cosign : rotation en cas d'exposition ou changement de release authority.
- Kubeconfig : régénération après recréation du cluster kind.
- Webhook secrets GitHub : rotation après test public ou fuite suspectée.

## Preuves à conserver

- sortie Gitleaks `no leaks found` ;
- liste des variables `.env.example` ;
- capture Jenkins Credentials sans révéler les valeurs ;
- preuve que `infra/jenkins/docker-compose.yml` lit `JENKINS_ADMIN_PASSWORD_FILE` et ne contient pas de mot de passe statique ;
- rapport final indiquant que les secrets réels sont hors dépôt.
- `artifacts/security/secrets-management.md` après `make secrets-management` ;
- `artifacts/security/production-db-secret.md` après création du Secret DB externe sur le cluster cible.

## Commandes production-like

Validation non destructive :

```bash
make secrets-management
```

Création du Secret DB externe. Cette action est mutative sur le cluster cible :

```bash
DB_HOST='<postgres-host>' \
DB_USERNAME='<postgres-user>' \
DB_PASSWORD='<mot-de-passe-fort-minimum-20-caracteres>' \
DB_SSLMODE=require \
make production-db-secret
```

Dry-run sans mutation :

```bash
DRY_RUN=true \
DB_HOST='<postgres-host>' \
DB_USERNAME='<postgres-user>' \
DB_PASSWORD='<mot-de-passe-fort-minimum-20-caracteres>' \
make production-db-secret
```

Application depuis un secret SOPS chiffré. Action mutative sur le cluster cible :

```bash
ENCRYPTED_SECRET_FILE='infra/secrets/production/securerag-database-secrets.enc.yaml' \
make sops-db-secret
```

Rendu non destructif du chemin External Secrets :

```bash
make external-secret-render
```

Preuve runtime External Secrets si l'opérateur est installé :

```bash
make external-secret-runtime-proof
```
