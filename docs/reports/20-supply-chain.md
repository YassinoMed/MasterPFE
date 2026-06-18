# 20 — Supply Chain Security

> **Date :** 2026-06-18  
> **Verdict :** ⚠️ WARNING

---

## Résumé Exécutif

La supply chain est partiellement implémentée. Le pipeline CD Jenkins a 15 stages incluant signature, SBOM, promotion et déploiement. Les scripts SLSA L3+ sont prêts mais pas exécutés dans ce cycle.

---

## Pipeline CD

| Stage | Statut |
|-------|:------:|
| Scans (Trivy, Semgrep, Gitleaks) | ✅ CI |
| Cosign signing | ⚠️ Scripts prêts |
| SBOM generation (Syft) | ⚠️ Scripts prêts |
| Image promotion by digest | ⚠️ Scripts prêts |
| GitOps sync | ⚠️ Config prête |
| DAST (OWASP ZAP) | ✅ Config prête |
| SLSA provenance | ✅ Scripts créés |

---

## Scripts Supply Chain

| Script | Fonction | Statut |
|--------|----------|:------:|
| `scripts/release/sign-images.sh` | Signature | ✅ Défini |
| `scripts/release/promote-by-digest.sh` | Promotion | ✅ Défini |
| `scripts/supply-chain/build-provenance.sh` | SLSA provenance | ✅ Créé |
| `scripts/supply-chain/hermetic-build.sh` | Build hermétique | ✅ Créé |
| `scripts/supply-chain/verify-slsa.sh` | Vérification SLSA | ✅ Créé |
| `scripts/supply-chain/rekor-upload.sh` | Rekor upload | ✅ Créé |

---

## Score Supply Chain

| Métrique | Score |
|----------|:-----:|
| Pipeline CD | 15 stages |
| Signing config | Keyless + Key |
| SBOM | 0 généré |
| SLSA | Scripts L3+ prêts |
| **Score** | **50%** |

---

## Recommandations

1. Exécuter SBOM generation (Syft) sur les images
2. Activer Cosign signing dans le pipeline CD
3. Intégrer la vérification SLSA dans la quality gate
4. Uploader les attestations vers Rekor

---

## Conclusion

La supply chain est bien architecturée avec 15 stages CD. L'exécution effective des scripts de signature et SBOM est la prochaine étape.
