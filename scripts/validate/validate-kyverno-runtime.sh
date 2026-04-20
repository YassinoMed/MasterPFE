#!/usr/bin/env bash

set -euo pipefail

NS="${NS:-securerag-hub}"
OUT_DIR="${OUT_DIR:-artifacts/validation}"
OUT_FILE="${OUT_FILE:-${OUT_DIR}/kyverno-runtime-report.md}"
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
  printf -- '- Supply chain attestation: `%s`\n\n' "${SUPPLY_CHAIN_ATTESTATION}"
  printf '| Component | Status | Evidence |\n'
  printf '|---|---:|---|\n'
} > "${OUT_FILE}"

if ! kubectl version --request-timeout=5s >/dev/null 2>&1; then
  row "Kubernetes API" "DÉPENDANT_DE_L_ENVIRONNEMENT" "API server unreachable"
  cat >> "${OUT_FILE}" <<'EOF'

## Diagnostic

Start kind or export a valid kubeconfig, install Kyverno Audit, then rerun:

```bash
make kyverno-runtime-proof
```
EOF
  warn "Kubernetes API unreachable. Kyverno runtime report written to ${OUT_FILE}"
  exit 0
fi

row "Kubernetes API" "TERMINÉ" "API server reachable"

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
  row "Kyverno CRDs" "DÉPENDANT_DE_L_ENVIRONNEMENT" "missing: ${missing_crds[*]}"
fi

if kubectl get namespace kyverno >/dev/null 2>&1; then
  row "Kyverno namespace" "TERMINÉ" "namespace/kyverno exists"
else
  row "Kyverno namespace" "DÉPENDANT_DE_L_ENVIRONNEMENT" "namespace/kyverno missing"
fi

if kyverno_deployments="$(kubectl get deploy -n kyverno --no-headers 2>/dev/null || true)" && [[ -n "${kyverno_deployments}" ]]; then
  not_ready="$(awk '$2 != $3 {print $1 "=" $2 "/" $3}' <<<"${kyverno_deployments}" | paste -sd ', ' - || true)"
  if [[ -z "${not_ready}" ]]; then
    row "Kyverno deployments" "TERMINÉ" "all Kyverno deployments are ready"
  else
    row "Kyverno deployments" "DÉPENDANT_DE_L_ENVIRONNEMENT" "not ready: ${not_ready}"
  fi
else
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
  row "Kyverno Audit policies" "PRÊT_NON_EXÉCUTÉ" "missing policies: ${missing_policies[*]}"
fi

policy_json="$(mktemp)"
cluster_policy_json="$(mktemp)"
attestation_summary="$(mktemp)"
trap 'rm -f "${policy_json}" "${cluster_policy_json}" "${attestation_summary}"' EXIT

kubectl get policyreport -A -o json > "${policy_json}" 2>/dev/null || printf '{"items":[]}\n' > "${policy_json}"
kubectl get clusterpolicyreport -A -o json > "${cluster_policy_json}" 2>/dev/null || printf '{"items":[]}\n' > "${cluster_policy_json}"

python3 - "${policy_json}" "${cluster_policy_json}" "${attestation_summary}" "${SUPPLY_CHAIN_ATTESTATION}" <<'PY'
import json
import pathlib
import sys

policy_path, cluster_policy_path, summary_path, attestation_path = sys.argv[1:]


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

if report_count > 0:
    policy_report_status = "TERMINÉ"
    policy_report_evidence = f"reports={report_count}; pass={pass_count}; warn={warn_count}; fail_or_error={fail_count}"
else:
    policy_report_status = "PRÊT_NON_EXÉCUTÉ"
    policy_report_evidence = "no PolicyReport returned yet; wait for Kyverno reports controller or generate workload events"

if report_count > 0 and fail_count == 0 and attestation_ready:
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

row "Kyverno PolicyReports" "${policy_report_status}" "${policy_report_evidence}"
row "Kyverno Enforce readiness" "${enforce_status}" "${enforce_evidence}"

capture "Kubernetes context" kubectl config current-context
capture "Kyverno CRDs" kubectl get crd clusterpolicies.kyverno.io policyreports.wgpolicyk8s.io clusterpolicyreports.wgpolicyk8s.io
capture "Kyverno deployments" kubectl get deploy -n kyverno -o wide
capture "Kyverno pods" kubectl get pods -n kyverno -o wide
capture "Kyverno policies" kubectl get clusterpolicy -o wide
capture "Kyverno policy reports" kubectl get policyreport,clusterpolicyreport -A

cat >> "${OUT_FILE}" <<'EOF'

## Enforce rule

`Enforce` must not be enabled automatically. It is acceptable only when:

- Kyverno CRDs, deployments and SecureRAG Audit policies are present.
- PolicyReports exist and contain no `fail` or `error` result.
- The supply-chain release attestation is `COMPLETE_PROVEN`.
- The deployed images are the same digests that were signed, verified and promoted.
EOF

info "Kyverno runtime report written to ${OUT_FILE}"
