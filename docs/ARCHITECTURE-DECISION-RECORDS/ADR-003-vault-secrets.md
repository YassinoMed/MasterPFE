# ADR-003 : Gestion Centralisée des Secrets via HashiCorp Vault

* **Statut** : Accepté
* **Date** : 2026-06-15
* **Auteurs** : Équipe DevSecOps SecureRAG Hub

---

## Contexte

Dans les architectures Kubernetes initiales, les secrets applicatifs (mots de passe de base de données, clés d'API LLM, jetons d'authentification) étaient stockés dans des objets `Secret` natifs de Kubernetes ou passés en clair via des fichiers `.env`.

Cette approche pose plusieurs problèmes critiques de sécurité :
1. **Chiffrement par défaut** : Les secrets K8s ne sont que codés en Base64. Sans configuration additionnelle du chiffrement au repos d'etcd, toute personne ayant accès à etcd ou des privilèges de lecture sur le namespace peut lire les secrets.
2. **Absence de traçabilité** : Impossible de savoir précisément quel pod ou quel utilisateur a lu un secret particulier et à quel moment.
3. **Secrets statiques** : La rotation des mots de passe est complexe, manuelle et rarement effectuée, augmentant la probabilité d'exploitation d'un secret fuité.
4. **Pas de révocation dynamique** : Si un secret est compromis, il n'existe pas de mécanisme automatique de révocation rapide.

## Décision

Nous décidons de centraliser l'ensemble des secrets applicatifs et d'infrastructure au sein de **HashiCorp Vault**. 

Les modalités d'implémentation sont les suivantes :
1. **Stockage sécurisé** : Tous les secrets statiques et dynamiques sont conservés dans le moteur KV (Key-Value) version 2 de Vault.
2. **Méthode d'authentification K8s** : Les pods Kubernetes s'authentifient auprès de Vault en utilisant leur jeton de `ServiceAccount` via la méthode d'authentification `kubernetes` de Vault.
3. **Injection par Agent Vault (Sidecar)** : L'injecteur d'agent Vault (`vault-agent-injector`) est utilisé pour monter dynamiquement les secrets sous forme de fichiers dans un volume en mémoire (`tmpfs`) au sein du conteneur applicatif. Aucun secret n'est écrit sur le disque physique du nœud.
4. **Secrets de pipeline** : Les pipelines Jenkins récupèrent les jetons d'accès et de signature à la volée depuis Vault lors de la phase de build, réduisant le stockage de secrets à long terme dans l'outil de CI.
5. **Sauvegarde chiffrée** : Les clés d'unseal de Vault sont gérées et distribuées de façon sécurisée (Shamir's Secret Sharing) ou déléguées à un KMS externe.

## Conséquences

### Avantages (Pros)
* **Chiffrement fort et centralisé** : Les secrets sont chiffrés au repos dans le stockage physique de Vault.
* **Audit log complet** : Journalisation de chaque demande d'accès aux secrets (qui, quand, quoi) vers le système d'audit.
* **Secrets dynamiques et éphémères** : Possibilité d'activer des secrets dynamiques (ex: identifiants PostgreSQL valides 1 heure) réduisant l'impact d'une fuite.
* **Pas de secrets dans Git** : Aucun secret n'est commité dans les dépôts (les fichiers `.sops.yaml` ou configs GitOps ne contiennent que des références ou du contenu chiffré).

### Inconvénients et Alternatives (Cons)
* **Point de défaillance unique (SPOF)** : Si Vault est indisponible ou verrouillé (`sealed`), les pods ne peuvent plus démarrer ou renouveler leurs jetons.
* **Mitigation** : Déploiement de Vault en mode haute disponibilité (HA) avec auto-unseal basé sur un KMS cloud ou des clés de déverrouillage distribuées de manière hautement sécurisée.
