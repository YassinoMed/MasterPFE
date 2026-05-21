#!/usr/bin/env bash
# Chaos lite (P1-18) — supprime un pod et prouve le self-heal Kubernetes
# pendant que le service reste disponible (HTTP 200 sur /health).
#
# Pré-requis : `curl`, `kubectl`, accès au service `portal-web` via port-forward
# ou ingress. Service par défaut : portal-web.
#
# Sortie : artifacts/validation/chaos-pod-delete-<ts>.md

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT}"

NS="${NS:-securerag-hub}"
APP="${APP:-portal-web}"
PROBE_URL="${PROBE_URL:-http://localhost:8000/health}"  # adapter selon port-forward
PROBE_INTERVAL="${PROBE_INTERVAL:-1}"
DURATION="${DURATION:-90}"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
REPORT="${REPORT:-artifacts/validation/chaos-pod-delete-${TS}.md}"
LOG="${REPORT%.md}.log"
mkdir -p "$(dirname "${REPORT}")"

require() { command -v "$1" >/dev/null 2>&1 || { echo "[FAIL] missing $1" >&2; exit 2; }; }
require kubectl
require curl

echo "[INFO] Chaos pod-delete on ${NS}/${APP} — probing ${PROBE_URL} every ${PROBE_INTERVAL}s for ${DURATION}s"

probe_total=0
probe_ok=0
probe_fail=0

# Probe loop in background
(
  end=$(( $(date +%s) + DURATION ))
  while [ "$(date +%s)" -lt "${end}" ]; do
    probe_total=$((probe_total+1))
    if curl -fsS --max-time 2 "${PROBE_URL}" >/dev/null 2>&1; then
      probe_ok=$((probe_ok+1))
      printf '[%s] %s OK\n' "$(date -u +%H:%M:%S)" "${PROBE_URL}"
    else
      probe_fail=$((probe_fail+1))
      printf '[%s] %s FAIL\n' "$(date -u +%H:%M:%S)" "${PROBE_URL}"
    fi
    sleep "${PROBE_INTERVAL}"
  done
  echo "PROBE_TOTAL=${probe_total}"
  echo "PROBE_OK=${probe_ok}"
  echo "PROBE_FAIL=${probe_fail}"
) > "${LOG}" 2>&1 &
PROBE_PID=$!

# Wait a bit, then delete a pod
sleep 5
echo "[INFO] picking pod"
pod=$(kubectl -n "${NS}" get pod -l app.kubernetes.io/name="${APP}" \
        -o jsonpath='{.items[0].metadata.name}')
[ -n "${pod}" ] || { echo "[FAIL] no pod found"; kill "${PROBE_PID}" || true; exit 2; }

t0=$(date +%s)
echo "[INFO] deleting pod ${pod}"
kubectl -n "${NS}" delete pod "${pod}" --grace-period=0 --force >/dev/null 2>&1 || true

# Wait until rollout is back up
kubectl -n "${NS}" rollout status deploy/"${APP}" --timeout=120s
t1=$(date +%s)
heal_secs=$((t1 - t0))

# Wait for probe loop to finish
wait "${PROBE_PID}" || true

# Parse probe results
total=$(grep '^PROBE_TOTAL=' "${LOG}" | tail -1 | cut -d= -f2)
ok=$(grep '^PROBE_OK='    "${LOG}" | tail -1 | cut -d= -f2)
fail=$(grep '^PROBE_FAIL=' "${LOG}" | tail -1 | cut -d= -f2)

verdict="PASS"
[ "${fail:-0}" -gt $(( ${total:-1} / 10 )) ] && verdict="DEGRADED"
[ "${heal_secs}" -gt 60 ] && verdict="DEGRADED"

{
  echo "# Chaos pod-delete drill — ${verdict}"
  echo
  echo "_Generated UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)_"
  echo
  echo "- Namespace        : \`${NS}\`"
  echo "- Workload deleted : \`${APP}\` (pod \`${pod}\`)"
  echo "- Self-heal time   : ${heal_secs}s (rollout status)"
  echo "- Probe URL        : \`${PROBE_URL}\`"
  echo "- Probe results    : ${ok:-0} OK / ${fail:-0} FAIL / ${total:-0} total"
  echo "- Verdict          : **${verdict}** (PASS si ≤ 10% probes en échec et heal ≤ 60s)"
  echo
  echo "Log détaillé : \`${LOG}\`"
} > "${REPORT}"

echo "[INFO] Verdict: ${verdict}  ·  Report: ${REPORT}"
[ "${verdict}" = "PASS" ]
