#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

PUBLIC_HOST="${PUBLIC_HOST:-141.95.135.130}"
REGISTRY_HOST="${REGISTRY_HOST:-localhost:5001}"
IMAGE_TAG="${IMAGE_TAG:-demo}"
IMAGE_PREFIX="${IMAGE_PREFIX:-securerag-hub}"
KUSTOMIZE_OVERLAY="${KUSTOMIZE_OVERLAY:-infra/k8s/overlays/demo}"

echo "[INFO] Repair Docker forwarding"
sudo /sbin/sysctl -w net.ipv4.ip_forward=1
printf 'net.ipv4.ip_forward=1\n' | sudo tee /etc/sysctl.d/99-securerag-docker.conf >/dev/null
sudo /sbin/iptables -P FORWARD ACCEPT || true

echo "[INFO] Ensure cluster and secrets"
bash scripts/deploy/create-kind.sh
bash scripts/secrets/bootstrap-local-secrets.sh
bash scripts/secrets/create-dev-secrets.sh

echo "[INFO] Build images with host network"
for component in \
  services/api-gateway \
  services/auth-users \
  services/chatbot-manager \
  services/llm-orchestrator \
  services/security-auditor \
  services/knowledge-hub \
  platform/portal-web
do
  name="$(basename "$component")"
  image="${REGISTRY_HOST}/${IMAGE_PREFIX}-${name}:${IMAGE_TAG}"
  echo "[INFO] Building ${image}"
  docker build --network host -t "${image}" -f "${component}/Dockerfile" "${component}"
  docker push "${image}"
done

echo "[INFO] Deploy demo"
REGISTRY_HOST="${REGISTRY_HOST}" IMAGE_PREFIX="${IMAGE_PREFIX}" IMAGE_TAG="${IMAGE_TAG}" \
KUSTOMIZE_OVERLAY="${KUSTOMIZE_OVERLAY}" \
bash scripts/deploy/deploy-kind.sh

echo "[INFO] Restart pods"
kubectl delete pod -n securerag-hub --all || true
kubectl wait --for=condition=Ready pod --all -n securerag-hub --timeout=300s

echo "[INFO] Validate"
IMAGE_TAG="${IMAGE_TAG}" bash scripts/validate/smoke-tests.sh

echo "[INFO] Start Jenkins"
bash scripts/jenkins/bootstrap-local-credentials.sh
bash scripts/jenkins/bootstrap-local-kubeconfig.sh
docker compose -f infra/jenkins/docker-compose.yml up -d

echo "[INFO] Final campaign dry-run"
OFFICIAL_SCENARIO=demo CAMPAIGN_MODE=dry-run make final-campaign

echo "[INFO] URLs"
echo "API Gateway: http://${PUBLIC_HOST}:8080/healthz"
echo "Portal Web:  http://${PUBLIC_HOST}:8081/health"
echo "Jenkins:     http://${PUBLIC_HOST}:8085"
