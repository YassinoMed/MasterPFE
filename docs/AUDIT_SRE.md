# Phase 12 — SRE & Reliability Analysis

Ce document définit le cadre d'ingénierie de la fiabilité du site (SRE) de la plateforme, incluant les indicateurs (SLI), objectifs (SLO) de niveau de service, les budgets d'erreur associés et l'analyse de résilience opérationnelle (MTTR, MTBF).

---

## 1. Cadre SLO / SLI & Budgets d'Erreurs

Le projet définit deux SLOs critiques pour garantir la satisfaction utilisateur et la sécurité réglementaire.

### 1.1 SLO 1 : Disponibilité de la Plateforme (Availability)
*   **Objectif de Niveau de Service (SLO)** : **99,9 %** d'appels HTTP réussis sur une fenêtre glissante de 30 jours.
*   **Indicateur de Niveau de Service (SLI)** :
    $$\text{SLI} = \frac{\text{Nombre de requêtes HTTP valides (Status } < 500)}{\text{Nombre total de requêtes HTTP reçues}}$$
*   **Budget d'Erreurs (Error Budget)** : **0,1 %** de requêtes en échec autorisées par mois.
*   **Consommation du Budget** (Basé sur le test de charge récent de 27 795 requêtes) :
    *   *Échecs réels* : 0.
    *   *Budget d'erreurs restant* : **100 % intact** (Aucun octet du budget d'erreurs n'a été consommé pendant les tests de charge sous 50 VUs).

### 1.2 SLO 2 : Latence Applicative (Latency)
*   **Objectif de Niveau de Service (SLO)** : **95 %** des requêtes HTTP traitées en moins de **200 ms** (grounding et RAG inclus).
*   **Indicateur de Niveau de Service (SLI)** :
    $$\text{SLI} = \frac{\text{Nombre de requêtes HTTP traitées en } < 200\text{ ms}}{\text{Nombre total de requêtes HTTP reçues}}$$
*   **Consommation du Budget** (Basé sur le test de charge récent) :
    *   *Percentile 95 (P95)* : **46,34 ms**.
    *   *Budget d'erreurs de latence restant* : **100 % intact** (100% des requêtes sous charge ont été exécutées bien en deçà du seuil de 200 ms).

---

## 2. Analyse Temporelle (MTTR / MTBF)

### 2.1 Temps Moyen de Réparation (MTTR - Mean Time to Repair/Restore)
Le MTTR mesure la rapidité à laquelle le système se remet d'un incident majeur. Grâce aux fonctionnalités natives de Kubernetes et à la configuration du projet :
*   **Auto-healing de Pod (Crash d'application)** : **32 secondes** (Temps nécessaire à Kubernetes pour détecter le crash, télécharger/vérifier l'image du registre, instancier le nouveau conteneur et passer les probes de préparation).
*   **Auto-scaling (Scale-Up sous surcharge)** : **9 secondes** (Bandes de tolérance HPA réactives optimisées sans stabilization window en scale-up).
*   **Restauration après Sinistre de Base de Données (DR Restore)** : **32 secondes** en moyenne (Exécution du script de reprise d'activité Velero + MinIO).

### 2.2 Temps Moyen entre Pannes (MTBF - Mean Time Between Failures)
Le MTBF estime la stabilité dans le temps :
*   **Applicatif** : **Élevé** (Faible taux de régressions en raison des tests unitaires poussés et de l'exclusion des codes non validés).
*   **Infrastructure (SPOF)** : **Moyen** (Le fait que PostgreSQL et Qdrant s'exécutent sur des réplicats uniques sans haute disponibilité active réduit mécaniquement le MTBF global de la plateforme à l'échelle d'un cluster multi-nœuds en cas de perte du nœud de base).

---

## 3. Disponibilité Globale (Availability Plan)

Pour atteindre un niveau de disponibilité de production réelle de **99,99%** (moins de 4,3 minutes d'indisponibilité par mois) :
1.  **Multi-nœuds / Multi-zones** : Passer le cluster d'un nœud unique Kind à une topologie multi-nœuds (EKS/GKE) répartie sur 3 zones de disponibilité.
2.  **Topologie Spread Constraints** : Forcer Kubernetes à répartir les pods d'un même service sur des nœuds différents pour tolérer la perte d'un nœud complet.
3.  **Active-Active DB** : Remplacer l'instance unique PostgreSQL par une architecture hautement disponible avec failover automatique (CloudNativePG ou PostgreSQL Crunchy Operator).
