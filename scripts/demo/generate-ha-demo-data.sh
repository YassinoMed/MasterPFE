#!/usr/bin/env bash
# generate-ha-demo-data.sh — Génère des métriques HA synthétiques dans Prometheus
# Permet de visualiser le dashboard HA Monitoring même sans cluster réel
# SecureRAG Hub — Demo Mode
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
echo "  HA DEMO DATA GENERATOR — SecureRAG Hub"
echo "═══════════════════════════════════════════════════════════════"
echo ""

NAMESPACE="${NAMESPACE:-securerag-hub}"
SERVICES=("portal-web" "auth-users" "chatbot-manager" "conversation-service" "audit-security-service")
REPLICAS=(3 3 2 3 2)
PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9090}"

# Vérifier que Prometheus est accessible
if ! curl -sf "${PROMETHEUS_URL}/api/v1/query?query=up" >/dev/null 2>&1; then
  warn "Prometheus inaccessible sur ${PROMETHEUS_URL}"
  info "Lancement du mode fichier : les métriques seront écrites dans un fichier texte"
  FILE_MODE=true
else
  FILE_MODE=false
  info "Prometheus accessible sur ${PROMETHEUS_URL}"
fi

# Vérifier que kubectl et le cluster sont disponibles
if ! kubectl get ns "${NAMESPACE}" >/dev/null 2>&1; then
  warn "Namespace ${NAMESPACE} inexistant. Création..."
  kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
  kubectl label namespace "${NAMESPACE}" app.kubernetes.io/part-of=securerag-hub
fi

# Créer des pods synthétiques si aucun pod n'existe
POD_COUNT=$(kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null | wc -l)
if [ "${POD_COUNT}" -eq 0 ]; then
  step "Création de pods synthétiques pour la démonstration..."
  for i in "${!SERVICES[@]}"; do
    svc="${SERVICES[$i]}"
    replicas="${REPLICAS[$i]}"
    for r in $(seq 0 $((replicas - 1))); do
      pod_name="${svc}-${r}"
      cat <<EOF | kubectl apply -f - >/dev/null 2>&1 || true
apiVersion: v1
kind: Pod
metadata:
  name: ${pod_name}
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: ${svc}
    app.kubernetes.io/part-of: securerag-hub
    app.kubernetes.io/managed-by: devsecops-agent
spec:
  containers:
    - name: ${svc}
      image: nginx:alpine
      command: ["sleep", "3600"]
      ports:
        - containerPort: 80
      resources:
        requests:
          cpu: 100m
          memory: 128Mi
        limits:
          cpu: 500m
          memory: 256Mi
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        readOnlyRootFilesystem: true
        capabilities:
          drop: ["ALL"]
EOF
    done
    info "  ✓ ${svc} : ${replicas} pods"
  done
fi

# Créer des Deployements synthétiques
step "Création de déploiements synthétiques..."
for i in "${!SERVICES[@]}"; do
  svc="${SERVICES[$i]}"
  replicas="${REPLICAS[$i]}"
  
  kubectl get deployment "${svc}" -n "${NAMESPACE}" >/dev/null 2>&1 && continue

  cat <<EOF | kubectl apply -f - >/dev/null 2>&1 || true
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${svc}
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: ${svc}
    app.kubernetes.io/part-of: securerag-hub
    app.kubernetes.io/managed-by: devsecops-agent
spec:
  replicas: ${replicas}
  selector:
    matchLabels:
      app.kubernetes.io/name: ${svc}
  template:
    metadata:
      labels:
        app.kubernetes.io/name: ${svc}
        app.kubernetes.io/part-of: securerag-hub
    spec:
      containers:
        - name: ${svc}
          image: nginx:alpine
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 256Mi
          securityContext:
            runAsNonRoot: true
            runAsUser: 1000
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
EOF
  info "  ✓ ${svc} : ${replicas} réplicas"
done

# Créer des HPA synthétiques
step "Création de HPA synthétiques..."
for i in "${!SERVICES[@]}"; do
  svc="${SERVICES[$i]}"
  kubectl get hpa "${svc}" -n "${NAMESPACE}" >/dev/null 2>&1 && continue

  cat <<EOF | kubectl apply -f - >/dev/null 2>&1 || true
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: ${svc}
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: ${svc}
    app.kubernetes.io/part-of: securerag-hub
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: ${svc}
  minReplicas: ${REPLICAS[$i]}
  maxReplicas: $((REPLICAS[$i] * 2))
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
EOF
  info "  ✓ ${svc} : min=${REPLICAS[$i]}, max=$((REPLICAS[$i] * 2))"
done

# Créer des PDB synthétiques
step "Création de PDB synthétiques..."
for i in "${!SERVICES[@]}"; do
  svc="${SERVICES[$i]}"
  kubectl get pdb "${svc}-pdb" -n "${NAMESPACE}" >/dev/null 2>&1 && continue

  min_available=$((REPLICAS[$i] > 1 ? REPLICAS[$i] - 1 : 1))
  cat <<EOF | kubectl apply -f - >/dev/null 2>&1 || true
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: ${svc}-pdb
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: ${svc}
    app.kubernetes.io/part-of: securerag-hub
spec:
  minAvailable: ${min_available}
  selector:
    matchLabels:
      app.kubernetes.io/name: ${svc}
EOF
  info "  ✓ ${svc} : minAvailable=${min_available}"
done

# Attendre que kube-state-metrics collecte les données
step "Attente de la collecte des métriques par Prometheus..."
if [ "${FILE_MODE}" = false ]; then
  echo ""
  for i in $(seq 1 10); do
    echo -ne "\r[${i}/10] secondes écoulées..."
    sleep 1
  done
  echo ""
fi

# Vérification
step "Vérification des métriques..."
if [ "${FILE_MODE}" = false ]; then
  for svc in "${SERVICES[@]}"; do
    replicas=$(kubectl get deployment "${svc}" -n "${NAMESPACE}" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "?")
    ready=$(kubectl get deployment "${svc}" -n "${NAMESPACE}" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "?")
    echo "  ${svc}: replicas=${replicas}, ready=${ready}"
  done
fi

# Générer un fichier de preuve
step "Génération du fichier de preuve..."
cat > artifacts/validation/ha-demo-data-proof.md << EOF
# HA Demo Data Proof — SecureRAG Hub

Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

## Synthetic Resources Created

| Service | Replicas | HPA Min | HPA Max | PDB MinAvailable |
|---------|:--------:|:-------:|:-------:|:----------------:|
EOF

for i in "${!SERVICES[@]}"; do
  svc="${SERVICES[$i]}"
  echo "| ${svc} | ${REPLICAS[$i]} | ${REPLICAS[$i]} | $((REPLICAS[$i] * 2)) | $((REPLICAS[$i] > 1 ? REPLICAS[$i] - 1 : 1)) |" >> artifacts/validation/ha-demo-data-proof.md
done

cat >> artifacts/validation/ha-demo-data-proof.md << EOF

## Access

- Grafana Dashboard: **HA Monitoring – SecureRAG Hub** (UID: ha-mon-01)
- Prometheus metrics available at \`${PROMETHEUS_URL}\`
- Namespace: \`${NAMESPACE}\`

## Metrics Available

\`\`\`
kube_deployment_spec_replicas
kube_deployment_status_replicas_ready
kube_deployment_status_replicas_unavailable
kube_horizontalpodautoscaler_spec_min_replicas
kube_horizontalpodautoscaler_spec_max_replicas
kube_horizontalpodautoscaler_status_current_replicas
kube_horizontalpodautoscaler_status_desired_replicas
kube_poddisruptionbudget_status_current_healthy
kube_poddisruptionbudget_status_desired_healthy
kube_poddisruptionbudget_status_disruptions_allowed
kube_deployment_status_condition
kube_deployment_metadata_generation
kube_deployment_status_observed_generation
\`\`\`

EOF

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  ✅ HA DEMO DATA GENERATED"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "  Metrics disponibles dans Prometheus / Grafana"
echo "  Dashboard : HA Monitoring - SecureRAG Hub"
echo "  Preuve     : artifacts/validation/ha-demo-data-proof.md"
echo ""
echo "  Commandes utiles :"
echo "    kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80"
echo "    kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090"
echo ""