# Test de Résilience HA — SecureRAG Hub

**Date :** Wed Jun 17 11:30:33 PM UTC 2026
**Service testé :** portal-web
**Namespace :** securerag-hub

## Résultats

| Vérification | Statut |
|-------------|:------:|
| HPA configuré | ✅ |
| PDB configuré | ✅ |
| Réplicas initial = 1 | ✅ |
| Pod initial Ready | ✅ |
| Montée auto des pods (HPA) | ❌ |
| Max réplicas atteint (3) | ❌ |
| Service disponible pendant scaling | ✅ |
| PDB respecté (0 violations) | ✅ |
| Retour à 1 réplica | ✅ |
| Déploiement final = 1 replica | ✅ |

**Score :** 12/14 (85%)

## Métriques

- Temps de scale-up : 0s
- Temps de scale-down : 0s
- HPA CPU threshold : 70%
- PDB minAvailable : 1
