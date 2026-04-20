# Release Promotion Runbook — SecureRAG Hub

## Objectif
Promouvoir un artefact OCI déjà construit, signé et vérifié vers un tag de déploiement, sans reconstruction intermédiaire.

## Principe retenu
La chaîne de confiance suit cette logique :

1. build initial de l’image
2. push dans le registre OCI
3. scan Trivy des images candidates avec gate CRITICAL bloquant
4. signature Cosign
5. vérification de la signature sur le tag source
6. promotion par digest vers un nouveau tag sans rebuild
7. vérification que le digest cible correspond au digest source
8. génération des SBOM CycloneDX sur les images promues
9. attestation Cosign des SBOM
10. attestation et gate obligatoire des preuves release
11. provenance SLSA-style basée sur les digests promus
12. déploiement uniquement du tag promu

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
- `scripts/release/generate-provenance-statement.sh`
- `scripts/release/assert-supply-chain-evidence.sh`
- `scripts/deploy/verify-and-deploy-kind.sh`

## Variables principales
- `REGISTRY_HOST`
- `IMAGE_PREFIX`
- `SOURCE_IMAGE_TAG`
- `TARGET_IMAGE_TAG`
- `COSIGN_PUBLIC_KEY`
- `TRIVY_REPORT_SEVERITY` : severites reportees, valeur recommandee `HIGH,CRITICAL`
- `TRIVY_BLOCKING_SEVERITY` : severites bloquantes, valeur recommandee `CRITICAL`
- `TRIVY_FAIL_ON_HIGH` : mettre `true` uniquement si la release doit bloquer aussi sur HIGH

## Politique Trivy image
La politique release par defaut est volontairement simple et defendable :

- `CRITICAL` bloque la release.
- `HIGH` est archive et visible dans le resume, mais non bloquant par defaut.
- `TRIVY_FAIL_ON_HIGH=true` transforme les vulnerabilites HIGH en gate bloquant.
- les rapports JSON par image sont archives sous `security/reports/trivy-image-*.json`.
- le resume humain est archive dans `artifacts/release/image-scan-summary.md`.
- l'index machine-readable est archive dans `artifacts/release/image-scan-index.json`.

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
IMAGE_DIGEST_FILE=artifacts/release/promotion-digests.txt \
REQUIRE_DIGEST_DEPLOY=true \
COSIGN_PUBLIC_KEY=/absolute/path/to/cosign.pub \
RUN_POSTDEPLOY_VALIDATION=true \
bash scripts/deploy/verify-and-deploy-kind.sh
```

## Résultats attendus
- `artifacts/release/image-scan-summary.txt`
- `artifacts/release/image-scan-summary.md`
- `artifacts/release/image-scan-index.json`
- `security/reports/trivy-image-*.json`
- `artifacts/release/promotion-by-digest-summary.txt`
- `artifacts/release/promotion-by-digest-summary.md`
- `artifacts/release/promotion-digests.txt`
- `artifacts/release/promotion-digests.json`
- `artifacts/release/no-rebuild-deploy-summary.md`
- `artifacts/release/release-evidence.md`
- `artifacts/release/release-attestation.json`
- `artifacts/release/release-attestation.md`
- `artifacts/release/provenance.slsa.json`
- `artifacts/release/provenance.slsa.md`
- `artifacts/release/supply-chain-evidence.md`
- `artifacts/release/supply-chain-gate-report.md`
- `artifacts/release/sign-summary.txt`
- `artifacts/release/sign-summary.md`
- `artifacts/release/sign-index.json`
- `artifacts/release/verify-summary.txt`
- `artifacts/release/verify-summary.md`
- `artifacts/release/verify-index.json`
- `artifacts/release/sbom-summary.txt`
- `artifacts/release/sbom-summary.md`
- `artifacts/release/attest-summary.txt`
- `artifacts/sbom/sbom-index.txt`
- `artifacts/sbom/sbom-index.json`
- `artifacts/sbom/*-sbom.cdx.json`
- `artifacts/validation/validation-summary.md`

## Intégration Jenkins CD
Le pipeline CD utilise :
- `SOURCE_IMAGE_TAG` comme tag candidat déjà construit et signé
- `TARGET_IMAGE_TAG` comme tag promu puis déployé
- un fichier de digest promus comme preuve de l'identite exacte des artefacts

Le pipeline CD ne doit pas reconstruire les images.
Quand `REQUIRE_DIGEST_DEPLOY=true`, le deploiement echoue si `promotion-digests.txt` est absent ou incomplet. C'est le mode attendu pour une release defendable.

Le stage de provenance SLSA-style est volontairement strict dans Jenkins : il
échoue si les digests promus sont absents ou si `release-attestation.json` n'est
pas `COMPLETE_PROVEN`.

## Points d’attention sécurité
- ne jamais signer une image dont le scan critique Trivy a échoué
- ne jamais promouvoir un tag non vérifié
- ne jamais déclarer une release validée si `assert-supply-chain-evidence.sh` échoue
- ne jamais déclarer les SBOM attestés si `attest-summary.txt` ne contient pas une ligne `PASS` par service officiel
- conserver les rapports de vérification et de promotion comme preuves de la chaîne de confiance
- privilégier la vérification par clé publique Cosign dans Jenkins pour une démo stable et reproductible
- si la registry change de dépôt et pas seulement de tag, revalider soigneusement le comportement de vérification car les références Cosign dépendent du digest et du repository
