# Release Attestation — SecureRAG Hub

- Generated at UTC: `2026-09-23T03:59:22Z`
- Git commit: `62b3dd4875322ad43c1a29374ac63f65e1cb5724`
- Expected services: `5`
- Expected service names: `auth-users chatbot-manager conversation-service audit-security-service portal-web`
- Status: `COMPLETE_PROVEN`
- Strict mode: `true`

## Evidence status

| Control | Status | Evidence |
|---|---|---|
| Trivy image scan | `PROVEN` | `artifacts/release/image-scan-summary.txt` |
| Cosign sign | `PROVEN` | `artifacts/release/sign-summary.txt` |
| Cosign verify | `PROVEN` | `artifacts/release/verify-summary.txt` |
| Digest promotion | `PROVEN` | `artifacts/release/promotion-by-digest-summary.txt` |
| Digest record | `PROVEN` | `artifacts/release/promotion-digests.txt` |
| SBOM generation | `PROVEN` | `artifacts/release/sbom-summary.txt` |
| SBOM attestation | `PROVEN` | `artifacts/release/attest-summary.txt` |
| SBOM files | `5` | `artifacts/sbom` |
| Release evidence | `PRESENT` | `artifacts/release/release-evidence.md` |
| Supply chain evidence | `PRESENT` | `artifacts/release/supply-chain-evidence.md` |

## Honest reading

The release chain is complete for the expected service set: image scan, SBOM, SBOM attestation, signing, verification, digest promotion and no-rebuild promotion evidence are all proven without FAIL or SKIP rows.
