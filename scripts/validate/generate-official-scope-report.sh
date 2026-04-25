#!/usr/bin/env bash

set -euo pipefail

OUT="${OUT:-artifacts/final/official-scope-report.md}"
BASE_KUSTOMIZATION="${BASE_KUSTOMIZATION:-infra/k8s/base/kustomization.yaml}"
LEGACY_OVERLAY_README="${LEGACY_OVERLAY_README:-infra/k8s/overlays/legacy/README.md}"

official_workloads=(
  portal-web
  auth-users
  chatbot-manager
  conversation-service
  audit-security-service
)

legacy_workloads=(
  api-gateway
  knowledge-hub
  llm-orchestrator
  ollama
  qdrant
  security-auditor
)

mkdir -p "$(dirname "${OUT}")"

row() {
  local check="$1"
  local status="$2"
  local detail="$3"
  printf '| %s | %s | %s |\n' "${check}" "${status}" "${detail}" >> "${OUT}"
}

status="TERMINÉ"

{
  printf '# Official Scope Report - SecureRAG Hub\n\n'
  printf -- '- Generated at UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Status: `PENDING`\n\n'
  printf '## 1. Scope decision\n\n'
  printf 'The official production-like runtime is Laravel-first: portal, Laravel business services, DevSecOps/Kubernetes, security controls and archived evidence. Historical Python IA/RAG components remain legacy and are excluded from the official deployment graph until their sources, images, policies and runtime proofs are restored together.\n\n'
  printf '| Check | Status | Detail |\n'
  printf '|---|---:|---|\n'
} > "${OUT}"

if [[ ! -s "${BASE_KUSTOMIZATION}" ]]; then
  row "Base Kustomize graph" "PARTIEL" "\`${BASE_KUSTOMIZATION}\` missing"
  status="PARTIEL"
else
  missing_official=()
  for workload in "${official_workloads[@]}"; do
    if ! grep -Eq "^[[:space:]]*-[[:space:]]+${workload}/(deployment|service|serviceaccount|networkpolicy|pdb|hpa)\\.yaml" "${BASE_KUSTOMIZATION}"; then
      missing_official+=("${workload}")
    fi
  done

  if [[ "${#missing_official[@]}" -eq 0 ]]; then
    row "Official Laravel workloads" "TERMINÉ" "all five official workloads are referenced by \`${BASE_KUSTOMIZATION}\`"
  else
    row "Official Laravel workloads" "PARTIEL" "missing references: \`${missing_official[*]}\`"
    status="PARTIEL"
  fi

  legacy_found=()
  for workload in "${legacy_workloads[@]}"; do
    if grep -Eq "^[[:space:]]*-[[:space:]]+${workload}/" "${BASE_KUSTOMIZATION}"; then
      legacy_found+=("${workload}")
    fi
  done

  if [[ "${#legacy_found[@]}" -eq 0 ]]; then
    row "Legacy workloads excluded from official graph" "TERMINÉ" "no legacy workload is referenced by \`${BASE_KUSTOMIZATION}\`"
  else
    row "Legacy workloads excluded from official graph" "PARTIEL" "legacy references still present: \`${legacy_found[*]}\`"
    status="PARTIEL"
  fi
fi

if [[ -s "${LEGACY_OVERLAY_README}" ]] && grep -Fq 'does not provide a deployable `kustomization.yaml`' "${LEGACY_OVERLAY_README}"; then
  row "Legacy overlay guardrail" "TERMINÉ" "\`${LEGACY_OVERLAY_README}\` documents that legacy is intentionally non-deployable"
else
  row "Legacy overlay guardrail" "PARTIEL" "legacy overlay marker is missing or ambiguous"
  status="PARTIEL"
fi

if [[ -s scripts/validate/rag-smoke.sh ]] && grep -Fq 'ENABLE_LEGACY_RAG_VALIDATION' scripts/validate/rag-smoke.sh; then
  row "RAG validation opt-in" "TERMINÉ" "\`scripts/validate/rag-smoke.sh\` keeps legacy RAG checks opt-in"
else
  row "RAG validation opt-in" "PARTIEL" "legacy RAG validation opt-in guard is missing"
  status="PARTIEL"
fi

if [[ -s README.md ]] && grep -Fq 'Runtime Python legacy' README.md && grep -Fq 'docs/architecture/official-scope.md' README.md; then
  row "README scope disclosure" "TERMINÉ" "README links the official scope and marks Python/RAG as legacy"
else
  row "README scope disclosure" "PARTIEL" "README needs the official scope link and legacy status"
  status="PARTIEL"
fi

if [[ -s docs/architecture/official-scope.md ]]; then
  row "Architecture scope document" "TERMINÉ" "\`docs/architecture/official-scope.md\` present"
else
  row "Architecture scope document" "PARTIEL" "\`docs/architecture/official-scope.md\` missing"
  status="PARTIEL"
fi

{
  printf '\n## 2. Official runtime\n\n'
  for workload in "${official_workloads[@]}"; do
    printf -- '- `%s`\n' "${workload}"
  done

  printf '\n## 3. Legacy / non-official runtime\n\n'
  for workload in "${legacy_workloads[@]}"; do
    printf -- '- `%s`\n' "${workload}"
  done

  printf '\n## 4. Future evolution\n\n'
  printf 'A real RAG pipeline can be reintroduced as a separate evolution only after source code, Dockerfiles, Kustomize resources, NetworkPolicies, probes, resources, signatures, SBOMs, Kyverno policies and runtime evidence are restored as one coherent scope.\n'
} >> "${OUT}"

python3 - "${OUT}" "${status}" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
status = sys.argv[2]
text = path.read_text(encoding="utf-8")
path.write_text(text.replace("- Status: `PENDING`", f"- Status: `{status}`", 1), encoding="utf-8")
PY

printf '[INFO] Official scope report written to %s\n' "${OUT}"
