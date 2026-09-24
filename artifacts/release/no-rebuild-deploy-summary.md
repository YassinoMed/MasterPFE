# No-Rebuild Deploy Evidence - SecureRAG Hub

- Generated at UTC: `2026-09-22T12:09:57Z`
- Namespace: `securerag-hub`
- Overlay: `infra/k8s/overlays/dev`
- Registry: `localhost:5001`
- Image prefix: `securerag-hub`
- Image tag fallback: `dev`
- Digest file: `artifacts/release/promotion-digests.txt`
- Require digest deploy: `true`

- Forced rollout: `true`
- Deploy started at: `2026-09-22T12:09:20Z`
- Runtime image proof: `artifacts/validation/runtime-image-rollout-proof.md`

## Runtime deployments

```text
NAME                     READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS               IMAGES                                                                                                                        SELECTOR
audit-security-service   1/1     1            1           28h   audit-security-service   localhost:5001/securerag-hub-audit-security-service@sha256:f681d9c8f698b01be192a2471cc5230652ccc0f2ce8fcbe86433e468ede0a58b   app.kubernetes.io/name=audit-security-service,app.kubernetes.io/part-of=securerag-hub
auth-users               1/1     1            1           28h   auth-users               localhost:5001/securerag-hub-auth-users@sha256:0d7795be3c8c678f3616779b1365d5ae160efce38b6a2e03c8b6fba3bf74ec93               app.kubernetes.io/name=auth-users,app.kubernetes.io/part-of=securerag-hub
chatbot-manager          1/1     1            1           28h   chatbot-manager          localhost:5001/securerag-hub-chatbot-manager@sha256:7d52f77d49fe1b3f458cb4c06ac9f3568c2f48c3a4f27dff56a39d59a11195eb          app.kubernetes.io/name=chatbot-manager,app.kubernetes.io/part-of=securerag-hub
conversation-service     1/1     1            1           28h   conversation-service     localhost:5001/securerag-hub-conversation-service@sha256:68e3d1f29ed008be81171d5a9f7711da5b030ad2e26846828905def992fe5b6c     app.kubernetes.io/name=conversation-service,app.kubernetes.io/part-of=securerag-hub
portal-web               1/1     1            1           28h   portal-web               localhost:5001/securerag-hub-portal-web@sha256:6b7081614bec1aadb1f526a828baed62e7a3803b7d4f7b60465dcc317223ea0c               app.kubernetes.io/name=portal-web,app.kubernetes.io/part-of=securerag-hub
postgres-auth            1/1     1            1           28h   postgres-auth            localhost:5001/postgres:16-alpine                                                                                             app.kubernetes.io/name=postgres-auth,app.kubernetes.io/part-of=securerag-hub
```

## Runtime images

```text
audit-security-service	localhost:5001/securerag-hub-audit-security-service@sha256:f681d9c8f698b01be192a2471cc5230652ccc0f2ce8fcbe86433e468ede0a58b 
auth-users	localhost:5001/securerag-hub-auth-users@sha256:0d7795be3c8c678f3616779b1365d5ae160efce38b6a2e03c8b6fba3bf74ec93 
chatbot-manager	localhost:5001/securerag-hub-chatbot-manager@sha256:7d52f77d49fe1b3f458cb4c06ac9f3568c2f48c3a4f27dff56a39d59a11195eb 
conversation-service	localhost:5001/securerag-hub-conversation-service@sha256:68e3d1f29ed008be81171d5a9f7711da5b030ad2e26846828905def992fe5b6c 
portal-web	localhost:5001/securerag-hub-portal-web@sha256:6b7081614bec1aadb1f526a828baed62e7a3803b7d4f7b60465dcc317223ea0c 
postgres-auth	localhost:5001/postgres:16-alpine 
```
