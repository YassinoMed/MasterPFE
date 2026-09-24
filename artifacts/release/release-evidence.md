# SecureRAG Hub Release Evidence

- Generated at (UTC): `2026-09-23T03:59:22Z`
- Registry: `localhost:5001`
- Image prefix: `securerag-hub`
- Source tag: `dev`
- Target tag: `release-local`

## Release artefacts

| Artefact | Statut |
|---|---|
| `image-scan-summary.txt` | present |
| `verify-summary.txt` | present |
| `promotion-summary.txt` | present |
| `promotion-by-digest-summary.txt` | present |
| `promotion-digests.txt` | present |
| `sign-summary.txt` | present |
| `sbom-summary.txt` | present |
| `attest-summary.txt` | present |
| `release-manifest.env` | present |
| `supply-chain-evidence.md` | present |

## Digests promoted

| Service | Source | Target | Digest |
|---|---|---|---|
| `auth-users` | `localhost:5001/securerag-hub-auth-users:dev` | `localhost:5001/securerag-hub-auth-users:release-local` | `sha256:0d7795be3c8c678f3616779b1365d5ae160efce38b6a2e03c8b6fba3bf74ec93` |
| `chatbot-manager` | `localhost:5001/securerag-hub-chatbot-manager:dev` | `localhost:5001/securerag-hub-chatbot-manager:release-local` | `sha256:7d52f77d49fe1b3f458cb4c06ac9f3568c2f48c3a4f27dff56a39d59a11195eb` |
| `conversation-service` | `localhost:5001/securerag-hub-conversation-service:dev` | `localhost:5001/securerag-hub-conversation-service:release-local` | `sha256:68e3d1f29ed008be81171d5a9f7711da5b030ad2e26846828905def992fe5b6c` |
| `audit-security-service` | `localhost:5001/securerag-hub-audit-security-service:dev` | `localhost:5001/securerag-hub-audit-security-service:release-local` | `sha256:f681d9c8f698b01be192a2471cc5230652ccc0f2ce8fcbe86433e468ede0a58b` |
| `portal-web` | `localhost:5001/securerag-hub-portal-web:dev` | `localhost:5001/securerag-hub-portal-web:release-local` | `sha256:88492602d12bf81f4a6c8f611fb82f75de067e147a4fc0639989b33c7d2a905b` |

## SBOM inventory

- `audit-security-service-sbom.cdx.json`
- `auth-users-sbom.cdx.json`
- `chatbot-manager-sbom.cdx.json`
- `conversation-service-sbom.cdx.json`
- `portal-web-sbom.cdx.json`

## Notes

- This document records release evidence only; runtime validation evidence is stored under `artifacts/validation/`.
- Consolidated supply-chain evidence is stored in `artifacts/release/supply-chain-evidence.md` when generated.
- If image scanning, SBOM attestation or promotion by digest has not run yet, tag-level evidence may exist without complete release evidence.
