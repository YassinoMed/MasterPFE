# Supply Chain Mandatory Evidence Gate

- Generated at: `2026-04-15T04:33:01Z`
- REQUIRE_SUPPLY_CHAIN_EVIDENCE: `true`
- Expected services: `7`
- Services: `api-gateway auth-users chatbot-manager llm-orchestrator security-auditor knowledge-hub portal-web`

| Required evidence | Status | Detail |
|---|---:|---|
| Cosign sign summary | FAIL | `artifacts/release/sign-summary.txt` missing or empty |
| Cosign verify summary | FAIL | `artifacts/release/verify-summary.txt` missing or empty |
| Digest promotion summary | FAIL | `artifacts/release/promotion-by-digest-summary.txt` missing or empty |
| Digest promotion record | FAIL | `artifacts/release/promotion-digests.txt` missing or empty |
| SBOM generation summary | FAIL | `artifacts/release/sbom-summary.txt` missing or empty |
| SBOM index | FAIL | `artifacts/sbom/sbom-index.txt` missing or empty |
| Release attestation | FAIL | `artifacts/release/release-attestation.json` is present but not COMPLETE_PROVEN |
