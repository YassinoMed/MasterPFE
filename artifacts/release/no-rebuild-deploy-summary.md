# No-Rebuild Deploy Evidence - SecureRAG Hub

- Generated at UTC: `2026-04-22T14:53:17Z`
- Namespace: `securerag-hub`
- Overlay: `infra/k8s/overlays/production`
- Registry: `localhost:5001`
- Image prefix: `securerag-hub`
- Image tag fallback: `production`
- Digest file: `none`
- Require digest deploy: `false`

- Forced rollout: `true`
- Deploy started at: `2026-04-22T14:51:46Z`
- Runtime image proof: `artifacts/validation/runtime-image-rollout-proof.md`

## Runtime deployments

```text
NAME                     READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS               IMAGES                                                           SELECTOR
audit-security-service   2/2     2            2           91s   audit-security-service   localhost:5001/securerag-hub-audit-security-service:production   app.kubernetes.io/name=audit-security-service,app.kubernetes.io/part-of=securerag-hub
auth-users               2/2     2            2           91s   auth-users               localhost:5001/securerag-hub-auth-users:production               app.kubernetes.io/name=auth-users,app.kubernetes.io/part-of=securerag-hub
chatbot-manager          2/2     2            2           91s   chatbot-manager          localhost:5001/securerag-hub-chatbot-manager:production          app.kubernetes.io/name=chatbot-manager,app.kubernetes.io/part-of=securerag-hub
conversation-service     2/2     2            2           91s   conversation-service     localhost:5001/securerag-hub-conversation-service:production     app.kubernetes.io/name=conversation-service,app.kubernetes.io/part-of=securerag-hub
portal-web               3/3     3            3           91s   portal-web               localhost:5001/securerag-hub-portal-web:production               app.kubernetes.io/name=portal-web,app.kubernetes.io/part-of=securerag-hub
```

## Runtime images

```text
audit-security-service	localhost:5001/securerag-hub-audit-security-service:production 
auth-users	localhost:5001/securerag-hub-auth-users:production 
chatbot-manager	localhost:5001/securerag-hub-chatbot-manager:production 
conversation-service	localhost:5001/securerag-hub-conversation-service:production 
portal-web	localhost:5001/securerag-hub-portal-web:production 
```
