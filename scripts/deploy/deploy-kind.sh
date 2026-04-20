#!/usr/bin/env bash

set -euo pipefail

command -v kubectl >/dev/null 2>&1 || { echo "kubectl is required"; exit 1; }

NS="${NS:-securerag-hub}"
REGISTRY_HOST="${REGISTRY_HOST:-localhost:5001}"
IMAGE_PREFIX="${IMAGE_PREFIX:-securerag-hub}"
IMAGE_TAG="${IMAGE_TAG:-dev}"
IMAGE_DIGEST_FILE="${IMAGE_DIGEST_FILE:-}"
KUSTOMIZE_OVERLAY="${KUSTOMIZE_OVERLAY:-infra/k8s/overlays/dev}"
REQUIRE_DIGEST_DEPLOY="${REQUIRE_DIGEST_DEPLOY:-false}"
DEPLOY_EVIDENCE_FILE="${DEPLOY_EVIDENCE_FILE:-artifacts/release/no-rebuild-deploy-summary.md}"
RUNTIME_IMAGE_PROOF_FILE="${RUNTIME_IMAGE_PROOF_FILE:-artifacts/validation/runtime-image-rollout-proof.md}"
FORCE_WORKLOAD_ROLLOUT="${FORCE_WORKLOAD_ROLLOUT:-true}"
STRICT_RUNTIME_IMAGE_PROOF="${STRICT_RUNTIME_IMAGE_PROOF:-true}"
OVERLAY_RELATIVE_PATH="${KUSTOMIZE_OVERLAY#infra/k8s/}"

official_deployments=(
  portal-web
  auth-users
  chatbot-manager
  conversation-service
  audit-security-service
)

is_true() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|y|Y|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

temp_root="$(mktemp -d)"
trap 'rm -rf "${temp_root}"' EXIT

cp -R infra/k8s "${temp_root}/k8s"

python3 - "${temp_root}/k8s/${OVERLAY_RELATIVE_PATH}/kustomization.yaml" "${REGISTRY_HOST}" "${IMAGE_PREFIX}" "${IMAGE_TAG}" "${IMAGE_DIGEST_FILE}" "${REQUIRE_DIGEST_DEPLOY}" <<'PY'
import sys

path, registry_host, image_prefix, image_tag, digest_file, require_digest_deploy = sys.argv[1:7]
require_digest_deploy = require_digest_deploy.lower() in {"1", "true", "yes", "y", "on"}
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
        if require_digest_deploy:
            raise SystemExit(f"required digest file is missing: {digest_file}")

if require_digest_deploy and not digests:
    raise SystemExit("REQUIRE_DIGEST_DEPLOY=true but no digest records were loaded")

current_service = None
missing_digests = []
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
        elif require_digest_deploy:
            missing_digests.append(current_service)
        else:
            lines[index] = f"{indent}newTag: {image_tag}"

if missing_digests:
    missing = ", ".join(sorted(set(missing_digests)))
    raise SystemExit(f"REQUIRE_DIGEST_DEPLOY=true but missing digest records for: {missing}")

with open(path, "w", encoding="utf-8") as fh:
    fh.write("\n".join(lines) + "\n")
PY

overlay_path="${temp_root}/k8s/${OVERLAY_RELATIVE_PATH}"
deploy_started_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

kubectl apply -k "${overlay_path}"

if is_true "${FORCE_WORKLOAD_ROLLOUT}"; then
  printf '[INFO] Forcing controlled rollout for official workloads to avoid mutable-tag false positives\n'
  deploy_started_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  for deployment in "${official_deployments[@]}"; do
    kubectl rollout restart "deployment/${deployment}" -n "${NS}"
  done
fi

for deployment in "${official_deployments[@]}"; do
  kubectl rollout status "deployment/${deployment}" -n "${NS}" --timeout=180s
done

REGISTRY_HOST="${REGISTRY_HOST}" \
IMAGE_PREFIX="${IMAGE_PREFIX}" \
IMAGE_TAG="${IMAGE_TAG}" \
DIGEST_RECORD_FILE="${IMAGE_DIGEST_FILE:-${REPORT_DIR:-artifacts/release}/promotion-digests.txt}" \
REQUIRE_DIGEST_DEPLOY="${REQUIRE_DIGEST_DEPLOY}" \
DEPLOY_STARTED_AT="${deploy_started_at}" \
REPORT_FILE="${RUNTIME_IMAGE_PROOF_FILE}" \
STRICT_RUNTIME_IMAGE_PROOF="${STRICT_RUNTIME_IMAGE_PROOF}" \
NS="${NS}" \
bash scripts/validate/validate-runtime-image-rollout.sh

mkdir -p "$(dirname "${DEPLOY_EVIDENCE_FILE}")"
{
  printf '# No-Rebuild Deploy Evidence - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Namespace: `%s`\n' "${NS}"
  printf -- '- Overlay: `%s`\n' "${KUSTOMIZE_OVERLAY}"
  printf -- '- Registry: `%s`\n' "${REGISTRY_HOST}"
  printf -- '- Image prefix: `%s`\n' "${IMAGE_PREFIX}"
  printf -- '- Image tag fallback: `%s`\n' "${IMAGE_TAG}"
  printf -- '- Digest file: `%s`\n' "${IMAGE_DIGEST_FILE:-none}"
  printf -- '- Require digest deploy: `%s`\n\n' "${REQUIRE_DIGEST_DEPLOY}"
  printf -- '- Forced rollout: `%s`\n' "${FORCE_WORKLOAD_ROLLOUT}"
  printf -- '- Deploy started at: `%s`\n' "${deploy_started_at}"
  printf -- '- Runtime image proof: `%s`\n\n' "${RUNTIME_IMAGE_PROOF_FILE}"
  printf '## Runtime deployments\n\n'
  printf '```text\n'
  kubectl get deploy -n "${NS}" -o wide
  printf '```\n\n'
  printf '## Runtime images\n\n'
  printf '```text\n'
  kubectl get deploy -n "${NS}" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .spec.template.spec.containers[*]}{.image}{" "}{end}{"\n"}{end}'
  printf '```\n'
} > "${DEPLOY_EVIDENCE_FILE}"
