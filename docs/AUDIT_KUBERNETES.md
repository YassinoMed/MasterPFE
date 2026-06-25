# Phase 4 — Kubernetes Security & Cluster Hardening Audit

Ce document présente l'audit approfondi de la configuration des manifestes et de la posture de sécurité de l'orchestrateur **Kubernetes (K8s)** du projet.

---

## 1. Audit des Workloads et Objets Kubernetes

### 1.1 Deployments & StatefulSets
*   **Workloads Applicatifs** : Les microservices Laravel (`auth-users`, `chatbot-manager`, `conversation-service`, `audit-security-service`) et le portail `portal-web` sont déployés sous forme de `Deployments`.
*   **Bases de Données & State** : Qdrant et PostgreSQL sont gérés avec des StatefulSets (`infra/k8s/base/qdrant/` et `postgres-auth/`).
*   **Vigilance (SecurityContext)** : Les workloads applicatifs intègrent des durcissements stricts de sécurité :
    *   `runAsNonRoot: true`
    *   `allowPrivilegeEscalation: false`
    *   `capabilities.drop: ["ALL"]`
    *   `seccompProfile.type: RuntimeDefault`
*   **Vigilance (ReadOnlyRootFilesystem)** : La plupart des services ont `readOnlyRootFilesystem: true`. Cependant, Qdrant et Ollama manquent de cette directive ou l'ont désactivée sans volume writable temporaire (`tmpfs`), augmentant la surface d'attaque en écriture en cas de compromission.

### 1.2 DaemonSets
Les DaemonSets du cluster sont réservés aux composants d'infrastructure de sécurité et réseau :
*   **Falco** (`infra/k8s/runtime-detection/daemonset.yaml`) : S'exécute avec des privilèges élevés pour intercepter les appels système du noyau (eBPF).
*   **Cilium** (`infra/k8s/cilium/daemonset.yaml`) : S'exécute en mode privilégié pour gérer le réseau de pods eBPF.

### 1.3 Ingress & Services
*   **API Gateway / Ingress** : L'Ingress Kong gère le routage externe.
*   **Risque Identifié** : Kong expose le port d'administration `8001` par défaut (`infra/k8s/kong/deployment.yaml`). Si ce port n'est pas restreint par une NetworkPolicy interne stricte, un attaquant dans le cluster peut reconfigurer dynamiquement les routes de l'API Gateway.

### 1.4 Network Policies (Zero-Trust Network)
*   **Enforcement** : Présence de `00-default-deny-all.yaml` appliquant un blocage systématique de tout flux entrant/sortant non explicitement autorisé.
*   **Flux Spécifiques** : Des NetworkPolicies dédiées sont écrites pour isoler chaque microservice (`k8s/network-policies/`).
*   **Faiblesse** : Certaines NetworkPolicies d'infrastructure (notamment le namespace `monitoring` ou le namespace `kube-system`) manquent de règles de restriction strictes sur l'Egress, permettant potentiellement à un pod compromis de contacter des adresses IP externes.

### 1.5 Auto-scaling (HPA / VPA) & Résilience (PDB)
*   **HPA (Horizontal Pod Autoscaler)** : HPAs actifs pour `portal-web` et les microservices Laravel avec des règles de scale-up agressives en production (`maxSurge: 2-3`, stabilization window à 0s pour faire face aux pics de charge).
*   **VPA (Vertical Pod Autoscaler)** : **Absent**. Aucun manifest de type VerticalPodAutoscaler n'est configuré pour ajuster dynamiquement les limites CPU/RAM des microservices ou de la DB.
*   **PDB (Pod Disruption Budget)** : Très bien configurés pour assurer la haute disponibilité en limitant l'indisponibilité à 1 pod lors des évènements de drainage (`minAvailable: 1` ou `2`).

### 1.6 RBAC & ServiceAccounts
*   Chaque service dispose d'un ServiceAccount dédié.
*   **automountServiceAccountToken** : Correctement désactivé à `false` sur tous les microservices applicatifs métier pour éviter le vol de tokens de service.
*   **Exception Identifiée** : Le pod `portal-web` a `automountServiceAccountToken: true` afin de pouvoir s'authentifier auprès de Vault. Cette exception est documentée mais augmente le blast radius sur ce pod exposé publiquement.

### 1.7 Namespaces, Quotas & Limits
*   Enforcement des PSS (Pod Security Standards) au niveau du namespace `securerag-hub` :
    ```yaml
    pod-security.kubernetes.io/enforce: restricted
    ```
*   `ResourceQuota` et `LimitRange` sont déployés dans le namespace de base pour éviter les attaques par déni de service interne (Resource Exhaustion).

---

## 2. Détection des Vulnérabilités de Configuration (Findings)

### Finding K8s-01 : Workloads Infra Utilisant le Tag `:latest` [HIGH]
*   **Description** : Plusieurs déploiements de composants d'infrastructure (ex. certaines images d'outils de monitoring, Harbor ou tests) utilisent le tag d'image `:latest` au lieu de tags fixés ou de digests cryptographiques.
*   **Impact** : Risque d'instabilité au redémarrage des pods en cas de mise à jour transparente de l'image sur le registre public.
*   **Recommandation** : Pinner toutes les images de la base et des overlays avec des versions fixes et des digests.

### Finding K8s-02 : Absence de Probes de Démarrage sur les Services Lourdes [LOW]
*   **Description** : Les composants lourds comme `ollama`, `qdrant` ou `api-gateway` ne disposent pas de `startupProbe`.
*   **Impact** : En cas de chargement de modèle lourd au démarrage (ex. Ollama chargeant Mistral), le conteneur peut être tué prématurément par le `livenessProbe` s'il dépasse le délai de grâce standard.
*   **Recommandation** : Ajouter des `startupProbes` avec des tolérances élevées sur ces composants.

### Finding K8s-03 : Conteneurs Privilégiés Falco et Cilium sans Exception Validée par Sigstore [MEDIUM]
*   **Description** : Les conteneurs privilégiés nécessaires à la stack de sécurité s'exécutent avec des droits root réels sans être signés cryptographiquement en production.
*   **Impact** : Possibilité d'injecter un agent de sécurité modifié non signé dans le cluster (bypass de la Supply Chain).
*   **Recommandation** : Signer les images d'infrastructure Falco/Cilium avec Cosign et les intégrer aux règles d'admission Kyverno.

---

## 3. Scoreboard Kubernetes Security

### Note Globale : 91/100

| Domaine d'Audit | Score | Justification |
| :--- | :--- | :--- |
| **Pod Security Standards (PSS)** | 98/100 | namespaces sous PSS `restricted` stricte. Pas d'escalade de privilège, pas de pod root applicatif. |
| **Réseau (NetworkPolicies)** | 92/100 | Default-deny configuré, mais des ports d'admin (Kong 8001) et certains flux d'egress infra restent à restreindre. |
| **Haute Disponibilité & Probes** | 88/100 | HPAs, PDBs et liveness/readiness probes configurés, mais absence de startupProbes sur Ollama/Qdrant et absence de VPA. |
| **RBAC & Isolation des Comptes** | 90/100 | ServiceAccounts fin, mais token monté en clair sur le portal-web (nécessaire à Vault). |
| **Gestion des Images** | 88/100 | Kyverno bloque le non-signé et le `:latest` en prod, mais certains manifests d'infra utilisent toujours des tags mouvants. |
