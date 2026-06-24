#!/bin/bash
set -eo pipefail

echo "Starting infrastructure and state restore..."

# 1. Install Velero CLI if not present
if ! command -v velero &> /dev/null; then
    echo "Velero CLI not found. Downloading..."
    curl -L -o velero.tar.gz https://github.com/vmware-tanzu/velero/releases/download/v1.13.0/velero-v1.13.0-linux-amd64.tar.gz
    tar -zxvf velero.tar.gz
    sudo mv velero-v1.13.0-linux-amd64/velero /usr/local/bin/velero
    rm -rf velero*
fi

# 2. Install Velero into the cluster
echo "Installing Velero into cluster..."
velero install \
    --provider aws \
    --plugins velero/velero-plugin-for-aws:v1.9.0 \
    --bucket soc2-dr-backups \
    --secret-file ./credentials-velero \
    --backup-location-config region=eu-west-3 \
    --wait || echo "Velero might already be installed or credentials missing, proceeding..."

# 3. Trigger Restore from latest backup
echo "Finding latest backup..."
LATEST_BACKUP=$(velero backup get -o json | jq -r '.items[0].metadata.name' || echo "securerag-backup-latest")

echo "Triggering restore for backup: $LATEST_BACKUP"
velero restore create --from-backup "$LATEST_BACKUP" --wait || echo "Velero restore failed or no backups found. Attempting ArgoCD bootstrap."

# 4. Bootstrap ArgoCD (GitOps fallback/reconciliation)
echo "Bootstrapping ArgoCD..."
kubectl create namespace argocd || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Applying root application..."
kubectl apply -f infra/k8s/argocd/root-app.yaml || echo "ArgoCD root app manifest not found. Skipping."

echo "Restore phase completed."
