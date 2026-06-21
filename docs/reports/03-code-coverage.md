# 03 — Code Coverage

> **Date :** 2026-06-18  
> **Verdict :** ✅ PASS

---

## Résumé Exécutif

**Couverture globale : 87.09%** (1,235/1,418 statements). Le seuil minimal de 80% est atteint.

---

## Couverture par Service

| Service | Line-Rate | Covered | Total |
|---------|:---------:|:-------:|:-----:|
| portal-web | 88.2% | — | — |
| auth-users-service | 85.4% | — | — |
| chatbot-manager-service | 86.3% | — | — |
| conversation-service | 87.1% | — | — |
| audit-security-service | 88.5% | — | — |
| **Global** | **87.09%** | **1,235** | **1,418** |

---

## Seuils

| Métrique | Seuil | Atteint | Statut |
|----------|:-----:|:-------:|:------:|
| Line-rate minimum | 80% | 87.09% | ✅ PASS |
| Fichiers couverts | — | 84 | ✅ |
| Services ≥ 80% | 5/5 | 5/5 | ✅ PASS |

---

## Détail

- Fichiers analysés : 84
- Statements couverts : 1,235
- Statements total : 1,418
- Coverage driver : Xdebug 3.4.0
- PHP version : 8.4.22

---

## Recommandations

- Maintenir la couverture ≥ 85%
- Ajouter des tests sur les chemins d'erreur
- Cibler 90%+ pour les services critiques (auth-users, audit-security)

---

## Conclusion

Coverage gate passée (87.09% > 80%). Tous les services respectent le seuil minimal. La qualité du code est satisfaisante.
