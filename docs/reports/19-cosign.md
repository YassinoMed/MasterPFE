# 19 — Cosign Image Signing

> **Date :** 2026-06-18  
> **Verdict :** ⚠️ WARNING

---

## Résumé Exécutif

Cosign n'est pas installé sur la machine de test. Les scripts de signature et vérification existent dans `scripts/release/`. La configuration keyless via GitHub OIDC est définie.

---

## État Actuel

| Composant | Statut |
|-----------|:------:|
| Cosign CLI | ❌ Non installé |
| Key signing | ✅ Configuré (keyless + public key) |
| Signature verification | ⚠️ Scripts prêts |
| Image signing | ⚠️ Scripts prêts |

---

## Configuration

- **Keyless signing** : GitHub OIDC (`https://github.com/YassinoMed/MasterPFE/*`)
- **Issuer** : `https://token.actions.githubusercontent.com`
- **Rekor** : `https://rekor.sigstore.dev`
- **Public key** : Intégrée dans la ClusterPolicy `securerag-verify-cosign-images`

---

## Scripts Disponibles

| Script | Fonction |
|--------|----------|
| `scripts/release/sign-images.sh` | Signer les images |
| `scripts/release/sign-images-keyless.sh` | Signature keyless |
| `scripts/release/verify-signatures.sh` | Vérification |
| `scripts/release/verify-signatures-keyless.sh` | Vérification keyless |

---

## Recommandations

1. Installer Cosign CLI dans le pipeline Jenkins
2. Activer la signature automatique dans le CD pipeline
3. Vérifier que toutes les images production sont signées

---

## Conclusion

La chaîne de signature est conçue et configurée. L'installation de Cosign CLI et l'intégration CI/CD sont les seules étapes manquantes.
