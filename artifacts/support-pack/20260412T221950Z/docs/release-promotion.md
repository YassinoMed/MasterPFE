# Release Promotion Runbook — SecureRAG Hub

## Objectif
Promouvoir un artefact OCI déjà construit, signé et vérifié vers un tag de déploiement, sans reconstruction intermédiaire.

## Principe retenu
La chaîne de confiance suit cette logique :

1. build initial de l’image
2. push dans le registre OCI
3. signature Cosign
4. vérification de la signature sur le tag source
5. promotion vers un nouveau tag sans rebuild
6. traçage du digest promu par service
6. vérification de la signature sur le tag promu
7. déploiement uniquement du tag promu

Cette approche évite les dérives classiques où la CD reconstruit une image différente de celle qui a été testée et signée.

## Scripts utilisés
- `scripts/release/verify-signatures.sh`
- `scripts/release/promote-verified-images.sh`
- `scripts/release/promote-by-digest.sh`
- `scripts/release/record-release-evidence.sh`
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
- `artifacts/release/promotion-summary.txt`
- `artifacts/release/promotion-by-digest-summary.txt`
- `artifacts/release/promotion-digests.txt`
- `artifacts/release/release-evidence.md`
- `artifacts/release/verify-summary.txt`
- `artifacts/sbom/*`
- `artifacts/validation/validation-summary.md`

## Intégration Jenkins CD
Le pipeline CD utilise :
- `SOURCE_IMAGE_TAG` comme tag candidat déjà construit et signé
- `TARGET_IMAGE_TAG` comme tag promu puis déployé
- un fichier de digest promus comme preuve de l'identite exacte des artefacts

Le pipeline CD ne doit pas reconstruire les images.

## Points d’attention sécurité
- ne jamais promouvoir un tag non vérifié
- conserver les rapports de vérification et de promotion comme preuves de la chaîne de confiance
- privilégier la vérification par clé publique Cosign dans Jenkins pour une démo stable et reproductible
- si la registry change de dépôt et pas seulement de tag, revalider soigneusement le comportement de vérification car les références Cosign dépendent du digest et du repository
