# No-Rebuild Deploy Evidence - SecureRAG Hub

- Generated at UTC: `2026-06-21T10:34:37Z`
- Namespace: `securerag-hub`
- Overlay: `infra/k8s/overlays/demo`
- Registry: `localhost:5001`
- Image prefix: `securerag-hub`
- Image tag fallback: `demo`
- Digest file: `none`
- Require digest deploy: `false`

- Forced rollout: `true`
- Deploy started at: `2026-06-21T10:34:15Z`
- Runtime image proof: `artifacts/validation/runtime-image-rollout-proof.md`

## Runtime deployments

```text
NAME                     READY   UP-TO-DATE   AVAILABLE   AGE    CONTAINERS               IMAGES                                                     SELECTOR
audit-security-service   1/1     1            1           104m   audit-security-service   localhost:5001/securerag-hub-audit-security-service:demo   app.kubernetes.io/name=audit-security-service,app.kubernetes.io/part-of=securerag-hub
auth-users               1/1     1            1           104m   auth-users               localhost:5001/securerag-hub-auth-users:demo               app.kubernetes.io/name=auth-users,app.kubernetes.io/part-of=securerag-hub
chatbot-manager          1/1     1            1           104m   chatbot-manager          localhost:5001/securerag-hub-chatbot-manager:demo          app.kubernetes.io/name=chatbot-manager,app.kubernetes.io/part-of=securerag-hub
conversation-service     1/1     1            1           104m   conversation-service     localhost:5001/securerag-hub-conversation-service:demo     app.kubernetes.io/name=conversation-service,app.kubernetes.io/part-of=securerag-hub
portal-web               1/1     1            1           104m   portal-web               localhost:5001/securerag-hub-portal-web:demo               app.kubernetes.io/name=portal-web,app.kubernetes.io/part-of=securerag-hub
postgres-auth            1/1     1            1           104m   postgres-auth            postgres:16-alpine                                         app.kubernetes.io/name=postgres-auth,app.kubernetes.io/part-of=securerag-hub
```

## Runtime images

```text
audit-security-service	localhost:5001/securerag-hub-audit-security-service:demo 
auth-users	localhost:5001/securerag-hub-auth-users:demo 
chatbot-manager	localhost:5001/securerag-hub-chatbot-manager:demo 
conversation-service	localhost:5001/securerag-hub-conversation-service:demo 
portal-web	localhost:5001/securerag-hub-portal-web:demo 
postgres-auth	postgres:16-alpine 
```
