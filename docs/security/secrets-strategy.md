# Secrets Strategy — SecureRAG Hub

## Objectif
Définir une stratégie réaliste et démontrable pour trois périmètres séparés :
- secrets applicatifs Kubernetes ;
- credentials Jenkins/Cosign/Sonar ;
- fichiers locaux développeur.

## Principe de séparation
| Périmètre | Stockage local | Injection | État |
|---|---|---|---:|
| Kubernetes apps | `security/secrets/.env.local` ignoré par Git | `scripts/secrets/create-dev-secrets.sh` vers `securerag-common-secrets` | TERMINÉ |
| Jenkins admin | `infra/jenkins/secrets/jenkins-admin-password` ignoré par Git | `JENKINS_ADMIN_PASSWORD_FILE` dans Docker Compose | TERMINÉ |
| Cosign Jenkins | `infra/jenkins/secrets/cosign.*` ignoré par Git | Jenkins Credentials bootstrap | TERMINÉ |
| Sonar Jenkins | `infra/jenkins/secrets/sonar-token` ignoré par Git | Jenkins credential `sonar-token` si fourni | PRÊT_NON_EXÉCUTÉ |
| DB externe production | Variables d'environnement opérateur ou SOPS/age optionnel | Secret Kubernetes `securerag-database-secrets` | PRÊT_NON_EXÉCUTÉ |

## Options modernes documentées

| Option | Rôle | État honnête |
|---|---|---:|
| SOPS/age | Secret chiffré versionné, déchiffrement contrôlé par clés age | PRÊT_NON_EXÉCUTÉ |
| External Secrets Operator | Synchroniser des secrets depuis un backend central | PRÊT_NON_EXÉCUTÉ |
| Vault | Gestion centralisée, rotation et accès dynamiques | PRÊT_NON_EXÉCUTÉ |

Ces options sont volontairement documentées sans être déclarées `TERMINÉ`. Le
projet reste défendable aujourd'hui avec des secrets Kubernetes créés hors Git
et des credentials Jenkins locaux, puis extensible vers un modèle opérateur
quand l'environnement cible le justifie.

Le mot de passe admin Jenkins n’est pas injecté dans le Secret applicatif Kubernetes.

## Bootstrap local
```bash
bash scripts/secrets/bootstrap-local-secrets.sh
bash scripts/secrets/create-dev-secrets.sh
bash scripts/jenkins/bootstrap-local-credentials.sh
```

`create-dev-secrets.sh` refuse les placeholders, les secrets faibles et un `APP_KEY` Laravel invalide.

Pour activer Sonar dans Jenkins sans exposer le token :

```bash
SONAR_TOKEN_VALUE='<token-sonar-reel>' bash scripts/jenkins/bootstrap-local-credentials.sh
```

## Production external DB

Le chemin production-like ne versionne pas le Secret DB. Il utilise soit des
variables d'environnement opérateur, soit un secret chiffré SOPS/age.

Création directe depuis variables d'environnement :

```bash
DB_HOST='<postgres-host>' \
DB_USERNAME='<postgres-user>' \
DB_PASSWORD='<mot-de-passe-fort-minimum-20-caracteres>' \
make production-db-secret
```

Le script écrit uniquement une preuve redigée :

```text
artifacts/security/production-db-secret.md
```

Option SOPS/age préparée :

```text
infra/secrets/sops/sops-age.example.yaml
infra/secrets/production/securerag-database-secrets.template.yaml
scripts/secrets/apply-sops-production-db-secret.sh
```

Elle reste `PRÊT_NON_EXÉCUTÉ` tant qu'un destinataire age réel et un fichier
chiffré n'ont pas été créés.

Application depuis un secret chiffré SOPS :

```bash
ENCRYPTED_SECRET_FILE='infra/secrets/production/securerag-database-secrets.enc.yaml' \
make sops-db-secret
```

Option External Secrets / Vault préparée :

```text
infra/secrets/external-secrets/cluster-secret-store.vault.template.yaml
infra/secrets/external-secrets/securerag-database.external-secret.template.yaml
scripts/secrets/render-production-db-external-secret.sh
scripts/secrets/validate-external-secrets-runtime.sh
```

Rendu non destructif :

```bash
make external-secret-render
```

Preuve runtime si External Secrets Operator est installé :

```bash
make external-secret-runtime-proof
```

## Rotation
- `SECURERAG_SHARED_API_TOKEN` : à régénérer après fuite ou changement de périmètre service-to-service.
- `APP_KEY` : rotation destructive pour données chiffrées Laravel ; à planifier.
- Cosign keypair : rotation après exposition ou changement d’autorité release.
- Sonar token : rotation après fuite, fin de soutenance ou changement de projet Sonar.
- Jenkins admin password/API token : rotation après soutenance, publication temporaire ou changement de collaborateur.

## Options futures
External Secrets Operator ou Vault restent pertinents pour une vraie production
multi-environnement. Ils ne sont pas activés par défaut pour ne pas complexifier
la démonstration kind locale, mais la stratégie cible est désormais documentée
explicitement pour ne pas laisser ce sujet implicite.
