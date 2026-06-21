# 09 — Haute Disponibilité

> **Date :** 2026-06-18  
> **Verdict :** ❌ FAIL

---

## Résumé Exécutif

La validation HA a échoué sur les paramètres `maxSurge` des rolling updates. Les valeurs actuelles (maxSurge=1) sont insuffisantes pour garantir un déploiement sans interruption de service.

---

## Stratégie de Rolling Update

| Service | maxSurge | maxUnavailable | Attendu maxSurge | Statut |
|---------|:--------:|:--------------:|:----------------:|:------:|
| portal-web | 1 | 0 | 3 | ❌ |
| auth-users | 1 | 0 | 2 | ❌ |
| chatbot-manager | 1 | 0 | 2 | ❌ |
| conversation-service | 1 | 0 | 2 | ❌ |
| audit-security-service | 1 | 0 | 2 | ❌ |

---

## Anti-Affinité

| Service | PodAntiAffinity | TopologyKey |
|---------|:---------------:|-------------|
| portal-web | ✅ preferred | kubernetes.io/hostname |
| auth-users | ✅ preferred | kubernetes.io/hostname |
| chatbot-manager | ✅ preferred | kubernetes.io/hostname |
| conversation-service | ✅ preferred | kubernetes.io/hostname |
| audit-security-service | ✅ preferred | kubernetes.io/hostname |

---

## Réplicas

| Service | Réplicas |
|---------|:--------:|
| portal-web | 1 |
| auth-users | 1 |
| chatbot-manager | 1 |
| conversation-service | 1 |
| audit-security-service | 1 |

---

## Score HA

| Métrique | Score |
|----------|:-----:|
| Rolling update strategy | 0/5 |
| PodAntiAffinity | 5/5 |
| PDB | 5/5 |
| HPA | 1/5 |
| Multi-replica | 0/5 |
| **Score HA** | **11/25 (44%)** |

---

## Recommandations

1. Corriger `maxSurge` dans les patches HA production
2. Augmenter les réplicas à 2 minimum pour chaque service
3. Activer HPA pour tous les services (pas seulement portal-web)

---

## Conclusion

La HA est partiellement configurée. Les PDB et AntiAffinity sont en place mais les rolling updates et le nombre de réplicas doivent être améliorés.
