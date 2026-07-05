# Rapport de Stress Test Performance - Inference Server GPU
*   **Hôte cible** : `http://10.15.10.119:8000/api/predict`
*   **Nombre de requêtes** : `120`
*   **Parallélisme (Concurrency)** : `30` threads
*   **Durée totale du test** : `1.95 secondes`
*   **Débit moyen (Throughput)** : `61.40 req/s`

## 1. Métriques de Latence et Succès
| Indicateur | Valeur |
| :--- | :--- |
| **Taux de succès** | `100.00%` (120/120) |
| **Taux d'échec** | `0.00%` (0/120) |
| **Latence Minimale** | `92.66 ms` |
| **Latence Moyenne** | `241.89 ms` |
| **Latence p95** | `1191.87 ms` |
| **Latence p99** | `1270.82 ms` |
| **Latence Maximale** | `1286.42 ms` |

## 2. Répartition des Erreurs
🟢 Aucune erreur réseau ou applicative détectée.
