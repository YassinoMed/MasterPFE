# 05 — Secrets Gitleaks

> **Date :** 2026-06-18  
> **Verdict :** ❌ FAIL

---

## Résumé Exécutif

Gitleaks a détecté **13 secrets** dans le code. Tous sont des credentials `admin:admin` hardcodés dans les scripts OpenSearch. 21.81 MB scannés en 1.66s.

---

## Résultats

| Métrique | Valeur |
|----------|:------:|
| Taille scannée | 21.81 MB |
| Durée | 1.66s |
| Secrets trouvés | 13 |
| Type | curl-auth-user (admin:admin) |

---

## Détail des Fuites

| Fichier | Lignes | Type |
|---------|:------:|------|
| `scripts/opensearch/deploy-opensearch.sh` | 25, 34, 53, 74, 82, 85 | admin:admin |
| `scripts/opensearch/configure-data-pipeline.sh` | 74, 155 | admin:admin |
| `scripts/opensearch/validate-siem.sh` | 24, 37, 53, 62, 85 | admin:admin |

---

## Analyse

- **Cause :** Credentials OpenSearch par défaut (`admin:admin`) hardcodés dans les scripts de déploiement
- **Risque :** Faible (credentials par défaut OpenSearch, changés en production)
- **Impact :** Les scripts sont destinés au bootstrap initial uniquement

---

## Recommandations

1. Remplacer `admin:admin` par des variables d'environnement (`OPENSEARCH_USER`, `OPENSEARCH_PASSWORD`)
2. Utiliser Vault pour stocker les credentials OpenSearch
3. Ajouter `.gitleaks.toml` allowlist pour les credentials par défaut documentés si nécessaire
4. Appliquer le correctif immédiatement

---

## Conclusion

13 secrets détectés mais limités à des credentials par défaut dans des scripts de bootstrap. Correction simple par passage en variables d'environnement.
