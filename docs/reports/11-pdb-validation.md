# 11 — PDB Validation

> **Date :** 2026-06-18  
> **Verdict :** ⚠️ WARNING

---

## Résumé Exécutif

**5 PodDisruptionBudgets configurés, un par service.** Tous utilisent `minAvailable: 1`. Avec un seul réplica par service, les PDBs interdisent toute disruption volontaire (allowed disruptions = 0).

---

## PDBs Configurés

| Service | Min Available | Max Unavailable | Allowed Disruptions | Statut |
|---------|:-------------:|:---------------:|:-------------------:|:------:|
| portal-web | 1 | N/A | 0 | ⚠️ |
| auth-users | 1 | N/A | 0 | ⚠️ |
| chatbot-manager | 1 | N/A | 0 | ⚠️ |
| conversation-service | 1 | N/A | 0 | ⚠️ |
| audit-security-service | 1 | N/A | 0 | ⚠️ |

---

## Analyse

- **Allowed disruptions = 0** signifie qu'aucun pod ne peut être évincé volontairement (kubectl drain, node maintenance)
- Ce blocage est dû au fait que chaque service n'a qu'**1 réplica**
- Avec `minAvailable: 1` et 1 réplica, la disruption est impossible

---

## Recommandations

1. Augmenter les réplicas à 2 minimum pour tous les services
2. Passer à `maxUnavailable: 1` pour permettre les rolling updates
3. Alternative : `minAvailable: 50%` pour les services avec 2+ réplicas

---

## Conclusion

Les PDBs sont correctement configurés mais inefficaces avec 1 seul réplica. L'augmentation des réplicas à 2+ débloquera la résilience.
