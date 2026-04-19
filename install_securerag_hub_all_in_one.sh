#!/usr/bin/env bash
set -Eeuo pipefail

########################################
# SecureRAG Hub - all-in-one installer #
########################################

# Usage:
#   chmod +x install_securerag_hub_all_in_one.sh
#   sudo -u <your_user> ./install_securerag_hub_all_in_one.sh
#
# Example:
#   REPO_URL="https://github.com/your-org/securerag-hub.git" \
#   REPO_BRANCH="main" \
#   VPS_USER="$USER" \
#   ./install_securerag_hub_all_in_one.sh
#
# Optional flags:
#   INSTALL_NGINX=true DOMAIN="secure-rag.example.com"
#   INSTALL_JENKINS=true
#   INSTALL_SUPPLY_CHAIN=true
#   INSTALL_KYVERNO=true
#   INSTALL_HPA_RUNTIME_PROOF=true
#   GENERATE_FINAL_ARTIFACTS=true

########################################
# Configurable variables               #
########################################

REPO_URL="${REPO_URL:-<URL_DU_REPO>}"
REPO_DIR="${REPO_DIR:-$HOME/securerag-hub}"
REPO_BRANCH="${REPO_BRANCH:-main}"
VPS_USER="${VPS_USER:-$USER}"

REGISTRY_HOST="${REGISTRY_HOST:-localhost:5001}"
IMAGE_PREFIX="${IMAGE_PREFIX:-securerag-hub}"
IMAGE_TAG="${IMAGE_TAG:-production}"
KUSTOMIZE_OVERLAY="${KUSTOMIZE_OVERLAY:-infra/k8s/overlays/production}"
DIGEST_RECORD_FILE="${DIGEST_RECORD_FILE:-artifacts/release/promotion-digests.txt}"
SOURCE_IMAGE_TAG="${SOURCE_IMAGE_TAG:-production}"
TARGET_IMAGE_TAG="${TARGET_IMAGE_TAG:-release-local}"
REPORT_DIR="${REPORT_DIR:-artifacts/release}"
SBOM_DIR="${SBOM_DIR:-artifacts/sbom}"

# Optional features
INSTALL_NGINX="${INSTALL_NGINX:-false}"
DOMAIN="${DOMAIN:-secure-rag.example.com}"
INSTALL_CERTBOT_TLS="${INSTALL_CERTBOT_TLS:-false}"
INSTALL_HPA_RUNTIME_PROOF="${INSTALL_HPA_RUNTIME_PROOF:-false}"
INSTALL_KYVERNO="${INSTALL_KYVERNO:-false}"
INSTALL_JENKINS="${INSTALL_JENKINS:-false}"
INSTALL_SUPPLY_CHAIN="${INSTALL_SUPPLY_CHAIN:-false}"
DEPLOY_BY_DIGEST="${DEPLOY_BY_DIGEST:-false}"
GENERATE_FINAL_ARTIFACTS="${GENERATE_FINAL_ARTIFACTS:-false}"
DESTROY_EXISTING_KIND_CLUSTER="${DESTROY_EXISTING_KIND_CLUSTER:-false}"

########################################
# Helpers                              #
########################################

log() {
  printf '\n[%s] %s\n' "$(date '+%F %T')" "$*"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Commande requise introuvable: $1" >&2
    exit 1
  }
}

bool_true() {
  case "${1,,}" in
    true|1|yes|y) return 0 ;;
    *) return 1 ;;
  esac
}

get_arch() {
  local arch
  arch="$(dpkg --print-architecture)"
  case "$arch" in
    amd64) echo "amd64" ;;
    arm64) echo "arm64" ;;
    *)
      echo "Architecture non supportée: $arch" >&2
      exit 1
      ;;
  esac
}

ensure_not_placeholder() {
  if [[ "$REPO_URL" == "<URL_DU_REPO>" ]]; then
    echo "Vous devez définir REPO_URL avant d'exécuter le script." >&2
    echo 'Exemple: REPO_URL="https://github.com/your-org/securerag-hub.git" ./install_securerag_hub_all_in_one.sh' >&2
    exit 1
  fi
}

########################################
# Pre-flight                           #
########################################

ensure_not_placeholder

if [[ "$EUID" -eq 0 ]]; then
  echo "Évitez d'exécuter ce script en root direct. Lancez-le avec un utilisateur sudo." >&2
  exit 1
fi

require_cmd sudo
require_cmd curl
require_cmd bash

export DEBIAN_FRONTEND=noninteractive
KARCH="$(get_arch)"

log "Début de l'installation SecureRAG Hub sur Debian"

########################################
# 1) Prepare Debian                    #
########################################

log "Mise à jour système et installation des paquets de base"
sudo apt update
sudo apt -y upgrade
sudo apt install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  git \
  make \
  jq \
  unzip \
  openssl \
  python3 \
  python3-pip \
  bash \
  coreutils \
  apt-transport-https \
  wget

########################################
# 2) Install Docker Engine             #
########################################

log "Installation de Docker Engine"
sudo install -m 0755 -d /etc/apt/keyrings

if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
  curl -fsSL https://download.docker.com/linux/debian/gpg \
    | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
fi

sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

sudo apt update
sudo apt install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

if ! id -nG "$VPS_USER" | grep -qw docker; then
  sudo usermod -aG docker "$VPS_USER"
  log "Utilisateur ajouté au groupe docker: $VPS_USER"
  log "Le script utilisera 'sg docker -c' pour éviter une reconnexion immédiate."
fi

sg docker -c 'docker version'
sg docker -c 'docker compose version'
sg docker -c 'docker run --rm hello-world'

########################################
# 3) Install kubectl                   #
########################################

log "Installation de kubectl"
KUBECTL_VERSION="$(curl -L -s https://dl.k8s.io/release/stable.txt)"
curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${KARCH}/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/kubectl
kubectl version --client

########################################
# 4) Install kind                      #
########################################

log "Installation de kind"
KIND_VERSION="$(curl -fsSL https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | jq -r .tag_name)"
curl -Lo kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-${KARCH}"
chmod +x kind
sudo mv kind /usr/local/bin/kind
kind version

########################################
# 5) Clone repo                        #
########################################

log "Clonage ou mise à jour du dépôt"
mkdir -p "$(dirname "$REPO_DIR")"
if [[ -d "$REPO_DIR/.git" ]]; then
  git -C "$REPO_DIR" fetch --all --tags
  git -C "$REPO_DIR" checkout "$REPO_BRANCH"
  git -C "$REPO_DIR" pull --ff-only origin "$REPO_BRANCH"
else
  git clone "$REPO_URL" "$REPO_DIR"
  git -C "$REPO_DIR" checkout "$REPO_BRANCH"
fi

cd "$REPO_DIR"
find scripts -type f -name "*.sh" -exec chmod +x {} \;
ls
make help || true

########################################
# 6) Create kind cluster               #
########################################

log "Création du cluster kind production-like"
if bool_true "$DESTROY_EXISTING_KIND_CLUSTER"; then
  CONFIRM_DESTROY=YES bash scripts/deploy/recreate-production-kind.sh
else
  bash scripts/deploy/recreate-production-kind.sh
fi

kubectl config current-context
kubectl get nodes -o wide
sg docker -c 'docker ps'

########################################
# 7) Generate secrets                  #
########################################

log "Génération et application des secrets locaux"
bash scripts/secrets/bootstrap-local-secrets.sh
ls -l security/secrets/.env.local
bash scripts/secrets/create-dev-secrets.sh
kubectl get ns securerag-hub
kubectl get secret -n securerag-hub

########################################
# 8) Build Docker images               #
########################################

log "Build des images Docker locales"
REGISTRY_HOST="$REGISTRY_HOST" \
IMAGE_TAG="$IMAGE_TAG" \
bash scripts/deploy/build-local-images.sh

sg docker -c 'docker images | grep securerag-hub || true'
curl -fsS "http://${REGISTRY_HOST}/v2/_catalog" || curl -fsS http://localhost:5001/v2/_catalog

########################################
# 9) Deploy production overlay         #
########################################

log "Déploiement Kubernetes de l'overlay production"
REGISTRY_HOST="$REGISTRY_HOST" \
IMAGE_PREFIX="$IMAGE_PREFIX" \
IMAGE_TAG="$IMAGE_TAG" \
KUSTOMIZE_OVERLAY="$KUSTOMIZE_OVERLAY" \
bash scripts/deploy/deploy-kind.sh

kubectl get deploy -n securerag-hub
kubectl get pods -n securerag-hub -o wide
kubectl get svc -n securerag-hub
kubectl get pdb -n securerag-hub || true
kubectl get hpa -n securerag-hub || true

########################################
# 10) Local access reminder            #
########################################

log "Accès portail attendu: http://127.0.0.1:8081 ou via tunnel SSH depuis votre poste"
echo "Tunnel SSH conseillé depuis votre machine locale :"
echo "ssh -L 8081:127.0.0.1:8081 ${VPS_USER}@<IP_DU_VPS>"
curl -fsS http://127.0.0.1:8081/health || true

########################################
# 11) Optional Nginx                   #
########################################

if bool_true "$INSTALL_NGINX"; then
  log "Installation et configuration Nginx"
  sudo apt install -y nginx certbot python3-certbot-nginx

  sudo tee /etc/nginx/sites-available/securerag-hub >/dev/null <<EOF_NGINX
server {
    listen 80;
    server_name ${DOMAIN};

    location / {
        proxy_pass http://127.0.0.1:8081;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF_NGINX

  sudo ln -sf /etc/nginx/sites-available/securerag-hub /etc/nginx/sites-enabled/securerag-hub
  sudo nginx -t
  sudo systemctl reload nginx

  if bool_true "$INSTALL_CERTBOT_TLS"; then
    log "Activation TLS Let's Encrypt"
    sudo certbot --nginx -d "$DOMAIN"
    curl -I "https://${DOMAIN}/health" || true
  else
    curl -I "http://${DOMAIN}/health" || true
  fi
fi

########################################
# 12) Optional metrics-server + HPA    #
########################################

if bool_true "$INSTALL_HPA_RUNTIME_PROOF"; then
  log "Installation / mise à jour metrics-server et preuve HPA"
  make refresh-hpa-runtime-proof
  kubectl get apiservice v1beta1.metrics.k8s.io || true
  kubectl top nodes || true
  kubectl top pods -n securerag-hub || true
  kubectl get hpa -n securerag-hub || true
  cat artifacts/validation/hpa-runtime-report.md || true
  cat artifacts/validation/production-runtime-evidence.md || true
fi

########################################
# 13) Optional Kyverno audit           #
########################################

if bool_true "$INSTALL_KYVERNO"; then
  log "Installation de Kyverno en mode Audit"
  make kyverno-install
  kubectl get ns kyverno || true
  kubectl get pods -n kyverno || true
  kubectl get crd | grep kyverno || true
  kubectl get clusterpolicy || true
  kubectl get policyreport,clusterpolicyreport -A || true
  make cluster-security-proof
  cat artifacts/validation/cluster-security-addons.md || true
fi

########################################
# 14) Optional runtime proofs          #
########################################

if bool_true "$GENERATE_FINAL_ARTIFACTS"; then
  log "Génération des preuves runtime / observability"
  make production-cluster-clean-proof
  make production-runtime-evidence
  make observability-snapshot
  ls -lh artifacts/validation/ || true
  ls -lh artifacts/observability/ || true
  cat artifacts/validation/production-cluster-clean.md || true
  cat artifacts/validation/production-runtime-evidence.md || true
  cat artifacts/observability/observability-snapshot.md || true
fi

########################################
# 15) Optional Jenkins                 #
########################################

if bool_true "$INSTALL_JENKINS"; then
  log "Bootstrap Jenkins local"
  bash scripts/jenkins/bootstrap-local-credentials.sh
  bash scripts/jenkins/bootstrap-local-kubeconfig.sh
  sg docker -c 'docker compose -f infra/jenkins/docker-compose.yml up --build -d'
  bash scripts/jenkins/wait-for-jenkins.sh
  echo "Tunnel SSH Jenkins depuis votre machine locale :"
  echo "ssh -L 8085:127.0.0.1:8085 ${VPS_USER}@<IP_DU_VPS>"
  echo "URL Jenkins : http://localhost:8085"
  cat infra/jenkins/secrets/jenkins-admin-password || true
fi

########################################
# 16) Optional supply chain            #
########################################

if bool_true "$INSTALL_SUPPLY_CHAIN"; then
  log "Installation de Trivy"
  sudo install -m 0755 -d /usr/share/keyrings
  wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key \
    | sudo gpg --dearmor -o /usr/share/keyrings/trivy.gpg
  echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" \
    | sudo tee /etc/apt/sources.list.d/trivy.list
  sudo apt update
  sudo apt install -y trivy
  trivy --version

  log "Installation de Syft"
  curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh \
    | sudo sh -s -- -b /usr/local/bin
  syft version

  log "Installation de Cosign"
  COSIGN_VERSION="$(curl -fsSL https://api.github.com/repos/sigstore/cosign/releases/latest | jq -r .tag_name)"
  curl -Lo cosign "https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/cosign-linux-${KARCH}"
  chmod +x cosign
  sudo mv cosign /usr/local/bin/cosign
  cosign version

  log "Exécution de la supply chain"
  REGISTRY_HOST="$REGISTRY_HOST" \
  IMAGE_PREFIX="$IMAGE_PREFIX" \
  SOURCE_IMAGE_TAG="$SOURCE_IMAGE_TAG" \
  TARGET_IMAGE_TAG="$TARGET_IMAGE_TAG" \
  REPORT_DIR="$REPORT_DIR" \
  SBOM_DIR="$SBOM_DIR" \
  DIGEST_RECORD_FILE="$DIGEST_RECORD_FILE" \
  make supply-chain-execute

  make supply-chain-evidence
  make release-attestation
  make release-evidence

  ls -lh artifacts/release/ || true
  ls -lh artifacts/sbom/ || true
  cat artifacts/release/supply-chain-evidence.md || true
  cat artifacts/release/release-attestation.md || true
  cat "$DIGEST_RECORD_FILE" || true
fi

########################################
# 17) Optional digest deployment       #
########################################

if bool_true "$DEPLOY_BY_DIGEST"; then
  log "Déploiement par digest sans rebuild"
  REGISTRY_HOST="$REGISTRY_HOST" \
  IMAGE_PREFIX="$IMAGE_PREFIX" \
  IMAGE_TAG="$TARGET_IMAGE_TAG" \
  KUSTOMIZE_OVERLAY="$KUSTOMIZE_OVERLAY" \
  DIGEST_RECORD_FILE="$DIGEST_RECORD_FILE" \
  bash scripts/deploy/deploy-kind.sh

  kubectl rollout status deployment/portal-web -n securerag-hub --timeout=180s
  kubectl get deploy,pods,svc,hpa,pdb -n securerag-hub -o wide || true
fi

########################################
# 18) Optional support pack            #
########################################

if bool_true "$GENERATE_FINAL_ARTIFACTS"; then
  log "Génération du support pack final"
  make final-summary
  make support-pack
  ls -lh artifacts/final/ || true
  ls -lh artifacts/support-pack/ || true
fi

########################################
# 19) Diagnostics                      #
########################################

log "Diagnostics utiles"
kubectl cluster-info || true
kubectl get nodes -o wide || true
kubectl get all -n securerag-hub || true
kubectl get svc portal-web -n securerag-hub -o wide || true
kubectl get endpoints portal-web -n securerag-hub || true
curl -v http://127.0.0.1:8081/health || true
kubectl get pods -n securerag-hub -o wide || true
kubectl logs -n securerag-hub deploy/portal-web --tail=100 || true
kubectl get apiservice v1beta1.metrics.k8s.io -o wide || true
kubectl get pods -n kube-system -l k8s-app=metrics-server || true
kubectl top nodes || true
kubectl top pods -n securerag-hub || true
kubectl get hpa -n securerag-hub || true
kubectl get pods -n kyverno || true
kubectl get clusterpolicy || true
kubectl get policyreport,clusterpolicyreport -A || true

log "Terminé"
echo
echo "Accès portail via tunnel SSH :"
echo "  ssh -L 8081:127.0.0.1:8081 ${VPS_USER}@<IP_DU_VPS>"
echo "Puis ouvrez : http://localhost:8081"
echo
echo "Exemple minimal :"
echo "  REPO_URL=\"https://github.com/your-org/securerag-hub.git\" ./$(basename "$0")"
