#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# run-cis-benchmark.sh — CIS Kubernetes Benchmark automatisé
# Exécute kube-bench, parse les résultats, génère un rapport Markdown.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

log()    { printf '[INFO]  %s\n' "$*"; }
warn()   { printf '[WARN]  %s\n' "$*"; }
fail()   { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REPORT_DIR="${PROJECT_ROOT}/artifacts/security"
KUBE_BENCH_IMAGE="aquasec/kube-bench:latest"
JOB_NAME="kube-bench-job"
JOB_NS="kube-system"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

mkdir -p "${REPORT_DIR}"

log "=========================================="
log "  CIS Kubernetes Benchmark - SecureRAG Hub"
log "  Date: ${TIMESTAMP}"
log "=========================================="

# ── Détection version Kubernetes ────────────────────────────────────────────
K8S_VERSION=$(kubectl version --short 2>/dev/null | grep "Server" | awk '{print $3}' || echo "unknown")
log "Kubernetes version detected: ${K8S_VERSION}"

# ── Nettoyage d'un éventuel job précédent ────────────────────────────────────
kubectl delete job "${JOB_NAME}" -n "${JOB_NS}" --ignore-not-found --wait=true 2>/dev/null || true

# ── Création du job kube-bench ──────────────────────────────────────────────
log "Creating kube-bench job..."
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: ${JOB_NAME}
  namespace: ${JOB_NS}
  labels:
    app: kube-bench
    benchmark: cis-k8s
    securerag-component: security-scanning
spec:
  backoffLimit: 2
  ttlSecondsAfterFinished: 3600
  template:
    metadata:
      labels:
        app: kube-bench
    spec:
      serviceAccountName: cis-benchmark
      hostPID: true
      containers:
        - name: kube-bench
          image: ${KUBE_BENCH_IMAGE}
          command:
            - kube-bench
            - --json
            - --version
            - "${K8S_VERSION}"
          volumeMounts:
            - name: var-lib-etcd
              mountPath: /var/lib/etcd
              readOnly: true
            - name: var-lib-kubelet
              mountPath: /var/lib/kubelet
              readOnly: true
            - name: etc-kubernetes
              mountPath: /etc/kubernetes
              readOnly: true
            - name: etc-systemd
              mountPath: /etc/systemd
              readOnly: true
            - name: usr-bin
              mountPath: /usr/local/mount-from-host/bin
              readOnly: true
      restartPolicy: Never
      volumes:
        - name: var-lib-etcd
          hostPath: { path: /var/lib/etcd }
        - name: var-lib-kubelet
          hostPath: { path: /var/lib/kubelet }
        - name: etc-kubernetes
          hostPath: { path: /etc/kubernetes }
        - name: etc-systemd
          hostPath: { path: /etc/systemd }
        - name: usr-bin
          hostPath: { path: /usr/bin }
EOF

# ── Attente de complétion ───────────────────────────────────────────────────
log "Waiting for kube-bench job to complete..."
if ! kubectl wait --for=condition=complete "job/${JOB_NAME}" -n "${JOB_NS}" --timeout=300s; then
  log "Job did not complete within timeout. Checking logs..."
  kubectl describe job "${JOB_NAME}" -n "${JOB_NS}"
  kubectl logs "job/${JOB_NAME}" -n "${JOB_NS}" --tail=50 || true
  fail "kube-bench job failed or timed out"
fi

# ── Extraction des résultats ────────────────────────────────────────────────
log "Extracting kube-bench results..."
kubectl logs "job/${JOB_NAME}" -n "${JOB_NS}" > "${REPORT_DIR}/kube-bench-raw.json"

# Vérifier que le JSON est valide
if ! python3 -m json.tool "${REPORT_DIR}/kube-bench-raw.json" > /dev/null 2>&1; then
  warn "Raw output is not valid JSON — attempting to extract JSON portion..."
  # Parfois kube-bench émet des logs avant le JSON
  python3 -c "
import json, sys
with open('${REPORT_DIR}/kube-bench-raw.json') as f:
    content = f.read()
# Trouver le premier crochet ouvrant
start = content.find('[')
if start >= 0:
    end = content.rfind(']') + 1
    json_str = content[start:end]
    with open('${REPORT_DIR}/kube-bench.json', 'w') as out:
        out.write(json.dumps(json.loads(json_str), indent=2))
    print('JSON extracted successfully')
else:
    print('No JSON found in output')
    sys.exit(1)
" || fail "Unable to extract valid JSON from kube-bench output"
else
  cp "${REPORT_DIR}/kube-bench-raw.json" "${REPORT_DIR}/kube-bench.json"
fi

log "Cleaning up kube-bench job..."
kubectl delete job "${JOB_NAME}" -n "${JOB_NS}" --ignore-not-found 2>/dev/null || true

# ── Génération du rapport Markdown ──────────────────────────────────────────
log "Generating CIS benchmark report..."
bash "${SCRIPT_DIR}/cis-report-parser.sh" \
  "${REPORT_DIR}/kube-bench.json" \
  "${REPORT_DIR}/cis-report.md"

# ── Vérification des échecs critiques ──────────────────────────────────────
log "Checking for critical failures..."
CRITICAL_COUNT=$(python3 -c "
import json
with open('${REPORT_DIR}/kube-bench.json') as f:
    data = json.load(f)
count = 0
for control in data if isinstance(data, list) else []:
    for test in control.get('checks', []):
        if test.get('status') == 'FAIL' and test.get('scored', True):
            count += 1
print(count)
" 2>/dev/null || echo "0")

if [ "${CRITICAL_COUNT}" -gt 0 ]; then
  warn "Found ${CRITICAL_COUNT} critical (FAIL) CIS checks!"
  grep "CRITICAL" "${REPORT_DIR}/cis-report.md" 2>/dev/null || true
fi

log "=== CIS Benchmark terminé ==="
echo ""
echo "  Rapport:     ${REPORT_DIR}/cis-report.md"
echo "  Données:     ${REPORT_DIR}/kube-bench.json"
echo "  Failures:    ${CRITICAL_COUNT}"
echo ""

if [ "${CRITICAL_COUNT}" -gt 0 ]; then
  fail "CIS Benchmark: ${CRITICAL_COUNT} critical failure(s) detected"
fi

log "CIS Benchmark passed — no critical failures"
