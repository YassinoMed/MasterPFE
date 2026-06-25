# Phase 14 — Gap Analysis (Analyse des Écarts)

Ce document confronte l'état actuel de la plateforme **SecureRAG Hub** aux standards d'excellence opérationnelle et de sécurité des leaders technologiques (Google, Netflix, Spotify, AWS et la CNCF).

---

## 1. Benchmarking Technologique

### 1.1 Alignement Google Production Ready Standards
*   **Exigences Google** : Rôle SRE fort, définition d'objectifs de niveau de service (SLO/SLI) clairs, instrumentation complète, plan de reprise après sinistre (DR) testé de manière automatisée.
*   **Évaluation SecureRAG Hub** : **Forte maturité**. Le projet dispose d'indicateurs SLO avancés et d'outils de restauration automatiques (Velero). 
*   **Écart principal** : Google impose l'absence totale de SPOF (Single Point of Failure) dans la couche de données. Le fait d'utiliser des instances simples (non répliquées) de PostgreSQL et Qdrant est en contradiction directe avec ce standard.

### 1.2 Alignement Netflix Chaos Engineering
*   **Exigences Netflix** : Architecture hautement résiliente (design for failure), chaos injecté en continu en production (ex. Chaos Monkey) pour valider l'auto-correction automatique, architecture active-active multi-régions.
*   **Évaluation SecureRAG Hub** : **Partielle**. Bien que des manifestes Litmus Chaos (`infra/k8s/chaos/litmus-experiments.yaml`) et des scripts de suppression de pods (`pod-delete-and-prove.sh`) existent, le chaos n'est pas injecté de manière continue en production pour tester la tolérance aux pannes des bases de données ou des API.

### 1.3 Alignement Spotify Engineering Model
*   **Exigences Spotify** : Découplage maximal des équipes et des microservices, autonomie de build et de release, simplicité extrême du développement local.
*   **Évaluation SecureRAG Hub** : **Forte**. Chaque microservice possède sa propre structure de dossiers, ses tests unitaires, son Dockerfile et son pipeline indépendant dans Jenkins. La stack Laravel-first est facile à instancier localement en SQLite.

### 1.4 Alignement AWS Well-Architected Framework (WAF)
*   **Exigences AWS** : 5 piliers (Sécurité, Fiabilité, Efficacité des performances, Excellence opérationnelle, Optimisation des coûts).
*   **Évaluation SecureRAG Hub** : **Bonne**. L'excellence opérationnelle et la sécurité sont bien couvertes (Kyverno, OPA, Semgrep, Trivy, Falco).
*   **Écart principal (Sécurité & Fiabilité)** : Chiffrement des données en transit interne non forcé (mTLS inactif par défaut), stockage de clés de chiffrement applicatives Laravel (`APP_KEY`) dans Git historique, absence de KMS managé (KMS AWS/Vault non synchronisés avec rotation automatique active).

### 1.5 Alignement CNCF Best Practices
*   **Exigences CNCF** : Sécurisation par couches (Cloud, Cluster, Container, Code), GitOps (ArgoCD) autoritaire, signature de conteneurs de bout en bout (Sigstore/Cosign), sécurité au niveau du noyau (eBPF).
*   **Évaluation SecureRAG Hub** : **Excellente**. Très fort alignement grâce à l'enforcement PSS (restricted), aux politiques réseau eBPF Cilium et à la détection Falco.
*   **Écart principal** : ArgoCD est configuré (`infra/k8s/argocd/`) mais n'est pas utilisé comme source unique de vérité dynamique pour synchroniser l'état réel avec Git (Jenkins effectue encore des push directs de Kustomize via kubectl en CD).

---

## 2. Synthèse des Écarts Critiques

| Source Standard | Écart Identifié | Gravité | Impact Operational | Action de Remédiation Prioritaire |
| :--- | :--- | :--- | :--- | :--- |
| **Google SRE** | Bases PostgreSQL et Qdrant non configurées en Haute Disponibilité. | **CRITICAL** | Perte de service totale en cas de crash du nœud hébergeant les conteneurs de base de données. | Déployer CloudNativePG et configurer Qdrant en mode cluster 3 réplicas. |
| **AWS WAF** | Communication interne inter-services en clair (sans TLS). | **HIGH** | Risque d'écoute clandestine ou d'interception de jetons d'authentification par un conteneur voisin compromis. | Activer Istio mTLS en mode Strict sur le namespace `securerag-hub`. |
| **CNCF Supply Chain** | Stack Sigstore Rekor/Fulcio locale non déployée, binaire Cosign manquant. | **HIGH** | Impossible de certifier l'intégrité de la supply chain et de bloquer réellement les conteneurs falsifiés. | Installer Cosign dans les agents Jenkins et finaliser le script `deploy-sigstore-stack.sh`. |
| **Netflix Chaos** | Absence de tests destructifs continus. | **MEDIUM** | Les mécanismes de bascule (failover) ne sont pas validés sous charge réelle. | Intégrer les expériences Litmus Chaos dans le pipeline CD de recette. |
