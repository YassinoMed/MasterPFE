#!/usr/bin/env bash
# Drill de rotation de secret en namespace isolé.
# Pas d'impact sur production. Sortie binaire PASS / FAIL pour CI.

set -euo pipefail

NS="${NS:-securerag-rotation-drill}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG="${ROOT}/artifacts/security/rotations/drill-$(date -u +%Y%m%dT%H%M%SZ).log"
mkdir -p "$(dirname "${LOG}")"

require() { command -v "$1" >/dev/null 2>&1 || { echo "[FAIL] missing $1" >&2; exit 2; }; }
require kubectl
require sops
require age
require openssl

cleanup() {
  kubectl delete ns "${NS}" --ignore-not-found --wait=false >/dev/null 2>&1 || true
}
trap cleanup EXIT

{
  echo "=== drill start $(date -u) ==="
  kubectl create ns "${NS}" --dry-run=client -o yaml | kubectl apply -f -
  echo "[OK] namespace ${NS} ready"

  PWD_OLD="$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 24)"
  PWD_NEW="$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 24)"
  echo "[OK] generated test passwords"

  # Apply initial secret (clear) -- represents pre-rotation state
  cat <<EOF | kubectl apply -n "${NS}" -f -
apiVersion: v1
kind: Secret
metadata:
  name: drill-secret
type: Opaque
stringData:
  PASSWORD: "${PWD_OLD}"
EOF
  echo "[OK] initial secret applied"

  # Spawn a tiny pod that reads the env var
  cat <<EOF | kubectl apply -n "${NS}" -f -
apiVersion: v1
kind: Pod
metadata:
  name: drill-consumer
spec:
  restartPolicy: Never
  containers:
    - name: c
      image: busybox:1.36
      command: ["sh","-c","echo \$PASSWORD; sleep 30"]
      env:
        - name: PASSWORD
          valueFrom:
            secretKeyRef: { name: drill-secret, key: PASSWORD }
EOF
  kubectl -n "${NS}" wait --for=condition=Ready pod/drill-consumer --timeout=30s
  got_old="$(kubectl -n "${NS}" logs drill-consumer | head -1)"
  if [ "${got_old}" != "${PWD_OLD}" ]; then
    echo "[FAIL] consumer did not see initial password"; exit 1
  fi
  echo "[OK] consumer sees old password"

  # Rotate (in real life this is sops re-encrypt + git push + argocd sync)
  kubectl -n "${NS}" patch secret drill-secret \
    --type=merge -p "{\"stringData\":{\"PASSWORD\":\"${PWD_NEW}\"}}"
  echo "[OK] secret rotated"

  # Trigger restart and verify the consumer reads the new value
  kubectl -n "${NS}" delete pod drill-consumer --grace-period=0 --force
  cat <<EOF | kubectl apply -n "${NS}" -f -
apiVersion: v1
kind: Pod
metadata:
  name: drill-consumer
spec:
  restartPolicy: Never
  containers:
    - name: c
      image: busybox:1.36
      command: ["sh","-c","echo \$PASSWORD; sleep 30"]
      env:
        - name: PASSWORD
          valueFrom:
            secretKeyRef: { name: drill-secret, key: PASSWORD }
EOF
  kubectl -n "${NS}" wait --for=condition=Ready pod/drill-consumer --timeout=30s
  got_new="$(kubectl -n "${NS}" logs drill-consumer | head -1)"
  if [ "${got_new}" != "${PWD_NEW}" ]; then
    echo "[FAIL] consumer did not pick up rotated password"; exit 1
  fi
  echo "[OK] consumer sees new password after rotation"

  echo "ROTATION_DRILL: PASS"
} 2>&1 | tee "${LOG}"
