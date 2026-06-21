# Runtime Image Rollout Proof - SecureRAG Hub

- Generated at UTC: `2026-06-17T21:51:00Z`
- Namespace: `securerag-hub`
- Registry: `localhost:5001`
- Image prefix: `securerag-hub`
- Image tag: `dev`
- Require digest deploy: `false`
- Digest record file: `artifacts/release/promotion-digests.txt`
- Deploy started at: `not provided`
- Status: `PARTIEL`

| Service | Status | Desired | Ready pods | Recent pods | Expected image/digest | Runtime image proof |
|---|---:|---:|---:|---:|---|---|
| `auth-users` | PARTIEL | 1 | 1 | not_checked | `localhost:5001/securerag-hub-auth-users:dev` | imageID/digest not proven |
| `chatbot-manager` | PARTIEL | 1 | 1 | not_checked | `localhost:5001/securerag-hub-chatbot-manager:dev` | imageID/digest not proven |
| `conversation-service` | PARTIEL | 1 | 1 | not_checked | `localhost:5001/securerag-hub-conversation-service:dev` | imageID/digest not proven |
| `audit-security-service` | PARTIEL | 1 | 1 | not_checked | `localhost:5001/securerag-hub-audit-security-service:dev` | imageID/digest not proven |
| `portal-web` | PARTIEL | 1 | 1 | not_checked | `localhost:5001/securerag-hub-portal-web:dev` | imageID/digest not proven |

## Runtime pod details

### auth-users

- Deployment images: `localhost:5001/securerag-hub-auth-users:demo`
- Deployment image ok: `False`
- Digest record ok: `True`
- `auth-users-6f6b795bc4-xk9x5` ready=`True` created=`2026-06-17T11:51:17Z` recent=`None` imageIDMatch=`False`
  - imageID: `localhost:5001/securerag-hub-auth-users@sha256:0539a63c0387008274def09c44115a07361973950844e7610c24cbbcc113db0f`

### chatbot-manager

- Deployment images: `localhost:5001/securerag-hub-chatbot-manager:demo`
- Deployment image ok: `False`
- Digest record ok: `True`
- `chatbot-manager-58d7f6849b-62rdm` ready=`True` created=`2026-06-17T01:07:15Z` recent=`None` imageIDMatch=`False`
  - imageID: `localhost:5001/securerag-hub-chatbot-manager@sha256:fab7c3001344ff2872c9cf761ffbe62b82d2371063f8b177136245b1eb86af67`

### conversation-service

- Deployment images: `localhost:5001/securerag-hub-conversation-service:demo`
- Deployment image ok: `False`
- Digest record ok: `True`
- `conversation-service-6556bc84fd-n75n4` ready=`True` created=`2026-06-17T01:07:15Z` recent=`None` imageIDMatch=`False`
  - imageID: `localhost:5001/securerag-hub-conversation-service@sha256:c1c7f050e081f70f8aac9f21bcad8633fb3f2049f6752d94f39373d0f8b29b37`

### audit-security-service

- Deployment images: `localhost:5001/securerag-hub-audit-security-service:demo`
- Deployment image ok: `False`
- Digest record ok: `True`
- `audit-security-service-9ff7f9ddc-km222` ready=`True` created=`2026-06-17T01:07:15Z` recent=`None` imageIDMatch=`False`
  - imageID: `localhost:5001/securerag-hub-audit-security-service@sha256:dbe4052bfaa5e483971304008e290afa273b7043d7cefb21e3e2c814a43a574d`

### portal-web

- Deployment images: `localhost:5001/securerag-hub-portal-web:demo`
- Deployment image ok: `False`
- Digest record ok: `True`
- `portal-web-c99d94df-tgk7n` ready=`True` created=`2026-06-17T11:50:59Z` recent=`None` imageIDMatch=`False`
  - imageID: `localhost:5001/securerag-hub-portal-web@sha256:0cbc3de627ab4bc5e9c8d591dc0ec07a063ec3dec32d41984ce0536d66094550`

## Honest interpretation

- `TERMINÉ` means the deployment spec, Ready pods and runtime container image IDs match the expected tag or promoted digest.
- When `DEPLOY_STARTED_AT` is provided, pods must also be newer than the deployment action. This catches `deployment unchanged` false positives.
- Digest mode is complete only when `REQUIRE_DIGEST_DEPLOY=true` and every service has a valid promoted digest record.
