#!/usr/bin/env bash

set -euo pipefail

KUBECONFIG_OUTPUT="${KUBECONFIG_OUTPUT:-infra/jenkins/secrets/kubeconfig}"

info() { printf '[INFO] %s\n' "$*"; }
error() { printf '[ERROR] %s\n' "$*" >&2; }

command -v kubectl >/dev/null 2>&1 || { error "kubectl is required"; exit 2; }

mkdir -p "$(dirname "${KUBECONFIG_OUTPUT}")"
if [[ -d "${KUBECONFIG_OUTPUT}" ]]; then
  error "${KUBECONFIG_OUTPUT} is a directory; remove it or choose a file path for KUBECONFIG_OUTPUT"
  exit 2
fi
kubectl config view --minify --raw > "${KUBECONFIG_OUTPUT}"
python3 -c "
import sys, json, yaml, re
with open('${KUBECONFIG_OUTPUT}', 'r') as f:
    config = yaml.safe_load(f)
for cluster in config.get('clusters', []):
    server = cluster['cluster']['server']
    server = re.sub(r'https://[^:]+:\d+', 'https://securerag-dev-control-plane:6443', server)
    cluster['cluster']['server'] = server
with open('${KUBECONFIG_OUTPUT}', 'w') as f:
    yaml.safe_dump(config, f)
"
chmod 600 "${KUBECONFIG_OUTPUT}"

info "Local kind kubeconfig exported to ${KUBECONFIG_OUTPUT}"
