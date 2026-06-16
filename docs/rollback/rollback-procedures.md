# Rollback Procedures — SecureRAG Hub
# Chaque composant a un rollback documenté.

## Production (composants existants — non modifiés)

| Composant | Rollback | Temps estimé |
|-----------|----------|:------------:|
| 5 services Laravel | ArgoCD: `argocd app rollback securerag-production <REV>` | < 30s |
| Jenkins | `docker compose -f infra/jenkins/docker-compose.yml down && docker compose up -d` | < 60s |
| ArgoCD | `kubectl delete -k infra/k8s/argocd && kubectl apply -k infra/k8s/argocd` | < 120s |
| Prometheus | `kubectl rollout undo deploy/prometheus -n securerag-monitoring` | < 30s |
| Grafana | `kubectl rollout undo deploy/grafana -n securerag-monitoring` | < 30s |
| Loki | `kubectl rollout undo deploy/loki -n securerag-monitoring` | < 30s |
| Alertmanager | `kubectl rollout undo deploy/alertmanager -n securerag-monitoring` | < 30s |
| Falco | `kubectl rollout undo daemonset/falco -n falco` | < 30s |
| Kyverno | `make kyverno-enforce-off` (Audit mode) | < 10s |
| Harbor | `kubectl rollout undo deploy/harbor -n harbor` | < 60s |
| Vault | `kubectl rollout undo deploy/vault -n vault` | < 60s |
| Velero | `kubectl rollout undo deploy/velero -n velero` | < 60s |
| PostgreSQL | `kubectl create job --from=cronjob/postgres-backup restore-$(date +%s) -n securerag-backup` | < 5 min |

## Nouveaux composants (PHASE 1-9)

| Composant | Feature Flag | Rollback | Temps |
|-----------|:-----------:|----------|:-----:|
| Multi-cluster staging | ENABLE_STAGING_CLUSTER=false | `kubectl delete application securerag-staging -n argocd` | < 10s |
| Multi-cluster DR | ENABLE_DR_CLUSTER=false | `kubectl delete application securerag-dr -n argocd` | < 10s |
| AWS EKS | count=0 | `terraform destroy -target=aws_eks_cluster.securerag` | < 10 min |
| Azure AKS | count=0 | `terraform destroy -target=azurerm_kubernetes_cluster.securerag` | < 10 min |
| GCP GKE | count=0 | `terraform destroy -target=google_container_cluster.securerag` | < 10 min |
| SLSA 4 | ENABLE_SLSA4=false | Retour à SLSA 3+ automatique | Instantané |
| Backstage | ENABLE_BACKSTAGE=false | `kubectl delete ns backstage-system` | < 30s |
| AIOps | ENABLE_AIOPS=false | `kubectl delete ns aiops-system` | < 30s |
| OpenTelemetry | ENABLE_OPENTELEMETRY=false | `kubectl delete ns otel-system` | < 30s |
| Istio | ENABLE_SERVICE_MESH=false | `istioctl uninstall --purge -y` | < 60s |
| Chaos Mesh | ENABLE_CHAOS_MESH=false | `helm uninstall chaos-mesh -n chaos-mesh` | < 30s |
| Argo Rollouts | ENABLE_ARGO_ROLLOUTS=false | `kubectl delete rollout chatbot-manager-canary` | < 10s |

## Rollback global

```bash
# Revenir à l'état exact avant toute nouvelle fonctionnalité
kubectl delete configmap securerag-feature-flags -n securerag-hub --ignore-not-found
for ns in backstage-system aiops-system otel-system chaos-mesh istio-system; do
  kubectl delete ns $ns --ignore-not-found --timeout=60s
done
kubectl delete applicationset securerag-multi-cluster -n argocd --ignore-not-found
echo "Rollback complete. Production unchanged."
```
