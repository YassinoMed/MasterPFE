# Policy Matrix — SecureRAG Hub

## Objectif
Rendre lisible la posture de sécurité actuelle du cluster local et la trajectoire de durcissement retenue, en détaillant l'état actuel et la cible de production pour chaque règle de sécurité.

---

## 1. Matrice Kyverno Détaillée

| Policy | Mode Actuel | Mode Cible (Prod) | Justification du Mode Actuel | Prérequis pour Enforce | Impact | Risque |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `securerag-require-pod-security` | `Audit` | `Enforce` | Permet le déploiement local fluide tout en alertant sur les écarts PSS. | Validation de tous les conteneurs tiers utilisés (ex: PostgreSQL/Redis helm charts). | Remonte les écarts de posture pod sans bloquer la démo. | Faible en `Audit`, moyen en `Enforce`. |
| `securerag-require-workload-controls` | `Audit` | `Enforce` | Évite le rejet de pods de tests rapides sans probes. | Ajout systématique de liveness/readiness probes à tous les conteneurs éphémères. | Exige des probes et un token ServiceAccount non monté par défaut. | Faible en `Audit`, moyen en `Enforce`. |
| `securerag-restrict-image-references` | `Audit` | `Enforce` | Permet l'utilisation de registres locaux (`localhost:5001`) ou de builds à la volée. | Configuration d'une whitelist de registres d'entreprise (ex: AWS ECR). | Audite les tags `latest` et les registres non approuvés. | Faible en `Audit`, moyen en `Enforce`. |
| `securerag-restrict-service-exposure` | `Audit` | `Enforce` | Permet d'exposer des ports spécifiques pour les outils d'administration locaux. | Configuration des règles d'ingress sécurisées d'entreprise. | Interdit les services `LoadBalancer` non managés et limite `NodePort`. | Faible en `Audit`, moyen en `Enforce`. |
| `securerag-restrict-volume-types` | `Audit` | `Enforce` | Permet l'accès aux volumes locaux Kind pour persister la base PostgreSQL. | Provisionnement de volumes persistants CSI de production (ex: EBS, Longhorn). | Interdit les volumes `hostPath` dans le namespace applicatif. | Faible en `Audit`, moyen en `Enforce`. |
| `securerag-verify-cosign-images` | `Audit` | `Enforce` | Évite les échecs de vérification de signature dus à la non-résolution DNS de `localhost:5001` par Kyverno. | Enregistrement des certificats et clé publique dans un KMS stable; images de prod signées. | Contrôle la chaîne de confiance de bout en bout avant exécution. | Faible en `Audit`, très élevé en `Enforce` localement (Blocker connu). |

---

## 2. Guardrails Namespace Applicatif

| Contrôle | État | Prérequis | Impact | Risque si absent |
| :--- | :--- | :--- | :--- | :--- |
| **Pod Security Admission (PSA) `restricted`** | Actif dans les manifests | Kubernetes >= 1.25 | Bloque les pods non conformes au profil restricted. | Pods privilégiés ou root acceptés dans le namespace. |
| **`ResourceQuota`** | Actif | Namespace appliqué | Évite la surconsommation grossière de CPU/RAM en démo locale. | Pression forte sur la machine hôte en cas de fuite de ressources. |
| **`LimitRange`** | Actif | Namespace appliqué | Donne des defaults CPU/RAM et `ephemeral-storage` cohérents. | Travaux non bornés risquant de provoquer des évictions brutales. |
| **`PodDisruptionBudget`** | Actif sur workloads critiques | Réplication ciblée | Protège les composants critiques des interruptions volontaires (maintenance). | Interruption brutale de l'application pendant les mises à jour de nœuds. |
| **`HPA` (Horizontal Pod Autoscaler)** | Actif | `metrics-server` installé | Rend la charge observable et prouve la mise à l'échelle automatique. | HPA présents mais non fonctionnels (statut `<unknown>`). |
| **Pods de validation hardened** | Actif dans les scripts | `curlimages/curl` disponible | Garantit la compatibilité des smoke tests avec le profil PSA restricted. | Rejet des pods de test par le contrôleur d'admission Kubernetes. |

---

## 3. Prérequis et Blockers pour le Passage en `Enforce`

### Blockers Connus dans le Contexte Local (Kind)
* **Résolution de la Registry Locale (`localhost:5001`)** :
  Le contrôleur Kyverno s'exécute à l'intérieur du cluster. Lorsqu'il tente de valider la signature d'une image stockée dans `localhost:5001`, l'URL pointe vers le pod de Kyverno lui-même ou le plan de contrôle Kubernetes, ce qui échoue car la registry est exposée sur l'hôte.
* **Absence de résilience KMS locale** :
  L'absence de stockage redondant pour la clé publique Cosign locale présente un risque élevé de fail-closed en cas de redémarrage complet de l'environnement Kind.

### Feuille de route technique pour le passage en `Enforce`
1. **Migration vers une Registry Stable** (ex: GitHub Packages, Docker Hub privé) accessible publiquement ou via secrets d'image.
2. **Stockage de la clé Cosign dans un Secret K8s scellé** (SealedSecrets) ou gestionnaire de secrets sécurisé (Vault).
3. **Mise à jour des manifests Kyverno** via Kustomize overlays pour la production :
   ```yaml
   apiVersion: kyverno.io/v1
   kind: ClusterPolicy
   metadata:
     name: securerag-verify-cosign-images
   spec:
     validationFailureAction: Enforce
   ```

---

*Matrice mise à jour dans le cadre de la finalisation DevSecOps — branche `devsecops-final-hardening`*
