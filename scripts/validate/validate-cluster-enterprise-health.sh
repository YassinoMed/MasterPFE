#!/usr/bin/env bash
# Enterprise Kubernetes Cluster Health & Security Audit Validation Script
set -euo pipefail

REPORT_FILE="${REPORT_FILE:-artifacts/validation/enterprise-cluster-health.md}"
mkdir -p "$(dirname "${REPORT_FILE}")"

echo "[INFO] Running Enterprise Kubernetes Cluster Health Checks..."

{
  echo "# Enterprise Kubernetes Cluster Health Audit Report"
  echo ""
  echo "- Timestamp UTC: \`$(date -u '+%Y-%m-%dT%H:%M:%SZ')\`"
  echo "- Audit Type: \`Full Enterprise Stack Sanity & Security Check\`"
  echo ""

  echo "## 1. Node Status & Metrics"
  echo "\`\`\`"
  kubectl get nodes -o wide || echo "[WARN] Unable to fetch nodes"
  kubectl top nodes || echo "[WARN] Metrics server not reachable or top nodes unavailable"
  echo "\`\`\`"
  echo ""

  echo "## 2. All Namespace Pod Status"
  echo "\`\`\`"
  kubectl get pods -A -o wide || echo "[WARN] Unable to fetch pods"
  echo "\`\`\`"
  echo ""

  echo "## 3. Ingress, Services & Storage"
  echo "\`\`\`"
  kubectl get ingress -A || echo "[WARN] No ingress resources found"
  kubectl get svc -A || echo "[WARN] Unable to fetch services"
  kubectl get pvc -A || echo "[WARN] No PVC resources found"
  echo "\`\`\`"
  echo ""

  echo "## 4. Security & Network Policies"
  echo "\`\`\`"
  kubectl get networkpolicy -A || echo "[WARN] No NetworkPolicies found"
  kubectl get clusterrole | head -n 20 || echo "[WARN] Unable to fetch ClusterRoles"
  echo "\`\`\`"
  echo ""

  echo "## 5. Cert-Manager Issuers & Certificates"
  echo "\`\`\`"
  kubectl get clusterissuer -A || echo "[WARN] Cert-Manager ClusterIssuers not found"
  kubectl get certificaterequests -A || echo "[WARN] No CertificateRequests found"
  echo "\`\`\`"
  echo ""

  echo "## 6. GitOps Applications (ArgoCD)"
  echo "\`\`\`"
  kubectl get applications -n argocd || echo "[WARN] ArgoCD applications not found or namespace missing"
  echo "\`\`\`"
  echo ""

  echo "## 7. Security Engine Pods (Falco & Kyverno)"
  echo "\`\`\`"
  echo "--- Falco Pods ---"
  kubectl get pods -n falco || echo "[WARN] Falco namespace or pods not found"
  echo "--- Kyverno Pods ---"
  kubectl get pods -n kyverno || echo "[WARN] Kyverno namespace or pods not found"
  echo "\`\`\`"

} > "${REPORT_FILE}"

echo "[INFO] Health audit complete -> ${REPORT_FILE}"
