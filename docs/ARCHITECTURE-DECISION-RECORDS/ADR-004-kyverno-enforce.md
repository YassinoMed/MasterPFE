# ADR-004 : Transition de Kyverno du mode Audit au mode Enforce

* **Statut** : Accepté
* **Date** : 2026-06-15
* **Auteurs** : Équipe DevSecOps SecureRAG Hub

---

## Contexte

Pour sécuriser l'admission dans le cluster Kubernetes, SecureRAG Hub utilise le moteur de politiques Kyverno. Initialement, les politiques d'admission (comme l'interdiction des conteneurs root, la validation des signatures d'images ou l'obligation de fixer des limites de ressources) étaient déployées avec l'action `validationFailureAction: Audit`.

Le mode `Audit` permet d'observer les violations sans bloquer les déploiements. Bien qu'utile pour analyser l'existant sans interruption de service, il présente des risques majeurs :
1. **Sécurité passive** : Des pods non conformes ou des images non signées peuvent être déployés en production, créant des failles de sécurité actives.
2. **Dérive de configuration** : Pas de contrôle bloquant à la source pour empêcher les développeurs de déployer des configurations non durcies (ex. montage hostPath, privilèges root).
3. **Manque de conformité** : Le niveau SLSA 3 et le profil PSS Restricted exigent une application stricte (`enforcement`), pas seulement une surveillance.

## Décision

Nous décidons de passer progressivement toutes les politiques de sécurité clés de Kyverno du mode `Audit` au mode `Enforce` (blocage actif à l'admission) :

1. **Bascule progressive** :
   - **Phase 1** : Audit de l'existant et correction de tous les manifests de déploiement en base GitOps pour s'assurer qu'aucun pod actuel ne viole les règles.
   - **Phase 2** : Bascule en mode `Enforce` sur le namespace de non-production (`recette`) afin de valider le comportement lors des déploiements Jenkins et des tests d'intégration.
   - **Phase 3** : Bascule finale en mode `Enforce` sur le namespace de production (`securerag-hub`).
2. **Double Déclaration** :
   - Maintenir deux versions de chaque fichier de politique dans le dépôt : `policy-audit.yaml` et `policy-enforce.yaml` pour faciliter les rollbacks rapides en cas d'incident de déploiement majeur.
3. **Gestion des exceptions** :
   - Interdiction de modifier les politiques globales pour accommoder un cas particulier. Utilisation exclusive des ressources natives `PolicyException` de Kyverno pour accorder des dérogations temporaires et documentées (ex. agents de monitoring Falco ou Promtail nécessitant des accès spécifiques).

## Conséquences

### Avantages (Pros)
* **Garantie de sécurité active** : Aucun pod ne respectant pas les critères de sécurité PSS Restricted ou de signature d'image ne peut être planifié dans le cluster de production.
* **Détection précoce dans la CI** : Les erreurs de sécurité sont détectées dès la phase de déploiement en recette (Jenkins échoue immédiatement si le manifest est rejeté par Kyverno).
* **Conformité réglementaire** : Alignement complet avec les critères techniques des audits de sécurité et des normes ISO 27001 / PSS.

### Inconvénients et Alternatives (Cons)
* **Risque de blocage accidentel** : Une mise à jour tierce de chart Helm non conforme peut bloquer soudainement le pipeline de déploiement.
* **Mitigation** : Procédure de rollback rapide via l'application de la politique en mode audit ou déclaration d'une `PolicyException` ciblée et validée par l'équipe SecOps.
