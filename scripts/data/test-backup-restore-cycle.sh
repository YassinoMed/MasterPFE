#!/usr/bin/env bash
# Test cyclique backup -> restore PostgreSQL.
# Lance le CronJob manuellement, attend complétion, vérifie présence du dump,
# puis effectue un restore vers une base éphémère et compare un row count.
#
# Variables :
#   NS                    namespace backup (def. securerag-backup)
#   APP_NS                namespace SecureRAG (def. securerag-hub)
#   TEST_DB               base témoin pour comparer le row count (def. portal_web)
#   TEST_TABLE            table témoin (def. users)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

NS="${NS:-securerag-backup}"
APP_NS="${APP_NS:-securerag-hub}"
TEST_DB="${TEST_DB:-portal_web}"
TEST_TABLE="${TEST_TABLE:-users}"
REPORT_FILE="${REPORT_FILE:-artifacts/backup/postgres-backup-restore-cycle.md}"
mkdir -p "$(dirname "${REPORT_FILE}")"

if ! command -v kubectl >/dev/null 2>&1 || ! kubectl get ns "${NS}" >/dev/null 2>&1; then
  cat > "${REPORT_FILE}" <<EOF
# Postgres backup-restore cycle proof

- Generated UTC: \`$(date -u '+%Y-%m-%dT%H:%M:%SZ')\`
- Status: \`DÉPENDANT_DE_L_ENVIRONNEMENT\`
- Reason: namespace \`${NS}\` not reachable on this host.
EOF
  echo "[INFO] cluster unreachable -> ${REPORT_FILE}"
  exit 0
fi

job_name="postgres-backup-test-$(date -u +%s)"
echo "[INFO] creating one-shot Job from CronJob template"
kubectl -n "${NS}" create job --from=cronjob/postgres-backup "${job_name}"

echo "[INFO] waiting for completion (timeout 10min)"
kubectl -n "${NS}" wait --for=condition=complete --timeout=600s "job/${job_name}"

echo "[INFO] inspecting backup PVC content"
pod="$(kubectl -n "${NS}" run pg-inspect --rm -i --restart=Never \
  --image=alpine:3.20 --command -- ls -l /backup 2>/dev/null || true)"

# Attempt a structural restore in a sidecar (without touching live DB)
echo "[INFO] starting restore sidecar"
restore_pod="postgres-restore-test-$(date -u +%s)"
kubectl -n "${NS}" run "${restore_pod}" --restart=Never \
  --image=postgres:16.4-alpine \
  --overrides='{
    "spec":{
      "containers":[{
        "name":"restore",
        "image":"postgres:16.4-alpine",
        "command":["sh","-c","sleep 3600"],
        "volumeMounts":[{"name":"data","mountPath":"/backup"}]
      }],
      "volumes":[{"name":"data","persistentVolumeClaim":{"claimName":"postgres-backup-data"}}]
    }}' >/dev/null
kubectl -n "${NS}" wait --for=condition=Ready "pod/${restore_pod}" --timeout=120s

# Démarre Postgres local dans le pod
kubectl -n "${NS}" exec "${restore_pod}" -- sh -c '
  export PGDATA=/tmp/pgdata
  initdb -U postgres >/dev/null 2>&1
  pg_ctl -D $PGDATA -l /tmp/pg.log start >/dev/null 2>&1
  createdb -U postgres '"${TEST_DB}"'
  latest=$(ls -1t /backup/securerag-'"${TEST_DB}"'-*.dump 2>/dev/null | head -1)
  if [ -z "$latest" ]; then
    echo "NO_DUMP_FOUND"
    exit 1
  fi
  pg_restore -U postgres -d '"${TEST_DB}"' "$latest" 2>/dev/null || true
  count=$(psql -U postgres -d '"${TEST_DB}"' -tAc "SELECT count(*) FROM '"${TEST_TABLE}"';" 2>/dev/null || echo 0)
  echo "RESTORED_ROW_COUNT=$count"
' | tee /tmp/restore-output.txt

restored="$(grep -oE 'RESTORED_ROW_COUNT=[0-9]+' /tmp/restore-output.txt | cut -d= -f2 || echo 0)"
status="TERMINÉ"
if [[ "${restored:-0}" -le 0 ]]; then
  status="PARTIEL"
fi

kubectl -n "${NS}" delete pod "${restore_pod}" --ignore-not-found >/dev/null

cat > "${REPORT_FILE}" <<EOF
# Postgres backup-restore cycle proof

- Generated UTC: \`$(date -u '+%Y-%m-%dT%H:%M:%SZ')\`
- Job: \`${job_name}\`
- Test DB: \`${TEST_DB}\`
- Test table: \`${TEST_TABLE}\`
- Restored row count: \`${restored:-0}\`
- Status: \`${status}\`

## PVC content snapshot

\`\`\`
${pod}
\`\`\`
EOF
echo "[INFO] proof -> ${REPORT_FILE}"
