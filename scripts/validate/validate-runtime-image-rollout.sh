#!/usr/bin/env bash

set -euo pipefail

NS="${NS:-securerag-hub}"
REGISTRY_HOST="${REGISTRY_HOST:-localhost:5001}"
IMAGE_PREFIX="${IMAGE_PREFIX:-securerag-hub}"
IMAGE_TAG="${IMAGE_TAG:-production}"
DIGEST_RECORD_FILE="${DIGEST_RECORD_FILE:-artifacts/release/promotion-digests.txt}"
REQUIRE_DIGEST_DEPLOY="${REQUIRE_DIGEST_DEPLOY:-false}"
DEPLOY_STARTED_AT="${DEPLOY_STARTED_AT:-}"
REPORT_FILE="${REPORT_FILE:-artifacts/validation/runtime-image-rollout-proof.md}"
JSON_FILE="${JSON_FILE:-${REPORT_FILE%.md}.json}"
STRICT_RUNTIME_IMAGE_PROOF="${STRICT_RUNTIME_IMAGE_PROOF:-false}"

DEFAULT_SERVICES=(
  auth-users
  chatbot-manager
  conversation-service
  audit-security-service
  portal-web
)

if [[ -n "${SERVICES:-}" ]]; then
  # shellcheck disable=SC2206
  SERVICES_ARRAY=(${SERVICES//,/ })
else
  SERVICES_ARRAY=("${DEFAULT_SERVICES[@]}")
fi

mkdir -p "$(dirname "${REPORT_FILE}")" "$(dirname "${JSON_FILE}")"

is_true() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|y|Y|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

if ! command -v kubectl >/dev/null 2>&1; then
  {
    printf '# Runtime Image Rollout Proof - SecureRAG Hub\n\n'
    printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf -- '- Status: `DÉPENDANT_DE_L_ENVIRONNEMENT`\n\n'
    printf 'kubectl is required to collect runtime image evidence.\n'
  } > "${REPORT_FILE}"
  printf '{"status":"DÉPENDANT_DE_L_ENVIRONNEMENT","reason":"kubectl missing"}\n' > "${JSON_FILE}"
  exit 0
fi

if ! kubectl get namespace "${NS}" >/dev/null 2>&1; then
  {
    printf '# Runtime Image Rollout Proof - SecureRAG Hub\n\n'
    printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf -- '- Namespace: `%s`\n' "${NS}"
    printf -- '- Status: `DÉPENDANT_DE_L_ENVIRONNEMENT`\n\n'
    printf 'The namespace is not reachable in the current Kubernetes context.\n'
  } > "${REPORT_FILE}"
  printf '{"status":"DÉPENDANT_DE_L_ENVIRONNEMENT","reason":"namespace unreachable"}\n' > "${JSON_FILE}"
  exit 0
fi

set +e
python3 - "${NS}" "${REGISTRY_HOST}" "${IMAGE_PREFIX}" "${IMAGE_TAG}" "${DIGEST_RECORD_FILE}" "${REQUIRE_DIGEST_DEPLOY}" "${DEPLOY_STARTED_AT}" "${REPORT_FILE}" "${JSON_FILE}" "${SERVICES_ARRAY[@]}" <<'PY'
import datetime as dt
import json
import pathlib
import re
import subprocess
import sys
from typing import Any

ns, registry, prefix, image_tag, digest_file, require_digest, deploy_started, report_file, json_file, *services = sys.argv[1:]
require_digest = require_digest.lower() in {"1", "true", "yes", "y", "on"}
report_path = pathlib.Path(report_file)
json_path = pathlib.Path(json_file)

def kubectl_json(*args: str) -> dict[str, Any]:
    raw = subprocess.check_output(["kubectl", *args], text=True)
    return json.loads(raw)

def parse_time(value: str | None) -> dt.datetime | None:
    if not value:
        return None
    return dt.datetime.fromisoformat(value.replace("Z", "+00:00"))

def is_pod_ready(pod: dict[str, Any]) -> bool:
    conditions = pod.get("status", {}).get("conditions") or []
    return any(cond.get("type") == "Ready" and cond.get("status") == "True" for cond in conditions)

def container_statuses(pod: dict[str, Any]) -> list[dict[str, Any]]:
    return pod.get("status", {}).get("containerStatuses") or []

def expected_digest_records(path: str) -> dict[str, str]:
    records: dict[str, str] = {}
    digest_re = re.compile(r"^sha256:[0-9a-f]{64}$")
    digest_path = pathlib.Path(path)
    if not digest_path.exists():
        return records
    for raw_line in digest_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split("|")
        if len(parts) != 4:
            continue
        service, _source_ref, _target_ref, digest = parts
        if digest_re.match(digest):
            records[service] = digest
    return records

started_at = parse_time(deploy_started)
digests = expected_digest_records(digest_file)

try:
    deployments = kubectl_json("get", "deploy", "-n", ns, "-o", "json").get("items", [])
    pods = kubectl_json("get", "pods", "-n", ns, "-o", "json").get("items", [])
except Exception as exc:
    status = "DÉPENDANT_DE_L_ENVIRONNEMENT"
    report_path.write_text(
        "# Runtime Image Rollout Proof - SecureRAG Hub\n\n"
        f"- Generated at UTC: `{dt.datetime.now(dt.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}`\n"
        f"- Namespace: `{ns}`\n"
        f"- Status: `{status}`\n\n"
        f"Unable to collect runtime image evidence: `{exc}`\n",
        encoding="utf-8",
    )
    json_path.write_text(json.dumps({"status": status, "error": str(exc)}, indent=2) + "\n", encoding="utf-8")
    raise SystemExit(0)

deploy_by_name = {item.get("metadata", {}).get("name"): item for item in deployments}
pods_by_service: dict[str, list[dict[str, Any]]] = {service: [] for service in services}
for pod in pods:
    labels = pod.get("metadata", {}).get("labels") or {}
    service = labels.get("app.kubernetes.io/name")
    if service in pods_by_service:
        pods_by_service[service].append(pod)

rows = []
all_ok = True

for service in services:
    deployment = deploy_by_name.get(service)
    service_pods = sorted(pods_by_service.get(service, []), key=lambda pod: pod.get("metadata", {}).get("name", ""))
    expected_tag_ref = f"{registry}/{prefix}-{service}:{image_tag}"
    expected_digest = digests.get(service)
    expected_digest_ref = f"{registry}/{prefix}-{service}@{expected_digest}" if expected_digest else None

    desired = deployment.get("spec", {}).get("replicas", 0) if deployment else 0
    images = []
    if deployment:
        containers = deployment.get("spec", {}).get("template", {}).get("spec", {}).get("containers") or []
        images = [container.get("image", "") for container in containers]

    pod_details = []
    ready_count = 0
    recent_count = 0
    image_id_match_count = 0

    for pod in service_pods:
        pod_name = pod.get("metadata", {}).get("name", "unknown")
        created = parse_time(pod.get("metadata", {}).get("creationTimestamp"))
        ready = is_pod_ready(pod)
        if ready:
            ready_count += 1
        recent = bool(started_at and created and created >= started_at)
        if recent:
            recent_count += 1
        statuses = container_statuses(pod)
        image_ids = [status.get("imageID", "") for status in statuses]
        pod_images = [status.get("image", "") for status in statuses]
        if require_digest and expected_digest:
            image_id_match = any(expected_digest in image_id for image_id in image_ids)
        else:
            image_id_match = any(expected_tag_ref == image or image.startswith(f"{expected_tag_ref}@") for image in pod_images)
        if image_id_match:
            image_id_match_count += 1
        pod_details.append({
            "name": pod_name,
            "ready": ready,
            "created": pod.get("metadata", {}).get("creationTimestamp", "unknown"),
            "recent": recent if started_at else None,
            "images": pod_images,
            "imageIDs": image_ids,
            "imageIDMatch": image_id_match,
        })

    if require_digest:
        deployment_image_ok = bool(expected_digest_ref and expected_digest_ref in images)
        digest_record_ok = expected_digest is not None
        pod_image_ok = desired > 0 and image_id_match_count >= desired
    else:
        deployment_image_ok = expected_tag_ref in images
        digest_record_ok = True
        pod_image_ok = desired > 0 and image_id_match_count >= desired

    ready_ok = desired > 0 and ready_count >= desired
    recent_ok = True if not started_at else desired > 0 and recent_count >= desired
    status = "TERMINÉ" if deployment and deployment_image_ok and digest_record_ok and ready_ok and recent_ok and pod_image_ok else "PARTIEL"
    if status != "TERMINÉ":
        all_ok = False

    rows.append({
        "service": service,
        "status": status,
        "desired": desired,
        "readyPods": ready_count,
        "recentPods": recent_count if started_at else "not_checked",
        "deploymentImages": images,
        "expectedTagRef": expected_tag_ref,
        "expectedDigest": expected_digest,
        "deploymentImageOk": deployment_image_ok,
        "digestRecordOk": digest_record_ok,
        "podImageOk": pod_image_ok,
        "pods": pod_details,
    })

global_status = "TERMINÉ" if all_ok else "PARTIEL"
now = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

with report_path.open("w", encoding="utf-8") as handle:
    handle.write("# Runtime Image Rollout Proof - SecureRAG Hub\n\n")
    handle.write(f"- Generated at UTC: `{now}`\n")
    handle.write(f"- Namespace: `{ns}`\n")
    handle.write(f"- Registry: `{registry}`\n")
    handle.write(f"- Image prefix: `{prefix}`\n")
    handle.write(f"- Image tag: `{image_tag}`\n")
    handle.write(f"- Require digest deploy: `{str(require_digest).lower()}`\n")
    handle.write(f"- Digest record file: `{digest_file}`\n")
    handle.write(f"- Deploy started at: `{deploy_started or 'not provided'}`\n")
    handle.write(f"- Status: `{global_status}`\n\n")
    handle.write("| Service | Status | Desired | Ready pods | Recent pods | Expected image/digest | Runtime image proof |\n")
    handle.write("|---|---:|---:|---:|---:|---|---|\n")
    for row in rows:
        if require_digest:
            expected = row["expectedDigest"] or "missing digest"
        else:
            expected = row["expectedTagRef"]
        runtime = "imageID/digest matched" if row["podImageOk"] else "imageID/digest not proven"
        handle.write(
            f"| `{row['service']}` | {row['status']} | {row['desired']} | {row['readyPods']} | "
            f"{row['recentPods']} | `{expected}` | {runtime} |\n"
        )
    handle.write("\n## Runtime pod details\n\n")
    for row in rows:
        handle.write(f"### {row['service']}\n\n")
        handle.write(f"- Deployment images: `{', '.join(row['deploymentImages']) if row['deploymentImages'] else 'missing'}`\n")
        handle.write(f"- Deployment image ok: `{row['deploymentImageOk']}`\n")
        handle.write(f"- Digest record ok: `{row['digestRecordOk']}`\n")
        for pod in row["pods"]:
            handle.write(
                f"- `{pod['name']}` ready=`{pod['ready']}` created=`{pod['created']}` "
                f"recent=`{pod['recent']}` imageIDMatch=`{pod['imageIDMatch']}`\n"
            )
            for image_id in pod["imageIDs"]:
                handle.write(f"  - imageID: `{image_id}`\n")
        handle.write("\n")
    handle.write("## Honest interpretation\n\n")
    handle.write("- `TERMINÉ` means the deployment spec, Ready pods and runtime container image IDs match the expected tag or promoted digest.\n")
    handle.write("- When `DEPLOY_STARTED_AT` is provided, pods must also be newer than the deployment action. This catches `deployment unchanged` false positives.\n")
    handle.write("- Digest mode is complete only when `REQUIRE_DIGEST_DEPLOY=true` and every service has a valid promoted digest record.\n")

json_path.write_text(json.dumps({
    "generatedAt": now,
    "namespace": ns,
    "registry": registry,
    "imagePrefix": prefix,
    "imageTag": image_tag,
    "requireDigestDeploy": require_digest,
    "digestRecordFile": digest_file,
    "deployStartedAt": deploy_started or None,
    "status": global_status,
    "services": rows,
}, indent=2, sort_keys=True) + "\n", encoding="utf-8")

raise SystemExit(0 if global_status == "TERMINÉ" else 1)
PY
python_status=$?
set -e

status="$(python3 - "${JSON_FILE}" <<'PY' 2>/dev/null || printf 'DÉPENDANT_DE_L_ENVIRONNEMENT'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as handle:
    print(json.load(handle).get("status", "PARTIEL"))
PY
)"

if [[ "${status}" != "TERMINÉ" ]] && is_true "${STRICT_RUNTIME_IMAGE_PROOF}"; then
  printf '[ERROR] Runtime image rollout proof is not complete. See %s\n' "${REPORT_FILE}" >&2
  exit 1
fi

printf '[INFO] Runtime image rollout proof written to %s\n' "${REPORT_FILE}"
