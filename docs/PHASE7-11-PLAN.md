# Phase 7 (Cilium) + Phase 11 (Chaos) — Plan d'Implémentation

## Phase 7 : Cilium / Zero-Trust
**Statut : NON RÉALISÉ** (nécessite recréation du cluster)
**Prérequis** : Nouveau cluster kind avec `disableDefaultCNI: true`
```bash
kind create cluster --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking: { disableDefaultCNI: true }
EOF
cilium install --set kubeProxyReplacement=true
cilium hubble enable --ui
```
Puis : reproduire les namespaces, NetworkPolicies, workloads, observabilité, ingress, DNS, OTEL.
**Estimation** : 2-3 semaines | **Priorité** : Moyenne

## Phase 11 : Chaos Engineering
**Statut : NON RÉALISÉ** (manifests existent : `infra/k8s/chaos/` + `infra/k8s/chaos-mesh/`)
**Prérequis** : Déployer chaos-mesh ou Litmus dans un namespace de test
```bash
helm install chaos-mesh chaos-mesh/chaos-mesh -n chaos-testing --create-namespace
kubectl apply -f infra/k8s/chaos/experiments.yaml
```
Tests : pod-kill, latency, network-partition, restart.
Métrie : availability, error-rate, latency, recovery-time.
**Estimation** : 3-5 jours | **Priorité** : Basse (nice-to-have)
