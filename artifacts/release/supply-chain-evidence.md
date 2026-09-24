# Supply Chain Evidence — SecureRAG Hub

- Generated at UTC: `2026-09-23T03:59:22Z`
- Git commit: `62b3dd4875322ad43c1a29374ac63f65e1cb5724`

## Evidence inventory

| Evidence | Status |
|---|---|
| `image-scan-summary.txt` | present: PASS=0 FAIL=0 SKIP=0 |
| `image-scan-summary.md` | present |
| `image-scan-index.json` | present |
| `sign-summary.txt` | present: PASS=5 FAIL=0 SKIP=0 |
| `sign-summary.md` | present |
| `sign-index.json` | present |
| `verify-summary.txt` | present: PASS=5 FAIL=0 SKIP=0 |
| `verify-summary.md` | present |
| `verify-index.json` | present |
| `promotion-by-digest-summary.txt` | present: PASS=5 FAIL=0 SKIP=0 |
| `promotion-by-digest-summary.md` | present |
| `promotion-digests.txt` | present |
| `promotion-digests.json` | present |
| `sbom-summary.txt` | present: PASS=5 FAIL=0 SKIP=0 |
| `sbom-summary.md` | present |
| `attest-summary.txt` | present: PASS=5 FAIL=0 SKIP=0 |
| `no-rebuild-deploy-summary.md` | present |
| `release-evidence.md` | present |
| `release-attestation.json` | present |
| `release-attestation.md` | present |
| `provenance.slsa.json` | present |
| `provenance.slsa.md` | present |
| SBOM files | 5 |

## SBOM files

- `artifacts/sbom/audit-security-service-sbom.cdx.json`
- `artifacts/sbom/auth-users-sbom.cdx.json`
- `artifacts/sbom/chatbot-manager-sbom.cdx.json`
- `artifacts/sbom/conversation-service-sbom.cdx.json`
- `artifacts/sbom/portal-web-sbom.cdx.json`

## Honest reading

- `present` means the artefact exists locally.
- `PASS` means a script recorded a successful control for at least one image.
- A full release proof requires Trivy image scanning, SBOM generation, SBOM attestation, Cosign sign, Cosign verify, digest promotion and release attestation generated from the same execution context.
