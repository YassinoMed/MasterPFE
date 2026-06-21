# ADR-002 : Signature Keyless d'Images via Sigstore/Cosign et OIDC

* **Statut** : Accepté
* **Date** : 2026-06-15
* **Auteurs** : Équipe DevSecOps SecureRAG Hub

---

## Contexte

Pour garantir que seules les images construites par le pipeline de confiance (CI/CD) soient exécutées dans le cluster, SecureRAG Hub s'appuie sur la signature d'images de conteneurs. Initialement, cette signature utilisait des paires de clés Cosign statiques stockées sous forme de secrets Jenkins.

Cette approche présente des limites importantes en matière de sécurité :
1. **Gestion des clés privées** : La clé privée de signature doit être conservée dans Jenkins. En cas de compromission du serveur Jenkins ou d'une fuite d'identifiants, un attaquant peut extraire la clé et signer des images malveillantes.
2. **Rotation des clés** : Changer de clé requiert des opérations manuelles lourdes sur l'ensemble des pipelines et des contrôleurs d'admission dans Kubernetes.
3. **Absence de transparence** : Il n'existe pas d'historique centralisé et immuable des signatures effectuées.

## Décision

Nous décidons d'implémenter la **signature sans clé (keyless signing)** via le workflow Sigstore (Cosign, Fulcio, Rekor) couplé à un fournisseur d'identité OIDC (OpenID Connect) :

1. Le pipeline Jenkins s'authentifie auprès du serveur OIDC interne (Keycloak) et obtient un jeton d'identité OIDC attestant de son identité de constructeur (`builder`).
2. Cosign génère localement une paire de clés éphémère en mémoire (valable uniquement pour la session de build).
3. Cosign transmet le jeton OIDC à **Fulcio** (l'autorité de certification de Sigstore) qui, après validation du jeton, délivre un certificat X.509 à courte durée de vie (10 minutes) liant la clé publique éphémère à l'identité du pipeline Jenkins.
4. Cosign signe l'image de conteneur avec la clé privée éphémère, puis détruit cette dernière.
5. La signature et le certificat sont enregistrés dans **Rekor**, le registre de transparence immuable (transparency log).
6. Le contrôleur d'admission Kyverno du cluster Kubernetes vérifie l'image à l'aide du certificat éphémère présent dans Rekor en validant que l'émetteur (`issuer`) correspond bien à Keycloak et le sujet (`subject`) à l'identité Jenkins.

## Conséquences

### Avantages (Pros)
* **Zéro gestion de clé** : Plus aucune clé privée n'est stockée au repos, éliminant totalement le risque de fuite ou de vol de clé de signature.
* **Traçabilité absolue** : Chaque signature d'image est liée à une identité de build précise et stockée dans un registre immuable (anti-tampering).
* **Vérification simplifiée** : Kyverno valide directement l'identité d'origine (OIDC claims) plutôt que de valider une clé publique spécifique.

### Inconvénients et Alternatives (Cons)
* **Dépendance envers l'infrastructure Sigstore** : La disponibilité de Keycloak, Fulcio, et Rekor devient critique au moment de la signature (dans la CI) et de la vérification (à l'admission dans Kubernetes).
* **Solution** : Déploiement hautement disponible de la stack Sigstore dans le cluster d'infrastructure, avec des caches locaux pour la validation des signatures.
