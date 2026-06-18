# 22 — SLSA Supply Chain Levels

> **Date :** 2026-06-18  
> **Verdict :** ⚠️ WARNING

---

## Résumé Exécutif

**Niveau SLSA actuel : ~2.** Les scripts pour SLSA L3+ sont créés mais pas exécutés en CI. Les attestations de provenance ne sont pas produites.

---

## Niveaux SLSA

| Niveau | Exigence | Statut |
|:------:|----------|:------:|
| L1 | Provenance existe | ✅ Scripts prêts |
| L2 | Provenance non-forgeable | ✅ Keyless signing |
| L3 | Provenance + Hermetic build | ⚠️ Scripts créés |
| L4 | Provenance + Isolated + Reproducible | ❌ Non atteint |

---

## Scripts SLSA L3+

| Script | Fonction |
|--------|----------|
| `scripts/supply-chain/build-provenance.sh` | Génère provenance SLSA v1.0 |
| `scripts/supply-chain/hermetic-build.sh` | Build sans réseau |
| `scripts/supply-chain/verify-slsa.sh` | Vérification slsa-verifier |
| `scripts/supply-chain/rekor-upload.sh` | Upload attestations |
| `scripts/supply-chain/slsa-report.sh` | Rapport de conformité |

---

## Recommandations

1. Atteindre SLSA L3 : exécuter hermetic-build + provenance en CI
2. Uploader toutes les attestations vers Rekor
3. Ajouter slsa-verifier à la quality gate
4. Viser SLSA L4 avec builds isolés et reproductibles

---

## Conclusion

SLSA L2 atteint avec la signature Cosign. Les scripts L3+ sont prêts. L'intégration CI/CD est la prochaine étape.
