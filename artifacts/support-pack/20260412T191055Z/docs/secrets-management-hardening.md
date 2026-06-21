# Secrets Management Hardening - SecureRAG Hub

## Objectif

Définir une trajectoire crédible de gestion des secrets pour passer d'un mode `demo` maîtrisé vers une pré-production plus professionnelle.

## État actuel

- Aucun vrai secret ne doit être versionné.
- Les secrets Jenkins et Cosign sont attendus dans des chemins locaux contrôlés.
- Gitleaks permet de détecter les fuites accidentelles.
- Les valeurs de démonstration doivent rester des placeholders.

## Règles immédiates

- Ne jamais commiter de kubeconfig réel, clé Cosign privée ou token Jenkins.
- Utiliser `.env.example` pour documenter les variables, jamais pour stocker des secrets.
- Stocker les credentials Jenkins dans Jenkins Credentials.
- Stocker les clés Cosign hors dépôt, par exemple sous `infra/jenkins/secrets/` en local ignoré.
- Régénérer et révoquer tout secret accidentellement exposé.

## Cible pré-production réaliste

### Option légère

Utiliser des secrets Kubernetes créés au bootstrap :

```bash
kubectl create secret generic securerag-demo-secrets \
  --from-literal=PLACEHOLDER_ONLY=change-me \
  -n securerag-hub
```

Valeur : simple, compatible kind, facile à expliquer.

### Option intermédiaire

Utiliser SOPS avec Age :

- secrets chiffrés dans Git ;
- déchiffrement contrôlé au déploiement ;
- bonne valeur pédagogique pour un Master DSIR.

Coût : gestion des clés Age, discipline Git, runbook supplémentaire.

### Option avancée

Utiliser External Secrets Operator avec Vault ou un backend cloud.

Valeur : proche production.

Coût : plus lourd pour une démo locale, dépendances supplémentaires, risque de déstabiliser la soutenance.

## Politique de rotation

- Tokens Jenkins : rotation après soutenance ou changement de collaborateur.
- Clés Cosign : rotation en cas d'exposition ou changement de release authority.
- Kubeconfig : régénération après recréation du cluster kind.
- Webhook secrets GitHub : rotation après test public ou fuite suspectée.

## Preuves à conserver

- sortie Gitleaks `no leaks found` ;
- liste des variables `.env.example` ;
- capture Jenkins Credentials sans révéler les valeurs ;
- rapport final indiquant que les secrets réels sont hors dépôt.
