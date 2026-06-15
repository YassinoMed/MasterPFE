#!/usr/bin/env bash
# security/sigstore/deploy-sigstore-stack.sh
# Installation and configuration script for the local keyless Sigstore stack.

set -euo pipefail

NAMESPACE="sigstore-system"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

info() { printf '\e[34m[INFO]\e[0m %s\n' "$*"; }
warn() { printf '\e[33m[WARN]\e[0m %s\n' "$*" >&2; }
error() { printf '\e[31m[ERROR]\e[0m %s\n' "$*" >&2; exit 1; }

# 1. Install Helm if missing
if ! command -v helm &>/dev/null; then
  info "Helm is not installed. Installing Helm v3..."
  curl -fsSL https://get.helm.sh/helm-v3.12.0-linux-amd64.tar.gz -o /tmp/helm.tar.gz
  tar -C /tmp -zxvf /tmp/helm.tar.gz
  mv /tmp/linux-amd64/helm /usr/local/bin/helm
  rm -rf /tmp/helm.tar.gz /tmp/linux-amd64
  info "Helm installed successfully."
fi

# 2. Add Helm repositories
info "Configuring Helm repositories..."
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add sigstore https://sigstore.github.io/helm-charts
helm repo update

# 3. Create Namespace
info "Creating namespace '${NAMESPACE}'..."
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

# 4. Create Keycloak Realm ConfigMap
info "Creating Keycloak Realm Import JSON..."
REALM_FILE="/tmp/securerag-cicd-realm.json"
cat <<EOF > "${REALM_FILE}"
{
  "id": "securerag-cicd",
  "realm": "securerag-cicd",
  "enabled": true,
  "sslRequired": "none",
  "clients": [
    {
      "clientId": "jenkins-cosign",
      "secret": "jenkins-cosign-secret",
      "enabled": true,
      "publicClient": false,
      "serviceAccountsEnabled": true,
      "protocol": "openid-connect",
      "protocolMappers": [
        {
          "name": "build_signer",
          "protocol": "openid-connect",
          "protocolMapper": "oidc-hardcoded-claim-mapper",
          "consentRequired": false,
          "config": {
            "claim.name": "build_signer",
            "claim.value": "jenkins-pipeline",
            "jsonType.label": "String",
            "id.token.claim": "true",
            "access.token.claim": "true",
            "userinfo.token.claim": "true"
          }
        },
        {
          "name": "email",
          "protocol": "openid-connect",
          "protocolMapper": "oidc-hardcoded-claim-mapper",
          "consentRequired": false,
          "config": {
            "claim.name": "email",
            "claim.value": "jenkins-cosign@securerag.local",
            "jsonType.label": "String",
            "id.token.claim": "true",
            "access.token.claim": "true",
            "userinfo.token.claim": "true"
          }
        }
      ]
    }
  ]
}
EOF

kubectl create configmap keycloak-realm-import \
  --namespace "${NAMESPACE}" \
  --from-file=securerag-cicd-realm.json="${REALM_FILE}" \
  --dry-run=client -o yaml | kubectl apply -f -
rm -f "${REALM_FILE}"

# 5. Deploy Keycloak
info "Deploying Keycloak..."
helm upgrade --install keycloak bitnami/keycloak \
  --namespace "${NAMESPACE}" \
  -f "${SCRIPT_DIR}/keycloak-values.yaml" \
  --wait --timeout=300s

# 6. Deploy Rekor (Trillian dependency enabled)
info "Deploying Rekor..."
helm upgrade --install rekor sigstore/rekor \
  --namespace "${NAMESPACE}" \
  -f "${SCRIPT_DIR}/rekor-values.yaml" \
  --wait --timeout=300s

# 7. Deploy Fulcio (CTLog dependency enabled)
info "Deploying Fulcio..."
helm upgrade --install fulcio sigstore/fulcio \
  --namespace "${NAMESPACE}" \
  -f "${SCRIPT_DIR}/fulcio-values.yaml" \
  --wait --timeout=300s

# 8. Force NodePort Expositions (to bind to mapped host ports)
info "Patching Kubernetes Services to expose ports..."
kubectl patch svc keycloak -n "${NAMESPACE}" -p '{"spec": {"type": "NodePort", "ports": [{"port": 80, "targetPort": "http", "nodePort": 30080, "name": "http"}]}}' || warn "Failed to patch Keycloak NodePort"
kubectl patch svc fulcio -n "${NAMESPACE}" -p '{"spec": {"type": "NodePort", "ports": [{"port": 80, "targetPort": 80, "nodePort": 30081, "name": "http"}]}}' || warn "Failed to patch Fulcio NodePort"
kubectl patch svc rekor -n "${NAMESPACE}" -p '{"spec": {"type": "NodePort", "ports": [{"port": 80, "targetPort": 3000, "nodePort": 30082, "name": "http"}]}}' || warn "Failed to patch Rekor NodePort"

# 9. Configure Nginx Proxy Router on 'kind' docker network
info "Configuring Nginx Router Proxy container..."
NGINX_CONF="/tmp/sigstore-nginx.conf"
cat <<EOF > "${NGINX_CONF}"
events {}
http {
    server {
        listen 80;
        server_name keycloak.sigstore-system;
        location / {
            proxy_pass http://securerag-dev-control-plane:30080;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }
    server {
        listen 80;
        server_name fulcio.sigstore-system;
        location / {
            proxy_pass http://securerag-dev-control-plane:30081;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }
    server {
        listen 80;
        server_name rekor.sigstore-system;
        location / {
            proxy_pass http://securerag-dev-control-plane:30082;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }
}
EOF

docker rm -f sigstore-proxy &>/dev/null || true
docker run -d --name sigstore-proxy --network kind \
  --network-alias keycloak.sigstore-system \
  --network-alias fulcio.sigstore-system \
  --network-alias rekor.sigstore-system \
  -p 80:80 \
  -v "${NGINX_CONF}:/etc/nginx/nginx.conf:ro" \
  nginx:alpine

# 10. Update /etc/hosts on the host for domain resolution
info "Updating /etc/hosts with local OIDC/Sigstore domain mappings..."
DOMAINS=("keycloak.sigstore-system" "fulcio.sigstore-system" "rekor.sigstore-system")
for domain in "${DOMAINS[@]}"; do
  if ! grep -q "$domain" /etc/hosts; then
    echo "127.0.0.1 $domain" >> /etc/hosts
    info "Added $domain mapping to /etc/hosts"
  else
    info "$domain mapping already exists in /etc/hosts"
  fi
done

# 11. Connect Jenkins container to kind network (if not connected)
if ! docker inspect securerag-jenkins --format='{{json .NetworkSettings.Networks.kind}}' | grep -q "IPv4Address" 2>/dev/null; then
  info "Connecting Jenkins container to kind network..."
  docker network connect kind securerag-jenkins || true
fi

info "Sigstore stack deployment complete!"
kubectl get pods -n "${NAMESPACE}"
docker ps | grep sigstore-proxy
