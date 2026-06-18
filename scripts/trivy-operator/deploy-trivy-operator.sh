#!/usr/bin/env bash
# File: scripts/trivy-operator/deploy-trivy-operator.sh
# Description: Déploie Trivy Operator via Kustomize et valide les rapports de scan.
# Date: 2026-06-18
set -euo pipefail

NAMESPACE="trivy-system"
TRIVY_OPERATOR_DIR="infra/k8s/trivy-operator"

echo "[INFO] Déploiement de Trivy Operator dans le namespace ${NAMESPACE}..."

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo "[INFO] Application des manifests via Kustomize..."
kubectl apply -k "${TRIVY_OPERATOR_DIR}"

echo "[INFO] Attente du déploiement de Trivy Operator..."
kubectl wait --for=condition=Available deployment/trivy-operator \
  -n "${NAMESPACE}" --timeout=180s

echo "[INFO] Vérification du pod Trivy Operator..."
kubectl get pods -n "${NAMESPACE}" -l app.kubernetes.io/name=trivy-operator

echo "[INFO] Création du ClusterComplianceReport de test..."
cat <<EOF | kubectl apply -f -
apiVersion: aquasecurity.github.io/v1alpha1
kind: ClusterComplianceReport
metadata:
  name: securerag-compliance
  namespace: ${NAMESPACE}
spec:
  reportType: summary
  compliance:
    - name: nsa-cisa
      description: NSA CISA Kubernetes Hardening
      controls:
        - id: "1.0"
          name: Non-root containers
          description: Containers must not run as root
          commands:
            - /kubectl_get_pods
        - id: "1.1"
          name: Immutable container filesystems
          description: Container filesystem must be read-only
          commands:
            - /kubectl_get_pods
EOF

echo "[INFO] Attente de la génération des VulnerabilityReports..."
sleep 10

REPORT_COUNT=$(kubectl get vulnerabilityreports -A --no-headers 2>/dev/null | wc -l)
echo "[INFO] VulnerabilityReports trouvés: ${REPORT_COUNT}"

if [[ "${REPORT_COUNT}" -gt 0 ]]; then
  echo "[OK] Trivy Operator déployé et rapports de vulnérabilités générés."
else
  echo "[WARN] Aucun VulnerabilityReport trouvé. Les scans peuvent prendre plus de temps."
fi

echo "[INFO] Statut des rapports de conformité:"
kubectl get clustercompliancereports -n "${NAMESPACE}" -o wide 2>/dev/null || echo "Aucun rapport de conformité."

echo "✓ Déploiement de Trivy Operator terminé."
