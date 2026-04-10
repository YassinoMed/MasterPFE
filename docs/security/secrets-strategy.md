# Secrets Strategy — SecureRAG Hub

## Objectif
Définir une stratégie simple, claire et soutenable pour la gestion des secrets dans SecureRAG Hub, en distinguant trois contextes :
- local développeur
- Jenkins
- Kubernetes

## Principes
- aucun secret réel ne doit être committé dans le dépôt
- les fichiers exemple ne contiennent que des placeholders
- les secrets Jenkins et Kubernetes doivent être créés hors Git
- les secrets de démonstration doivent être explicitement marqués comme non productifs

## Local développeur
- utiliser `security/secrets/.env.example` comme modèle
- créer un fichier local non versionné à partir de ce modèle
- ne jamais y stocker de clé Cosign de production

## Jenkins
### Credentials attendus
- `cosign-private-key` : Secret file
- `cosign-public-key` : Secret file
- `cosign-password` : Secret text

### Règles
- créer les credentials directement dans Jenkins
- ne jamais monter les clés depuis le dépôt
- limiter les permissions d’accès à ces credentials aux seuls jobs concernés

## Kubernetes
### Secrets recommandés
- `securerag-common-secrets`
- secrets applicatifs dédiés si un service a des besoins spécifiques

### Règles
- créer les secrets via `kubectl create secret` ou un script local contrôlé
- ne pas committer les manifestes contenant des valeurs sensibles
- conserver des manifestes d’exemple ou des commandes de création, pas les secrets réels

## Conventions
- variables d’environnement en majuscules
- séparation claire entre `ConfigMap` non sensible et `Secret` sensible
- suffixe `-example` ou `.example` pour tout fichier de démonstration

## Amélioration possible
En environnement plus avancé, remplacer la gestion locale par :
- Vault
- External Secrets Operator
- Sealed Secrets

Pour le périmètre PFE, la stratégie locale + Jenkins credentials + Kubernetes secrets est suffisante si elle est bien documentée et démontrée.
