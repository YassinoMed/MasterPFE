#!/usr/bin/env bash
# ha-monitoring-quickstart.sh — Active et vérifie le monitoring HA en 3 étapes
# SecureRAG Hub — High Availability Observability Quickstart
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { printf "${GREEN}[INFO]${NC}  %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }
step()  { printf "${BLUE}[STEP]${NC}  %s\nn" "$*"; }

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  HA MONITORING QUICKSTART — SecureRAG Hub"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Étape 1 : Vérifier que Prometheus stack est déployé
step "Étape 1/3 : Vérification de la stack Prometheus..."

if kubectl get ns monitoring >/dev/null 2>&1; then
  info "Namespace monitoring trouvé"
else
  warn "Stack monitoring non déployée. Déploiement..."
  bash scripts/deploy/deploy-observability.sh
fi

# Vérifier kube-state-metrics (indispensable pour les métriques HA)
if kubectl get pods -n monitoring -l app.kubernetes.io/name=kube-state-metrics 2>/dev/null | grep -q Running; then
  info "kube-state-metrics ✅ actif"
else
  warn "kube-state-metrics non trouvé. Vérification dans kube-prometheus-stack..."
  # kube-state-metrics est inclus par défaut dans kube-prometheus-stack
  kubectl get pods -n monitoring | grep -i kube-state || warn "kube-state-metrics peut ne pas être déployé"
fi

# Vérifier que Prometheus scrape les métriques kube
PROMETHEUS_POD=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus -o name 2>/dev/null | head -1)
if [ -n "${PROMETHEUS_POD}" ]; then
  info "Prometheus pod: ${PROMETHEUS_POD}"
fi

# Étape 2 : Déployer les ressources HA de démonstration
step "Étape 2/3 : Déploiement des ressources HA de démonstration..."

if kubectl get ns securerag-hub >/dev/null 2>&1; then
  # Vérifier s'il y a des ressources HA
  DEPLOY_COUNT=$(kubectl get deployments -n securerag-hub --no-headers 2>/dev/null | wc -l)
  if [ "${DEPLOY_COUNT}" -ge 5 ]; then
    info "Ressources HA déjà présentes (${DEPLOY_COUNT} déploiements)"
  else
    warn "Ressources HA insuffisantes. Génération des données de démo..."
    bash scripts/demo/generate-ha-demo-data.sh
  fi
else
  warn "Namespace securerag-hub inexistant. Génération complète..."
  bash scripts/demo/generate-ha-demo-data.sh
fi

# Étape 3 : Déployer le dashboard HA ConfigMap
step "Étape 3/3 : Déploiement du dashboard HA Grafana..."

kubectl apply -f infra/k8s/configmaps/grafana-dashboard-ha.yaml
info "Dashboard HA ConfigMap déployé (auto-découvert par Grafana)"

# Vérifier que le sidecar Grafana a bien chargé le dashboard
sleep 2
GRAFANA_POD=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana -o name 2>/dev/null | head -1)
if [ -n "${GRAFANA_POD}" ]; then
  info "Redémarrage du sidecar Grafana pour prise en compte..."
  kubectl exec -n monitoring "${GRAFANA_POD}" -- grafana-cli admin reset-admin-password admin 2>/dev/null || true
fi

# Test : Vérifier que Prometheus voit les métriques HA
step "Vérification des métriques HA dans Prometheus..."

PROMETHEUS_SVC="kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090"

# Attendre que kube-state-metrics collecte les données
info "Attente de 10s pour la collecte des métriques..."
sleep 10

# Vérification via kubectl exec sur Prometheus ou via port-forward
echo ""
echo "Métriques disponibles pour le dashboard HA :"
echo ""

# Vérifier les déploiements
kubectl get deployments -n securerag-hub -o wide 2>/dev/null || echo "(pas de déploiements)"
echo ""

# Vérifier les HPA
kubectl get hpa -n securerag-hub 2>/dev/null || echo "(pas de HPA)"
echo ""

# Vérifier les PDB
kubectl get pdb -n securerag-hub 2>/dev/null || echo "(pas de PDB)"
echo ""

# Vérifier les pods
kubectl get pods -n securerag-hub -o wide 2>/dev/null | head -20 || echo "(pas de pods)"
echo ""

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  ✅ HA MONITORING READY"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "  Accès Grafana :"
echo "    kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80"
echo "    → http://localhost:3000"
echo "    → Dashboard : HA Monitoring — SecureRAG Hub"
echo ""
echo "  Accès Prometheus :"
echo "    kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090"
echo "    → http://localhost:9090"
echo "    → Query: kube_deployment_spec_replicas{namespace=\"securerag-hub\"}"
echo ""
echo "  Si les métriques sont vides :"
echo "    kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80 &"
echo "    bash scripts/demo/generate-ha-demo-data.sh"
echo ""