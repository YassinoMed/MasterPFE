# Supply Chain Mandatory Evidence Gate

- Generated at: `2026-09-24T08:01:22Z`
- REQUIRE_SUPPLY_CHAIN_EVIDENCE: `true`
- Expected services: `5`
- Services: `auth-users chatbot-manager conversation-service audit-security-service portal-web`

| Required evidence | Status | Detail |
|---|---:|---|
| Trivy image scan summary | OK | PASS=0, WARN=5, accepted=5/5, sha256=d4417b8999a292e41621e7d32f528b2807f4662dd48b471db26a4e92350ba584 |
| Cosign sign summary | OK | PASS=5/5, sha256=b8dada426b85c1a16e1085cf1dd01658d9e09e76b3610a9db9850714d82b0821 |
| Cosign verify summary | OK | PASS=5/5, sha256=f2b4ddf777cae2517b3e0fc063a801d87efa7828f8160ea86cb58a0fc8231ea7 |
| Digest promotion summary | OK | PASS=5/5, sha256=db9ac47d19f5fab97dee7a0d78299f02013a34bb1b942fa9a3ae5e97030f50e0 |
| Digest promotion record | OK | records=5/5, sha256=5a01a81f842d494906bd8debdc779bddd8e0c75e0fc0cf78bfe819f627601f67 |
| SBOM generation summary | OK | PASS=5/5, sha256=5d0240522185d9b2747ccc7ac7f58d81f2b43d44af0f5dd9c43da8d3a85c7881 |
| Cosign SBOM attestation summary | OK | PASS=5/5, sha256=9f76c4a51fe4feabdd6db8af9926ff3dd7536d6a9e07f3f8bf739ad2fe11b779 |
| SBOM index | OK | records=5/5, sha256=219dd79b87f9ee73059596a14992196438554978eec38f7aa5ddc3a6b7827099 |
| Release attestation | OK | status=COMPLETE_PROVEN, sha256=24840af9dc7a59236fed9d9cf7c36e6bd975e5b31bcf361642594657787d0862 |

## Global status

Statut global: `TERMINÉ`

All mandatory supply-chain release gates are proven for the expected official services.
