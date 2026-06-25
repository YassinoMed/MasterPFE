# Phase 9 — Performance & Load Test Review

Ce document présente l'audit des performances physiques et logiques de la plateforme, basé sur les métriques système, la consommation des ressources (CPU, RAM, Stockage) et les résultats récents des tests de charge k6 (`reports/k6/`).

---

## 1. Analyse des Résultats des Tests de Charge (k6 Load Tests)

Les données de performance de la dernière campagne de tests de charge (datée du 25 Juin 2026) fournissent des métriques de référence sous une charge de **50 Utilisateurs Virtuels (VUs)** :

### 1.1 Métriques de Débit (Throughput)
*   **Nombre de requêtes HTTP traitées** : 27 795 requêtes.
*   **Taux de requêtes par seconde** : **92,43 reqs/s**.
*   **Taux de succès HTTP** : **100,00 %** (0 échec HTTP détecté sur l'ensemble des runs).
*   **Volume de données échangées** : 51,9 MB reçus (~172,7 KB/s) et 5,2 MB émis (~17,4 KB/s).

### 1.2 Métriques de Latence (Latency)
*   **Temps de réponse moyen (Average Request Duration)** : **17,00 ms**.
*   **Médiane (Median)** : 10,35 ms.
*   **Percentile 90 (P90)** : 32,19 ms.
*   **Percentile 95 (P95)** : **46,34 ms** (Le seuil cible de 200 ms est largement respecté).
*   **Temps de réponse maximum (Max)** : 594,78 ms (Spike de démarrage réseau lors du premier appel).

### 1.3 Latence par Microservice (Health & API Endpoints)
Tous les microservices métier respectent l'exigence de temps de réponse inférieur à 500 ms sur leurs endpoints de santé :
*   `portal-web` : 100% de succès, durée moyenne < 15 ms.
*   `auth-users-service` : 100% de succès, durée moyenne < 20 ms.
*   `chatbot-manager-service` : 100% de succès, durée moyenne < 20 ms.
*   `conversation-service` : 100% de succès, durée moyenne < 25 ms.
*   `audit-security-service` : 100% de succès, durée moyenne < 15 ms.

---

## 2. Analyse des Ressources Systèmes (CPU, RAM, Stockage, Réseau)

### 2.1 Surconsommation (Overconsumption / Hot Spots)
1.  **AI Inference Service / CyberGuard Model** : S'exécutant sur CPU uniquement dans le cluster local, le chargement et l'analyse via le modèle de sécurité HuggingFace PyTorch s'avèrent gourmands en calcul (consommation de 2 à 4 cœurs CPU complets par thread d'analyse). 
    *   *Mitigation* : Le **Heuristic Fallback Engine** (`ai-security/app.py`) évite la saturation en basculant sur des expressions régulières et des arbres de décision légers si la file d'attente d'inférence dépasse 100 ms.
2.  **Ollama (LLM Local)** : L'invocation de modèles de type LLaMA3 ou Mistral sur CPU sans carte graphique GPU dédiée sature instantanément les ressources du nœud Kind (100% CPU, latence par token supérieure à 1,5 seconde).

### 2.2 Sous-utilisation (Underutilization)
*   **Microservices Laravel** : En l'absence de trafic, les pods Laravel consomment moins de 5m CPU et 45Mi RAM par réplicat. Cette empreinte minimale s'explique par l'utilisation de serveurs web PHP-FPM légers sous Alpine, mais représente une opportunité de consolidation (ex. réduction des instances minimales hors période d'activité).

### 2.3 Saturation (Bottlenecks)
*   **Base de Données PostgreSQL** : L'utilisation de volumes persistants ou de bases SQLite locales en écriture séquentielle sature le disque en cas d'écriture massive de logs d'audit ou d'historique de chat.
*   **Network Saturation** : Pas de compression Gzip active par défaut sur les flux inter-services, augmentant inutilement le trafic réseau interne (Egress/Ingress Pods).

---

## 3. Scoreboard Performance

### Note Globale : 90/100 (Performance Score)

| Critère d'Audit | Score | Justification |
| :--- | :--- | :--- |
| **Temps de Réponse (Latence)** | 98/100 | Moyenne de 17 ms et P95 à 46 ms sous charge de 50 VUs. Performance exceptionnelle pour une stack microservices. |
| **Débit et Fiabilité** | 100/100 | 100% de requêtes OK, aucun échec ou timeout détecté sur 27k+ requêtes. |
| **Optimisation des Ressources** | 72/100 | CPU saturé par Ollama et l'Inference Engine en mode CPU-only. Pas de GPU-passthrough configuré. |
| **Configuration Réseau & IO** | 90/100 | IO disque limitées par l'écriture synchrone des logs d'audit. |
