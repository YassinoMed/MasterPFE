# Supply Chain Execute Summary

- Generated at: `2026-09-23T03:58:17Z`
- Mode: `execute`
- Registry: `localhost:5001`
- Image prefix: `securerag-hub`
- Source tag: `dev`
- Target tag: `release-local`

## Preflight

- OK: `localhost:5001/securerag-hub-auth-users:dev`
- OK: `localhost:5001/securerag-hub-chatbot-manager:dev`
- OK: `localhost:5001/securerag-hub-conversation-service:dev`
- OK: `localhost:5001/securerag-hub-audit-security-service:dev`
- OK: `localhost:5001/securerag-hub-portal-web:dev`

## Executed steps

- scan source images with Trivy: OK
- sign source images: OK
- verify source signatures: OK
- promote by digest without rebuild: OK
- verify promoted images: OK
- generate SBOMs: OK
- attest promoted image SBOMs: OK
- record release evidence: OK

- mandatory supply-chain evidence gate: OK

- release attestation: OK
- SLSA-style provenance statement: OK

## Produced evidence

- `artifacts/release/image-scan-summary.txt`
- `artifacts/release/image-scan-summary.md`
- `artifacts/release/image-scan-index.json`
- `artifacts/release/sign-summary.txt`
- `artifacts/release/sign-summary.md`
- `artifacts/release/sign-index.json`
- `artifacts/release/verify-summary.txt`
- `artifacts/release/verify-summary.md`
- `artifacts/release/verify-index.json`
- `artifacts/release/promotion-by-digest-summary.txt`
- `artifacts/release/promotion-by-digest-summary.md`
- `artifacts/release/promotion-digests.txt`
- `artifacts/release/promotion-digests.json`
- `artifacts/release/sbom-summary.txt`
- `artifacts/release/sbom-summary.md`
- `artifacts/release/attest-summary.txt`
- `artifacts/release/release-evidence.md`
- `artifacts/release/supply-chain-evidence.md`
- `artifacts/release/supply-chain-gate-report.md`
- `artifacts/release/release-attestation.json`
- `artifacts/release/release-attestation.md`
- `artifacts/release/provenance.slsa.json`
- `artifacts/release/provenance.slsa.md`
- `artifacts/sbom/sbom-index.txt`
