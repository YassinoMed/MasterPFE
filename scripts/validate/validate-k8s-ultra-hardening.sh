#!/usr/bin/env bash

set -euo pipefail

REPORT_DIR="${REPORT_DIR:-artifacts/security}"
REPORT_FILE="${REPORT_DIR}/k8s-ultra-hardening.md"
OVERLAYS=(
  "infra/k8s/overlays/dev"
  "infra/k8s/overlays/demo"
  "infra/k8s/overlays/production"
)
POLICY_OVERLAYS=(
  "infra/k8s/policies/kyverno"
  "infra/k8s/policies/kyverno-enforce"
)

mkdir -p "${REPORT_DIR}"

for cmd in kubectl python3; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "[ERROR] Missing command: ${cmd}" >&2
    exit 1
  fi
done

if ! python3 - <<'PY' >/dev/null 2>&1
import yaml  # noqa: F401
PY
then
  echo "[ERROR] Missing Python module: yaml. Install python3-yaml or PyYAML." >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

for overlay in "${OVERLAYS[@]}"; do
  kubectl kustomize "${overlay}" > "${tmp_dir}/$(basename "${overlay}").yaml"
done

for overlay in "${POLICY_OVERLAYS[@]}"; do
  kubectl kustomize "${overlay}" > "${tmp_dir}/$(basename "${overlay}")-policies.yaml"
done

python3 - "${tmp_dir}" "${REPORT_FILE}" <<'PY'
import glob
import os
import sys

import yaml

tmp_dir, report_file = sys.argv[1:]
official = [
    "portal-web",
    "auth-users",
    "chatbot-manager",
    "conversation-service",
    "audit-security-service",
]
required_policy_names = [
    "securerag-audit-cleartext-env-values",
    "securerag-require-pod-security",
    "securerag-require-workload-controls",
    "securerag-restrict-image-references",
    "securerag-restrict-service-exposure",
    "securerag-restrict-volume-types",
    "securerag-verify-cosign-images",
]

failures = []
rows = []


def dig(obj, *keys):
    for key in keys:
        if not isinstance(obj, dict):
            return None
        obj = obj.get(key)
    return obj


def check(condition, overlay, control, evidence):
    if condition:
        rows.append([overlay, control, "TERMINÉ", evidence])
    else:
        failures.append(f"{overlay}: {control} -- {evidence}")
        rows.append([overlay, control, "FAIL", evidence])


for path in sorted(glob.glob(os.path.join(tmp_dir, "*.yaml"))):
    overlay = os.path.basename(path).removesuffix(".yaml")
    with open(path, encoding="utf-8") as handle:
        docs = [doc for doc in yaml.safe_load_all(handle) if isinstance(doc, dict)]

    if overlay.endswith("-policies"):
        policies = [doc for doc in docs if doc.get("kind") == "ClusterPolicy"]
        names = [dig(doc, "metadata", "name") for doc in policies]
        for name in required_policy_names:
            check(names.count(name) > 0, overlay, f"Kyverno policy {name} rendered", "ClusterPolicy present")

        if overlay == "kyverno-enforce-policies":
            for policy in policies:
                policy_name = dig(policy, "metadata", "name")
                check(
                    dig(policy, "spec", "validationFailureAction") == "Enforce",
                    overlay,
                    f"{policy_name} is Enforce",
                    "validationFailureAction=Enforce",
                )
        continue

    namespace = next(
        (
            doc
            for doc in docs
            if doc.get("kind") == "Namespace" and dig(doc, "metadata", "name") == "securerag-hub"
        ),
        None,
    )
    labels = dig(namespace or {}, "metadata", "labels") or {}
    check(labels.get("pod-security.kubernetes.io/enforce") == "restricted", overlay, "Pod Security Admission enforce restricted", "namespace label enforce=restricted")
    check(labels.get("pod-security.kubernetes.io/audit") == "restricted", overlay, "Pod Security Admission audit restricted", "namespace label audit=restricted")
    check(labels.get("pod-security.kubernetes.io/warn") == "restricted", overlay, "Pod Security Admission warn restricted", "namespace label warn=restricted")

    service_accounts = [doc for doc in docs if doc.get("kind") == "ServiceAccount"]
    for sa in [f"sa-{name}" for name in official] + ["sa-validation"]:
        sa_doc = next((doc for doc in service_accounts if dig(doc, "metadata", "name") == sa), None)
        check(sa_doc is not None and sa_doc.get("automountServiceAccountToken") is False, overlay, f"ServiceAccount {sa} token automount disabled", "automountServiceAccountToken=false")

    deployments = [doc for doc in docs if doc.get("kind") == "Deployment"]
    deployments_by_name = {dig(doc, "metadata", "name"): doc for doc in deployments}
    for name in official:
        dep = deployments_by_name.get(name)
        check(dep is not None, overlay, f"Deployment {name} rendered", "Deployment present")
        if not dep:
            continue

        pod_spec = dig(dep, "spec", "template", "spec") or {}
        pod_sc = pod_spec.get("securityContext") or {}
        containers = pod_spec.get("containers") or []
        volumes = pod_spec.get("volumes") or []

        check(bool(pod_spec.get("serviceAccountName")) and pod_spec.get("serviceAccountName") != "default", overlay, f"{name} explicit non-default ServiceAccount", str(pod_spec.get("serviceAccountName") or ""))
        check(pod_spec.get("automountServiceAccountToken") is False, overlay, f"{name} token automount disabled", "automountServiceAccountToken=false")
        check(pod_sc.get("runAsNonRoot") is True, overlay, f"{name} pod runs as non-root", "runAsNonRoot=true")
        check(dig(pod_sc, "seccompProfile", "type") == "RuntimeDefault", overlay, f"{name} RuntimeDefault seccomp", "seccompProfile=RuntimeDefault")
        check(not pod_spec.get("hostNetwork", False), overlay, f"{name} hostNetwork disabled", "hostNetwork=false/absent")
        check(not pod_spec.get("hostPID", False), overlay, f"{name} hostPID disabled", "hostPID=false/absent")
        check(not pod_spec.get("hostIPC", False), overlay, f"{name} hostIPC disabled", "hostIPC=false/absent")
        check(all("hostPath" not in volume for volume in volumes), overlay, f"{name} no hostPath volume", "hostPath absent")

        for container in containers:
            cname = container.get("name")
            sc = container.get("securityContext") or {}
            resources = container.get("resources") or {}
            requests = resources.get("requests") or {}
            limits = resources.get("limits") or {}
            image = str(container.get("image") or "")

            check(sc.get("allowPrivilegeEscalation") is False, overlay, f"{name}/{cname} privilege escalation disabled", "allowPrivilegeEscalation=false")
            check(sc.get("readOnlyRootFilesystem") is True, overlay, f"{name}/{cname} read-only root filesystem", "readOnlyRootFilesystem=true")
            check("ALL" in (dig(sc, "capabilities", "drop") or []), overlay, f"{name}/{cname} drops all capabilities", "capabilities.drop includes ALL")
            for resource in ["cpu", "memory", "ephemeral-storage"]:
                check(resource in requests and resource in limits, overlay, f"{name}/{cname} {resource} request and limit", f"requests/limits {resource}")
            for probe in ["readinessProbe", "livenessProbe", "startupProbe"]:
                check(probe in container, overlay, f"{name}/{cname} {probe}", f"{probe} present")
            check(not image.endswith(":latest"), overlay, f"{name}/{cname} image not latest", image)

    services = [doc for doc in docs if doc.get("kind") == "Service"]
    for svc in services:
        name = dig(svc, "metadata", "name")
        service_type = dig(svc, "spec", "type") or "ClusterIP"
        allowed = service_type == "ClusterIP" or (name == "portal-web" and service_type == "NodePort")
        check(allowed, overlay, f"Service {name} exposure restricted", f"type={service_type}")

    pdb_names = [str(dig(doc, "metadata", "name") or "") for doc in docs if doc.get("kind") == "PodDisruptionBudget"]
    for name in official:
        check(any(name in pdb for pdb in pdb_names), overlay, f"PDB for {name}", "PodDisruptionBudget present")

    netpols = [doc for doc in docs if doc.get("kind") == "NetworkPolicy"]
    netpol_names = [dig(doc, "metadata", "name") for doc in netpols]
    for name in ["default-deny-all", "allow-dns-egress", "allow-validation-ingress", "allow-validation-egress"]:
        check(name in netpol_names, overlay, f"NetworkPolicy {name}", "NetworkPolicy present")

    for name in official:
        has_selector = False
        for netpol in netpols:
            labels = dig(netpol, "spec", "podSelector", "matchLabels") or {}
            exprs = dig(netpol, "spec", "podSelector", "matchExpressions") or []
            if labels.get("app.kubernetes.io/name") == name:
                has_selector = True
                break
            if any(expr.get("key") == "app.kubernetes.io/name" and name in (expr.get("values") or []) for expr in exprs):
                has_selector = True
                break
        check(has_selector, overlay, f"NetworkPolicy selects {name}", f"podSelector covers {name}")

with open(report_file, "w", encoding="utf-8") as handle:
    handle.write("# Kubernetes Ultra Hardening Validation - SecureRAG Hub\n\n")
    handle.write("| Overlay | Control | Status | Evidence |\n")
    handle.write("|---|---|---:|---|\n")
    for overlay, control, status, evidence in rows:
        handle.write(f"| `{overlay}` | {control} | {status} | `{evidence}` |\n")
    handle.write("\n## Interpretation\n\n")
    if not failures:
        handle.write("Statut global: TERMINÉ for static Kubernetes hardening render checks.\n")
    else:
        handle.write("Statut global: FAIL. Correct the listed controls before declaring the overlay hardened.\n\n")
        for failure in failures:
            handle.write(f"- {failure}\n")

if not failures:
    print(f"[INFO] Kubernetes ultra hardening validation passed. Report: {report_file}")
else:
    print(f"[ERROR] Kubernetes ultra hardening validation failed. Report: {report_file}", file=sys.stderr)
    for failure in failures:
        print(f" - {failure}", file=sys.stderr)
    raise SystemExit(1)
PY
