# 32 — DORA Metrics

> **Date :** 2026-06-18  
> **Verdict :** ⚠️ WARNING

---

## Résumé Exécutif

Les métriques DORA sont partiellement suivies via Jenkins CI/CD mais pas visualisées dans un dashboard dédié. Aucun dashboard "Four Keys" n'est déployé.

---

## Métriques DORA

| Métrique | Définition | Valeur Estimée | Dashboard |
|----------|------------|:--------------:|:---------:|
| Deployment Frequency | Merges vers main | Plusieurs/jour | ❌ |
| Lead Time | Pipeline duration | ~15-20 min | ❌ |
| MTTR | Rollback + fix | ~30-60 min | ❌ |
| Change Failure Rate | Échecs post-déploiement | < 5% | ❌ |

---

## Pipeline CI/CD

| Métrique | Valeur |
|----------|:------:|
| Stages CI | 15+ |
| Stages CD | 15+ |
| Quality Gates | 11 |
| Rollback scripts | ✅ Disponibles |

---

## Recommandations

1. Créer un dashboard Grafana "Four Keys" avec les métriques DORA
2. Taguer chaque release avec un ID unique
3. Collecter les métriques de déploiement depuis Jenkins API
4. Ajouter un stage CI qui publie les métriques DORA

---

## Conclusion

Les pratiques DORA sont bonnes (déploiements fréquents, quality gates) mais non mesurées formellement. Score : 50%.
