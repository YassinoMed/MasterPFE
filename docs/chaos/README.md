# Chaos Engineering — Advanced Testing

## Experiments (désactivés par défaut)

| Experiment | Type | Cible | Durée | Impact |
|-----------|------|-------|:-----:|--------|
| Pod Kill | PodChaos | portal-web | 30s | Auto-heal K8s |
| Network Partition | NetworkChaos | chatbot-manager | 10s | Istio retry |
| CPU Stress | StressChaos | portal-web | 60s | HPA scale |
| Container Kill | PodChaos | postgres-auth | 30s | CNPG failover |
| Node Drain | NodeChaos | worker-1 | 120s | Pod reschedule |
| Network Loss 100% | NetworkChaos | auth-users | 30s | Circuit breaker |

## Feature Flag
`ENABLE_CHAOS_MESH=false` (défaut)

## Activation (staging UNIQUEMENT)
```bash
export ENABLE_CHAOS_MESH=true
helm install chaos-mesh chaos-mesh/chaos-mesh --namespace=chaos-mesh --create-namespace
kubectl apply -f infra/k8s/chaos-mesh/experiments.yaml
```

## Mesures
```bash
# Avant le chaos
kubectl get pods -n securerag-hub -o wide > /tmp/pre-chaos.txt

# Pendant le chaos
kubectl get pods -n securerag-hub -w

# Après le chaos — vérifier auto-healing
kubectl rollout status deploy/portal-web -n securerag-hub --timeout=120s

# Mesurer RTO
echo "RTO: $(kubectl get deploy portal-web -n securerag-hub -o jsonpath='{.status.conditions[?(@.type=="Available")].lastTransitionTime}')"
```

## Rollback
```bash
kubectl delete -f infra/k8s/chaos-mesh/experiments.yaml
helm uninstall chaos-mesh -n chaos-mesh
```

## Risques
| Risque | Probabilité | Impact | Mitigation |
|--------|:----------:|:------:|------------|
| Chaos sur production | Nulle | Critique | ENABLE_CHAOS=false + namespace staging |
| Non-récupération | Faible | Élevé | Auto-healing K8s + PDB + HPA |
| Alerte fatiguée | Moyen | Faible | Alertmanager silence rules |
