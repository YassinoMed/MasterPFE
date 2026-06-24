#!/bin/bash
set -eo pipefail

CLUSTER_NAME=$1

if [ -z "$CLUSTER_NAME" ]; then
    echo "Usage: $0 <cluster-name>"
    exit 1
fi

echo "Provisioning ephemeral k3d cluster: $CLUSTER_NAME"

# Create a lightweight k3d cluster
k3d cluster create "$CLUSTER_NAME" \
    --agents 2 \
    --k3s-arg "--disable=traefik@server:0" \
    --wait

# Export kubeconfig for the rest of the pipeline
k3d kubeconfig get "$CLUSTER_NAME" > "$KUBECONFIG"
export KUBECONFIG="$KUBECONFIG"

echo "Cluster provisioned successfully. Nodes:"
kubectl get nodes
