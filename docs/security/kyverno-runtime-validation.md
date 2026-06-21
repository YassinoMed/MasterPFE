# Kyverno Runtime Validation — SecureRAG Hub

## Statut : FONCTIONNEL & AUDITÉ

Ce document présente l'évaluation au moment de l'exécution (runtime) des politiques d'admission control de **Kyverno** dans le cluster local (Kind) de démonstration.

---

## 1. Matrice des Politiques Runtime Kyverno

Le tableau ci-dessous synthétise le rôle, les modes de fonctionnement et l'évaluation runtime de nos politiques de conformité.

| Policy | Objectif | Mode Actuel | Mode Cible | Résultat Runtime | Justification du Mode Actuel |
| :--- | :--- | :--- | :--- | :---: | :--- |
| `securerag-require-pod-security` | Enforcer les règles Pod Security Standards (PSS) au niveau Restricted. | `Audit` | `Enforce` | ✅ Conforme | Évite de bloquer le déploiement local rapide tout en auditant les écarts. |
| `securerag-require-workload-controls` | S'assurer que les pods possèdent des probes et ne montent pas le token par défaut. | `Audit` | `Enforce` | ✅ Conforme | Permet de lancer des pods de debug légers sans forcer l'écriture de probes complexes. |
| `securerag-restrict-image-references` | Interdire l'utilisation d'images avec le tag `latest` ou provenant de registres non approuvés. | `Audit` | `Enforce` | ✅ Conforme | Permet d'importer des images de dev locales sans devoir configurer une whitelist dynamique de registres. |
| `securerag-restrict-service-exposure` | Limiter l'exposition des services en interdisant le type LoadBalancer non managé. | `Audit` | `Enforce` | ✅ Conforme | Permet l'exposition contrôlée via NodePorts locaux pour les outils de démonstration. |
| `securerag-restrict-volume-types` | Interdire les montages de type `hostPath` non sécurisés. | `Audit` | `Enforce` | ✅ Conforme | Tolère les volumes de stockage de la base PostgreSQL locale dans l'environnement Kind. |
| `securerag-verify-cosign-images` | Valider la signature cryptographique Cosign de l'image de conteneur avant démarrage. | `Audit` | `Enforce` | ⚠️ Bloqué (Audit) | **Blocker local connu** : Kyverno, s'exécutant dans le cluster, ne peut pas interroger de façon fiable `localhost:5001`. |

---

## 2. Analyse des Bloqueurs pour le passage en `Enforce`

### Blocker Technique Majeur : verifyImages sur Registry locale (`localhost:5001`)
Dans notre cluster de développement Kind :
1. Les images sont hébergées sur une registry Docker locale sur le port `5001`.
2. Le conteneur du webhook de Kyverno s'exécute à l'intérieur du réseau du cluster. Lorsqu'il intercepte un pod utilisant `localhost:5001/securerag-hub-portal-web:production`, il tente de résoudre `localhost` à l'intérieur du pod Kyverno lui-même, ce qui échoue inévitablement (car la registry tourne sur la machine hôte et est exposée via le nœud docker).
3. Par conséquent, forcer cette politique en `Enforce` bloquerait systématiquement tout déploiement local. 

### Solution pragmatique de démonstration
Nous maintenons cette règle en mode `Audit` pour que Kyverno ne bloque pas le cluster local. En contrepartie, la chaîne DevSecOps effectue une vérification rigoureuse **hors cluster** pendant l'étape CD de Jenkins ou manuellement avec `scripts/validate/verify-runtime-signatures.sh` qui utilise la clé publique locale pour valider la signature des images réelles.

---

## 3. Guide de Transition pour la Production

Pour basculer les politiques en mode restrictif (`Enforce`) en production :
1. Remplacer l'adresse de la registry locale par une registry de production managée et sécurisée (ex: AWS ECR, Azure ACR).
2. Mettre à jour l'attribut `validationFailureAction` dans les manifests Kyverno :
   ```yaml
   apiVersion: kyverno.io/v1
   kind: ClusterPolicy
   metadata:
     name: securerag-verify-cosign-images
   spec:
     validationFailureAction: Enforce
   ```
3. Exécuter un déploiement pilote pour s'assurer du non-blocage.
