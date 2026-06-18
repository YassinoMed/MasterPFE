# 21 — SBOM (Software Bill of Materials)

> **Date :** 2026-06-18  
> **Verdict :** ❌ FAIL

---

## Résumé Exécutif

**0 fichier SBOM trouvé.** Aucun SBOM CycloneDX ou SPDX n'a été généré. Les scripts de génération et d'attestation existent mais n'ont pas été exécutés.

---

## État Actuel

| Métrique | Valeur |
|----------|:------:|
| SBOM générés | 0 |
| Format | CycloneDX (configuré) |
| Outil | Syft (configuré) |
| Attestation | Cosign attest (configuré) |

---

## Scripts Disponibles

| Script | Fonction |
|--------|----------|
| `scripts/sbom/generate-sbom.sh` | Génération CycloneDX |
| `scripts/release/attest-sboms.sh` | Attestation Cosign |
| `scripts/release/sbom-validate.sh` | Validation |

---

## Recommandations

1. Exécuter Syft sur toutes les images production
2. Attester les SBOM avec Cosign
3. Stocker les SBOM dans un registry OCI (Harbor)
4. Ajouter une gate CI qui vérifie la présence de SBOM

---

## Conclusion

La génération SBOM est configurée mais pas exécutée. C'est un prérequis pour SLSA L3+.
