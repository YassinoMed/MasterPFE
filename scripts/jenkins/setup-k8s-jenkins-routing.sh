#!/usr/bin/env bash
# File: scripts/jenkins/setup-k8s-jenkins-routing.sh
# Description: Dynamically creates Kubernetes Services and Endpoints mapping to the Jenkins container IP on the kind Docker network.

set -euo pipefail

NAMESPACE="securerag-hub"
CONTAINER_NAME="securerag-jenkins"

log() {
  printf '[INFO] %s\n' "$*"
}

# 1. Get IP of Jenkins container on the kind network
JENKINS_IP=$(docker inspect -f '{{.NetworkSettings.Networks.kind.IPAddress}}' "${CONTAINER_NAME}" 2>/dev/null || true)

if [ -z "${JENKINS_IP}" ]; then
  # Fallback: check without network name
  JENKINS_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${CONTAINER_NAME}")
fi

if [ -z "${JENKINS_IP}" ]; then
  echo "[ERROR] Could not find IP for container ${CONTAINER_NAME}"
  exit 1
fi

log "Jenkins container IP on the kind network is ${JENKINS_IP}"

# 2. Create Service and Endpoints for Jenkins Web UI (port 8080)
log "Creating Service and Endpoints for jenkins (port 8080) in namespace ${NAMESPACE}..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: jenkins
  namespace: ${NAMESPACE}
spec:
  ports:
  - name: http
    port: 8080
    targetPort: 8080
---
apiVersion: v1
kind: Endpoints
metadata:
  name: jenkins
  namespace: ${NAMESPACE}
subsets:
- addresses:
  - ip: ${JENKINS_IP}
  ports:
  - name: http
    port: 8080
EOF

# 3. Create Service and Endpoints for Jenkins Agent JNPL (port 50000)
log "Creating Service and Endpoints for jenkins-agent (port 50000) in namespace ${NAMESPACE}..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: jenkins-agent
  namespace: ${NAMESPACE}
spec:
  ports:
  - name: jnlp
    port: 50000
    targetPort: 50000
---
apiVersion: v1
kind: Endpoints
metadata:
  name: jenkins-agent
  namespace: ${NAMESPACE}
subsets:
- addresses:
  - ip: ${JENKINS_IP}
  ports:
  - name: jnlp
    port: 50000
EOF

log "Kubernetes routing configuration completed successfully."
