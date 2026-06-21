# Runtime Image Rollout Proof - SecureRAG Hub

- Generated at UTC: `2026-06-21T08:50:19Z`
- Namespace: `securerag-hub`
- Registry: `localhost:5001`
- Image prefix: `securerag-hub`
- Image tag: `dev`
- Require digest deploy: `true`
- Digest record file: `artifacts/release/promotion-digests.txt`
- Deploy started at: `not provided`
- Status: `PARTIEL`

| Service | Status | Desired | Ready pods | Recent pods | Expected image/digest | Runtime image proof |
|---|---:|---:|---:|---:|---|---|
| `auth-users` | PARTIEL | 1 | 0 | not_checked | `missing digest` | imageID/digest matched |
| `chatbot-manager` | PARTIEL | 1 | 0 | not_checked | `missing digest` | imageID/digest matched |
| `conversation-service` | PARTIEL | 1 | 0 | not_checked | `missing digest` | imageID/digest matched |
| `audit-security-service` | PARTIEL | 1 | 0 | not_checked | `missing digest` | imageID/digest matched |
| `portal-web` | PARTIEL | 1 | 0 | not_checked | `missing digest` | imageID/digest matched |

## Runtime pod details

### auth-users

- Deployment images: `localhost:5001/securerag-hub-auth-users:dev`
- Deployment image ok: `False`
- Digest record ok: `False`
- `auth-users-799b8b5664-whwzb` ready=`False` created=`2026-06-21T08:49:51Z` recent=`None` imageIDMatch=`True`
  - imageID: ``
- `auth-users-c4b94d64b-t6k79` ready=`False` created=`2026-06-21T08:49:51Z` recent=`None` imageIDMatch=`True`
  - imageID: ``

### chatbot-manager

- Deployment images: `localhost:5001/securerag-hub-chatbot-manager:dev`
- Deployment image ok: `False`
- Digest record ok: `False`
- `chatbot-manager-779b7cc44b-bskxh` ready=`False` created=`2026-06-21T08:49:51Z` recent=`None` imageIDMatch=`True`
  - imageID: ``
- `chatbot-manager-976899cb8-jprbg` ready=`False` created=`2026-06-21T08:49:52Z` recent=`None` imageIDMatch=`True`
  - imageID: ``

### conversation-service

- Deployment images: `localhost:5001/securerag-hub-conversation-service:dev`
- Deployment image ok: `False`
- Digest record ok: `False`
- `conversation-service-64f99b44db-6n2vv` ready=`False` created=`2026-06-21T08:49:52Z` recent=`None` imageIDMatch=`True`
  - imageID: ``
- `conversation-service-778479dbbf-wwfcx` ready=`False` created=`2026-06-21T08:49:51Z` recent=`None` imageIDMatch=`True`
  - imageID: ``

### audit-security-service

- Deployment images: `localhost:5001/securerag-hub-audit-security-service:dev`
- Deployment image ok: `False`
- Digest record ok: `False`
- `audit-security-service-5fddbb654-n5ltk` ready=`False` created=`2026-06-21T08:49:51Z` recent=`None` imageIDMatch=`True`
  - imageID: ``
- `audit-security-service-b478dc875-b5s9d` ready=`False` created=`2026-06-21T08:49:52Z` recent=`None` imageIDMatch=`True`
  - imageID: ``

### portal-web

- Deployment images: `localhost:5001/securerag-hub-portal-web:dev`
- Deployment image ok: `False`
- Digest record ok: `False`
- `portal-web-68d97f97f-2sjcd` ready=`False` created=`2026-06-21T08:49:51Z` recent=`None` imageIDMatch=`True`
  - imageID: ``
- `portal-web-6ff6cd4545-swmh5` ready=`False` created=`2026-06-21T08:49:51Z` recent=`None` imageIDMatch=`True`
  - imageID: ``

## Honest interpretation

- `TERMINÉ` means the deployment spec, Ready pods and runtime container image IDs match the expected tag or promoted digest.
- When `DEPLOY_STARTED_AT` is provided, pods must also be newer than the deployment action. This catches `deployment unchanged` false positives.
- Digest mode is complete only when `REQUIRE_DIGEST_DEPLOY=true` and every service has a valid promoted digest record.
