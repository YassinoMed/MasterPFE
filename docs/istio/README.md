# Istio Service Mesh — mTLS Canary Migration

## Architecture
- **Mode** : PERMISSIVE → STRICT (migration canary)
- **Cible 1** : chatbot-manager (PERMISSIVE 1h → STRICT 2h)
- **Cible 2** : conversation-service (PERMISSIVE 1h)
- **Cible 3** : audit-security-service (PERMISSIVE 1h)

## Feature Flag
`ENABLE_SERVICE_MESH=false` (défaut)

## Installation (désactivée par défaut)
```bash
istioctl install --set profile=minimal -y
kubectl label namespace securerag-hub istio-injection=enabled --overwrite
```

## Activation Canary
```bash
# Étape 1 : PERMISSIVE sur chatbot-manager
kubectl label deploy chatbot-manager -n securerag-hub istio-mtls=canary --overwrite
kubectl apply -f infra/k8s/istio/canary-migration.yaml
# Observer 1h

# Étape 2 : STRICT sur chatbot-manager
kubectl patch peerauthentication securerag-mtls-canary -n securerag-hub \
  --type merge -p '{"spec":{"mtls":{"mode":"STRICT"}}}'
# Observer 2h

# Étape 3 : Étendre à conversation-service
kubectl label deploy conversation-service -n securerag-hub istio-mtls=canary --overwrite
```

## Validation
```bash
istioctl verify-install
istioctl proxy-status
kubectl get peerauthentication -n securerag-hub
kubectl logs -n istio-system -l app=istiod --tail=20
```

## Rollback
```bash
kubectl label namespace securerag-hub istio-injection-
kubectl delete peerauthentication securerag-mtls-canary -n securerag-hub
istioctl uninstall --purge -y
```

## Risques
| Risque | Probabilité | Impact | Mitigation |
|--------|:----------:|:------:|------------|
| Rupture communication | Moyenne | Élevé | PERMISSIVE d'abord |
| Latence sidecar | Faible | Moyen | Resource limits |
| Incompatibilité app | Faible | Élevé | Canary par service |

## Dépendances
- Aucune modification des Services Kubernetes existants
- Aucune modification des Deployments (injection side-car automatique)
