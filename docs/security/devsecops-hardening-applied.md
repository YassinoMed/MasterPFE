# DevSecOps Hardening Applied - SecureRAG Hub

## Objectif

Ce document trace les renforcements DevSecOps appliques apres l'audit Sonar/Kubernetes/supply chain. Il ne remplace pas les preuves runtime : il indique quels controles sont maintenant codes, scriptes et gates dans Jenkins.

## Corrections appliquees

| Bloc | Correction | Etat local | Preuve attendue |
|---|---|---|---|
| Sonar | CPD Laravel cadre via `sonar.cpd.exclusions`, Python version explicite, Python exclu du scan source officiel | TERMINÉ | `artifacts/security/sonar-cpd-scope.md` |
| Sonar | Quality Gate executable par Jenkins quand `RUN_SONAR=true`, `SONAR_HOST_URL` et credential `sonar-token` sont fournis | PRÊT_NON_EXÉCUTÉ | `security/reports/sonar-analysis.md`, `security/reports/sonar-quality-gate.json` |
| Laravel | Donnees RBAC de reference sorties du service applicatif vers `config/rbac.php` | TERMINÉ | `php artisan test --filter=RbacServiceTest` |
| CI | Validation Kyverno hors cluster ajoutee apres le hardening K8s statique | PRÊT_NON_EXÉCUTÉ si CLI absent | `artifacts/security/kyverno-policy-validation.md` |
| CD | Scan Trivy des images candidates avant verification/promotion | DÉPENDANT_DE_L_ENVIRONNEMENT | `artifacts/release/image-scan-summary.txt`, `security/reports/trivy-image-*.json` |
| CD | Attestation Cosign des SBOM CycloneDX apres generation SBOM | DÉPENDANT_DE_L_ENVIRONNEMENT | `artifacts/release/attest-summary.txt` |
| Release | Gate obligatoire enrichi : image scan, SBOM, attestation SBOM, signature, verification, promotion digest | DÉPENDANT_DE_L_ENVIRONNEMENT | `artifacts/release/supply-chain-gate-report.md` |
| Reporting | Rapport posture securite aligne sur les nouveaux artefacts | TERMINÉ | `artifacts/security/security-posture-report.md` |

## Commandes non destructives

```bash
bash scripts/ci/validate-sonar-cpd-scope.sh
REQUIRE_SONAR=false bash scripts/ci/run-sonar-analysis.sh
REQUIRE_KYVERNO_CLI=false bash scripts/ci/validate-kyverno-policies.sh
bash scripts/validate/generate-security-posture-report.sh
```

Pour un vrai gate Sonar Jenkins, preparer d'abord le credential local :

```bash
SONAR_TOKEN_VALUE='<token-sonar-reel>' bash scripts/jenkins/bootstrap-local-credentials.sh
```

## Commandes runtime reelles

Ces commandes exigent Docker, registry, images officielles, Trivy, Syft, Cosign et les cles Cosign locales :

```bash
REGISTRY_HOST=localhost:5001 IMAGE_PREFIX=securerag-hub IMAGE_TAG=dev \
bash scripts/release/scan-images.sh

REGISTRY_HOST=localhost:5001 IMAGE_PREFIX=securerag-hub \
SOURCE_IMAGE_TAG=dev TARGET_IMAGE_TAG=release-local \
bash scripts/release/run-supply-chain-execute.sh
```

## Lecture honnete

- `TERMINÉ` signifie qu'un script local a ete execute avec succes ou qu'un controle statique est verifie dans le depot.
- `PRÊT_NON_EXÉCUTÉ` signifie que le depot contient le controle, mais que l'outil externe ou le credential n'est pas disponible localement.
- `DÉPENDANT_DE_L_ENVIRONNEMENT` signifie que la preuve depend d'une execution reelle sur Docker/kind/Jenkins/registry/Cosign/Syft/Trivy/Kyverno.
- Une release ne doit etre presentee comme supply-chain-ready que si `scripts/release/assert-supply-chain-evidence.sh` reussit apres execution complete.
