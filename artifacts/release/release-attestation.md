# Release Attestation — SecureRAG Hub

- Generated at UTC: `2026-04-14T23:35:21Z`
- Git commit: `ea2440c357444b99b40c8334381b61455d9a752b`
- Status: `PARTIAL_READY_TO_PROVE`
- Strict mode: `false`

## Evidence status

| Control | Status | Evidence |
|---|---|---|
| Cosign sign | `MISSING` | `artifacts/release/sign-summary.txt` |
| Cosign verify | `MISSING` | `artifacts/release/verify-summary.txt` |
| Digest promotion | `MISSING` | `artifacts/release/promotion-by-digest-summary.txt` |
| Digest record | `MISSING` | `artifacts/release/promotion-digests.txt` |
| SBOM generation | `MISSING` | `artifacts/release/sbom-summary.txt` |
| SBOM files | `0` | `artifacts/sbom` |
| Release evidence | `PRESENT` | `artifacts/release/release-evidence.md` |
| Supply chain evidence | `PRESENT` | `artifacts/release/supply-chain-evidence.md` |

## Honest reading

The release chain is not fully proven yet. Missing or unproven evidence must be produced by `make supply-chain-execute` on an environment with Docker, registry access, Syft, Cosign and valid Cosign keys.
