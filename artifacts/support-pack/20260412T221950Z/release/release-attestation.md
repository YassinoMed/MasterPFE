# Release Attestation - SecureRAG Hub

- Generated at: `2026-04-12T22:18:49.158220Z`
- Git commit: `3ad99fe1bebdd5f5edd1bebe0e6d3b5f25d7a025`
- Git branch: `main`
- Working tree dirty: `true`
- Registry: `localhost:5001`
- Source tag: `dev`
- Target tag: `release-local`

## Chain of custody status

- Digest records: `0`
- SBOM artefacts: `0`
- Evidence files present: `2/7`

## Evidence files

- ABSENT `artifacts/release/sign-summary.txt`
- ABSENT `artifacts/release/verify-summary.txt`
- ABSENT `artifacts/release/promotion-by-digest-summary.txt`
- ABSENT `artifacts/release/promotion-digests.txt`
- ABSENT `artifacts/release/sbom-summary.txt`
- OK `artifacts/release/release-evidence.md` sha256=`e467bccc70b00df421b9a847f901b2461e0a4ac81f466890b72cf3abc702830d`
- OK `artifacts/release/supply-chain-evidence.md` sha256=`cf1509401a2a3fa211d966d15c5deffa6e14609ca5e3485dc7af41c9b988a244`

## Soutenance interpretation

- This attestation is generated locally and is safe to archive.
- A complete expert-level release also requires real SBOM, Cosign sign/verify and digest promotion artefacts.
- If the working tree is dirty, present this as local evidence, not as an immutable released commit.
