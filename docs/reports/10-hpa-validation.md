# 10 — HPA Validation

> **Date :** 2026-06-18  
> **Verdict :** ⚠️ WARNING

---

## Résumé Exécutif

**1 seul HPA sur 5 services.** Seul portal-web dispose d'un HPA configuré. Les 4 autres services (auth-users, chatbot-manager, conversation-service, audit-security-service) n'ont pas d'autoscaling.

---

## HPA Actifs

| Service | Target | Current | Min | Max | Réplicas | Statut |
|---------|--------|:-------:|:---:|:---:|:--------:|:------:|
| portal-web | cpu: 70% | 2% | 1 | 3 | 1 | ✅ |

---

## Services sans HPA

| Service | Statut |
|---------|:------:|
| auth-users | ❌ Manquant |
| chatbot-manager | ❌ Manquant |
| conversation-service | ❌ Manquant |
| audit-security-service | ❌ Manquant |

---

## Métriques

| Métrique | Valeur |
|----------|:------:|
| HPA configurés | 1/5 (20%) |
| Métrique CPU | portal-web: 2%/70% |
| Période de stabilisation | 0s (scale-up optimisé) |
| Max pods | 3 (portal-web) |

---

## Recommandations

1. Ajouter HPA pour les 4 services manquants
2. Configurer HPA sur mémoire en plus du CPU
3. Définir min=2, max=5 pour les services critiques
4. Ajouter des métriques custom (requests par seconde, latence)

---

## Conclusion

L'autoscaling est insuffisant. Seul portal-web est couvert. L'ajout de HPA pour tous les services est prioritaire pour la résilience.
