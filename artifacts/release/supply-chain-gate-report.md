# Supply Chain Mandatory Evidence Gate

- Generated at: `2026-09-25T06:53:11Z`
- REQUIRE_SUPPLY_CHAIN_EVIDENCE: `true`
- Expected services: `5`
- Services: `auth-users chatbot-manager conversation-service audit-security-service portal-web`

| Required evidence | Status | Detail |
|---|---:|---|
| Trivy image scan summary | OK | PASS=5, WARN=0, accepted=5/5, sha256=d743ecd42c9dffcca9387f2f4982f7108a538efafa9612d087490cfb24ea2737 |
| Cosign sign summary | FAIL | `artifacts/release/sign-summary.txt`: PASS=0/5, FAIL=0, SKIP=5 |
| Cosign verify summary | OK | PASS=5/5, sha256=01da1b0723c7ce3511f7191295a3eb35fd49805a6fabd44c038eb6be7733fe29 |
| Digest promotion summary | OK | PASS=5/5, sha256=db9ac47d19f5fab97dee7a0d78299f02013a34bb1b942fa9a3ae5e97030f50e0 |
| Digest promotion record | OK | records=5/5, sha256=5a01a81f842d494906bd8debdc779bddd8e0c75e0fc0cf78bfe819f627601f67 |
| SBOM generation summary | OK | PASS=5/5, sha256=3862ad177b57839df0910499865d403e764c065521f4ada8b6bd8b8c0ec89ca0 |
| Cosign SBOM attestation summary | OK | PASS=5/5, sha256=9f76c4a51fe4feabdd6db8af9926ff3dd7536d6a9e07f3f8bf739ad2fe11b779 |
| SBOM index | OK | records=5/5, sha256=1eca931c294509caf7626afa2a1bb4a46eba007c6f8416562e6ea6c72e91c85d |
| Release attestation | FAIL | `artifacts/release/release-attestation.json` is present but not COMPLETE_PROVEN |

## Global status

Statut global: `DÉPENDANT_DE_L_ENVIRONNEMENT`

Required supply-chain evidence is absent or incomplete in the current environment. Run the full release chain with Docker, registry access, Trivy, Syft, Cosign and valid signing keys.
