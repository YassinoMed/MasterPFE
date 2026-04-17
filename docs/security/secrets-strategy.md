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

## Rotation
- `SECURERAG_SHARED_API_TOKEN` : à régénérer après fuite ou changement de périmètre service-to-service.
- `APP_KEY` : rotation destructive pour données chiffrées Laravel ; à planifier.
- Cosign keypair : rotation après exposition ou changement d’autorité release.
- Sonar token : rotation après fuite, fin de soutenance ou changement de projet Sonar.
- Jenkins admin password/API token : rotation après soutenance, publication temporaire ou changement de collaborateur.

## Options futures
Pour une pré-production, utiliser SOPS/age, Sealed Secrets ou External Secrets Operator. Non activé par défaut pour ne pas complexifier la démonstration kind locale.
