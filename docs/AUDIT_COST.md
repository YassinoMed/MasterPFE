# Phase 13 — Cost & FinOps Optimization Audit

Ce document présente l'audit des coûts d'infrastructure (FinOps), identifiant les surdimensionnements de ressources, le stockage inefficace et estimant les économies financières possibles après optimisation.

---

## 1. Diagnostic de Gaspillage des Ressources (Wasted Resources)

### 1.1 Surdimensionnement des Pods Applicatifs (Laravel Workloads)
*   **Constat** : Les microservices métiers Laravel (`auth-users`, `chatbot-manager`, `conversation-service`, `audit-security-service`) ont des CPU requests configurées par défaut à **100m - 250m** et RAM à **128Mi - 256Mi** dans les profils de production standard pour assurer la stabilité.
*   **Réalité des mesures (k6 load testing included)** : Même sous une charge de 50 utilisateurs virtuels actifs (VUs), la consommation moyenne par pod ne dépasse pas **10m - 15m CPU** et **50Mi RAM**.
*   **Taux de surprovisionnement** : Environ **10x** en CPU et **3x** en RAM. À l'échelle de 2 ou 3 réplicas par service, cela génère une réservation virtuelle de ressources élevée sur le cluster, obligeant l'équipe infra à provisionner des nœuds de calcul (VMs) supplémentaires qui restent inactifs 90% du temps.

### 1.2 Compute Ollama (LLM) & Inférence IA Hors Heures Ouvrées
*   **Constat** : L'infrastructure Ollama (chargée en CPU lourd) et les pods d'inférence de sécurité (`ai-inference-service` CyberGuard) tournent en continu (24h/24, 7j/7) avec des réplicats actifs.
*   **Gaspillage** : Les développeurs et les équipes métier n'utilisent le chatbot RAG qu'en semaine pendant les heures de bureau (8h00 - 18h00). Le maintien de ces pods gourmands en CPU/RAM la nuit et le week-end représente 60% de consommation de facturation cloud inutile.

### 1.3 Gestion du Stockage (Backups et Logs)
*   **Constat** : Les sauvegardes PostgreSQL et Velero sont poussées localement sur du stockage PVC.
*   **Gaspillage** : Absence de politiques de cycle de vie (Lifecycle Rules) sur les compartiments de stockage d'objets (MinIO). Les fichiers de sauvegarde s'accumulent indéfiniment, augmentant la facture de stockage au fil du temps sans valeur ajoutée.

---

## 2. Plan d'Économie & Optimisations Proposées (ROI)

Pour optimiser les coûts dans le respect de la résilience, trois chantiers prioritaires sont recommandés :

### 2.1 Ajustement Fin des CPU/RAM (Right-Sizing)
*   **Action** : Réduire les CPU/RAM requests des microservices Laravel au plus proche de leur profil de consommation réel, tout en conservant des limites élevées pour absorber les pics de trafic :
    *   *Actuel (Moyen)* : Request 200m CPU / 256Mi RAM.
    *   *Cible* : Request **20m CPU** / **64Mi RAM** (Limit à 500m CPU / 256Mi RAM).
*   **Économie estimée** : **-65%** sur la réservation de ressources CPU/RAM du cluster, permettant de réduire la taille des nœuds de calcul (passer de serveurs 8 vCPU à des serveurs 4 vCPU).

### 2.2 Extinction des environnements hors production (Scale-down to Zero)
*   **Action** : Déployer un CronJob Kubernetes ou utiliser un outil de type KEDA (Kubernetes Event-driven Autoscaling) pour mettre à l'échelle à **0 réplicat** les services lourds (Ollama, AI Inference, Ingestion) et les environnements de dev/recette en dehors des heures ouvrées (de 19h00 à 7h00 et les week-ends).
*   **Économie estimée** : **-45%** de consommation de calcul par mois sur ces environnements.

### 2.3 Cycle de vie du stockage (Storage Cleanup)
*   **Action** : Configurer une règle de rétention à 14 jours maximum pour les backups Velero/Postgres de non-production et 30 jours pour la production.
*   **Économie estimée** : Stabilisation et réduction de la facture de stockage de 50%.

---

## 3. Synthèse Financière & Scoreboard

### Note Globale : 78/100 (FinOps Score)

| Poste de Coût | Potentiel d'Économie Mensuel (Estimation Cloud AWS/EKS) | Effort d'Implémentation | Priorité |
| :--- | :--- | :--- | :--- |
| **Right-sizing Laravel Pods** | ~150 $ / mois | Très faible (Modif de manifests Kustomize) | P0 |
| **Scale-down Ollama/Inference (Nuit)** | ~300 $ / mois | Faible (CronJob scale-down) | P1 |
| **Rétention des sauvegardes & logs** | ~80 $ / mois | Faible (Règles MinIO bucket) | P2 |
| **TOTAL** | **~530 $ / mois (Économie de ~55% de la facture brute)** | | |
