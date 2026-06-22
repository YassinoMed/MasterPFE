#!/usr/bin/env bash
# deploy-observability.sh — Deploy full Observability Stack (Prometheus, Grafana, Alertmanager, Loki, Tempo)
# SecureRAG Hub — Enterprise Observability
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { printf "${GREEN}[INFO]${NC}  %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }
step()  { printf "${BLUE}[STEP]${NC}  %s\n" "$*"; }

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  OBSERVABILITY STACK — DEPLOYMENT"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Phase 1: Create namespaces
step "Phase 1/7: Creating namespaces..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace loki --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace tempo --dry-run=client -o yaml | kubectl apply -f -
info "Namespaces ready"

# Phase 2: Deploy Prometheus Stack
step "Phase 2/7: Deploying Prometheus Stack..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update prometheus-community

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --values infra/helm/prometheus/values-production.yaml \
  --wait --timeout 10m

info "Prometheus Stack deployed"

# Phase 3: Deploy Grafana (additional dashboards)
step "Phase 3/7: Configuring Grafana..."
helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
helm repo update grafana

helm upgrade --install grafana grafana/grafana \
  --namespace monitoring --create-namespace \
  --wait --timeout 5m

info "Grafana configured"

# Phase 4: Deploy Alertmanager
step "Phase 4/7: Deploying Alertmanager..."
helm upgrade --install alertmanager prometheus-community/alertmanager \
  --namespace monitoring --create-namespace \
  --values infra/helm/alertmanager/values-production.yaml \
  --wait --timeout 5m

info "Alertmanager deployed"

# Phase 5: Deploy Loki (Logs)
step "Phase 5/7: Deploying Loki (Log Aggregation)..."
helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
helm repo update grafana

helm upgrade --install loki grafana/loki-stack \
  --namespace loki --create-namespace \
  --values infra/helm/loki/values-production.yaml \
  --wait --timeout 10m

info "Loki deployed"

# Phase 6: Deploy Tempo (Traces)
step "Phase 6/7: Deploying Tempo (Distributed Tracing)..."
helm upgrade --install tempo grafana/tempo \
  --namespace tempo --create-namespace \
  --values infra/helm/tempo/values-production.yaml \
  --wait --timeout 10m

info "Tempo deployed"

# Phase 7: Verify
step "Phase 7/7: Verifying deployment..."
echo ""
info "Pods in monitoring:"
kubectl get pods -n monitoring -o wide
echo ""
info "Pods in loki:"
kubectl get pods -n loki -o wide
echo ""
info "Pods in tempo:"
kubectl get pods -n tempo -o wide
echo ""

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  ✅ OBSERVABILITY STACK DEPLOYMENT COMPLETE"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "  Access URLs (via port-forward):"
echo "    Grafana:      kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:8:8:80"
echo "    Prometheus:   kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090"
echo "    Alertmanager: kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093"
echo "    Loki:         kubectl port-forward -n loki svc/loki 3100:3100"
echo "    Tempo:        kubectl port-forward -n tempo svc/tempo 3200:3200"
echo ""
echo "  Default Grafana credentials:"
echo "    User: admin"
echo "    Pass: (check secret kube-prometheus-stack-grafana in monitoring namespace)"
echo ""
echo "  Data sources auto-configured in Grafana:"
echo "    - Prometheus (metrics)"
echo "    - Loki (logs)"
echo "    - Tempo (traces)"
echo ""
echo "  To verify logs:     kubectl logs -n loki -l app=loki --tail=20"
echo "  To verify traces:   kubectl logs -n tempo -l app=tempo --tail=20"
echo ""

# Wait for readiness
step "Waiting for all pods to be Ready..."
kubectl wait --for=condition=Ready pods --all -n monitoring --timeout=300s 2>/dev/null || warn "Some monitoring pods not ready yet"
kubectl wait --for=condition=Ready pods --all -n loki --timeout=300s 2>/dev/null || warn "Some loki pods not ready yet"
kubectl wait --for=condition=Ready pods --all -n tempo --timeout=300s 2>/dev/null || warn "Some tempo pods not ready yet"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Observability stack is ready!"
echo "═══════════════════════════════════════════════════════════════"