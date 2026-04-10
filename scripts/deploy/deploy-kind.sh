#!/usr/bin/env bash

set -euo pipefail

command -v kubectl >/dev/null 2>&1 || { echo "kubectl is required"; exit 1; }

REGISTRY_HOST="${REGISTRY_HOST:-localhost:5001}"
IMAGE_PREFIX="${IMAGE_PREFIX:-securerag-hub}"
IMAGE_TAG="${IMAGE_TAG:-dev}"
IMAGE_DIGEST_FILE="${IMAGE_DIGEST_FILE:-}"
KUSTOMIZE_OVERLAY="${KUSTOMIZE_OVERLAY:-infra/k8s/overlays/dev}"
OVERLAY_RELATIVE_PATH="${KUSTOMIZE_OVERLAY#infra/k8s/}"

temp_root="$(mktemp -d)"
trap 'rm -rf "${temp_root}"' EXIT

cp -R infra/k8s "${temp_root}/k8s"

python3 - "${temp_root}/k8s/${OVERLAY_RELATIVE_PATH}/kustomization.yaml" "${REGISTRY_HOST}" "${IMAGE_PREFIX}" "${IMAGE_TAG}" "${IMAGE_DIGEST_FILE}" <<'PY'
import sys

path, registry_host, image_prefix, image_tag, digest_file = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
with open(path, "r", encoding="utf-8") as fh:
    lines = fh.read().splitlines()

digests = {}
if digest_file:
    try:
        with open(digest_file, "r", encoding="utf-8") as handle:
            for raw_line in handle:
                line = raw_line.strip()
                if not line or line.startswith("#"):
                    continue
                service, _source_ref, _target_ref, digest = line.split("|", 3)
                digests[service] = digest
    except FileNotFoundError:
        pass

current_service = None
for index, line in enumerate(lines):
    stripped = line.strip()
    if stripped.startswith("- name: ghcr.io/example/securerag-hub-"):
        current_service = stripped.split("ghcr.io/example/securerag-hub-", 1)[1]
        continue

    if current_service and stripped.startswith("newName: "):
        indent = line.split("newName:", 1)[0]
        lines[index] = f"{indent}newName: {registry_host}/{image_prefix}-{current_service}"
        continue

    if current_service and stripped.startswith("newTag: "):
        indent = line.split("newTag:", 1)[0]
        if current_service in digests:
            lines[index] = f"{indent}digest: {digests[current_service]}"
        else:
            lines[index] = f"{indent}newTag: {image_tag}"

with open(path, "w", encoding="utf-8") as fh:
    fh.write("\n".join(lines) + "\n")
PY

overlay_path="${temp_root}/k8s/${OVERLAY_RELATIVE_PATH}"

kubectl apply -k "${overlay_path}"
kubectl rollout status statefulset/qdrant -n securerag-hub --timeout=300s
kubectl rollout status deployment/ollama -n securerag-hub --timeout=300s
kubectl rollout status deployment/api-gateway -n securerag-hub --timeout=180s
kubectl rollout status deployment/auth-users -n securerag-hub --timeout=180s
kubectl rollout status deployment/chatbot-manager -n securerag-hub --timeout=180s
kubectl rollout status deployment/llm-orchestrator -n securerag-hub --timeout=180s
kubectl rollout status deployment/security-auditor -n securerag-hub --timeout=180s
kubectl rollout status deployment/knowledge-hub -n securerag-hub --timeout=180s
