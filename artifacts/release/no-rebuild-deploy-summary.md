# No-Rebuild Deploy Evidence - SecureRAG Hub

- Generated at UTC: `2026-06-22T21:55:17Z`
- Namespace: `securerag-hub`
- Overlay: `infra/k8s/overlays/dev`
- Registry: `localhost:5001`
- Image prefix: `securerag-hub`
- Image tag fallback: `dev`
- Digest file: `none`
- Require digest deploy: `false`

- Forced rollout: `true`
- Deploy started at: `2026-06-22T21:54:59Z`
- Runtime image proof: `artifacts/validation/runtime-image-rollout-proof.md`

## Runtime deployments

```text
NAME                     READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS               IMAGES                                                    SELECTOR
audit-security-service   1/1     1            1           24h   audit-security-service   localhost:5001/securerag-hub-audit-security-service:dev   app.kubernetes.io/name=audit-security-service,app.kubernetes.io/part-of=securerag-hub
auth-users               1/1     1            1           24h   auth-users               localhost:5001/securerag-hub-auth-users:dev               app.kubernetes.io/name=auth-users,app.kubernetes.io/part-of=securerag-hub
chatbot-manager          1/1     1            1           24h   chatbot-manager          localhost:5001/securerag-hub-chatbot-manager:dev          app.kubernetes.io/name=chatbot-manager,app.kubernetes.io/part-of=securerag-hub
conversation-service     1/1     1            1           24h   conversation-service     localhost:5001/securerag-hub-conversation-service:dev     app.kubernetes.io/name=conversation-service,app.kubernetes.io/part-of=securerag-hub
portal-web               1/1     1            1           24h   portal-web               localhost:5001/securerag-hub-portal-web:dev               app.kubernetes.io/name=portal-web,app.kubernetes.io/part-of=securerag-hub
postgres-auth            1/1     1            1           24h   postgres-auth            postgres:16-alpine                                        app.kubernetes.io/name=postgres-auth,app.kubernetes.io/part-of=securerag-hub
```

## Runtime images

```text
audit-security-service	localhost:5001/securerag-hub-audit-security-service:dev 
auth-users	localhost:5001/securerag-hub-auth-users:dev 
chatbot-manager	localhost:5001/securerag-hub-chatbot-manager:dev 
conversation-service	localhost:5001/securerag-hub-conversation-service:dev 
portal-web	localhost:5001/securerag-hub-portal-web:dev 
postgres-auth	postgres:16-alpine 
```
