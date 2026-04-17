# Release Promotion Runbook — SecureRAG Hub

## Objectif
Promouvoir un artefact OCI déjà construit, signé et vérifié vers un tag de déploiement, sans reconstruction intermédiaire.

## Principe retenu
La chaîne de confiance suit cette logique :

1. build initial de l’image
2. push dans le registre OCI
3. scan Trivy des images candidates
4. signature Cosign
5. vérification de la signature sur le tag source
6. promotion par digest vers un nouveau tag sans rebuild
7. vérification que le digest cible correspond au digest source
8. génération des SBOM CycloneDX sur les images promues
9. attestation Cosign des SBOM
10. attestation et gate obligatoire des preuves release
11. déploiement uniquement du tag promu

Cette approche évite les dérives classiques où la CD reconstruit une image différente de celle qui a été testée et signée.

## Scripts utilisés
- `scripts/release/scan-images.sh`
- `scripts/release/verify-signatures.sh`
- `scripts/release/promote-verified-images.sh`
- `scripts/release/promote-by-digest.sh`
- `scripts/release/generate-sbom.sh`
- `scripts/release/attest-sboms.sh`
- `scripts/release/record-release-evidence.sh`
- `scripts/release/generate-release-attestation.sh`
- `scripts/release/assert-supply-chain-evidence.sh`
- `scripts/deploy/verify-and-deploy-kind.sh`

## Variables principales
- `REGISTRY_HOST`
- `IMAGE_PREFIX`
- `SOURCE_IMAGE_TAG`
- `TARGET_IMAGE_TAG`
- `COSIGN_PUBLIC_KEY`

## Promotion manuelle
```bash
REGISTRY_HOST=localhost:5001 \
IMAGE_PREFIX=securerag-hub \
SOURCE_IMAGE_TAG=dev \
TARGET_IMAGE_TAG=release-local \
COSIGN_PUBLIC_KEY=/absolute/path/to/cosign.pub \
bash scripts/release/promote-verified-images.sh
```

Promotion recommandee avec digest :
```bash
REGISTRY_HOST=localhost:5001 \
IMAGE_PREFIX=securerag-hub \
SOURCE_IMAGE_TAG=dev \
TARGET_IMAGE_TAG=release-local \
COSIGN_PUBLIC_KEY=/absolute/path/to/cosign.pub \
bash scripts/release/promote-by-digest.sh
```

## Déploiement vérifié
```bash
REGISTRY_HOST=localhost:5001 \
IMAGE_PREFIX=securerag-hub \
IMAGE_TAG=release-local \
COSIGN_PUBLIC_KEY=/absolute/path/to/cosign.pub \
RUN_POSTDEPLOY_VALIDATION=true \
bash scripts/deploy/verify-and-deploy-kind.sh
```

## Résultats attendus
- `artifacts/release/image-scan-summary.txt`
- `security/reports/trivy-image-*.json`
- `artifacts/release/promotion-by-digest-summary.txt`
- `artifacts/release/promotion-digests.txt`
- `artifacts/release/release-evidence.md`
- `artifacts/release/release-attestation.json`
- `artifacts/release/supply-chain-evidence.md`
- `artifacts/release/supply-chain-gate-report.md`
- `artifacts/release/sign-summary.txt`
- `artifacts/release/verify-summary.txt`
- `artifacts/release/sbom-summary.txt`
- `artifacts/release/attest-summary.txt`
- `artifacts/sbom/sbom-index.txt`
- `artifacts/sbom/*-sbom.cdx.json`
- `artifacts/validation/validation-summary.md`

## Intégration Jenkins CD
Le pipeline CD utilise :
- `SOURCE_IMAGE_TAG` comme tag candidat déjà construit et signé
- `TARGET_IMAGE_TAG` comme tag promu puis déployé
- un fichier de digest promus comme preuve de l'identite exacte des artefacts

Le pipeline CD ne doit pas reconstruire les images.

## Points d’attention sécurité
- ne jamais signer une image dont le scan critique Trivy a échoué
- ne jamais promouvoir un tag non vérifié
- ne jamais déclarer une release validée si `assert-supply-chain-evidence.sh` échoue
- ne jamais déclarer les SBOM attestés si `attest-summary.txt` ne contient pas une ligne `PASS` par service officiel
- conserver les rapports de vérification et de promotion comme preuves de la chaîne de confiance
- privilégier la vérification par clé publique Cosign dans Jenkins pour une démo stable et reproductible
- si la registry change de dépôt et pas seulement de tag, revalider soigneusement le comportement de vérification car les références Cosign dépendent du digest et du repository
