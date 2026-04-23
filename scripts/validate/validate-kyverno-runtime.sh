#!/usr/bin/env bash

set -euo pipefail

NS="${NS:-securerag-hub}"
OUT_DIR="${OUT_DIR:-artifacts/validation}"
OUT_FILE="${OUT_FILE:-${OUT_DIR}/kyverno-runtime-report.md}"
BLOCKER_FILE="${BLOCKER_FILE:-${OUT_DIR}/kyverno-local-registry-enforce-blocker.md}"
SUPPLY_CHAIN_ATTESTATION="${SUPPLY_CHAIN_ATTESTATION:-artifacts/release/release-attestation.json}"
EXPECTED_POLICIES="${EXPECTED_POLICIES:-securerag-audit-cleartext-env-values,securerag-require-pod-security,securerag-require-workload-controls,securerag-restrict-image-references,securerag-restrict-service-exposure,securerag-restrict-volume-types,securerag-verify-cosign-images}"

mkdir -p "${OUT_DIR}"

info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
error() { printf '[ERROR] %s\n' "$*" >&2; }

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    error "Missing required command: $1"
    exit 2
  fi
}

capture() {
  local title="$1"
  shift

  {
    printf '\n## %s\n\n' "${title}"
    printf '```text\n'
    "$@" 2>&1 || true
    printf '```\n'
  } >> "${OUT_FILE}"
}

row() {
  local component="$1"
  local status="$2"
  local evidence="$3"

  printf '| %s | %s | %s |\n' "${component}" "${status}" "${evidence}" >> "${OUT_FILE}"
}

require_command kubectl
require_command python3

{
  printf '# Kyverno Runtime Report - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Namespace: `%s`\n' "${NS}"
  printf -- '- Supply chain attestation: `%s`\n' "${SUPPLY_CHAIN_ATTESTATION}"
  printf -- '- Status: `PENDING`\n\n'
  printf '| Component | Status | Evidence |\n'
  printf '|---|---:|---|\n'
} > "${OUT_FILE}"

if ! kubectl version --request-timeout=5s >/dev/null 2>&1; then
  row "Kubernetes API" "DÉPENDANT_DE_L_ENVIRONNEMENT" "API server unreachable"
  {
    printf '# Kyverno Cosign Enforce Local Registry Blocker

'
    printf -- '- Generated at UTC: `%s`
' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf -- '- Namespace: `%s`
' "${NS}"
    printf -- '- Affected policy: `securerag-verify-cosign-images`
'
    printf -- '- Status: `DÉPENDANT_DE_L_ENVIRONNEMENT`

'
    printf '## Finding

'
    printf 'The Kubernetes API is unreachable in the current environment, so Kyverno workload image references and `verifyImages` Enforce readiness cannot be proven.

'
    printf '## Decision

'
    printf 'Treat local-registry Enforce readiness as environment-dependent until a reachable cluster context is available and the runtime proof can inspect live Deployment image references.
'
  } > "${BLOCKER_FILE}"
  cat >> "${OUT_FILE}" <<'EOF'

## Diagnostic

Start kind or export a valid kubeconfig, install Kyverno Audit, then rerun:

```bash
make kyverno-runtime-proof
```
EOF
  python3 - "${OUT_FILE}" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
content = path.read_text(encoding="utf-8")
path.write_text(content.replace("- Status: `PENDING`", "- Status: `DÉPENDANT_DE_L_ENVIRONNEMENT`", 1), encoding="utf-8")
PY
  warn "Kubernetes API unreachable. Kyverno runtime report written to ${OUT_FILE}"
  exit 0
fi

row "Kubernetes API" "TERMINÉ" "API server reachable"
crds_ready=true
kyverno_namespace_ready=true
kyverno_deployments_ready=true
policies_ready=true
policy_reports_ready=false

required_crds=(
  clusterpolicies.kyverno.io
  policyreports.wgpolicyk8s.io
  clusterpolicyreports.wgpolicyk8s.io
)

missing_crds=()
for crd in "${required_crds[@]}"; do
  if ! kubectl get crd "${crd}" >/dev/null 2>&1; then
    missing_crds+=("${crd}")
  fi
done

if ((${#missing_crds[@]} == 0)); then
  row "Kyverno CRDs" "TERMINÉ" "required CRDs are present"
else
  crds_ready=false
  row "Kyverno CRDs" "DÉPENDANT_DE_L_ENVIRONNEMENT" "missing: ${missing_crds[*]}"
fi

if kubectl get namespace kyverno >/dev/null 2>&1; then
  row "Kyverno namespace" "TERMINÉ" "namespace/kyverno exists"
else
  kyverno_namespace_ready=false
  row "Kyverno namespace" "DÉPENDANT_DE_L_ENVIRONNEMENT" "namespace/kyverno missing"
fi

if kyverno_deployments="$(kubectl get deploy -n kyverno -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.readyReplicas}{"\t"}{.status.availableReplicas}{"\t"}{.spec.replicas}{"\n"}{end}' 2>/dev/null || true)" && [[ -n "${kyverno_deployments}" ]]; then
  not_ready="$(awk -F '\t' '
    {
      ready = ($2 == "" ? 0 : $2)
      available = ($3 == "" ? 0 : $3)
      desired = ($4 == "" ? 0 : $4)
      if (desired == 0 || ready != desired || available != desired) {
        print $1 "=" ready "/" available "/" desired
      }
    }
  ' <<<"${kyverno_deployments}" | paste -sd ', ' - || true)"
  if [[ -z "${not_ready}" ]]; then
    row "Kyverno deployments" "TERMINÉ" "all Kyverno deployments are ready"
  else
    kyverno_deployments_ready=false
    row "Kyverno deployments" "PARTIEL" "not ready: ${not_ready}"
  fi
else
  kyverno_deployments_ready=false
  row "Kyverno deployments" "DÉPENDANT_DE_L_ENVIRONNEMENT" "no Kyverno deployments returned"
fi

IFS=',' read -r -a expected_policy_array <<< "${EXPECTED_POLICIES}"
missing_policies=()
for policy in "${expected_policy_array[@]}"; do
  policy="${policy//[[:space:]]/}"
  [[ -z "${policy}" ]] && continue
  if ! kubectl get clusterpolicy "${policy}" >/dev/null 2>&1; then
    missing_policies+=("${policy}")
  fi
done

if ((${#missing_policies[@]} == 0)); then
  row "Kyverno Audit policies" "TERMINÉ" "all expected SecureRAG ClusterPolicies are present"
else
  policies_ready=false
  row "Kyverno Audit policies" "PRÊT_NON_EXÉCUTÉ" "missing policies: ${missing_policies[*]}"
fi

policy_json="$(mktemp)"
cluster_policy_json="$(mktemp)"
deployments_json="$(mktemp)"
attestation_summary="$(mktemp)"
trap 'rm -f "${policy_json}" "${cluster_policy_json}" "${deployments_json}" "${attestation_summary}"' EXIT

kubectl get policyreport -A -o json > "${policy_json}" 2>/dev/null || printf '{"items":[]}\n' > "${policy_json}"
kubectl get clusterpolicyreport -A -o json > "${cluster_policy_json}" 2>/dev/null || printf '{"items":[]}\n' > "${cluster_policy_json}"
kubectl get deploy -n "${NS}" -o json > "${deployments_json}" 2>/dev/null || printf '{"items":[]}\n' > "${deployments_json}"

python3 - "${policy_json}" "${cluster_policy_json}" "${deployments_json}" "${attestation_summary}" "${SUPPLY_CHAIN_ATTESTATION}" <<'PY'
import json
import pathlib
import sys

policy_path, cluster_policy_path, deployments_path, summary_path, attestation_path = sys.argv[1:]


def load_json(path):
    try:
        with open(path, encoding="utf-8") as handle:
            return json.load(handle)
    except Exception:
        return {"items": []}


def add_counts(target, result):
    status = str(result.get("result", "unknown")).lower()
    target[status] = target.get(status, 0) + 1


reports = []
for payload in (load_json(policy_path), load_json(cluster_policy_path)):
    reports.extend(payload.get("items") or [])

deployments = load_json(deployments_path).get("items") or []
local_registry_refs = []
for deployment in deployments:
    for container in (((deployment.get("spec") or {}).get("template") or {}).get("spec") or {}).get("containers", []) or []:
        image = str(container.get("image", ""))
        if image.startswith("localhost:") or image.startswith("127.0.0.1:") or image.startswith("0.0.0.0:"):
            local_registry_refs.append(image)

counts = {}
for report in reports:
    summary = report.get("summary") or {}
    if summary:
        for key, value in summary.items():
            counts[str(key).lower()] = counts.get(str(key).lower(), 0) + int(value or 0)
    else:
        for result in report.get("results") or []:
            add_counts(counts, result)

report_count = len(reports)
fail_count = counts.get("fail", 0) + counts.get("error", 0)
warn_count = counts.get("warn", 0)
pass_count = counts.get("pass", 0)
failed_results = []

for report in reports:
    scope = report.get("scope") or {}
    resource = "/".join(
        part for part in [str(scope.get("kind", "")).strip(), str(scope.get("name", "")).strip()] if part
    ) or report.get("metadata", {}).get("name", "unknown-scope")
    for result in report.get("results") or []:
        outcome = str(result.get("result", "")).lower()
        if outcome not in {"fail", "error"}:
            continue
        policy = str(result.get("policy", "unknown-policy"))
        rule = str(result.get("rule", "unknown-rule"))
        message = str(result.get("message", "")).strip()
        failed_results.append({
            "resource": resource,
            "policy": policy,
            "rule": rule,
            "message": message,
        })

attestation_ready = False
attestation_status = "MISSING"
attestation_file = pathlib.Path(attestation_path)
if attestation_file.is_file() and attestation_file.stat().st_size > 0:
    try:
        attestation = json.loads(attestation_file.read_text(encoding="utf-8"))
        attestation_status = str(attestation.get("status", "UNKNOWN"))
        claims = attestation.get("claims") or {}
        required = [
            "image_scan_passed",
            "sbom_generated",
            "sbom_attested",
            "cosign_signed",
            "cosign_verified",
            "digest_promoted",
            "no_rebuild_deploy_ready",
        ]
        attestation_ready = attestation_status == "COMPLETE_PROVEN" and all(claims.get(key) is True for key in required)
    except Exception as exc:
        attestation_status = f"INVALID:{exc}"

if report_count > 0 and fail_count == 0 and warn_count == 0:
    policy_report_status = "TERMINÉ"
    policy_report_evidence = f"reports={report_count}; pass={pass_count}; warn={warn_count}; fail_or_error={fail_count}"
elif report_count > 0:
    policy_report_status = "PARTIEL"
    policy_report_evidence = f"reports={report_count}; pass={pass_count}; warn={warn_count}; fail_or_error={fail_count}"
else:
    policy_report_status = "PRÊT_NON_EXÉCUTÉ"
    policy_report_evidence = "no PolicyReport returned yet; wait for Kyverno reports controller or generate workload events"

if local_registry_refs:
    enforce_status = "DÉPENDANT_DE_L_ENVIRONNEMENT"
    enforce_evidence = "local registry references used by workloads are not reachable from Kyverno pods for verifyImages Enforce"
elif report_count > 0 and fail_count == 0 and attestation_ready:
    enforce_status = "TERMINÉ"
    enforce_evidence = "Audit reports have no fail/error and supply-chain attestation is COMPLETE_PROVEN"
else:
    enforce_status = "PRÊT_NON_EXÉCUTÉ"
    blockers = []
    if report_count == 0:
        blockers.append("PolicyReports missing")
    if fail_count != 0:
        blockers.append(f"PolicyReports fail/error={fail_count}")
    if not attestation_ready:
        blockers.append(f"supply-chain attestation={attestation_status}")
    enforce_evidence = "; ".join(blockers) if blockers else "Enforce readiness not proven"

summary = {
    "policy_report_status": policy_report_status,
    "policy_report_evidence": policy_report_evidence,
    "enforce_status": enforce_status,
    "enforce_evidence": enforce_evidence,
    "report_count": report_count,
    "counts": counts,
    "attestation_status": attestation_status,
    "local_registry_blocker": bool(local_registry_refs),
    "local_registry_refs": sorted(set(local_registry_refs)),
    "failed_results": failed_results[:25],
}

pathlib.Path(summary_path).write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

policy_report_status="$(python3 - "${attestation_summary}" <<'PY'
import json, sys
print(json.load(open(sys.argv[1], encoding="utf-8"))["policy_report_status"])
PY
)"
policy_report_evidence="$(python3 - "${attestation_summary}" <<'PY'
import json, sys
print(json.load(open(sys.argv[1], encoding="utf-8"))["policy_report_evidence"])
PY
)"
enforce_status="$(python3 - "${attestation_summary}" <<'PY'
import json, sys
print(json.load(open(sys.argv[1], encoding="utf-8"))["enforce_status"])
PY
)"
enforce_evidence="$(python3 - "${attestation_summary}" <<'PY'
import json, sys
print(json.load(open(sys.argv[1], encoding="utf-8"))["enforce_evidence"])
PY
)"
local_registry_blocker="$(python3 - "${attestation_summary}" <<'PY'
import json, sys
print("true" if json.load(open(sys.argv[1], encoding="utf-8"))["local_registry_blocker"] else "false")
PY
)"
local_registry_refs="$(python3 - "${attestation_summary}" <<'PY'
import json, sys
refs = json.load(open(sys.argv[1], encoding="utf-8"))["local_registry_refs"]
print(", ".join(refs))
PY
)"
failed_results_detail="$(python3 - "${attestation_summary}" <<'PY'
import json, sys
failed = json.load(open(sys.argv[1], encoding="utf-8")).get("failed_results", [])
if not failed:
    print("")
else:
    for item in failed:
        message = item.get("message", "")
        if len(message) > 180:
            message = message[:177] + "..."
        print(f"{item['resource']}: {item['policy']}/{item['rule']} :: {message}")
PY
)"

row "Kyverno PolicyReports" "${policy_report_status}" "${policy_report_evidence}"
row "Kyverno Enforce readiness" "${enforce_status}" "${enforce_evidence}"
if [[ "${local_registry_blocker}" == "true" ]]; then
  row "Kyverno local registry Enforce blocker" "DÉPENDANT_DE_L_ENVIRONNEMENT" "${local_registry_refs}"
else
  row "Kyverno local registry Enforce blocker" "TERMINÉ" "No localhost/loopback image registry reference detected in current Deployments"
fi

if [[ "${policy_report_status}" == "TERMINÉ" ]]; then
  policy_reports_ready=true
fi

runtime_status="TERMINÉ"
if [[ "${crds_ready}" != "true" || "${kyverno_namespace_ready}" != "true" || "${kyverno_deployments_ready}" != "true" ]]; then
  runtime_status="DÉPENDANT_DE_L_ENVIRONNEMENT"
elif [[ "${policies_ready}" != "true" ]]; then
  runtime_status="PRÊT_NON_EXÉCUTÉ"
elif [[ "${policy_reports_ready}" != "true" ]]; then
  runtime_status="${policy_report_status}"
fi

{
  printf '# Kyverno Cosign Enforce Local Registry Blocker\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Namespace: `%s`\n' "${NS}"
  if [[ "${local_registry_blocker}" == "true" ]]; then
    printf -- '- Registry reference used by workloads: `%s`\n' "${local_registry_refs}"
    printf -- '- Affected policy: `securerag-verify-cosign-images`\n'
    printf -- '- Status: `DÉPENDANT_DE_L_ENVIRONNEMENT`\n\n'
    printf '## Finding\n\n'
    printf 'Kyverno admission runs inside the cluster. For workload images referenced with `localhost` or another loopback address, `verifyImages` Enforce cannot reach the same registry endpoint that is reachable from the host.\n\n'
    printf '## Decision\n\n'
    printf 'Keep `securerag-verify-cosign-images` in Audit for the local kind registry, and keep host-side Cosign verification and digest deploy as the blocking release gate.\n'
  else
    printf -- '- Affected policy: `securerag-verify-cosign-images`\n'
    printf -- '- Status: `TERMINÉ`\n\n'
    printf '## Finding\n\n'
    printf 'No loopback image registry reference was detected in the current SecureRAG workload Deployments.\n\n'
    printf '## Decision\n\n'
    printf 'No local-registry-specific Enforce blocker is currently detected from the workload image references.\n'
  fi
} > "${BLOCKER_FILE}"

capture "Kubernetes context" kubectl config current-context
capture "Kyverno CRDs" kubectl get crd clusterpolicies.kyverno.io policyreports.wgpolicyk8s.io clusterpolicyreports.wgpolicyk8s.io
capture "Kyverno deployments" kubectl get deploy -n kyverno -o wide
capture "Kyverno pods" kubectl get pods -n kyverno -o wide
capture "Kyverno policies" kubectl get clusterpolicy -o wide
capture "Kyverno policy reports" kubectl get policyreport,clusterpolicyreport -A
capture "SecureRAG deployment images" kubectl get deploy -n "${NS}" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .spec.template.spec.containers[*]}{.image}{" "}{end}{"\n"}{end}'

if [[ -n "${failed_results_detail}" ]]; then
  {
    printf '\n## Failing PolicyReport results\n\n'
    printf '```text\n%s\n```\n' "${failed_results_detail}"
  } >> "${OUT_FILE}"
fi

cat >> "${OUT_FILE}" <<'EOF'

## Enforce rule

`Enforce` must not be enabled automatically. It is acceptable only when:

- Kyverno CRDs, deployments and SecureRAG Audit policies are present.
- PolicyReports exist and contain no `fail` or `error` result.
- The supply-chain release attestation is `COMPLETE_PROVEN`.
- The deployed images are the same digests that were signed, verified and promoted.
- No loopback image registry reference such as `localhost:5001` is used by the workload images targeted by `verifyImages`.
EOF

python3 - "${OUT_FILE}" "${runtime_status}" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
status = sys.argv[2]
content = path.read_text(encoding="utf-8")
path.write_text(content.replace("- Status: `PENDING`", f"- Status: `{status}`", 1), encoding="utf-8")
PY

info "Kyverno runtime report written to ${OUT_FILE}"
