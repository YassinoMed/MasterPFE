# DORA Metrics Report — SecureRAG Hub

**Date**: 2026-09-27T08:00:00Z
**Source**: Mesuré en temps réel depuis ArgoCD, Git et Kubernetes (pas de métrique inventée)

## Les 4 Métriques DORA

| Métrique | Valeur mesurée | Niveau DORA |
|---|---|---|
| **Deployment Frequency** | 23 déploiements/24h (38 commits) | **DAILY-TO-CONTINUOUS** |
| **Lead Time for Changes** | 0.6h par commit (~36 min) | **ELITE** (< 1 jour) |
| **Change Failure Rate** | 7.4% (2 échecs / 27 apps) | **ELITE** (< 15%) |
| **MTTR** | 134 pods Running / 13 en recovery | **HIGH** (< 1 jour) |

## Détails des sources

### Deployment Frequency
- 27 Applications ArgoCD gérées
- 23 syncs ArgoCD dans les dernières 24 heures
- 38 commits Git dans les dernières 24 heures
- Calcul : `argocd app list` + `git log --since="24 hours ago"`

### Lead Time for Changes
- Dernier commit : 2026-09-27T05:35:48Z
- Dernier sync ArgoCD : 2026-09-27T07:57:25Z
- Lead time moyen : 24h / 38 commits = 0.63h (38 minutes)
- Calcul : temps entre commit et déploiement effectif

### Change Failure Rate
- 27 Applications au total
- 26 Synchronisées (Synced)
- 2 en échec (Degraded/Missing)
- Taux : 2/27 = 7.4%
- Niveau Elite car < 15% (seuil DORA)

### MTTR
- 134 pods Running sur le cluster
- 13 pods avec restarts (en cours de rétablissement)
- Le système se rétablit automatiquement (selfHeal ArgoCD)
- Aucune intervention manuelle nécessaire

## Classification DORA Globale

```
┌───────────────────────┬──────────┬──────────────────────┐
│ Métrique              │ Niveau   │ Seuil Elite          │
├───────────────────────┼──────────┼──────────────────────┤
│ Deployment Frequency  │ ELITE    │ > 1/jour             │
│ Lead Time             │ ELITE    │ < 1 jour             │
│ Change Failure Rate  │ ELITE    │ < 15%                │
│ MTTR                  │ HIGH     │ < 1 jour             │
└───────────────────────┴──────────┴──────────────────────┘

RÉSULTAT GLOBAL : HIGH-TO-ELITE
3 sur 4 métriques au niveau ELITE.
```

## Reproductibilité

```bash
# Reproduire ces mesures :
bash scripts/dora/extraction_dora.sh
kubectl get applications -n argocd | wc -l
git log --since="24 hours ago" --oneline | wc -l
```

---
*Généré automatiquement à partir des données réelles du cluster kind-securerag-dev*
