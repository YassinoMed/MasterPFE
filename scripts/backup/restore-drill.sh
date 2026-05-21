#!/usr/bin/env bash
# Restore drill PostgreSQL (P1-17) — sans toucher prod.
#
# Procédure :
#   1. crée un namespace isolé `pg-restore-drill-<ts>`
#   2. spawn une instance PG vierge
#   3. trouve le dernier snapshot Restic (`restic snapshots --tag pg --latest 1`)
#   4. télécharge + decompresse + psql -f
#   5. compte les rows d'une table connue (USERS_TABLE) — doit être > seuil
#   6. archive `artifacts/validation/restore-drill-<ts>.md` (PASS/FAIL)
#   7. cleanup namespace
#
# Usage :
#   bash scripts/backup/restore-drill.sh
#   USERS_TABLE=users MIN_ROWS=1 bash scripts/backup/restore-drill.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT}"

TS="$(date -u +%Y%m%dT%H%M%SZ)"
NS="pg-restore-drill-${TS,,}"
NS="${NS//[^a-z0-9-]/}"   # sanitize
USERS_TABLE="${USERS_TABLE:-users}"
MIN_ROWS="${MIN_ROWS:-1}"
REPORT="${REPORT:-artifacts/validation/restore-drill-${TS}.md}"
mkdir -p "$(dirname "${REPORT}")"

require() { command -v "$1" >/dev/null 2>&1 || { echo "[FAIL] missing $1" >&2; exit 2; }; }
require kubectl

cleanup() {
  echo "[CLEANUP] kubectl delete ns ${NS}"
  kubectl delete ns "${NS}" --ignore-not-found --wait=false >/dev/null 2>&1 || true
}
trap cleanup EXIT

verdict="FAIL"
detail=""

{
  echo "[INFO] Drill ${TS} — namespace ${NS}"
  kubectl create ns "${NS}" --dry-run=client -o yaml | kubectl apply -f -

  # Throwaway PG instance (ephemeral, no PV)
  cat <<EOF | kubectl apply -n "${NS}" -f -
apiVersion: v1
kind: Pod
metadata:
  name: pg-target
  labels: { app: pg-target }
spec:
  restartPolicy: Never
  securityContext:
    runAsNonRoot: true
    runAsUser: 999
    fsGroup: 999
    seccompProfile: { type: RuntimeDefault }
  containers:
    - name: pg
      image: postgres:16.3-alpine
      env:
        - { name: POSTGRES_PASSWORD, value: drill }
        - { name: POSTGRES_DB,       value: drill }
      ports: [ { containerPort: 5432 } ]
      readinessProbe:
        exec:
          command: ["pg_isready", "-U", "postgres"]
        initialDelaySeconds: 5
        periodSeconds: 3
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: false   # PG requires writable data dir; tmpfs in real prod
        capabilities: { drop: ["ALL"] }
EOF
  kubectl -n "${NS}" wait --for=condition=Ready pod/pg-target --timeout=120s

  # Spawn restorer pod that has restic + psql
  cat <<EOF | kubectl apply -n "${NS}" -f -
apiVersion: v1
kind: Pod
metadata:
  name: pg-restorer
spec:
  restartPolicy: Never
  serviceAccountName: default
  automountServiceAccountToken: false
  securityContext:
    runAsNonRoot: true
    runAsUser: 65532
    seccompProfile: { type: RuntimeDefault }
  containers:
    - name: r
      image: ghcr.io/example/securerag-pg-restic:1.0.0
      command: ["sh","-c","sleep 600"]
      env:
        - name: PGHOST
          value: pg-target.${NS}.svc.cluster.local
        - name: PGPORT
          value: "5432"
        - name: PGUSER
          value: postgres
        - name: PGPASSWORD
          value: drill
        - name: PGDATABASE
          value: drill
        - name: RESTIC_REPOSITORY
          valueFrom: { secretKeyRef: { name: pg-backup-secrets, key: RESTIC_REPOSITORY } }
        - name: RESTIC_PASSWORD
          valueFrom: { secretKeyRef: { name: pg-backup-secrets, key: RESTIC_PASSWORD } }
        - name: AWS_ACCESS_KEY_ID
          valueFrom: { secretKeyRef: { name: pg-backup-secrets, key: AWS_ACCESS_KEY_ID } }
        - name: AWS_SECRET_ACCESS_KEY
          valueFrom: { secretKeyRef: { name: pg-backup-secrets, key: AWS_SECRET_ACCESS_KEY } }
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities: { drop: ["ALL"] }
      volumeMounts:
        - { name: tmp, mountPath: /tmp }
  volumes:
    - { name: tmp, emptyDir: { sizeLimit: 4Gi } }
EOF
  # NOTE: pg-backup-secrets must exist in NS. The drill copies it.
  if kubectl -n securerag-hub get secret pg-backup-secrets >/dev/null 2>&1; then
    kubectl -n securerag-hub get secret pg-backup-secrets -o yaml \
      | sed -e "s/namespace: securerag-hub/namespace: ${NS}/" \
      | kubectl apply -f -
  fi

  kubectl -n "${NS}" wait --for=condition=Ready pod/pg-restorer --timeout=60s

  # Run the restore
  kubectl -n "${NS}" exec pg-restorer -- sh -c '
    set -euo pipefail
    cd /tmp
    restic snapshots --tag pg --latest 1 --json > snap.json
    snap_id=$(jq -r ".[0].short_id" snap.json)
    echo "[INFO] restoring snapshot ${snap_id}"
    restic restore "${snap_id}" --target /tmp/restore
    dump=$(find /tmp/restore -name "dump-*.sql.gz" | head -1)
    [ -n "${dump}" ] || { echo "no dump found"; exit 1; }
    echo "[INFO] applying ${dump}"
    gunzip -c "${dump}" | psql -v ON_ERROR_STOP=1 -q -f -
    echo "RESTORE_OK"
  ' || {
    detail="restore command failed"
    verdict="FAIL"
    echo "[FAIL] ${detail}"
    return 1 || true
  }

  # Verify a known table
  rows=$(kubectl -n "${NS}" exec pg-target -- psql -U postgres -d drill -tAc "SELECT count(*) FROM ${USERS_TABLE};" 2>/dev/null || echo "0")
  rows=$(echo "${rows}" | tr -d '[:space:]')
  if [ "${rows:-0}" -ge "${MIN_ROWS}" ]; then
    verdict="PASS"
    detail="${USERS_TABLE} rows=${rows}"
  else
    verdict="FAIL"
    detail="${USERS_TABLE} rows=${rows} < MIN_ROWS=${MIN_ROWS}"
  fi
} 2>&1 | tee -a "${REPORT}.log"

{
  echo "# Restore drill — ${verdict}"
  echo
  echo "_Generated UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)_"
  echo
  echo "- Namespace : \`${NS}\`"
  echo "- Detail    : ${detail}"
  echo "- Log       : \`${REPORT}.log\`"
} > "${REPORT}"

echo "[INFO] Verdict: ${verdict}"
[ "${verdict}" = "PASS" ]
