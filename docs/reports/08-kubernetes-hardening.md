# 08 — Kubernetes Hardening

> **Date :** 2026-06-18  
> **Verdict :** ✅ PASS

---

## Résumé Exécutif

**10/10 contrôles PASS.** Le namespace `securerag-hub` est entièrement hardened avec Pod Security Standards en mode Enforce Restricted, ResourceQuota, LimitRange, NetworkPolicy default-deny, et 5 PDBs.

---

## Résultats Détaillés

| # | Contrôle | Statut |
|:-:|----------|:------:|
| 1 | PSA Enforce Restricted | ✅ PASS |
| 2 | ResourceQuota | ✅ PASS |
| 3 | LimitRange | ✅ PASS |
| 4 | portal-web hardened | ✅ PASS |
| 5 | auth-users hardened | ✅ PASS |
| 6 | chatbot-manager hardened | ✅ PASS |
| 7 | conversation-service hardened | ✅ PASS |
| 8 | audit-security-service hardened | ✅ PASS |
| 9 | Default-deny NetworkPolicy | ✅ PASS |
| 10 | 5 PodDisruptionBudgets | ✅ PASS |

---

## Détail Hardening par Service

| Service | runAsNonRoot | RO RootFS | Drop ALL Caps | Seccomp | Probes | Resources |
|---------|:------------:|:---------:|:-------------:|:-------:|:------:|:---------:|
| portal-web | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| auth-users | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| chatbot-manager | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| conversation-service | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| audit-security-service | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

---

## Pod Security Standards

| Label | Valeur |
|-------|--------|
| `pod-security.kubernetes.io/enforce` | restricted |
| `pod-security.kubernetes.io/enforce-version` | latest |
| `pod-security.kubernetes.io/audit` | restricted |
| `pod-security.kubernetes.io/warn` | restricted |

---

## ServiceAccounts

| SA | Namespace |
|----|-----------|
| sa-portal-web | securerag-hub |
| sa-auth-users | securerag-hub |
| sa-chatbot-manager | securerag-hub |
| sa-conversation-service | securerag-hub |
| sa-audit-security-service | securerag-hub |
| sa-postgres-auth | securerag-hub |

---

## Recommandations

1. Ajouter des limits CPU/Memory explicites sur les initContainers
2. Activer Falco pour la détection runtime
3. Ajouter des policies OPA Gatekeeper

---

## Conclusion

Le hardening Kubernetes est excellent. Tous les contrôles sont PASS. La plateforme respecte les standards de sécurité les plus stricts.
