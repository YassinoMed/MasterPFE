# 28 — Performance k6

> **Date :** 2026-06-18  
> **Verdict :** ⚠️ NOT EXECUTED

---

## Résumé Exécutif

k6 n'est pas installé. Les scripts de test de performance sont complets (smoke, load, stress, spike, soak) avec des seuils SLO définis mais pas exécutés.

---

## Scripts Disponibles

| Script | Type | Seuils SLO |
|--------|:----:|------------|
| `tests/load/k6-load-test.js` | Multi-scenario | p95<500ms, p99<1s, failure<1% |
| `tests/load/k6-api-load-test.js` | Per-service | p95<300ms (auth), p95<400ms (chatbot) |
| `tests/performance/k6-smoke-test.js` | Smoke | Validation baseline |
| `tests/performance/k6-load-test.js` | Load | p95<500ms |
| `tests/performance/k6-spike-test.js` | Spike | Résilience pic |
| `tests/performance/k6-endurance-test.js` | Soak | Stabilité 30min |

---

## Seuils SLO Configurés

| Service | p95 Target | p99 Target |
|---------|:----------:|:----------:|
| auth-users | < 300ms | < 1s |
| portal-web | < 500ms | < 1s |
| chatbot-manager | < 400ms | < 1s |
| conversation-service | < 500ms | < 1s |
| audit-security-service | < 500ms | < 1s |

---

## Recommandations

1. Installer k6 CLI
2. Exécuter les tests en mode smoke d'abord
3. Intégrer k6 dans le pipeline CI (stage performance)
4. Configurer des alertes Prometheus basées sur les résultats k6

---

## Conclusion

Les scripts k6 sont prêts avec des seuils SLO réalistes. L'exécution et l'intégration CI sont les seules étapes manquantes.
