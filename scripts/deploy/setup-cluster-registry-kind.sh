#!/usr/bin/env bash

set -euo pipefail

KIND_CLUSTER="${KIND_CLUSTER:-securerag-prod}"
REGISTRY_CONTAINER="${REGISTRY_CONTAINER:-securerag-registry}"
REGISTRY_CLUSTER_HOST="${REGISTRY_CLUSTER_HOST:-securerag-registry:5000}"
REGISTRY_HOST_SIDE="${REGISTRY_HOST_SIDE:-127.0.0.1:5002}"
REPORT_FILE="${REPORT_FILE:-artifacts/validation/cluster-registry-setup.md}"

registry_name="${REGISTRY_CLUSTER_HOST%%:*}"
registry_container_port="${REGISTRY_CLUSTER_HOST##*:}"
registry_host_port="${REGISTRY_HOST_SIDE##*:}"

info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }

write_report() {
  local status="$1"
  local detail="$2"

  mkdir -p "$(dirname "${REPORT_FILE}")"
  {
    printf '# Cluster Reachable Registry Setup - SecureRAG Hub\n\n'
    printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf -- '- Status: `%s`\n' "${status}"
    printf -- '- Kind cluster: `%s`\n' "${KIND_CLUSTER}"
    printf -- '- Cluster registry: `%s`\n' "${REGISTRY_CLUSTER_HOST}"
    printf -- '- Host registry: `%s`\n' "${REGISTRY_HOST_SIDE}"
    printf -- '- Registry container: `%s`\n\n' "${REGISTRY_CONTAINER}"
    printf '## Detail\n\n%s\n' "${detail}"
  } > "${REPORT_FILE}"
}

if ! command -v docker >/dev/null 2>&1; then
  write_report "DÉPENDANT_DE_L_ENVIRONNEMENT" "Docker is required to run the local registry container."
  warn "Docker is missing; report written to ${REPORT_FILE}"
  exit 0
fi

if ! command -v kind >/dev/null 2>&1; then
  write_report "DÉPENDANT_DE_L_ENVIRONNEMENT" "kind is required to patch node containerd registry mirrors."
  warn "kind is missing; report written to ${REPORT_FILE}"
  exit 0
fi

if ! docker network inspect kind >/dev/null 2>&1; then
  write_report "DÉPENDANT_DE_L_ENVIRONNEMENT" "Docker network `kind` does not exist. Create the kind cluster first."
  warn "kind network is missing; report written to ${REPORT_FILE}"
  exit 0
fi

if docker ps -a --format '{{.Names}}' | grep -Fxq "${REGISTRY_CONTAINER}"; then
  info "Starting existing registry container ${REGISTRY_CONTAINER}"
  docker start "${REGISTRY_CONTAINER}" >/dev/null
else
  info "Creating registry container ${REGISTRY_CONTAINER}"
  docker run -d \
    --restart=always \
    --name "${REGISTRY_CONTAINER}" \
    --network kind \
    -p "${registry_host_port}:${registry_container_port}" \
    registry:2 >/dev/null
fi

if ! docker network inspect kind --format '{{json .Containers}}' | grep -Fq "\"${REGISTRY_CONTAINER}\""; then
  docker network connect kind "${REGISTRY_CONTAINER}" >/dev/null 2>&1 || true
fi

nodes="$(kind get nodes --name "${KIND_CLUSTER}" 2>/dev/null || true)"
if [[ -z "${nodes}" ]]; then
  write_report "DÉPENDANT_DE_L_ENVIRONNEMENT" "No kind nodes were found for cluster `${KIND_CLUSTER}`."
  warn "No kind nodes found; report written to ${REPORT_FILE}"
  exit 0
fi

for node in ${nodes}; do
  info "Configuring containerd registry mirror on ${node}"
  docker exec "${node}" mkdir -p "/etc/containerd/certs.d/${REGISTRY_CLUSTER_HOST}"
  cat <<TOML | docker exec -i "${node}" tee "/etc/containerd/certs.d/${REGISTRY_CLUSTER_HOST}/hosts.toml" >/dev/null
server = "http://${REGISTRY_CLUSTER_HOST}"

[host."http://${REGISTRY_CLUSTER_HOST}"]
  capabilities = ["pull", "resolve", "push"]
  skip_verify = true
TOML
  docker exec "${node}" sh -c 'systemctl restart containerd >/dev/null 2>&1 || pkill -SIGHUP containerd || true'
done

registry_ip="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${REGISTRY_CONTAINER}" 2>/dev/null || true)"
if [[ -n "${registry_ip}" && -w /etc/hosts ]]; then
  tmp_hosts="$(mktemp)"
  grep -vE "[[:space:]]${registry_name}($|[[:space:]])" /etc/hosts > "${tmp_hosts}" || true
  printf '%s %s\n' "${registry_ip}" "${registry_name}" >> "${tmp_hosts}"
  cat "${tmp_hosts}" > /etc/hosts
  rm -f "${tmp_hosts}"
fi

write_report "TERMINÉ" "Registry container is running and every kind node has an HTTP containerd mirror for `${REGISTRY_CLUSTER_HOST}`."
info "Cluster registry setup report written to ${REPORT_FILE}"
