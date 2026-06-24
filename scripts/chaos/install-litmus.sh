#!/bin/bash
set -eo pipefail

echo "[INFO] Installing Litmus Chaos Operator and ChaosCenter..."

kubectl create namespace litmus || true

# Add Litmus Helm repo
helm repo add litmuschaos https://litmuschaos.github.io/litmus-helm/
helm repo update

# Install Litmus ChaosCenter
helm upgrade --install chaos litmuschaos/litmus \
  --namespace litmus \
  --set portal.frontend.service.type=ClusterIP \
  --wait

# Create a cluster-wide service account for Litmus ChaosRunner
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: litmus-cluster-scope
  namespace: securerag-hub
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: litmus-cluster-scope
rules:
  - apiGroups: ["", "apps", "batch", "litmuschaos.io", "networking.k8s.io"]
    resources: ["*"]
    verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: litmus-cluster-scope
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: litmus-cluster-scope
subjects:
  - kind: ServiceAccount
    name: litmus-cluster-scope
    namespace: securerag-hub
EOF

echo "[INFO] Litmus Chaos installed successfully."
