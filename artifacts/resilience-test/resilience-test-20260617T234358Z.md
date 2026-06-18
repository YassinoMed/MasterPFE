# Test de Résilience HA — SecureRAG Hub

**Date :** Wed Jun 17 11:48:27 PM UTC 2026
**Service testé :** portal-web
**Namespace :** securerag-hub

## Résultats

| Vérification | Statut |
|-------------|:------:|
| HPA configuré | ✅ |
| PDB configuré | ✅ |
| Réplicas initial = 1 | ✅ |
| Pod initial Ready | ✅ |
| Montée auto des pods (HPA) | ✅ |
| Max réplicas atteint (3) | ❌ |
| Service disponible pendant scaling | ❌ |
| PDB respecté (0 violations) | ✅ |
| Retour à 1 réplica | ✅ |
| Déploiement final = 1 replica | ✅ |

**Score :** 11/13 (84%)

## Métriques

- Temps de scale-up : 5s
- Temps de scale-down : 10s
- HPA CPU threshold : 70%
- PDB minAvailable : 1
