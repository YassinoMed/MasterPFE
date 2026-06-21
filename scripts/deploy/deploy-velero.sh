#!/usr/bin/env bash
# deploy-velero.sh — Deploy Velero + MinIO for Backup & DR
# SecureRAG Hub — Enterprise Disaster Recovery
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { printf "${GREEN}[INFO]${NC}  %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  VELERO + MINIO — BACKUP & DR DEPLOYMENT"
echo "═══════════════════════════════════════════════════════════════"

# Phase 1: Deploy MinIO
info "Phase 1/5: Deploying MinIO..."
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: minio
  labels:
    app.kubernetes.io/part-of: securerag-hub
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minio
  namespace: minio
  labels:
    app.kubernetes.io/name: minio
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: minio
  template:
    metadata:
      labels:
        app.kubernetes.io/name: minio
    spec:
      containers:
        - name: minio
          image: quay.io/minio/minio:RELEASE.2025-04-08T15-58-05Z
          args:
            - server
            - /data
            - --console-address
            - ":9001"
          env:
            - name: MINIO_ROOT_USER
              value: "minioadmin"
            - name: MINIO_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: minio-credentials
                  key: password
          ports:
            - containerPort: 9000
              name: s3
            - containerPort: 9001
              name: console
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 512Mi
          volumeMounts:
            - name: data
              mountPath: /data
      volumes:
        - name: data
          emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: minio
  namespace: minio
  labels:
    app.kubernetes.io/name: minio
spec:
  ports:
    - port: 9000
      targetPort: 9000
      name: s3
    - port: 9001
      targetPort: 9001
      name: console
  selector:
    app.kubernetes.io/name: minio
---
apiVersion: v1
kind: Secret
metadata:
  name: minio-credentials
  namespace: minio
type: Opaque
stringData:
  password: "$(python3 -c 'import secrets; print(secrets.token_urlsafe(32))')"
  username: "minioadmin"
EOF

kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=minio -n minio --timeout=120s || {
  error "MinIO not ready"
  exit 1
}
info "MinIO deployed"

# Phase 2: Install Velero
info "Phase 2/5: Installing Velero..."
MINIO_PASS=$(kubectl get secret minio-credentials -n minio -o jsonpath='{.data.password}' | base64 -d)

cat > /tmp/velero-credentials << CREDENTIALS
[default]
aws_access_key_id=minioadmin
aws_secret_access_key=${MINIO_PASS}
CREDENTIALS

kubectl create ns velero 2>/dev/null || true

helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts 2>/dev/null || true
helm upgrade --install velero vmware-tanzu/velero \
  --namespace velero \
  --create-namespace \
  --set configuration.provider=aws \
  --set configuration.backupStorageLocation.name=velero-minio \
  --set configuration.backupStorageLocation.bucket=securerag-velero \
  --set configuration.backupStorageLocation.config.region=minio \
  --set configuration.backupStorageLocation.config.s3ForcePathStyle=true \
  --set configuration.backupStorageLocation.config.s3Url=http://minio.minio.svc.cluster.local:9000 \
  --set configuration.volumeSnapshotLocation.name=velero-minio \
  --set configuration.volumeSnapshotLocation.config.region=minio \
  --set credentials.useSecret=true \
  --set-file credentials.secretContents.cloud=/tmp/velero-credentials \
  --set initContainers[0].name=velero-plugin-for-aws \
  --set initContainers[0].image=velero/velero-plugin-for-aws:v1.9.0 \
  --set initContainers[0].volumeMounts[0].name=plugins \
  --set initContainers[0].volumeMounts[0].mountPath=/target \
  --wait --timeout=5m

rm -f /tmp/velero-credentials

kubectl wait --for=condition=Ready pod -l component=velero -n velero --timeout=120s || {
  error "Velero not ready"
  exit 1
}
info "Velero installed"

# Phase 3: Apply backup schedules
info "Phase 3/5: Applying backup schedules..."
kubectl apply -f infra/k8s/velero/velero.yaml
info "Backup schedules applied"

# Phase 4: Create initial backup
info "Phase 4/5: Creating initial backup..."
velero backup create initial-securerag-backup \
  --include-namespaces securerag-hub,vault,observability \
  --wait || warn "Initial backup may still be running"

# Phase 5: Verify
info "Phase 5/5: Verifying backup infrastructure..."
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  ✅ VELERO + MINIO DEPLOYMENT COMPLETE"
echo "═══════════════════════════════════════════════════════════════"
echo ""
velero backup get 2>/dev/null | head -10 || warn "No backups yet"
velero schedule get 2>/dev/null || warn "No schedules found"
echo ""
echo "  MinIO console: kubectl port-forward -n minio svc/minio 9001:9001"
echo "  Velero logs:   kubectl logs -n velero deployment/velero"
echo "  Backup test:   bash scripts/dr/backup-test.sh"
