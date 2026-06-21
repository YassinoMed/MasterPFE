# Modèle de Menace STRIDE pour les Bases Vectorielles (ChromaDB & Qdrant)

Ce document étend le modèle de menaces global de SecureRAG Hub pour y intégrer les risques spécifiques liés au stockage vectoriel. Les bases de données vectorielles stockent les représentations numériques (embeddings) des documents médicaux et confidentiels.

---

## 1. Cartographie STRIDE des Bases Vectorielles

| Menace STRIDE | Risque Spécifique | Vecteur d'Attaque Concret | Contrôle de Mitigation | Policy Kyverno / NetworkPolicy |
| :--- | :--- | :--- | :--- | :--- |
| **S — Spoofing** (Usurpation) | **Injecter des embeddings sous l'identité d'un service légitime** | Un attaquant usurpe l'identité du service `chatbot-manager` pour insérer des données frelatées. | Authentification mutuelle (mTLS) ou authentification par jeton statique injecté via Secret. | `10-chromadb-restricted-policy.yaml` et secret de credentials. |
| **T — Tampering** (Altération) | **Poisoning Attack (Empoisonnement de données)** | Injection de vecteurs biaisés via l'API pour manipuler les réponses du chatbot. | Signature cryptographique des sources + Validation de schéma et dimension à l'ingestion. | Kyverno policy interdisant l'écriture directe aux pods non habilités. |
| **R — Repudiation** (Répudiation) | **Opération de lecture/écriture vectorielle non auditée** | Un attaquant supprime ou télécharge des collections entières sans laisser de traces. | Journalisation centralisée des accès API vectoriels via Envoy/API-Gateway + Loki. | Kyverno policy validant la configuration d'audit de l'API vectorielle. |
| **I — Information Disclosure** (Divulgation) | **Reconstruction de documents par inversion d'embeddings** | Extraction des embeddings pour reconstruire le texte source via un modèle inverse. | Chiffrement au repos des volumes persistants + Token-based auth sur l'API + mTLS. | Kyverno policy obligeant l'usage d'une `StorageClass` chiffrée. |
| **D — Denial of Service** (Déni de Service) | **Timing Attack / Épuisement des ressources par requêtes lourdes** | Requêtes de recherche vectorielle complexes provoquant un OOM du pod de la base. | Limites de ressources strictes + Rate-limiting + Cache des requêtes similaires. | Kyverno policy `require-resource-limits` & configurations de HPA. |
| **E — Elevation of Privilege** (Élévation de Privilège) | **Accès non autorisé à l'API d'administration de la base** | Un pod compromis (ex. `audit-security-service`) accède à l'API d'admin non authentifiée. | NetworkPolicy d'ingress limitant l'accès réseau au seul pod `chatbot-manager`. | `10-chromadb-restricted-policy.yaml` + `05-audit-security-policy.yaml`. |

---

## 2. Analyse Détaillée des Scénarios de Menace

### Menace 1 : Reconstruction de documents par inversion d'embeddings (Information Disclosure)

- **Description de la menace** : Les embeddings stockés dans ChromaDB et Qdrant ne sont pas de simples "empreintes" anonymes. Les modèles de Deep Learning récents (par exemple via inversion vectorielle ou modèles génératifs de reconstruction) permettent de reconstituer approximativement le texte source original à partir de son vecteur à plus de 80-90% de fidélité sémantique.
- **Attaquant concerné** : 
  - Un attaquant interne possédant un accès réseau au cluster.
  - Un conteneur compromis dans le même namespace.
  - Un attaquant externe ayant compromis le stockage physique (disque dur ou volume Cloud).
- **Vecteur d'attaque** :
  1. L'attaquant réalise un dump de la base ChromaDB (fichiers `.sqlite` ou parquet) ou interroge l'API via `POST /api/v1/collections/{id}/get` sans authentification.
  2. L'attaquant passe les vecteurs extraits dans un décodeur entraîné sur le même modèle (`sentence-transformers/all-MiniLM-L6-v2`) pour régénérer le texte brut.
- **Contrôles techniques de mitigation** :
  - **Chiffrement au repos** : Utilisation de volumes persistants chiffrés par clé matérielle ou logicielle (ex: `dm-crypt` / `LUKS` via la `StorageClass` de Kubernetes configurée avec intégration HashiCorp Vault).
  - **Chiffrement applicatif** (optionnel) : Salage ou légère perturbation déterministe des vecteurs sensibles n'affectant pas trop le classement de similarité, ou chiffrement de la charge utile de payload dans la base.
  - **Token-based auth** : Activation obligatoire de l'authentification ChromaDB pour bloquer la récupération des embeddings par un tiers.
- **Assocations (Kyverno / NetworkPolicy)** :
  - **NetworkPolicy** : `10-chromadb-restricted-policy.yaml` (bloque l'accès réseau).
  - **Kyverno** : Policy d'admission imposant l'utilisation d'une StorageClass chiffrée (ex: `gp3-encrypted` ou équivalent sur site).

---

### Menace 2 : Injection de vecteurs malveillants / Poisoning Attack (Tampering)

- **Description de la menace** : Un attaquant injecte des vecteurs de documents contenant de fausses instructions ou des biais idéologiques/techniques afin de manipuler le contexte envoyé au LLM, conduisant à des décisions médicales ou opérationnelles erronées.
- **Attaquant concerné** : Un utilisateur malveillant disposant de droits d'upload de documents, ou un attaquant réseau ayant contourné l'authentification de l'API de la base vectorielle.
- **Vecteur d'attaque** :
  1. L'attaquant télécharge un document médical falsifié rédigé de façon à ce que son embedding soit très proche de requêtes médicales courantes (e.g. "traitement de l'hypertension").
  2. Lors de la recherche vectorielle, ce vecteur empoisonné obtient le score de similarité le plus élevé et est injecté dans le prompt du LLM, remplaçant les vraies directives cliniques.
- **Contrôles techniques de mitigation** :
  - **Validation d'intégrité de la source** : Le service `knowledge-hub` calcule un hash SHA-256 du document d'origine et vérifie sa signature numérique avant l'ingestion.
  - **Validation des vecteurs** : Rejeter les vecteurs dont les dimensions sont incorrectes ou contenant des valeurs aberrantes (ex: infinies, NaN, ou norme hors intervalle standard).
  - **Détection des anomalies de similarité** : Comparaison avec un corpus de référence pour détecter des vecteurs atypiques.
- **Assocations (Kyverno / NetworkPolicy)** :
  - **Kyverno** : Vérification des signatures de fichiers de configuration d'ingestion.
  - **NetworkPolicy** : Restriction d'accès en écriture (`Ingress`) sur les ports de base vectorielle au seul pod d'ingestion qualifié (`knowledge-hub` / `chatbot-manager`).

---

### Menace 3 : Accès non autorisé à l'API ChromaDB/Qdrant (Elevation of Privilege)

- **Description de la menace** : Par défaut, ChromaDB et Qdrant n'activent pas d'authentification forte, permettant à tout pod du cluster de lire, modifier ou détruire les collections de données.
- **Attaquant concerné** : Tout conteneur compromis dans le cluster Kubernetes (par exemple, via une vulnérabilité d'exécution de code à distance - RCE dans une dépendance).
- **Vecteur d'attaque** :
  - Un attaquant exécute un shell ou un script Python dans un pod compromis, découvre l'adresse IP interne du service de la base vectorielle (`http://chromadb.securerag-hub.svc:8000`), et lance des requêtes curl pour vider la base.
- **Contrôles techniques de mitigation** :
  - **Authentification forte** : Configuration de l'authentification par jeton statique (`Static Token Auth`) pour ChromaDB et clé d'API (`api-key`) pour Qdrant.
  - **Network Policies strictes** : Appliquer une NetworkPolicy de type `Default Deny` au niveau du namespace, puis autoriser uniquement le service `chatbot-manager` à communiquer avec les ports vectoriels.
- **Assocations (Kyverno / NetworkPolicy)** :
  - **NetworkPolicy** : [10-chromadb-restricted-policy.yaml](../../k8s/network-policies/10-chromadb-restricted-policy.yaml)
  - **Kyverno** : Policy interdisant le déploiement de pods vectoriels sans secrets d'authentification définis dans la spécification du container.

---

### Menace 4 : Timing Attack sur la recherche vectorielle (Information Disclosure)

- **Description de la menace** : En mesurant précisément les temps de réponse de l'API de recherche, un attaquant externe peut déduire des caractéristiques sur les données stockées (par exemple, si un mot-clé confidentiel ou un dossier patient spécifique est présent dans la base de connaissances).
- **Attaquant concerné** : Attaquant externe ou interne interrogeant l'API publique de discussion ou de recherche.
- **Vecteur d'attaque** :
  - L'attaquant envoie des centaines de requêtes légèrement modifiées. Si la recherche vectorielle répond plus rapidement ou plus lentement pour certains termes (dû au cache, à l'indexation HNSW ou à la structure de l'arbre), l'attaquant en déduit la présence ou l'absence d'un document.
- **Contrôles techniques de mitigation** :
  - **Padding temporel (Uniform Delay)** : Introduire un temps de réponse artificiellement lissé ou retardé pour les requêtes de recherche vectorielle (ex: arrondir le temps de réponse à la centaine de millisecondes supérieure).
  - **Rate limiting strict** : Limiter drastiquement le nombre de requêtes de recherche autorisées par minute pour un même utilisateur.
- **Assocations (Kyverno / NetworkPolicy)** :
  - **Kyverno** : Obligation d'activer le middleware de rate-limiting dans l'API Gateway ou le chatbot manager.

---

### Menace 5 : Exfiltration par le service audit-security-service compromis (Principle of Least Privilege)

- **Description de la menace** : Le service `audit-security-service` est chargé d'analyser les logs d'accès et d'auditer la sécurité. S'il est compromis, il pourrait être utilisé comme tête de pont pour siphonner les données vectorielles de la clinique si les accès réseau ne sont pas restreints.
- **Attaquant concerné** : Un attaquant ayant exploité une faille de sécurité dans le code Python ou une dépendance du service d'audit.
- **Vecteur d'attaque** :
  - L'attaquant compromis le pod `audit-security-service` et tente d'interroger `qdrant:6333` ou `chromadb:8000`. Si aucune NetworkPolicy ne l'empêche, il réussit à exfiltrer les données vectorielles.
- **Contrôles techniques de mitigation** :
  - **Principe du Moindre Privilège réseau** : `audit-security-service` n'a techniquement aucun besoin d'accéder aux vecteurs. Sa NetworkPolicy doit donc bloquer toute communication sortante (`Egress`) vers les bases de données vectorielles.
  - **Pas de partages de secrets** : Les jetons d'accès aux bases vectorielles ne doivent pas être injectés dans les variables d'environnement de `audit-security-service`.
- **Assocations (Kyverno / NetworkPolicy)** :
  - **NetworkPolicy** : [05-audit-security-policy.yaml](../../k8s/network-policies/05-audit-security-policy.yaml) (egress vide pour bloquer tout trafic sortant sauf DNS/Loki si nécessaire).
  - **Kyverno** : Une policy Kyverno qui valide que seuls les pods labellisés `database-client` peuvent monter les secrets d'accès aux bases vectorielles.
