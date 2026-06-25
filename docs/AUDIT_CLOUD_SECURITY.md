# Phase 5 — Cloud Security & Secrets Management Review

Ce document présente l'audit de la gestion des identités, des accès et de la confidentialité des secrets (IAM, SOPS, HashiCorp Vault, ESO, OIDC et TLS) du projet.

---

## 1. Secrets Management & Intégrations

### 1.1 HashiCorp Vault & External Secrets Operator (ESO)
*   **Architecture** : Le dépôt contient une structure complète pour externaliser les secrets via Vault et les injecter dynamiquement dans Kubernetes à l'aide d'External Secrets Operator (ESO) (`infra/k8s/secrets/`).
*   **Enregistrement des secrets (ClusterSecretStore)** : La configuration utilise un magasin de secrets au niveau du cluster (`eso-cluster-secret-store.yaml`) qui s'authentifie auprès de Vault en utilisant le ServiceAccount Kubernetes de l'application.
*   **Statut opérationnel** : Bien que les manifests d'intégration de Vault et d'ESO soient présents, ils ne sont pas activés par défaut dans l'environnement local Kind sans le lancement manuel du script `scripts/deploy/deploy-vault-and-eso.sh`.

### 1.2 SOPS (Secrets on Git)
*   **Configuration** : Un fichier de configuration `.sops.yaml` est présent à la racine, configuré pour chiffrer les secrets via des clés Age et PGP (`.sops.yaml`).
*   **Constat** : Le mécanisme SOPS n'est pas utilisé pour chiffrer les configurations applicatives en clair présentes dans le dépôt. Il n'y a aucun fichier chiffré de type `*.enc.yaml`.

### 1.3 Gestion des identités et ServiceAccounts
*   **Principe de moindre privilège** : Correctement appliqué pour les microservices métier qui disposent chacun d'un ServiceAccount dédié sans droit d'administration sur le cluster.
*   **Rôle RBAC read-only** : Configuré sous `infra/k8s/base/rbac-runtime-readonly.yaml` pour restreindre les droits d'accès de l'application à l'API Kubernetes.

---

## 2. Détection des Secrets Hardcodés & Faiblesses IAM (Findings)

### Finding SEC-01 : Fichiers `.env` Commités dans Git [CRITICAL]
*   **Description** : Cinq fichiers `.env` contenant des clés de chiffrement de production/démonstration (`APP_KEY` Laravel) et des configurations de base de données en clair sont présents dans l'historique et l'arborescence Git :
    *   `platform/portal-web/.env`
    *   `services-laravel/auth-users-service/.env`
    *   `services-laravel/chatbot-manager-service/.env`
    *   `services-laravel/conversation-service/.env`
    *   `services-laravel/audit-security-service/.env`
*   **Impact** : Fuite immédiate de clés cryptographiques permettant de déchiffrer les cookies, sessions et données sensibles en transit si un attaquant accède au dépôt.
*   **Recommandation** : Supprimer immédiatement ces fichiers du tracking Git (`git rm --cached`), les ajouter à `.gitignore` et déclencher une rotation de toutes les `APP_KEY` via Vault/ESO.

### Finding SEC-02 : Identifiants MinIO et Harbor par Défaut dans ArgoCD [HIGH]
*   **Description** : Les credentials d'administration de MinIO (`minioadmin:minioadmin`) et du Container Registry local/Harbor sont écrits en clair dans les fichiers YAML d'ArgoCD (`infra/k8s/argocd/application-velero.yaml`).
*   **Impact** : Compromission de l'intégralité des sauvegardes système (Velero) et possibilité de pousser des conteneurs vérolés dans le registre d'images.
*   **Recommandation** : Remplacer les valeurs en clair par des références à des ExternalSecrets gérés par ESO et Vault.

### Finding SEC-03 : Secret OIDC Client en Clair [HIGH]
*   **Description** : Le fichier `security/sigstore/deploy-sigstore-stack.sh` (ligne 47) contient un secret d'authentification Keycloak en clair (`jenkins-cosign-secret`).
*   **Impact** : Risque d'usurpation d'identité de l'agent de build Jenkins auprès du service d'attestation de la supply chain.
*   **Recommandation** : Injecter le client secret sous forme de variable d'environnement masquée dans Jenkins ou via Vault.

---

## 3. Analyse du Chiffrement des Flux (TLS / mTLS)

*   **Trafic Interne (Service-to-Service)** : Les microservices communiquent entre eux en clair (HTTP sans TLS sur le port 8000). Ce risque est documenté comme accepté pour l'environnement local (`cleartext-protocol-risk-acceptance.md`), mais représente une faille critique en production.
*   **Mitigation (mTLS Istio)** : Istio est pré-configuré sous `infra/k8s/istio/` avec injection automatique des conteneurs sidecars Envoy, mais n'est pas pleinement activé en mode Strict par défaut.
*   **TLS Externe (Ingress)** : Cert-manager gère la couche TLS pour l'accès utilisateur public. Cependant, en environnement local Kind, les certificats utilisés sont auto-signés, ce qui déclenche des avertissements de sécurité.

---

## 4. Scoreboard Cloud Security

### Note Globale : 80/100

| Domaine d'Audit | Score | Justification |
| :--- | :--- | :--- |
| **Secrets Management (Vault/ESO/SOPS)** | 88/100 | L'architecture technique est prête et bien pensée, mais souffre d'un manque d'automatisation complète de l'init et de fichiers SOPS inutilisés. |
| **Confidentialité (Secrets Hardcodés)** | 40/100 | Présence de 5 fichiers `.env` applicatifs contenant des secrets en clair commités dans le dépôt Git. |
| **Sécurité des Accès (IAM & RBAC)** | 92/100 | Excellente gestion des rôles de ServiceAccounts Kubernetes applicatifs avec jetons désactivés par défaut. |
| **Chiffrement des Flux (TLS/mTLS)** | 78/100 | Ingress sécurisé mais trafic interne en clair sans mTLS activé en configuration de base. |
