#!/usr/bin/env bash
# Audit statique Pod Security strict (P0-10).
#
# Pour chaque deployment.yaml dans infra/k8s/base/*/ , vérifie la présence
# de TOUS les contrôles attendus. Échec si au moins un contrôle manque.
#
# Contrôles obligatoires :
#   pod.spec.securityContext.runAsNonRoot                = true
#   pod.spec.securityContext.runAsUser                   non-root (≥ 1)
#   pod.spec.securityContext.seccompProfile.type         = RuntimeDefault
#   pod.spec.automountServiceAccountToken                = false
#   each container.securityContext.allowPrivilegeEscalation = false
#   each container.securityContext.readOnlyRootFilesystem   = true
#   each container.securityContext.capabilities.drop        contains "ALL"
#   each container.resources.requests.{cpu,memory}          present
#   each container.resources.limits.{memory}                present (cpu opt)
#
# Sortie : artifacts/security/pod-security-audit.md (+ exit 1 si écarts)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT}"

REPORT="${REPORT:-artifacts/security/pod-security-audit.md}"
mkdir -p "$(dirname "${REPORT}")"

require() { command -v "$1" >/dev/null 2>&1 || { echo "[FAIL] missing $1" >&2; exit 2; }; }
require yq

failures=0
results=()

check_field() {
  local file="$1" path="$2" expected="$3"
  local actual
  actual=$(yq eval "${path}" "${file}" 2>/dev/null || echo "null")
  if [ "${actual}" = "${expected}" ]; then
    return 0
  fi
  echo "${actual}"
  return 1
}

audit_one() {
  local file="$1"
  local svc; svc=$(basename "$(dirname "${file}")")
  local issues=()

  # pod.spec.securityContext
  if ! check_field "${file}" '.spec.template.spec.securityContext.runAsNonRoot' 'true' >/dev/null; then
    issues+=("runAsNonRoot != true")
  fi
  local rau; rau=$(yq eval '.spec.template.spec.securityContext.runAsUser // 0' "${file}")
  if [ "${rau}" = "0" ] || [ "${rau}" = "null" ]; then
    issues+=("runAsUser missing or 0")
  fi
  if ! check_field "${file}" '.spec.template.spec.securityContext.seccompProfile.type' 'RuntimeDefault' >/dev/null; then
    issues+=("seccompProfile.type != RuntimeDefault")
  fi
  local amount; amount=$(yq eval '.spec.template.spec.automountServiceAccountToken // "missing"' "${file}")
  if [ "${amount}" != "false" ]; then
    issues+=("automountServiceAccountToken != false (got ${amount})")
  fi

  # per-container
  local n; n=$(yq eval '.spec.template.spec.containers | length' "${file}" 2>/dev/null || echo 0)
  for i in $(seq 0 $((n-1))); do
    local cname; cname=$(yq eval ".spec.template.spec.containers[${i}].name" "${file}")
    for path_pair in \
      ".spec.template.spec.containers[${i}].securityContext.allowPrivilegeEscalation|false" \
      ".spec.template.spec.containers[${i}].securityContext.readOnlyRootFilesystem|true" ; do
      IFS='|' read -r p exp <<<"${path_pair}"
      v=$(yq eval "${p} // \"missing\"" "${file}")
      if [ "${v}" != "${exp}" ]; then
        issues+=("${cname}: ${p##*.} != ${exp} (got ${v})")
      fi
    done
    # capabilities drop ALL
    has_all=$(yq eval ".spec.template.spec.containers[${i}].securityContext.capabilities.drop // [] | contains([\"ALL\"])" "${file}")
    if [ "${has_all}" != "true" ]; then
      issues+=("${cname}: capabilities.drop missing ALL")
    fi
    # resources
    for rkey in 'requests.cpu' 'requests.memory' 'limits.memory'; do
      v=$(yq eval ".spec.template.spec.containers[${i}].resources.${rkey} // \"missing\"" "${file}")
      if [ "${v}" = "missing" ] || [ "${v}" = "null" ]; then
        issues+=("${cname}: resources.${rkey} missing")
      fi
    done
  done

  if [ ${#issues[@]} -eq 0 ]; then
    results+=("OK|${svc}|-")
  else
    failures=$((failures + 1))
    local joined; joined=$(IFS='; '; printf '%s' "${issues[*]}")
    results+=("FAIL|${svc}|${joined}")
  fi
}

shopt -s nullglob
for f in infra/k8s/base/*/deployment.yaml; do
  audit_one "${f}"
done
shopt -u nullglob

verdict="TERMINÉ"
[ "${failures}" -gt 0 ] && verdict="PARTIEL"

{
  echo "# Pod Security Strict — Audit statique"
  echo
  echo "_Generated UTC: $(date -u '+%Y-%m-%dT%H:%M:%SZ')_  · Status: \`${verdict}\`"
  echo
  echo "Contrôles vérifiés : runAsNonRoot, runAsUser≠0, seccompProfile=RuntimeDefault,"
  echo "automountServiceAccountToken=false, allowPrivilegeEscalation=false,"
  echo "readOnlyRootFilesystem=true, capabilities.drop⊇[ALL], resources requests+limits."
  echo
  echo "| Result | Service | Issues |"
  echo "|:------:|---------|--------|"
  for r in "${results[@]}"; do
    IFS='|' read -r res svc issues <<< "${r}"
    icon="✅"; [ "${res}" = "FAIL" ] && icon="❌"
    printf '| %s %s | `%s` | %s |\n' "${icon}" "${res}" "${svc}" "${issues}"
  done
} > "${REPORT}"

echo "[INFO] Report: ${REPORT}"
[ "${failures}" -eq 0 ] || exit 1
