# Digest Promotion Manifest - SecureRAG Hub

- Generated at UTC: `2026-09-23T03:58:34Z`
- Source tag: `dev`
- Target tag: `release-local`
- Digest record: `artifacts/release/promotion-digests.txt`
- JSON manifest: `artifacts/release/promotion-digests.json`

| Service | Status | Source image | Target image | Digest | Log | Detail |
|---|---:|---|---|---|---|---|
| `auth-users` | `PASS` | `localhost:5001/securerag-hub-auth-users:dev` | `localhost:5001/securerag-hub-auth-users:release-local` | `sha256:0d7795be3c8c678f3616779b1365d5ae160efce38b6a2e03c8b6fba3bf74ec93` | `artifacts/release/auth-users-promote-by-digest.log` | image promoted by digest without rebuild; target digest matched |
| `chatbot-manager` | `PASS` | `localhost:5001/securerag-hub-chatbot-manager:dev` | `localhost:5001/securerag-hub-chatbot-manager:release-local` | `sha256:7d52f77d49fe1b3f458cb4c06ac9f3568c2f48c3a4f27dff56a39d59a11195eb` | `artifacts/release/chatbot-manager-promote-by-digest.log` | image promoted by digest without rebuild; target digest matched |
| `conversation-service` | `PASS` | `localhost:5001/securerag-hub-conversation-service:dev` | `localhost:5001/securerag-hub-conversation-service:release-local` | `sha256:68e3d1f29ed008be81171d5a9f7711da5b030ad2e26846828905def992fe5b6c` | `artifacts/release/conversation-service-promote-by-digest.log` | image promoted by digest without rebuild; target digest matched |
| `audit-security-service` | `PASS` | `localhost:5001/securerag-hub-audit-security-service:dev` | `localhost:5001/securerag-hub-audit-security-service:release-local` | `sha256:f681d9c8f698b01be192a2471cc5230652ccc0f2ce8fcbe86433e468ede0a58b` | `artifacts/release/audit-security-service-promote-by-digest.log` | image promoted by digest without rebuild; target digest matched |
| `portal-web` | `PASS` | `localhost:5001/securerag-hub-portal-web:dev` | `localhost:5001/securerag-hub-portal-web:release-local` | `sha256:88492602d12bf81f4a6c8f611fb82f75de067e147a4fc0639989b33c7d2a905b` | `artifacts/release/portal-web-promote-by-digest.log` | image promoted by digest without rebuild; target digest matched |

## Result

- PASS: `5`
- FAIL: `0`
- SKIP: `0`
- Digest record: `artifacts/release/promotion-digests.txt`
- JSON manifest: `artifacts/release/promotion-digests.json`
