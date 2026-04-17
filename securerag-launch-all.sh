#!/usr/bin/env bash
set -Eeuo pipefail

# SecureRAG Hub full launcher
# Defaults to the stable demo path; production is supported with MODE=production.
#
# Examples:
#   bash securerag-launch-all.sh
#   MODE=production RUN_METRICS=true RUN_KYVERNO_AUDIT=true bash securerag-launch-all.sh
#   MODE=dev RUN_JENKINS=true bash securerag-launch-all.sh
#
# Environment variables:
#   MODE=demo|dev|production            Default: demo
#   ROOT_DIR=/path/to/MasterPFE         Default: current directory
#   REGISTRY_HOST=localhost:5001        Default: localhost:5001
#   IMAGE_PREFIX=securerag-hub          Default: securerag-hub
#   IMAGE_TAG=<tag>                     Default: MODE
#   RUN_JENKINS=true|false              Default: false
#   RUN_METRICS=true|false              Default: false
#   RUN_KYVERNO_AUDIT=true|false        Default: false
#   RUN_SMOKE_TESTS=true|false          Default: true
#   RUN_SUPPORT_PACK=true|false         Default: false

MODE="${MODE:-demo}"
ROOT_DIR="${ROOT_DIR:-$PWD}"
REGISTRY_HOST="${REGISTRY_HOST:-localhost:5001}"
IMAGE_PREFIX="${IMAGE_PREFIX:-securerag-hub}"
IMAGE_TAG="${IMAGE_TAG:-$MODE}"
RUN_JENKINS="${RUN_JENKINS:-false}"
RUN_METRICS="${RUN_METRICS:-false}"
RUN_KYVERNO_AUDIT="${RUN_KYVERNO_AUDIT:-false}"
RUN_SMOKE_TESTS="${RUN_SMOKE_TESTS:-true}"
RUN_SUPPORT_PACK="${RUN_SUPPORT_PACK:-false}"

OVERLAY="infra/k8s/overlays/${MODE}"

log()  { printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }
warn() { printf '\n[WARN] %s\n' "$*" >&2; }
die()  { printf '\n[ERROR] %s\n' "$*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Commande requise introuvable: $1"
}

run_if_exists() {
  local rel="$1"; shift || true
  if [[ -f "${ROOT_DIR}/${rel}" ]]; then
    log "Exécution: ${rel} $*"
    bash "${ROOT_DIR}/${rel}" "$@"
  else
    warn "Script absent, ignoré: ${rel}"
  fi
}

ensure_file() {
  [[ -f "${ROOT_DIR}/$1" ]] || die "Fichier requis introuvable: $1"
}

log "Dossier projet: ${ROOT_DIR}"
cd "${ROOT_DIR}" || die "Impossible d'entrer dans ${ROOT_DIR}"

[[ "$MODE" =~ ^(demo|dev|production)$ ]] || die "MODE invalide: ${MODE}. Utiliser demo, dev ou production."

ensure_file "scripts/deploy/create-kind.sh"
ensure_file "scripts/deploy/build-local-images.sh"
ensure_file "scripts/deploy/deploy-kind.sh"
ensure_file "${OVERLAY}/kustomization.yaml"

require_cmd docker
require_cmd kubectl

if ! docker info >/dev/null 2>&1; then
  die "Docker daemon indisponible. Démarre Docker Desktop puis relance."
fi

if command -v kind >/dev/null 2>&1; then
  log "kind détecté: $(kind --version 2>/dev/null || true)"
else
  warn "kind non détecté. Le script create-kind.sh peut embarquer son propre binaire, sinon installe kind."
fi

log "Mode sélectionné: ${MODE}"
log "Overlay sélectionné: ${OVERLAY}"
log "Registry: ${REGISTRY_HOST}"
log "Image prefix: ${IMAGE_PREFIX}"
log "Image tag: ${IMAGE_TAG}"

if [[ "${RUN_JENKINS}" == "true" ]]; then
  if [[ -f "infra/jenkins/docker-compose.yml" ]]; then
    log "Démarrage de Jenkins..."
    docker compose -f infra/jenkins/docker-compose.yml up -d --build
  else
    warn "infra/jenkins/docker-compose.yml absent. Jenkins non démarré."
  fi
fi

log "Création/validation du cluster kind..."
bash scripts/deploy/create-kind.sh

if [[ -f "scripts/secrets/bootstrap-local-secrets.sh" ]]; then
  log "Bootstrap des secrets locaux..."
  bash scripts/secrets/bootstrap-local-secrets.sh
fi

if [[ -f "scripts/secrets/create-dev-secrets.sh" ]]; then
  log "Création des secrets applicatifs..."
  bash scripts/secrets/create-dev-secrets.sh
fi

log "Build des images locales..."
REGISTRY_HOST="${REGISTRY_HOST}" IMAGE_PREFIX="${IMAGE_PREFIX}" IMAGE_TAG="${IMAGE_TAG}" \
  bash scripts/deploy/build-local-images.sh

log "Déploiement Kubernetes..."
REGISTRY_HOST="${REGISTRY_HOST}" IMAGE_PREFIX="${IMAGE_PREFIX}" IMAGE_TAG="${IMAGE_TAG}" \
KUSTOMIZE_OVERLAY="${OVERLAY}" \
  bash scripts/deploy/deploy-kind.sh

if [[ "${RUN_METRICS}" == "true" ]]; then
  if [[ -f "scripts/deploy/install-metrics-server.sh" ]]; then
    log "Installation de metrics-server..."
    bash scripts/deploy/install-metrics-server.sh
  else
    warn "Script metrics-server absent."
  fi
fi

if [[ "${RUN_KYVERNO_AUDIT}" == "true" ]]; then
  if [[ -f "scripts/deploy/install-kyverno.sh" ]]; then
    log "Installation de Kyverno (Audit)..."
    bash scripts/deploy/install-kyverno.sh
  else
    warn "Script Kyverno absent."
  fi
fi

if [[ "${RUN_SMOKE_TESTS}" == "true" ]]; then
  if [[ "${MODE}" == "production" && -f "scripts/validate/run-production-readiness-campaign.sh" ]]; then
    log "Collecte readiness production (lecture seule)..."
    bash scripts/validate/run-production-readiness-campaign.sh || warn "La campagne production a signalé un état partiel."
  elif [[ -f "scripts/validate/smoke-tests.sh" ]]; then
    log "Exécution des smoke tests..."
    IMAGE_TAG="${IMAGE_TAG}" bash scripts/validate/smoke-tests.sh || warn "Smoke tests partiels."
  else
    warn "Aucun script de smoke test trouvé."
  fi
fi

if [[ "${RUN_SUPPORT_PACK}" == "true" ]]; then
  if command -v make >/dev/null 2>&1; then
    log "Génération du support pack..."
    make final-summary support-pack || warn "Support pack non généré complètement."
  else
    warn "make absent. Support pack ignoré."
  fi
fi

log "Résumé rapide"
kubectl get deploy,svc,pods -n securerag-hub || warn "Impossible de lire l'état du namespace securerag-hub."

if [[ "${RUN_METRICS}" == "true" ]]; then
  kubectl top pods -n securerag-hub || warn "kubectl top indisponible (metrics-server absent ou non prêt)."
fi

cat <<EOF

Lancement terminé.

Vérifications utiles:
  kubectl get all -n securerag-hub
  kubectl get pdb,hpa -n securerag-hub
  kubectl top pods -n securerag-hub
  curl http://localhost:8080/healthz
  curl http://localhost:8081/health

Exemples:
  MODE=demo bash securerag-launch-all.sh
  MODE=production RUN_METRICS=true RUN_KYVERNO_AUDIT=true bash securerag-launch-all.sh
EOF
