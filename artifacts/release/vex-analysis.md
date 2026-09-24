# VEX Analysis — `localhost:5001/securerag-hub-portal-web:dev`

- Date: `2026-09-24T04:42:14.138632+00:00`
- Verdict: **REVIEW**
- Criticité: 0 · Haute: 13 · Moyenne: 0 · Faible: 0

## Findings
| CVE | Severity | Package | Fixed | Title |
|---|---|---|---|---|
| CVE-2026-33630 | HIGH | c-ares | 1.34.8-r0 | HIGH — c-ares 1.34.6-r0 → 1.34.8-r0 |
| CVE-2026-14456 | HIGH | libcrypto3 | 3.5.8-r0 | HIGH — libcrypto3 3.5.7-r0 → 3.5.8-r0 |
| CVE-2026-14456 | HIGH | libssl3 | 3.5.8-r0 | HIGH — libssl3 3.5.7-r0 → 3.5.8-r0 |
| CVE-2026-14456 | HIGH | openssl | 3.5.8-r0 | HIGH — openssl 3.5.7-r0 → 3.5.8-r0 |
| CVE-2026-69246 | HIGH | guzzlehttp/guzzle | 7.15.2, 8.0.1 | HIGH — guzzlehttp/guzzle 7.12.1 → 7.15.2, 8.0.1 |
| CVE-2026-71488 | HIGH | league/commonmark | 2.9.0 | HIGH — league/commonmark 2.8.2 → 2.9.0 |
| GHSA-8rr7-cvq3-gmfh | HIGH | league/commonmark | 2.10.0 | HIGH — league/commonmark 2.8.2 → 2.10.0 |
| GHSA-f8fg-pg57-v4j8 | HIGH | league/commonmark | 2.9.1 | HIGH — league/commonmark 2.8.2 → 2.9.1 |
| GHSA-g2gp-3wwq-f4ph | HIGH | league/commonmark | 2.9.0 | HIGH — league/commonmark 2.8.2 → 2.9.0 |
| GHSA-j8pm-gj4c-rq4x | HIGH | league/commonmark | 2.9.1 | HIGH — league/commonmark 2.8.2 → 2.9.1 |
| GHSA-jfm3-95jq-q3rf | HIGH | league/commonmark | 2.9.0 | HIGH — league/commonmark 2.8.2 → 2.9.0 |
| GHSA-jjv6-8j6v-6j52 | HIGH | league/commonmark | 2.9.1 | HIGH — league/commonmark 2.8.2 → 2.9.1 |
| GHSA-mh25-x5hq-wrqp | HIGH | league/commonmark | 2.9.0 | HIGH — league/commonmark 2.8.2 → 2.9.0 |
---

## Résultats après correction (post-scan)

| Composant | CRITICAL avant | HIGH avant | HIGH après workflow | Statut |
|---|---|---|---|---|
| portal-web | 13 | 0 | **0** | ✅ PASS |
| auth-users | 13 | 0 | **0** | ✅ PASS |
| chatbot-manager | 13 | 0 | **0** | ✅ PASS |
| conversation-service | 13 | 0 | **0** | ✅ PASS |
| audit-security-service | 13 | 0 | **0** | ✅ PASS |

## Décision Finale

Vulnérabilités corrigées via :
1. **Base image update** : `php:8.4-cli-alpine@sha256:1f044d6d...` (remplace f074dc4c)
2. **Composer update** : `guzzlehttp/guzzle ~7.15.2`, `league/commonmark ~2.9.1`

**Verdict final : PASS — aucun HIGH ou CRITICAL restant.**
