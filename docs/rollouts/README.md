# Argo Rollouts — Progressive Delivery

## Architecture
- **Rollout** : remplace Deployment pour chatbot-manager
- **Canary** : 10% → 30% → 50% → 100% (pauses 60-120s)
- **Analysis** : Prometheus (error-rate < 5%, p95-latency < 0.5s)
- **Abort** : automatique si Analysis échoue

## Feature Flag
`ENABLE_ARGO_ROLLOUTS=false` (défaut)

## Installation
```bash
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
kubectl apply -f infra/k8s/argo-rollouts/canary-strategy.yaml
```

## Canary Deployment Workflow
```
Stable v1 (100%)          Canary v2 (0%)
       │                        │
       ├─ Step 1: 10% v2 ──────┤  (60s pause, analyse Prometheus)
       ├─ Step 2: 30% v2 ──────┤  (60s pause)
       ├─ Step 3: 50% v2 ──────┤  (120s pause)
       └─ Step 4: 100% v2 ─────┤  (promotion complète)
                                  │
                            Si error-rate > 5% → ABORT → rollback v1
```

## Promotion
```bash
kubectl argo rollouts promote chatbot-manager-canary -n securerag-hub
kubectl argo rollouts get rollout chatbot-manager-canary -n securerag-hub --watch
```

## Abort / Rollback
```bash
kubectl argo rollouts abort chatbot-manager-canary -n securerag-hub
kubectl argo rollouts undo chatbot-manager-canary -n securerag-hub
```

## Rollback Complet
```bash
kubectl delete rollout chatbot-manager-canary -n securerag-hub
kubectl apply -k infra/k8s/base/chatbot-manager
```

## Risques
| Risque | Probabilité | Impact | Mitigation |
|--------|:----------:|:------:|------------|
| Canary défectueux | Faible | Moyen | Analysis auto-abort |
| Prometheus indisponible | Faible | Moyen | failureLimit: 2 |
| Trop lent | Faible | Faible | Pauses courtes |
