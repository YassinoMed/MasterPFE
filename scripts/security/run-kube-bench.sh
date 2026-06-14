#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# run-kube-bench.sh — Exécute CIS Kubernetes Benchmark via kube-bench
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

log()  { printf '[INFO]  %s\n' "$*"; }
fail() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

REPORT_DIR="security/reports"
mkdir -p "${REPORT_DIR}"

log "Starting CIS Kubernetes Benchmark (kube-bench)..."

kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: kube-bench
  namespace: kube-system
spec:
  template:
    metadata:
      labels:
        app: kube-bench
    spec:
      hostPID: true
      containers:
        - name: kube-bench
          image: aquasec/kube-bench:latest
          command: ["kube-bench", "--json"]
          volumeMounts:
            - name: var-lib-etcd
              mountPath: /var/lib/etcd
              readOnly: true
            - name: var-lib-kubelet
              mountPath: /var/lib/kubelet
              readOnly: true
            - name: etc-systemd
              mountPath: /etc/systemd
              readOnly: true
            - name: etc-kubernetes
              mountPath: /etc/kubernetes
              readOnly: true
            - name: usr-bin
              mountPath: /usr/local/mount-from-host/bin
              readOnly: true
      restartPolicy: Never
      volumes:
        - name: var-lib-etcd
          hostPath: { path: "/var/lib/etcd" }
        - name: var-lib-kubelet
          hostPath: { path: "/var/lib/kubelet" }
        - name: etc-systemd
          hostPath: { path: "/etc/systemd" }
        - name: etc-kubernetes
          hostPath: { path: "/etc/kubernetes" }
        - name: usr-bin
          hostPath: { path: "/usr/bin" }
EOF

log "Waiting for kube-bench job to complete..."
kubectl wait --for=condition=complete job/kube-bench -n kube-system --timeout=300s || fail "kube-bench job failed or timed out"

log "Extracting results..."
kubectl logs job/kube-bench -n kube-system > "${REPORT_DIR}/kube-bench.json"

log "Cleaning up..."
kubectl delete job kube-bench -n kube-system

log "CIS Benchmark completed. Results saved to ${REPORT_DIR}/kube-bench.json"
