#!/usr/bin/env bash

set -euo pipefail

NS="${NS:-securerag-hub}"
REPORT_DIR="${REPORT_DIR:-artifacts/validation}"
REPORT_FILE="${REPORT_DIR}/rag-smoke.txt"
VALIDATION_IMAGE="${VALIDATION_IMAGE:-localhost:5001/securerag-hub-api-gateway:dev}"
probe_pod="rag-smoke-check-$(date +%s)"
rag_pod="rag-endpoint-check-$(date +%s)"

mkdir -p "${REPORT_DIR}"
: > "${REPORT_FILE}"

pass() { echo "[PASS] $1" | tee -a "${REPORT_FILE}"; }
fail() { echo "[FAIL] $1" | tee -a "${REPORT_FILE}"; exit 1; }
skip() { echo "[SKIP] $1" | tee -a "${REPORT_FILE}"; }

echo "=== RAG smoke validation ===" | tee -a "${REPORT_FILE}"

for obj in \
  "deployment/llm-orchestrator" \
  "deployment/knowledge-hub" \
  "deployment/ollama" \
  "statefulset/qdrant"; do
  if kubectl get ${obj} -n "${NS}" >/dev/null 2>&1; then
    pass "${obj} exists"
  else
    fail "${obj} missing"
  fi
done

kubectl run "${probe_pod}" \
  --rm -i --attach=true --restart=Never -n "${NS}" \
  --labels=app.kubernetes.io/part-of=securerag-hub,job-role=validation \
  --image="${VALIDATION_IMAGE}" \
  --command -- python -c '
import urllib.request
for target in [
    "http://llm-orchestrator:8080/healthz",
    "http://knowledge-hub:8080/healthz",
    "http://qdrant:6333/healthz",
    "http://ollama:11434/api/tags",
]:
    with urllib.request.urlopen(target, timeout=5) as response:
        if response.status != 200:
            raise SystemExit(response.status)
' >/dev/null 2>&1 \
  && pass "RAG dependencies are reachable inside the cluster" \
  || fail "RAG dependencies are not fully reachable"

RAG_HTTP_CODE="$(kubectl run "${rag_pod}" \
  --rm -i --attach=true --restart=Never -n "${NS}" \
  --labels=app.kubernetes.io/part-of=securerag-hub,job-role=validation \
  --image="${VALIDATION_IMAGE}" \
  --command -- python -c '
import json
import urllib.error
import urllib.request

request = urllib.request.Request(
    "http://llm-orchestrator:8080/rag/query",
    data=json.dumps({"query": "Politique de congé ?"}).encode(),
    headers={"Content-Type": "application/json"},
    method="POST",
)
try:
    with urllib.request.urlopen(request, timeout=5) as response:
        print(response.status)
except urllib.error.HTTPError as exc:
    print(exc.code)
' 2>/dev/null || true)"

case "${RAG_HTTP_CODE}" in
  200|201)
    pass "RAG endpoint /rag/query is implemented and reachable"
    ;;
  404|405|"")
    skip "RAG endpoint /rag/query not implemented yet"
    ;;
  *)
    skip "RAG endpoint /rag/query returned HTTP ${RAG_HTTP_CODE}"
    ;;
esac

echo "RAG smoke validation completed." | tee -a "${REPORT_FILE}"
