# Supply Chain Mandatory Evidence Gate

- Generated at: `2026-04-20T04:51:23Z`
- REQUIRE_SUPPLY_CHAIN_EVIDENCE: `true`
- Expected services: `5`
- Services: `auth-users chatbot-manager conversation-service audit-security-service portal-web`

| Required evidence | Status | Detail |
|---|---:|---|
| Trivy image scan summary | FAIL | `artifacts/release/image-scan-summary.txt` missing or empty |
| Cosign sign summary | FAIL | `artifacts/release/sign-summary.txt` missing or empty |
| Cosign verify summary | FAIL | `artifacts/release/verify-summary.txt` missing or empty |
| Digest promotion summary | FAIL | `artifacts/release/promotion-by-digest-summary.txt` missing or empty |
| Digest promotion record | FAIL | `artifacts/release/promotion-digests.txt` missing or empty |
| SBOM generation summary | FAIL | `artifacts/release/sbom-summary.txt` missing or empty |
| Cosign SBOM attestation summary | FAIL | `artifacts/release/attest-summary.txt` missing or empty |
| SBOM index | FAIL | `artifacts/sbom/sbom-index.txt` missing or empty |
| Release attestation | FAIL | `artifacts/release/release-attestation.json` is present but not COMPLETE_PROVEN |

## Global status

Statut global: `DÉPENDANT_DE_L_ENVIRONNEMENT`

Required supply-chain evidence is absent or incomplete in the current environment. Run the full release chain with Docker, registry access, Trivy, Syft, Cosign and valid signing keys.
