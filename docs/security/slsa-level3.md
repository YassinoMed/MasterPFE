# SLSA Level 3+ Supply Chain Security — SecureRAG Hub

## Overview

SLSA (Supply-chain Levels for Software Artifacts, pronounced "salsa") is a security framework that defines a set of incrementally enforceable requirements for software supply chain integrity. This document describes SecureRAG Hub's implementation achieving **SLSA Level 3+**.

### Current Level: **3+**
### Target Level: **3+** (with roadmap to L4)

---

## SLSA Framework

SLSA defines four levels of supply chain security:

| Level | Description | Requirements |
|:---|:---|---|
| **L1** | Build process documents provenance | Provenance exists |
| **L2** | Signed provenance, tamper resistant | Provenance is signed and hosted |
| **L3** | Hardened build platform | Hermetic + isolated builds, verifiable dependencies |
| **L4** | Two-person review + hermetic by default | All L3 + pinning dependencies + zero network |

### SLSA v1.0 Predicate

All provenance attestations follow the [SLSA v1.0](https://slsa.dev/spec/v1.0/) predicate format:

```json
{
  "_type": "https://in-toto.io/Statement/v1",
  "subject": [{ "name": "", "digest": {"sha256": ""} }],
  "predicateType": "https://slsa.dev/provenance/v1",
  "predicate": {
    "buildDefinition": {
      "buildType": "https://slsa.dev/gha/github-actions-build-types/v1",
      "externalParameters": {},
      "resolvedDependencies": []
    },
    "runDetails": {
      "builder": {"id": "https://github.com/YassinoMed/MasterPFE/.github/workflows/ci.yml"},
      "metadata": {"completeness": {"parameters": true, "environment": true, "materials": true}},
      "byproducts": []
    }
  }
}
```

---

## Requirements Met

### SLSA Level 1 — Provenance Exists

| Requirement | Implementation | Verification |
|:---|:---|---|
| Provenance generated for all artifacts | `scripts/supply-chain/build-provenance.sh` | `verify-slsa.sh --all` |
| Format follows SLSA v1.0 | Generates in-toto Statement with SLSA predicate | JSON schema validation |

**Scripts:**
- `scripts/supply-chain/build-provenance.sh` — Generate SLSA provenance
- `scripts/supply-chain/verify-slsa.sh` — Validate provenance format and content

### SLSA Level 2 — Signed Provenance

| Requirement | Implementation | Verification |
|:---|:---|---|
| Provenance is signed | `cosign attest --type slsaprovenance` with keyless signing | `cosign verify-attestation` |
| Provenance is non-forgeable | Signed via Sigstore Fulcio + OIDC | Rekor transparency log entry |
| Authenticated via transparency log | Upload to Rekor | `rekor-upload.sh` verifies entries |

**Scripts:**
- `scripts/supply-chain/rekor-upload.sh` — Upload to Rekor and verify

### SLSA Level 3 — Hardened Build Platform

| Requirement | Implementation | Verification |
|:---|:---|---|
| **Hermetic build** | `docker build --no-cache --network=none` | `hermetic-build.sh` records build steps |
| **Isolated build environment** | Build runs in CI runner with no cross-build access | No network access during build |
| **Source versioned** | Git-based versioning with full commit history | `git rev-parse HEAD` in every script |
| **Dependencies verifiable** | Base images pinned by digest, recorded in provenance | `pin-base-digests.txt` in hermetic report |
| **Provenance non-forgeable** | Keyless Cosign signing with Rekor | Rekor entry verified |
| **Build config completeness** | All parameters, environment, materials documented | `completeness` block in predicate |

**Scripts:**
- `scripts/supply-chain/hermetic-build.sh` — Perform hermetic builds

---

## Provenance Generation

### Build Process

1. **Source checkout** — Git repository cloned at specific commit
2. **Hermetic build** — `docker build --no-cache --network=none` with pinned base images
3. **Provenance generation** — `build-provenance.sh` creates SLSA v1.0 predicate
4. **Cosign attestation** — `cosign attest --type slsaprovenance` signs with keyless mode
5. **Rekor upload** — Attestation recorded in Sigstore's public transparency log
6. **Verification** — `verify-slsa.sh` validates builder identity and material digests

### Builder Identity

- **Builder ID:** `https://github.com/YassinoMed/MasterPFE/.github/workflows/ci.yml`
- **Build Type:** `https://slsa.dev/gha/github-actions-build-types/v1`
- **Authentication:** Sigstore Fulcio certificate with OIDC token
- **Transparency:** Rekor public log at `https://rekor.sigstore.dev`

### Invocation Config Source

The provenance includes a `configSource` block referencing the exact GitHub Actions workflow and commit that triggered the build:

```json
"configSource": {
  "uri": "https://github.com/YassinoMed/MasterPFE.git",
  "digest": {"sha1": "<git-commit-hash>"},
  "entryPoint": ".github/workflows/ci.yml"
}
```

---

## Hermetic Builds

### What Makes a Build Hermetic

A hermetic build runs with:

| Property | Implementation |
|:---|:---|
| No network access | `--network=none` in Docker build |
| No cache | `--no-cache` to prevent stale layers |
| Pinned dependencies | Base images referenced by digest (e.g., `node@sha256:...`) |
| Reproducibility | Same inputs produce same output (byte-for-byte) |
| Recorded provenance | All build steps documented in SLSA predicate |

### Base Image Pinning

Base images are resolved to their exact digests before building:

| Original Reference | Pinned Reference |
|:---|:---|
| `node:20` | `node@sha256:a1b2c3...` |
| `python:3.11-slim` | `python@sha256:d4e5f6...` |

Pinned digests are recorded in `artifacts/release/hermetic/pinned-base-digests.txt`.

### Build Steps Recorded

Each build step is documented in the SLSA predicate's `buildConfig.steps`:

1. `docker build --no-cache --pull=false --network=none`
2. `cosign attest --type slsaprovenance`
3. `cosign attest --type cyclonedx`

---

## Rekor Integration

All attestations are uploaded to the [Rekor](https://rekor.sigstore.dev) transparency log for public verifiability.

### Attestation Types

| Type | Purpose | Script |
|:---|:---|---|
| `slsaprovenance` | SLSA v1.0 provenance | `build-provenance.sh` |
| `cyclonedx` | CycloneDX SBOM | `generate-sbom.sh` |
| `https://cosign.sigstore.dev/attestation/v1` | Release attestation | `rekor-upload.sh` |

### Verification Flow

```bash
# Upload all attestations
bash scripts/supply-chain/rekor-upload.sh --all

# Verify in Rekor
cosign verify-attestation --type slsaprovenance <image-ref>
```

---

## Tooling & Scripts

| Script | Purpose |
|:---|:---|
| `scripts/supply-chain/build-provenance.sh` | Generate SLSA v1.0 provenance for all services |
| `scripts/supply-chain/hermetic-build.sh` | Build images hermeticly with pinned base digests |
| `scripts/supply-chain/verify-slsa.sh` | Validate provenance against SLSA requirements |
| `scripts/supply-chain/rekor-upload.sh` | Upload attestations to Rekor transparency log |
| `scripts/supply-chain/slsa-report.sh` | Generate SLSA Level 3+ compliance report |

### Usage

```bash
# 1. Perform hermetic build
bash scripts/supply-chain/hermetic-build.sh

# 2. Generate provenance
bash scripts/supply-chain/build-provenance.sh

# 3. Upload to Rekor
bash scripts/supply-chain/rekor-upload.sh --all

# 4. Verify SLSA attestations
bash scripts/supply-chain/verify-slsa.sh --all

# 5. Generate compliance report
bash scripts/supply-chain/slsa-report.sh
```

---

## Compliance Reports

Reports are generated in markdown and placed in `artifacts/release/`:

| Report | Description |
|:---|:---|
| `provenance/provenance-report.md` | Provenance generation summary |
| `hermetic/hermetic-build-report.md` | Hermetic build details |
| `rekor/rekor-upload-report.md` | Rekor transparency log uploads |
| `verify-slsa/slsa-verification-report.md` | SLSA verification results |
| `slsa-level3-report.md` | Complete SLSA Level 3+ compliance report |

---

## Future Improvements (SLSA Level 4)

| Requirement | Current Status | Path to L4 |
|:---|:---|:---|
| Two-person review | Not implemented | Require PR approval + separate CI approval for releases |
| Hermetic by default | Implemented | Extend to all build types |
| Dependency pinning | Base images pinned | Pin all transitive dependencies |
| Zero network policy | Build level | Extend to CI pipeline level |
| Reproducible builds | Documented | Verify byte-for-byte reproducibility |
| All dependencies attested | Base images | Attest all third-party dependencies |
| Build platform attestation | CI runner | Generate platform attestation for runner integrity |

---

## References

- [SLSA Specification v1.0](https://slsa.dev/spec/v1.0/)
- [Sigstore / Cosign](https://docs.sigstore.dev/cosign/overview/)
- [Rekor Transparency Log](https://docs.sigstore.dev/rekor/overview/)
- [SLSA GitHub Actions Builder](https://github.com/slsa-framework/slsa-github-generator)
- [in-toto Attestation Framework](https://in-toto.io/)
