#!/usr/bin/env bash
# Tests d'admission Kyverno Enforce, pré-bascule.
#
# Pour chaque ClusterPolicy, on tente :
#   1. un manifeste conforme   -> doit être ADMIS
#   2. un manifeste violant    -> doit être REJETÉ
#
# Si toutes les paires passent, on autorise la bascule Audit -> Enforce via le
# script wrapper. Sinon on garde Audit et on archive les écarts.
#
# Sortie : artifacts/security/kyverno-admission-tests.md

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

NS="${NS:-kyverno-admission-test}"
REPORT_FILE="${REPORT_FILE:-artifacts/security/kyverno-admission-tests.md}"
mkdir -p "$(dirname "${REPORT_FILE}")"

if ! command -v kubectl >/dev/null 2>&1 || ! kubectl get crd clusterpolicies.kyverno.io >/dev/null 2>&1; then
  cat > "${REPORT_FILE}" <<EOF
# Kyverno admission tests — SecureRAG Hub

- Generated UTC: \`$(date -u '+%Y-%m-%dT%H:%M:%SZ')\`
- Status: \`DÉPENDANT_DE_L_ENVIRONNEMENT\`
- Reason: Kyverno controller (CRD clusterpolicies.kyverno.io) not present.
EOF
  echo "[INFO] kyverno absent -> ${REPORT_FILE}"
  exit 0
fi

kubectl create namespace "${NS}" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
trap 'kubectl delete namespace "${NS}" --ignore-not-found --wait=false >/dev/null 2>&1 || true' EXIT

PASS=()
FAIL=()

apply_expect_admit() {
  local name="$1" manifest="$2"
  if echo "${manifest}" | kubectl apply -n "${NS}" -f - >/dev/null 2>&1; then
    PASS+=("ADMIT/${name}")
    echo "${manifest}" | kubectl delete -n "${NS}" -f - --ignore-not-found >/dev/null 2>&1 || true
  else
    FAIL+=("ADMIT/${name} — expected admit, was rejected")
  fi
}

apply_expect_reject() {
  local name="$1" manifest="$2"
  if echo "${manifest}" | kubectl apply -n "${NS}" -f - >/dev/null 2>&1; then
    FAIL+=("REJECT/${name} — expected reject, was admitted")
    echo "${manifest}" | kubectl delete -n "${NS}" -f - --ignore-not-found >/dev/null 2>&1 || true
  else
    PASS+=("REJECT/${name}")
  fi
}

# Cas 1 — Pod restreint conforme (PSA restricted)
read -r -d '' OK_POD <<'YAML' || true
apiVersion: v1
kind: Pod
metadata:
  name: ok-pod
spec:
  securityContext:
    runAsNonRoot: true
    seccompProfile: { type: RuntimeDefault }
  containers:
    - name: app
      image: registry.k8s.io/pause:3.9
      securityContext:
        allowPrivilegeEscalation: false
        runAsNonRoot: true
        runAsUser: 1000
        capabilities: { drop: [ALL] }
YAML
apply_expect_admit "compliant-pod" "${OK_POD}"

# Cas 2 — Pod hostPath interdit (restrict-volume-types)
read -r -d '' BAD_HOSTPATH <<'YAML' || true
apiVersion: v1
kind: Pod
metadata:
  name: bad-hostpath
spec:
  securityContext: { runAsNonRoot: true, seccompProfile: { type: RuntimeDefault } }
  containers:
    - name: app
      image: registry.k8s.io/pause:3.9
      securityContext: { allowPrivilegeEscalation: false, runAsNonRoot: true, runAsUser: 1000, capabilities: { drop: [ALL] } }
      volumeMounts: [{ name: host, mountPath: /host }]
  volumes:
    - name: host
      hostPath: { path: /etc }
YAML
apply_expect_reject "hostpath-volume" "${BAD_HOSTPATH}"

# Cas 3 — Pod privileged (require-pod-security)
read -r -d '' BAD_PRIV <<'YAML' || true
apiVersion: v1
kind: Pod
metadata:
  name: bad-priv
spec:
  containers:
    - name: app
      image: registry.k8s.io/pause:3.9
      securityContext:
        privileged: true
YAML
apply_expect_reject "privileged-container" "${BAD_PRIV}"

# Cas 4 — Pod sans resources (require-workload-controls)
read -r -d '' BAD_NORES <<'YAML' || true
apiVersion: v1
kind: Pod
metadata:
  name: bad-nores
spec:
  securityContext: { runAsNonRoot: true, seccompProfile: { type: RuntimeDefault } }
  containers:
    - name: app
      image: registry.k8s.io/pause:3.9
      securityContext: { allowPrivilegeEscalation: false, runAsNonRoot: true, runAsUser: 1000, capabilities: { drop: [ALL] } }
YAML
apply_expect_reject "missing-resources" "${BAD_NORES}"

# Cas 5 — Service de type LoadBalancer (restrict-service-exposure)
read -r -d '' BAD_LB <<'YAML' || true
apiVersion: v1
kind: Service
metadata:
  name: bad-lb
spec:
  type: LoadBalancer
  selector: { app: ok-pod }
  ports: [{ port: 80, targetPort: 80 }]
YAML
apply_expect_reject "loadbalancer-service" "${BAD_LB}"

# Cas 6 — Pod cleartext env (audit-cleartext-env-values)
read -r -d '' BAD_CLEAR <<'YAML' || true
apiVersion: v1
kind: Pod
metadata:
  name: bad-cleartext
spec:
  securityContext: { runAsNonRoot: true, seccompProfile: { type: RuntimeDefault } }
  containers:
    - name: app
      image: registry.k8s.io/pause:3.9
      securityContext: { allowPrivilegeEscalation: false, runAsNonRoot: true, runAsUser: 1000, capabilities: { drop: [ALL] } }
      resources: { requests: { cpu: 10m, memory: 16Mi }, limits: { cpu: 50m, memory: 64Mi } }
      env:
        - { name: DB_PASSWORD, value: "supersecret123" }
YAML
apply_expect_reject "cleartext-secret" "${BAD_CLEAR}"

status="TERMINÉ"
if (( ${#FAIL[@]} > 0 )); then status="PARTIEL"; fi

{
  printf '# Kyverno admission tests — SecureRAG Hub\n\n'
  printf -- '- Generated UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Status: `%s`\n' "${status}"
  printf -- '- Pass: `%d`  Fail: `%d`\n\n' "${#PASS[@]}" "${#FAIL[@]}"
  printf '## PASS\n\n'
  for p in "${PASS[@]}"; do printf -- '- %s\n' "${p}"; done
  printf '\n## FAIL\n\n'
  if ((${#FAIL[@]} == 0)); then printf -- '- (none)\n'; else for f in "${FAIL[@]}"; do printf -- '- %s\n' "${f}"; done; fi
} > "${REPORT_FILE}"

echo "[INFO] admission tests -> ${REPORT_FILE}"
[[ "${status}" == "TERMINÉ" ]] || exit 1
