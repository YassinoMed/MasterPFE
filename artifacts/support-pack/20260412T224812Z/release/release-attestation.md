# Release Attestation - SecureRAG Hub

- Generated at: `2026-04-12T22:48:11.666186Z`
- Git commit: `09b4c07aead711dc91baf789ccfcf653f9a65516`
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
- OK `artifacts/release/release-evidence.md` sha256=`79c0bd19be7edff6058aa8096d97a5400dfb0e5eb097e2af8bed917525bf359d`
- OK `artifacts/release/supply-chain-evidence.md` sha256=`b86d5de1c8121d7d55c85246d468e3a78f6bde54da4e3e956bf8121911fd71dc`

## Soutenance interpretation

- This attestation is generated locally and is safe to archive.
- A complete expert-level release also requires real SBOM, Cosign sign/verify and digest promotion artefacts.
- If the working tree is dirty, present this as local evidence, not as an immutable released commit.
