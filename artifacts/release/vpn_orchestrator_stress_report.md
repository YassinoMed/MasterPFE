# Rapport de Stress Test Performance - AI Orchestrator Multi-Master
*   **Hôte cible** : `http://10.15.10.119:8082/api/v1/security/council`
*   **Nombre de requêtes** : `120`
*   **Parallélisme (Concurrency)** : `30` threads
*   **Durée totale du test** : `28.80 secondes`
*   **Débit moyen (Throughput)** : `4.17 req/s`

## 1. Métriques de Latence et Succès
| Indicateur | Valeur |
| :--- | :--- |
| **Taux de succès** | `84.17%` (101/120) |
| **Taux d'échec** | `15.83%` (19/120) |
| **Latence Minimale** | `592.11 ms` |
| **Latence Moyenne** | `5177.89 ms` |
| **Latence p95** | `11926.42 ms` |
| **Latence p99** | `13799.42 ms` |
| **Latence Maximale** | `13909.54 ms` |

## 2. Répartition des Erreurs
| Code HTTP | Nombre d'occurrences |
| :--- | :--- |
| `500` | `19` |
