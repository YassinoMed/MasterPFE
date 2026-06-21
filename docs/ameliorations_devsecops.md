# Propositions d'Amélioration de la Chaîne DevSecOps — SecureRAG Hub

Ce document détaille les recommandations d'amélioration de la chaîne **DevSecOps** de SecureRAG Hub, visant à élever le niveau de maturité (cible SLSA Level 3/4 et OWASP SAMM Niveau 2/3) et à remédier aux lacunes identifiées lors des audits.

---

## 1. Gestion Dynamique des Secrets (HashiCorp Vault)

### Constat Actuel
Les secrets d'environnement et de configuration sont chiffrés dans Git à l'aide de **SOPS et age**. Bien que cette approche protège le stockage de code, elle repose sur des clés statiques de déchiffrement persistantes configurées dans Jenkins et sur les serveurs de recette/production. En cas de compromission de l'exécuteur Jenkins, toutes ces clés peuvent être volées, exposant l'intégralité des secrets de l'organisation.

### Recommandations
1.  **Déploiement de HashiCorp Vault** : Mettre en place un serveur Vault sécurisé.
2.  **Intégration via AppRole** : Utiliser la méthode d'authentification `AppRole` dans Jenkins. Jenkins reçoit un `RoleID` et génère temporairement un `SecretID` éphémère pour s'authentifier auprès de Vault et récupérer les secrets à la volée en mémoire, sans jamais stocker de clé privée statique sur le disque de l'exécuteur.
3.  **Chiffrement via le moteur Transit (enveloppe)** : Pour les fichiers GitOps, utiliser le moteur Transit de Vault pour effectuer les opérations cryptographiques à l'intérieur de Vault. La clé de chiffrement ne quitte jamais le HSM ou le coffre-fort.
4.  **Secrets Éphémères et Rotation** : Activer la génération de secrets dynamiques (ex: identifiants PostgreSQL éphémères pour les applications Laravel, valides pour une durée limitée avec révocation automatique).

---

## 2. Signature sans Clé (Sigstore/Cosign Keyless)

### Constat Actuel
Le pipeline Jenkins CD utilise une paire de clés Cosign statique (`cosign.key` / `cosign.pub`) pour signer cryptographiquement les images Docker produites. Cette clé privée est enregistrée comme identifiant Jenkins et sa phrase de passe est stockée en clair dans les variables d'environnement Jenkins. C'est un point unique de défaillance (Single Point of Failure).

### Recommandations
1.  **Adopter le Keyless Signing (Sigstore)** : Éliminer la gestion des clés privées en utilisant la signature sans clé.
2.  **Mécanisme OIDC** :
    *   Configurer un fournisseur d'identité OIDC pour Jenkins (ou GitHub).
    *   Lors du build, l'exécuteur Jenkins demande un jeton d'identité JWT signé attestant son identité de build.
    *   **Cosign** transmet ce jeton JWT à l'autorité de certification **Fulcio** de Sigstore.
    *   Fulcio valide l'identité de l'exécuteur et génère un certificat cryptographique éphémère à usage unique (valide pendant 10 minutes) associé à la paire de clés publique/privée générée localement en mémoire par l'exécuteur.
    *   L'image est signée avec la clé privée éphémère, le certificat temporaire est joint à la signature, et la preuve de signature est enregistrée dans le journal de transparence public **Rekor**.
3.  **Validation par Kyverno** : Configurer la politique Kyverno du cluster pour valider la signature par l'identité OIDC de l'exécuteur Jenkins (ex: issuer `https://jenkins.securerag.local` et subject correspondant au job CD) au lieu d'une clé publique fixe.

---

## 3. Transition Progressive vers le mode "Enforce" de Kyverno

### Constat Actuel
Les politiques Kyverno déployées sur le cluster (Pod Security Standards, Service Exposure, etc.) sont configurées en mode `Audit`. Elles journalisent les violations de conformité mais ne bloquent pas le déploiement de ressources non conformes (ex: un pod sans livenessProbe ou une image non signée).

### Recommandations
1.  **Bascule par Namespace (Staging / Recette d'abord)** :
    *   Garder le namespace de production en mode `Audit` à court terme pour éviter les pannes de service.
    *   Passer le namespace de recette (`securerag-hub-recette` ou similaire) en mode `Enforce` :
        ```yaml
        spec:
          validationFailureAction: Enforce
        ```
    *   Toute nouvelle ressource ne respectant pas les critères (signature Cosign valide, sondes de santé déclarées, privilèges non root) sera immédiatement rejetée à l'entrée du cluster, forçant les développeurs à corriger les configurations dans leur code Git avant le déploiement.
2.  **Promotion en Production** : Après un cycle complet sans blocages intempestifs en recette, appliquer progressivement les politiques en mode `Enforce` en production.

---

## 4. Corrélation des Alertes de Sécurité avec Wazuh SIEM

### Constat Actuel
Vous disposez d'un squelette d'architecture Wazuh dans [infra/wazuh](file:///root/MasterPFE/infra/wazuh). Par ailleurs, **Falco** est utilisé pour détecter les intrusions au runtime, mais les alertes système restent isolées dans les logs de conteneurs locaux.

### Recommandations
1.  **Intégration Falco -> Wazuh** :
    *   Configurer Falco pour acheminer ses alertes au format JSON vers `falcosidekick`.
    *   Configurer `falcosidekick` pour transmettre les événements vers le gestionnaire d'événements de **Wazuh** (via syslog, webhook, ou écriture locale surveillée par Filebeat).
2.  **Création de Décodeurs et Règles Wazuh personnalisés** :
    *   Ajouter des décodeurs dans `infra/wazuh/decoders/` pour parser les alertes Falco (champs : règle enfreinte, conteneur fautif, namespace, commande système exécutée).
    *   Configurer des règles d'alerte Wazuh pour déclencher des notifications SecOps (Slack/Email) lors d'événements critiques (ex: un shell lancé dans le pod de la base de données).
3.  **Supervision des Kubernetes Audit Logs** : Activer les journaux d'audit du Control Plane Kubernetes et les transférer à Wazuh pour détecter des comportements suspects sur l'API (ex: création répétée de rôles RBAC par un compte de service).

---

## 5. Durcissement des Images : Passage au "Distroless"

### Constat Actuel
Les images Docker du chatbot, du portail web et des microservices intègrent des distributions de base complètes (Debian, Ubuntu, Alpine complète) qui contiennent des binaires non nécessaires au fonctionnement de l'application (shells `sh`/`bash`, gestionnaires de paquets `apt`/`apk`, utilitaires réseau `curl`/`wget`). Cela augmente inutilement la surface d'attaque et génère de nombreuses alertes de vulnérabilités système dans Trivy.

### Recommandations
1.  **Multi-Stage Builds** : Séparer l'environnement de compilation (contenant les dépendances de dev, npm, composer) de l'environnement d'exécution finale.
2.  **Conteneurs Distroless** : Utiliser des images de base distroless (comme `gcr.io/distroless/static` ou `gcr.io/distroless/base`) pour l'exécution.
    *   Ces images ne contiennent *aucun* shell, gestionnaire de paquets ou utilitaire système.
    *   Si un attaquant parvient à exploiter une vulnérabilité applicative (ex: injection de code), il lui sera impossible de lancer un shell interactif ou de télécharger des outils de post-exploitation (`curl` / `wget`).
    *   Le nombre de CVEs détectées par Trivy sur le système d'exploitation de base tombe presque à zéro.

---

## 6. Automatisation des Mises à Jour (Renovate / Dependabot)

### Constat Actuel
L'audit des dépendances tierces (SCA) est réactif : il bloque le build lors de la détection de CVE critiques. Cela force les équipes à gérer les correctifs manuellement en situation d'urgence.

### Recommandations
1.  **Mise en place de Renovate Bot** :
    *   Intégrer Renovate sur votre dépôt de code.
    *   Renovate scanne de manière planifiée et proactive vos fichiers de configuration (`composer.json`, `package.json`, `requirements.txt`, Graphiques Helm, etc.).
    *   Le bot génère automatiquement des Pull Requests de mise à jour dès qu'une nouvelle version de bibliothèque est disponible (correctifs de sécurité et mises à jour mineures).
2.  **Validation automatisée** : Associer ces PR à vos pipelines Jenkins CI existants pour valider automatiquement la non-régression et fusionner automatiquement les mises à jour mineures stables.
