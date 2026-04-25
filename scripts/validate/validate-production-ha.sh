#!/usr/bin/env bash

set -euo pipefail

OVERLAY="${OVERLAY:-infra/k8s/overlays/production}"
REPORT_DIR="${REPORT_DIR:-artifacts/security}"
REPORT_FILE="${REPORT_FILE:-${REPORT_DIR}/production-ha-readiness.md}"

mkdir -p "${REPORT_DIR}"

for cmd in kubectl python3; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "[ERROR] Missing command: ${cmd}" >&2
    exit 2
  fi
done

if ! python3 - <<'PY' >/dev/null 2>&1
import yaml  # noqa: F401
PY
then
  echo "[ERROR] Missing Python module: yaml. Install python3-yaml or PyYAML." >&2
  exit 2
fi

rendered="$(mktemp)"
trap 'rm -f "${rendered}"' EXIT

kubectl kustomize "${OVERLAY}" > "${rendered}"

python3 - "${rendered}" "${REPORT_FILE}" "${OVERLAY}" <<'PY'
import datetime as dt
import sys

import yaml

rendered, report_file, overlay = sys.argv[1:]
official = {
    "portal-web": 3,
    "auth-users": 2,
    "chatbot-manager": 2,
    "conversation-service": 2,
    "audit-security-service": 2,
}


def dig(obj, *keys):
    for key in keys:
        if not isinstance(obj, dict):
            return None
        obj = obj.get(key)
    return obj


with open(rendered, encoding="utf-8") as handle:
    docs = [doc for doc in yaml.safe_load_all(handle) if isinstance(doc, dict)]

deployments = {dig(doc, "metadata", "name"): doc for doc in docs if doc.get("kind") == "Deployment"}
pdbs = {dig(doc, "metadata", "name"): doc for doc in docs if doc.get("kind") == "PodDisruptionBudget"}
hpas = {dig(doc, "metadata", "name"): doc for doc in docs if doc.get("kind") == "HorizontalPodAutoscaler"}

rows = []
failures = []


def check(component, control, ok, evidence):
    rows.append([component, control, "TERMINÉ" if ok else "FAIL", evidence])
    if not ok:
        failures.append(f"{component}: {control} -- {evidence}")


for name, min_replicas in official.items():
    dep = deployments.get(name)
    check(name, "Deployment rendered", dep is not None, f"Deployment {name}")
    if not dep:
        continue

    replicas = int(dig(dep, "spec", "replicas") or 0)
    check(name, f"replicas >= {min_replicas}", replicas >= min_replicas, f"replicas={replicas}")

    strategy = dig(dep, "spec", "strategy") or {}
    rolling = strategy.get("rollingUpdate") or {}
    check(name, "RollingUpdate enabled", strategy.get("type") == "RollingUpdate", f"strategy.type={strategy.get('type')}")
    check(name, "rolling maxUnavailable=0", str(rolling.get("maxUnavailable")) == "0", f"maxUnavailable={rolling.get('maxUnavailable')}")
    check(name, "rolling maxSurge=1", str(rolling.get("maxSurge")) == "1", f"maxSurge={rolling.get('maxSurge')}")
    check(name, "minReadySeconds configured", int(dig(dep, "spec", "minReadySeconds") or 0) >= 10, f"minReadySeconds={dig(dep, 'spec', 'minReadySeconds')}")

    pod_spec = dig(dep, "spec", "template", "spec") or {}
    affinity_terms = dig(pod_spec, "affinity", "podAntiAffinity", "preferredDuringSchedulingIgnoredDuringExecution") or []
    anti_affinity_ok = any(
        dig(term, "podAffinityTerm", "topologyKey") == "kubernetes.io/hostname"
        and dig(term, "podAffinityTerm", "labelSelector", "matchLabels", "app.kubernetes.io/name") == name
        for term in affinity_terms
    )
    check(name, "soft pod anti-affinity", anti_affinity_ok, "preferred anti-affinity on kubernetes.io/hostname")

    spread = pod_spec.get("topologySpreadConstraints") or []
    spread_ok = any(
        constraint.get("topologyKey") == "kubernetes.io/hostname"
        and dig(constraint, "labelSelector", "matchLabels", "app.kubernetes.io/name") == name
        for constraint in spread
    )
    check(name, "topology spread constraint", spread_ok, "topologyKey=kubernetes.io/hostname")

    containers = pod_spec.get("containers") or []
    for probe in ["readinessProbe", "livenessProbe", "startupProbe"]:
        has_probe = bool(containers) and all(probe in container for container in containers)
        check(name, probe, has_probe, f"all containers define {probe}")

    pdb = pdbs.get(f"{name}-pdb")
    check(name, "PDB rendered", pdb is not None, f"{name}-pdb")
    if pdb:
        min_available = int(dig(pdb, "spec", "minAvailable") or 0)
        expected_min = 2 if name == "portal-web" else 1
        check(name, "PDB minAvailable coherent", min_available >= expected_min and min_available < replicas, f"minAvailable={min_available}, replicas={replicas}")

    hpa = hpas.get(name)
    check(name, "HPA rendered", hpa is not None, f"HorizontalPodAutoscaler {name}")
    if hpa:
        hpa_min = int(dig(hpa, "spec", "minReplicas") or 0)
        hpa_max = int(dig(hpa, "spec", "maxReplicas") or 0)
        metrics = dig(hpa, "spec", "metrics") or []
        metric_names = [dig(metric, "resource", "name") for metric in metrics if dig(metric, "resource", "name")]
        check(name, "HPA minReplicas >= deployment floor", hpa_min >= min_replicas, f"minReplicas={hpa_min}")
        check(name, "HPA maxReplicas > minReplicas", hpa_max > hpa_min, f"maxReplicas={hpa_max}, minReplicas={hpa_min}")
        check(name, "HPA CPU and memory metrics", all(metric in metric_names for metric in ["cpu", "memory"]), f"metrics={','.join(metric_names)}")

generated = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
with open(report_file, "w", encoding="utf-8") as handle:
    handle.write("# Production HA Readiness - SecureRAG Hub\n\n")
    handle.write(f"- Overlay: `{overlay}`\n")
    handle.write(f"- Generated at UTC: `{generated}`\n\n")
    handle.write("| Component | Control | Status | Evidence |\n")
    handle.write("|---|---|---:|---|\n")
    for component, control, status, evidence in rows:
        handle.write(f"| `{component}` | {control} | {status} | `{evidence}` |\n")
    handle.write("\n## Interpretation\n\n")
    if not failures:
        handle.write("Statut global: TERMINÉ. L'overlay production rend les controles HA statiques attendus.\n")
    else:
        handle.write("Statut global: FAIL. Les controles suivants doivent etre corriges avant de presenter l'overlay comme pret HA :\n")
        for failure in failures:
            handle.write(f"- {failure}\n")
    handle.write("\n## Limite runtime\n\n")
    handle.write("Cette validation est statique. Les preuves runtime exigent un cluster actif, metrics-server et `kubectl get deploy,pods,pdb,hpa -n securerag-hub`.\n")

if not failures:
    print(f"[INFO] Production HA readiness validation passed. Report: {report_file}")
else:
    print(f"[ERROR] Production HA readiness validation failed. Report: {report_file}", file=sys.stderr)
    for failure in failures:
        print(f" - {failure}", file=sys.stderr)
    raise SystemExit(1)
PY
