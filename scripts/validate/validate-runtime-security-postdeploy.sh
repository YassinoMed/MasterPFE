#!/usr/bin/env bash

set -euo pipefail

NS="${NS:-securerag-hub}"
OUT_DIR="${OUT_DIR:-artifacts/security}"
REPORT_FILE="${REPORT_FILE:-${OUT_DIR}/runtime-security-postdeploy.md}"
JSON_FILE="${JSON_FILE:-${REPORT_FILE%.md}.json}"
STRICT="${STRICT:-false}"
TAIL_LINES="${TAIL_LINES:-80}"

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

mkdir -p "${OUT_DIR}"

is_true() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|y|Y|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

capture() {
  local title="$1"
  shift

  {
    printf '\n## %s\n\n' "${title}"
    printf '```text\n'
    "$@" 2>&1 || true
    printf '```\n'
  } >> "${REPORT_FILE}"
}

write_env_report() {
  local status="$1"
  local reason="$2"

  {
    printf '# Runtime Security Post-Deployment Report - SecureRAG Hub\n\n'
    printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf -- '- Namespace: `%s`\n' "${NS}"
    printf -- '- Strict mode: `%s`\n' "${STRICT}"
    printf -- '- Status: `%s`\n\n' "${status}"
    printf '%s\n' "${reason}"
  } > "${REPORT_FILE}"
  printf '{"status":"%s","reason":"%s"}\n' "${status}" "${reason}" > "${JSON_FILE}"
}

if ! command -v kubectl >/dev/null 2>&1; then
  write_env_report "DÉPENDANT_DE_L_ENVIRONNEMENT" "kubectl is required to prove runtime workload hardening."
  is_true "${STRICT}" && exit 1
  exit 0
fi

if ! kubectl get namespace "${NS}" >/dev/null 2>&1; then
  write_env_report "DÉPENDANT_DE_L_ENVIRONNEMENT" "The namespace is not reachable in the current Kubernetes context."
  is_true "${STRICT}" && exit 1
  exit 0
fi

deployments_json="$(mktemp)"
pods_json="$(mktemp)"
serviceaccounts_json="$(mktemp)"
networkpolicies_json="$(mktemp)"
pdb_json="$(mktemp)"
hpa_json="$(mktemp)"
rbac_json="$(mktemp)"
trap 'rm -f "${deployments_json}" "${pods_json}" "${serviceaccounts_json}" "${networkpolicies_json}" "${pdb_json}" "${hpa_json}" "${rbac_json}"' EXIT

kubectl get deploy -n "${NS}" -o json > "${deployments_json}"
kubectl get pods -n "${NS}" -o json > "${pods_json}"
kubectl get sa -n "${NS}" -o json > "${serviceaccounts_json}"
kubectl get networkpolicy -n "${NS}" -o json > "${networkpolicies_json}"
kubectl get pdb -n "${NS}" -o json > "${pdb_json}"
kubectl get hpa -n "${NS}" -o json > "${hpa_json}" 2>/dev/null || printf '{"items":[]}\n' > "${hpa_json}"
kubectl get role,rolebinding -n "${NS}" -o json > "${rbac_json}" 2>/dev/null || printf '{"items":[]}\n' > "${rbac_json}"

set +e
python3 - "${REPORT_FILE}" "${JSON_FILE}" "${NS}" "${deployments_json}" "${pods_json}" "${serviceaccounts_json}" "${networkpolicies_json}" "${pdb_json}" "${hpa_json}" "${rbac_json}" "${SERVICES_ARRAY[@]}" <<'PY'
import datetime as dt
import json
import pathlib
import sys
from typing import Any

report_file, json_file, namespace, deployments_path, pods_path, serviceaccounts_path, networkpolicies_path, pdb_path, hpa_path, rbac_path, *services = sys.argv[1:]


def load_json(path: str) -> dict[str, Any]:
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def nested(obj: Any, *keys: str, default=None):
    current = obj
    for key in keys:
        if not isinstance(current, dict):
            return default
        current = current.get(key)
    return default if current is None else current


def pod_ready(pod: dict[str, Any]) -> bool:
    conditions = nested(pod, "status", "conditions", default=[]) or []
    return any(item.get("type") == "Ready" and item.get("status") == "True" for item in conditions)


def pod_selector_matches(policy: dict[str, Any], service: str) -> bool:
    selector = nested(policy, "spec", "podSelector", default={}) or {}
    labels = selector.get("matchLabels") or {}
    expressions = selector.get("matchExpressions") or []
    if labels.get("app.kubernetes.io/name") == service:
        return True
    for expr in expressions:
        if expr.get("key") == "app.kubernetes.io/name" and service in (expr.get("values") or []):
            return True
    return False


deployments = load_json(deployments_path).get("items", [])
pods = load_json(pods_path).get("items", [])
serviceaccounts = load_json(serviceaccounts_path).get("items", [])
networkpolicies = load_json(networkpolicies_path).get("items", [])
pdbs = load_json(pdb_path).get("items", [])
hpas = load_json(hpa_path).get("items", [])
rbac_items = load_json(rbac_path).get("items", [])

deployments_by_name = {item.get("metadata", {}).get("name"): item for item in deployments}
serviceaccounts_by_name = {item.get("metadata", {}).get("name"): item for item in serviceaccounts}
hpas_by_name = {item.get("metadata", {}).get("name"): item for item in hpas}

roles = [item for item in rbac_items if item.get("kind") == "Role"]
rolebindings = [item for item in rbac_items if item.get("kind") == "RoleBinding"]
role_names = {item.get("metadata", {}).get("name") for item in roles}
rolebinding_names = {item.get("metadata", {}).get("name") for item in rolebindings}

default_deny_present = any(item.get("metadata", {}).get("name") == "default-deny-all" for item in networkpolicies)
dns_egress_present = any(item.get("metadata", {}).get("name") == "allow-dns-egress" for item in networkpolicies)
runtime_readonly_role_present = "securerag-runtime-readonly" in role_names
audit_rolebinding_present = "securerag-runtime-readonly-audit-security-service" in rolebinding_names

rows = []
global_failures = []

for service in services:
    deployment = deployments_by_name.get(service)
    desired = nested(deployment or {}, "spec", "replicas", default=0) or 0
    pod_template = nested(deployment or {}, "spec", "template", "spec", default={}) or {}
    pod_sc = pod_template.get("securityContext") or {}
    expected_sa = f"sa-{service}"
    live_pods = sorted(
        [
            pod for pod in pods
            if nested(pod, "metadata", "labels", default={}).get("app.kubernetes.io/name") == service
        ],
        key=lambda pod: nested(pod, "metadata", "name", default="")
    )
    ready_pods = sum(1 for pod in live_pods if pod_ready(pod))
    pdb_present = any(service in (nested(item, "metadata", "name", default="") or "") for item in pdbs)
    hpa_present = service in hpas_by_name
    netpol_selected = any(pod_selector_matches(item, service) for item in networkpolicies)

    service_failures = []

    if not deployment:
        service_failures.append("deployment missing")
    if nested(deployment or {}, "spec", "template", "spec", "serviceAccountName") != expected_sa:
        service_failures.append(f"serviceAccountName != {expected_sa}")
    if pod_template.get("automountServiceAccountToken") is not False:
        service_failures.append("automountServiceAccountToken not false")
    if pod_sc.get("runAsNonRoot") is not True:
        service_failures.append("pod runAsNonRoot not true")
    if nested(pod_sc, "seccompProfile", "type") != "RuntimeDefault":
        service_failures.append("pod seccompProfile not RuntimeDefault")

    sa = serviceaccounts_by_name.get(expected_sa)
    if not sa:
        service_failures.append(f"{expected_sa} missing")
    elif sa.get("automountServiceAccountToken") is not False:
        service_failures.append(f"{expected_sa} automountServiceAccountToken not false")

    if not pdb_present:
        service_failures.append("PDB missing")
    if not hpa_present:
        service_failures.append("HPA missing")
    if not netpol_selected:
        service_failures.append("NetworkPolicy does not select workload")

    if desired <= 0:
        service_failures.append("desired replicas is 0")
    if len(live_pods) < desired:
        service_failures.append(f"live pods {len(live_pods)}/{desired}")
    if ready_pods < desired:
        service_failures.append(f"ready pods {ready_pods}/{desired}")

    pod_details = []
    image_id_coverage = 0
    runtime_security_coverage = 0

    for pod in live_pods:
        pod_name = nested(pod, "metadata", "name", default="unknown")
        pod_spec = pod.get("spec") or {}
        pod_sc_live = pod_spec.get("securityContext") or {}
        statuses = nested(pod, "status", "containerStatuses", default=[]) or []
        image_ids = [item.get("imageID", "") for item in statuses]
        image_id_ok = len(image_ids) == len(pod_spec.get("containers") or []) and all(image_ids)
        if image_id_ok:
            image_id_coverage += 1

        pod_runtime_failures = []
        if pod_spec.get("serviceAccountName") != expected_sa:
            pod_runtime_failures.append(f"pod serviceAccountName != {expected_sa}")
        if pod_spec.get("automountServiceAccountToken") is not False:
            pod_runtime_failures.append("pod automountServiceAccountToken not false")
        if pod_sc_live.get("runAsNonRoot") is not True:
            pod_runtime_failures.append("pod runAsNonRoot not true")
        if nested(pod_sc_live, "seccompProfile", "type") != "RuntimeDefault":
            pod_runtime_failures.append("pod seccompProfile not RuntimeDefault")

        for container in pod_spec.get("containers") or []:
            cname = container.get("name", "container")
            sc = container.get("securityContext") or {}
            if sc.get("allowPrivilegeEscalation") is not False:
                pod_runtime_failures.append(f"{cname} allowPrivilegeEscalation not false")
            if sc.get("readOnlyRootFilesystem") is not True:
                pod_runtime_failures.append(f"{cname} readOnlyRootFilesystem not true")
            if "ALL" not in (nested(sc, "capabilities", "drop", default=[]) or []):
                pod_runtime_failures.append(f"{cname} capabilities.drop missing ALL")
            if "readinessProbe" not in container:
                pod_runtime_failures.append(f"{cname} readinessProbe missing")
            if "livenessProbe" not in container:
                pod_runtime_failures.append(f"{cname} livenessProbe missing")
            if "startupProbe" not in container:
                pod_runtime_failures.append(f"{cname} startupProbe missing")
        if not pod_runtime_failures and image_id_ok and pod_ready(pod):
            runtime_security_coverage += 1

        pod_details.append({
            "name": pod_name,
            "ready": pod_ready(pod),
            "created": nested(pod, "metadata", "creationTimestamp", default="unknown"),
            "imageIDs": image_ids,
            "runtimeFailures": pod_runtime_failures,
        })

    service_status = "TERMINÉ" if not service_failures and runtime_security_coverage >= desired and image_id_coverage >= desired else "PARTIEL"
    if service_status != "TERMINÉ":
        global_failures.append(f"{service}: {'; '.join(service_failures or ['runtime pod security incomplete'])}")

    rows.append({
        "service": service,
        "status": service_status,
        "desired": desired,
        "readyPods": ready_pods,
        "livePods": len(live_pods),
        "imageIDCoverage": image_id_coverage,
        "runtimeCoverage": runtime_security_coverage,
        "serviceAccount": expected_sa,
        "pdbPresent": pdb_present,
        "hpaPresent": hpa_present,
        "networkPolicySelected": netpol_selected,
        "failures": service_failures,
        "pods": pod_details,
    })

global_status = "TERMINÉ" if not global_failures and default_deny_present and dns_egress_present and runtime_readonly_role_present and audit_rolebinding_present else "PARTIEL"
if not default_deny_present:
    global_failures.append("default-deny-all NetworkPolicy missing")
if not dns_egress_present:
    global_failures.append("allow-dns-egress NetworkPolicy missing")
if not runtime_readonly_role_present:
    global_failures.append("securerag-runtime-readonly Role missing")
if not audit_rolebinding_present:
    global_failures.append("securerag-runtime-readonly-audit-security-service RoleBinding missing")

now = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
report_path = pathlib.Path(report_file)
json_path = pathlib.Path(json_file)

with report_path.open("w", encoding="utf-8") as handle:
    handle.write("# Runtime Security Post-Deployment Report - SecureRAG Hub\n\n")
    handle.write(f"- Generated at UTC: `{now}`\n")
    handle.write(f"- Namespace: `{namespace}`\n")
    handle.write(f"- Status: `{global_status}`\n\n")
    handle.write("## Global controls\n\n")
    handle.write("| Control | Status | Evidence |\n")
    handle.write("|---|---:|---|\n")
    handle.write(f"| `default-deny-all` NetworkPolicy | {'TERMINÉ' if default_deny_present else 'PARTIEL'} | `kubectl get networkpolicy -n {namespace}` |\n")
    handle.write(f"| `allow-dns-egress` NetworkPolicy | {'TERMINÉ' if dns_egress_present else 'PARTIEL'} | `kubectl get networkpolicy -n {namespace}` |\n")
    handle.write(f"| Runtime readonly Role | {'TERMINÉ' if runtime_readonly_role_present else 'PARTIEL'} | `securerag-runtime-readonly` |\n")
    handle.write(f"| Audit service RoleBinding | {'TERMINÉ' if audit_rolebinding_present else 'PARTIEL'} | `securerag-runtime-readonly-audit-security-service` |\n")
    handle.write("\n## Workload summary\n\n")
    handle.write("| Workload | Status | Ready / Desired | imageID coverage | Runtime hardening coverage | ServiceAccount | NetPol | HPA | PDB |\n")
    handle.write("|---|---:|---:|---:|---:|---|---|---|---|\n")
    for row in rows:
        handle.write(
            f"| `{row['service']}` | {row['status']} | {row['readyPods']} / {row['desired']} | "
            f"{row['imageIDCoverage']} / {row['desired']} | {row['runtimeCoverage']} / {row['desired']} | "
            f"`{row['serviceAccount']}` | `{row['networkPolicySelected']}` | `{row['hpaPresent']}` | `{row['pdbPresent']}` |\n"
        )
    handle.write("\n## Workload details\n\n")
    for row in rows:
        handle.write(f"### {row['service']}\n\n")
        if row["failures"]:
            for failure in row["failures"]:
                handle.write(f"- Gap: {failure}\n")
        else:
            handle.write("- No deployment-level hardening gap detected.\n")
        for pod in row["pods"]:
            handle.write(
                f"- Pod `{pod['name']}` ready=`{pod['ready']}` created=`{pod['created']}` imageIDs=`{len(pod['imageIDs'])}`\n"
            )
            if pod["runtimeFailures"]:
                for failure in pod["runtimeFailures"]:
                    handle.write(f"  - Gap: {failure}\n")
            else:
                handle.write("  - Runtime hardening checks matched the active Pod spec.\n")
            for image_id in pod["imageIDs"]:
                handle.write(f"  - imageID: `{image_id}`\n")
        handle.write("\n")
    handle.write("## Honest reading\n\n")
    handle.write("- `TERMINÉ` means the active Deployments and live Pods match the expected runtime security controls.\n")
    handle.write("- `PARTIEL` means at least one live workload, Pod or cluster-side control is missing or inconsistent.\n")
    handle.write("- `DÉPENDANT_DE_L_ENVIRONNEMENT` means the current cluster or namespace is not reachable.\n")

payload = {
    "status": global_status,
    "namespace": namespace,
    "globalControls": {
        "defaultDenyNetworkPolicy": default_deny_present,
        "dnsEgressNetworkPolicy": dns_egress_present,
        "runtimeReadonlyRole": runtime_readonly_role_present,
        "auditRoleBinding": audit_rolebinding_present,
    },
    "services": rows,
    "failures": global_failures,
}
json_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")

raise SystemExit(0 if global_status == "TERMINÉ" else 1)
PY
python_status=$?
set -e

capture "Deployments" kubectl get deploy -n "${NS}" -o wide
capture "Pods" kubectl get pods -n "${NS}" -o wide
capture "Deployment images and imageIDs" bash -c \
  "kubectl get pods -n '${NS}' -o jsonpath='{range .items[*]}{.metadata.name}{\"\\t\"}{range .status.containerStatuses[*]}{.image}{\"\\t\"}{.imageID}{\"\\n\"}{end}{end}'"
capture "ServiceAccounts" kubectl get sa -n "${NS}" -o wide
capture "Roles and RoleBindings" kubectl get role,rolebinding -n "${NS}" -o wide
capture "NetworkPolicies" kubectl get networkpolicy -n "${NS}" -o wide
capture "PodDisruptionBudgets" kubectl get pdb -n "${NS}" -o wide
capture "HPA" kubectl get hpa -n "${NS}" -o wide
capture "Recent events" bash -c "kubectl get events -n '${NS}' --sort-by=.lastTimestamp | tail -n '${TAIL_LINES}'"

for deployment in "${SERVICES_ARRAY[@]}"; do
  capture "Logs deployment/${deployment}" kubectl logs -n "${NS}" "deployment/${deployment}" --tail="${TAIL_LINES}" --all-containers=true
done

if [[ "${python_status}" -ne 0 ]]; then
  printf '[WARN] Runtime security post-deployment report contains gaps: %s\n' "${REPORT_FILE}" >&2
  is_true "${STRICT}" && exit 1
else
  printf '[INFO] Runtime security post-deployment report passed: %s\n' "${REPORT_FILE}"
fi
