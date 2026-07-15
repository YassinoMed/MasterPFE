# 🌐 ARCHITECTURE FINALE DE SÉCURITÉ ET D'INFRASTRUCTURE — SECURERAG HUB

Ce document présente l'architecture cible et finale de la plateforme **SecureRAG Hub**. Contrairement au setup de développement initial basé sur Kind, cette architecture de niveau entreprise est conçue pour la production, orchestrée par **Terraform** pour le provisionnement multi-cloud/on-prem, configurée par **Ansible** pour le bootstrapping et durcie selon le modèle de sécurité **Zero-Trust**.

---

## 🗺️ 1. Schéma Global de l'Architecture Technique

```mermaid
flowchart TD
    subgraph Client [Accès Utilisateur]
        User[Navigateur Web / API Client]
    end

    subgraph Edge [Couche d'Accès & Edge]
        LB[Load Balancer / VIP Keepalived]
        Ingress[Ingress Controller Nginx / Cilium Ingress]
    end

    subgraph ControlPlane [Plan de Contrôle Kubernetes HA]
        HAP[HAProxy API Server LB]
        KAS1[kube-apiserver cp01]
        KAS2[kube-apiserver cp02]
        KAS3[kube-apiserver cp03]
        etcd[(etcd cluster chiffré)]
    end

    subgraph DataPlane [Nœuds Workers Applicatifs]
        subgraph PodsWeb [portal-web]
            PW[portal-web Laravel]
        end
        
        subgraph PodsServices [Services Internes - Laravel]
            AS[auth-users-service]
            CM[chatbot-manager-service]
            CS[conversation-service]
            AUD[audit-security-service]
        end

        subgraph SecurityRuntime [Sécurité Active & Politiques]
            Kyverno[Kyverno Policy Engine]
            Falco[Falco eBPF DaemonSet]
            Talon[Falco Talon Active Remediation]
        end

        subgraph DataStores [Persistance & Vecteurs]
            QD[(Qdrant Vector Database)]
            PG[(PostgreSQL HA)]
            OL[Ollama LLM local]
        end
    end

    subgraph External [Services de Sécurité & Stockage]
        Vault[HashiCorp Vault]
        S3[(Sauvegardes S3 / MinIO Chiffrées)]
    end

    %% Connexions et flux
    User -->|HTTPS| LB
    LB -->|Port 443 / 80| Ingress
    Ingress -->|L7 Routing| PW
    
    %% API Server
    KAS1 & KAS2 & KAS3 <--> etcd
    HAP --> KAS1 & KAS2 & KAS3

    %% Flow applicatif
    PW -->|RBAC/JWT Sanctum| AS
    PW -->|Orchestration RAG| CM
    PW -->|Sessions / WebSockets| CS
    CM -->|Validation Prompt & Reponse| AUD
    CM -->|Vecteurs Filtrés RBAC| QD
    CM -->|Appel LLM| OL
    AS & CS & AUD -->|TCP 5432| PG

    %% Vault secrets integration
    Vault -.->|External Secrets Operator| PodsServices
    
    %% Falco Runtime Monitoring
    Falco -->|Alertes temps-réel| Talon
    Talon -->|Action: Bloquer IP / Kill Pod| PodsServices
```

---

## 🛠️ 2. La Transition d'Infrastructure : Kind vs. Terraform + Ansible

L'architecture s'affranchit de **Kind** (qui reste dédié au développement local très rapide) pour un déploiement robuste multi-nœuds en production.

```mermaid
sequenceDiagram
    participant TF as Terraform
    participant Cloud as Cloud Provider (VMs, Réseau)
    participant Ans as Ansible
    participant K8s as Cluster Kubernetes (Kubeadm)
    
    rect rgb(240, 248, 255)
        note right of TF: Phase 1 : Provisionnement (Terraform)
        TF->>Cloud: Crée VPC, Sous-réseaux, Firewall & Security Groups
        TF->>Cloud: Crée 3 VMs Control Plane & 3 VMs Workers
        TF-->>Ans: Génère l'inventaire dynamique ou les variables d'IPs
    end
    
    rect rgb(245, 245, 220)
        note right of Ans: Phase 2 : Configuration & Bootstrap (Ansible)
        Ans->>Cloud: Configuration OS (Swap off, modules kernel overlay/br_netfilter)
        Ans->>Cloud: Installation de Containerd, Keepalived et HAProxy (VIP)
        Ans->>Cloud: Déploiement de Kubeadm, Kubelet et Kubectl
        Ans->>K8s: Initialisation du cluster (Kubeadm init) et Jonction des Workers
        Ans->>K8s: Déploiement du CNI Cilium (eBPF) et politiques de sécurité
    end
```

### Rôles du Binôme d'Infrastructure
* **Terraform** ([infra/terraform](file:///root/MasterPFE/infra/terraform)) : Déclare l'infrastructure réseau et les instances virtuelles cibles (AWS EC2/EKS, GCP, ou serveurs On-Prem Proxmox/VMware). Il gère également les comptes de service Cloud et les clés d'accès.
* **Ansible** ([infra/ansible](file:///root/MasterPFE/infra/ansible)) : Configure l'OS de base de chaque machine virtuelle, installe les dépendances, déploie les fichiers de configuration pour la haute disponibilité (`haproxy` + `keepalived`) et configure les paramètres du plan de contrôle Kubernetes via `kubeadm`.

---

## 🔒 3. Architecture de Sécurité (DevSecOps Defense in Depth)

La plateforme SecureRAG Hub applique un modèle de sécurité en couches pour respecter le principe du **Moindre Privilège** et du **Zero-Trust** :

```
+-----------------------------------------------------------------------+
|  1. SUPPLY CHAIN : SBOM (Syft), Vuln Scan (Trivy), Signature (Cosign) |
+-----------------------------------------------------------------------+
       |
+-----------------------------------------------------------------------+
|  2. ADMISSION CONTROL : Kyverno Policy Engine (Enforce Signature, PSA)|
+-----------------------------------------------------------------------+
       |
+-----------------------------------------------------------------------+
|  3. CLOISONNEMENT RÉSEAU : Cilium CNI (Micro-segmentation eBPF L7)    |
+-----------------------------------------------------------------------+
       |
+-----------------------------------------------------------------------+
|  4. SECRET MANAGEMENT : Vault + External Secrets Operator + etcd crypt |
+-----------------------------------------------------------------------+
       |
+-----------------------------------------------------------------------+
|  5. RUNTIME MONITORING : Falco + Falco Talon Active Remediation       |
+-----------------------------------------------------------------------+
```

### Description des Couches de Sécurité
1. **Supply Chain Security** :
   Toutes les images applicatives construites par les pipelines de CI (Jenkins) sont automatiquement scannées pour les vulnérabilités via **Trivy**, et un SBOM (Software Bill of Materials) est généré via **Syft**. Une signature cryptographique est apposée sur l'image avec **Cosign** avant son push dans le registre privé.
2. **Contrôle d'Admission (Admission Control)** :
   Un contrôleur d'admission **Kyverno** vérifie la signature de chaque image arrivant sur le cluster. Les conteneurs non signés par la clé officielle de l'organisation ou contenant des privilèges excessifs (s'exécutant en `root`) sont immédiatement bloqués. Les namespaces applicatifs appliquent la directive **Pod Security Admission (PSA) `restricted`**.
3. **Sécurité Réseau (Zero-Trust)** :
   Le plugin CNI **Cilium** est déployé pour assurer la micro-segmentation réseau basée sur eBPF. Par défaut, une politique `default-deny` bloque tout flux réseau non autorisé. Le filtrage s'effectue jusqu'au niveau L7 (HTTP), empêchant par exemple un pod compromis de requêter arbitrairement l'API de base de données.
4. **Gestion des Secrets & Chiffrement** :
   Les secrets applicatifs ne sont jamais stockés dans Git ni sur le disque. Ils résident dans **HashiCorp Vault** et sont injectés sous forme de Secrets Kubernetes à la volée par **External Secrets Operator (ESO)**. Les secrets stockés dans la base de données Kubernetes sont chiffrés au repos dans **etcd** via un fournisseur de chiffrement configuré lors du bootstrap Kubeadm (`EncryptionConfiguration` utilisant AES-GCM).
5. **Surveillance à l'Exécution (Runtime Security)** :
   **Falco** écoute les appels système via eBPF sur tous les nœuds pour détecter les comportements suspects (ex. lancement d'un shell interactif dans un pod, modification de fichiers systèmes, tentative d'extraction de credentials). Les alertes Falco sont transmises en temps réel à **Falco Talon**, qui applique une réponse automatisée immédiate (terminer le pod suspect ou appliquer une NetworkPolicy de quarantaine).

---

## ⚙️ 4. Flux Applicatif & Sécurité des Prompts RAG

Le cœur applicatif est développé en **Laravel** en respectant une structure DDD-light (Domain-Driven Design). Le flux de traitement des prompts est conçu pour prévenir toute tentative d'injection.

```mermaid
sequenceDiagram
    autonumber
    actor U as Utilisateur (Rôle: USER)
    participant PW as portal-web (Gateway)
    participant CM as chatbot-manager-service
    participant AUD as audit-security-service
    participant QD as Qdrant Vector Store
    participant OL as Ollama (LLM)

    U->>PW: Pose une question (Prompt)
    PW->>CM: Transmet la requête avec le JWT Sanctum
    CM->>AUD: POST /api/audit/prompt (Analyse du prompt brut)
    
    alt Prompt malveillant détecté (Prompt Injection)
        AUD-->>CM: score=88, action=BLOCKED (ex: "ignore previous...")
        CM-->>PW: HTTP 403 Forbidden
        PW-->>U: "Demande refusée pour des raisons de sécurité"
    else Prompt légitime
        AUD-->>CM: score=12, action=ALLOWED
        CM->>QD: Requête de recherche vectorielle avec filtre allowed_roles ⊇ USER
        Note over QD: Filtrage RBAC au niveau des métadonnées des chunks
        QD-->>CM: Renvoie le top-K des chunks autorisés
        CM->>OL: Envoie le Prompt enrichi (Prompt Système + Chunks + Question)
        OL-->>CM: Renvoie la réponse générée
        CM->>AUD: POST /api/audit/response (Analyse de la réponse)
        AUD-->>CM: score=8, action=ALLOWED
        CM-->>PW: Renvoie le résultat final + métadonnées d'audit
        PW-->>U: Affiche la réponse sécurisée
    end
```

---

## 📦 5. Structure des Fichiers & Composants Clés dans le Dépôt

Voici la cartographie des composants principaux dans votre espace de travail [MasterPFE](file:///root/MasterPFE/) :

* **`/infra`** : Code lié à l'infrastructure et aux déploiements
  * [infra/terraform/](file:///root/MasterPFE/infra/terraform/) : Scripts de provisionnement multi-cloud (AWS/EKS, GCP, Azure, Local Kind).
  * [infra/ansible/](file:///root/MasterPFE/infra/ansible/) : Playbooks pour le bootstrapping de clusters physiques/VMs avec Kubeadm, Keepalived et HAProxy.
  * [infra/k8s/](file:///root/MasterPFE/infra/k8s/) : Manifestes Kubernetes orchestrés par ArgoCD (ArgoCD, Kyverno, Cilium, Vault ESO, monitoring Loki/Tempo).
* **`/services-laravel`** : Modules applicatifs (PHP Laravel)
  * `portal-web` : Point d'entrée utilisateur, UI Web et routage HTTP.
  * `auth-users-service` : Authentification centralisée et gestion RBAC avec jetons d'accès Laravel Sanctum.
  * `chatbot-manager-service` : Moteur d'orchestration RAG, intégration Qdrant et LLM.
  * `conversation-service` : Gestionnaire de l'historique et de la persistance des discussions.
  * `audit-security-service` : Analyse des prompts (11 signatures d'injection) et décision d'autorisation.
* **`/tests`** : Validation et tests d'intrusion
  * Contient les tests unitaires, d'intégration et les scripts **k6** de test de charge.

---

## 🔄 6. Flux GitOps et Déploiement Continu (CD)

Le déploiement de l'infrastructure et de l'applicatif suit le modèle GitOps via **ArgoCD** :

1. **Root Application** :
   ArgoCD déploie l'application racine `securerag-root` (pattern "App of Apps") à partir de [application-root.yaml](file:///root/MasterPFE/infra/k8s/argocd/application-root.yaml).
2. **Synchronization Waves (Vagues de Synchronisation)** :
   Pour s'assurer que les composants d'infrastructure requis par les applications sont déjà opérationnels, le déploiement se fait par vagues ordonnées :
   * **Wave 1** : Namespaces globaux et configurations d'admission (Kyverno, External Secrets Operator).
   * **Wave 2** : Services de sécurité (HashiCorp Vault, Cilium Network Policies).
   * **Wave 3** : Bases de données et services de stockage (PostgreSQL, Qdrant).
   * **Wave 4** : Services applicatifs Laravel (Portal, Chatbot Manager, Audit Service).
   * **Wave 5** : Observabilité et collecteurs de traces (Loki, Tempo, Prometheus).

---

## 📈 7. Résilience & Disaster Recovery (DR)

* **Outil de sauvegarde** : **Velero** est configuré pour sauvegarder périodiquement les volumes persistants (PostgreSQL, Qdrant) et l'état des ressources Kubernetes.
* **Chiffrement et Stockage** : Les sauvegardes sont chiffrées à l'aide d'une clé **GPG** maîtresse puis externalisées vers un bucket **S3 / MinIO** distant sécurisé par des politiques d'accès strictes.
* **Validation continue** : Un script automatisé de reprise après sinistre [dr-test.sh](file:///root/MasterPFE/scripts/dr-test.sh) est exécuté périodiquement pour valider la restauration complète de l'application et mesurer le RTO (Recovery Time Objective).
