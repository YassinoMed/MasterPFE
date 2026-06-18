# Test de Résilience HA — SecureRAG Hub

**Date :** Thu Jun 18 12:30:33 AM UTC 2026
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
| Max réplicas atteint (3) | ✅ |
| Service disponible pendant scaling | ✅ |
| PDB respecté (0 violations) | ✅ |
| Retour à 1 réplica | ✅ |
| Déploiement final = 1 replica | ✅ |

**Score :** 13/13 (100%)

## Métriques

- Temps de scale-up : 15s
- Temps de scale-down : 180s
- HPA CPU threshold : 70%
- PDB minAvailable : 1
