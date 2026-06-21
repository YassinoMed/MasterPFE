# Supply Chain Evidence - SecureRAG Hub

## 1. Release evidence

- OK: `artifacts/release/release-evidence.md`
- OK: `artifacts/release/release-manifest.env`
- OK: `artifacts/release/release-attestation.md`
- OK: `artifacts/release/release-attestation.json`

## 2. Verification and signature evidence

- ABSENT: `artifacts/release/verify-summary.txt`
- ABSENT: `artifacts/release/sign-summary.txt`
- Signature logs detected: 0
- Verification artefacts detected: 0

## 3. Promotion evidence

- OK: `artifacts/release/promotion-summary.txt`
- ABSENT: `artifacts/release/promotion-by-digest-summary.txt`
- ABSENT: `artifacts/release/promotion-digests.txt`

## 4. SBOM evidence

- SBOM directory: `artifacts/sbom`
- SBOM files detected: 0
- ABSENT: `artifacts/release/sbom-summary.txt`

## 5. Status interpretation

- Ready: scripts and expected paths exist.
- Partial: evidence files are missing because the environment has not executed that step.
- Complete: digest promotion, SBOM, signature and verification artefacts are present for the release candidate.

## 6. Soutenance note

The official demo may use `dry-run` as preparatory evidence. Full supply-chain enforcement in `execute` mode depends on local availability of Cosign keys, Syft, Docker registry and reachable signed images.
