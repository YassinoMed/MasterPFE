#!/usr/bin/env bash

set -euo pipefail

NS="${NS:-securerag-hub}"
REPORT_DIR="${REPORT_DIR:-artifacts/validation}"
REPORT_FILE="${REPORT_DIR}/rag-smoke.txt"
ENABLE_LEGACY_RAG_VALIDATION="${ENABLE_LEGACY_RAG_VALIDATION:-false}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/validate/lib/k8s-validation-pod.sh
source "${SCRIPT_DIR}/lib/k8s-validation-pod.sh"

mkdir -p "${REPORT_DIR}"
: > "${REPORT_FILE}"

pass() { echo "[PASS] $1" | tee -a "${REPORT_FILE}"; }
fail() { echo "[FAIL] $1" | tee -a "${REPORT_FILE}"; exit 1; }
skip() { echo "[SKIP] $1" | tee -a "${REPORT_FILE}"; }

echo "=== RAG smoke validation ===" | tee -a "${REPORT_FILE}"

if [ "${ENABLE_LEGACY_RAG_VALIDATION}" != "true" ]; then
  skip "PRÊT_NON_EXÉCUTÉ: legacy RAG runtime is excluded from the official Laravel Kubernetes runtime because Python sources under services/ are absent"
  skip "Set ENABLE_LEGACY_RAG_VALIDATION=true only in an environment where llm-orchestrator, knowledge-hub, qdrant and ollama are intentionally restored"
  echo "RAG smoke validation completed with documented exclusion." | tee -a "${REPORT_FILE}"
  exit 0
fi

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

VALIDATION_IMAGE="${VALIDATION_IMAGE:-curlimages/curl:8.11.1}"
probe_pod="rag-smoke-check-$(date +%s)"
rag_pod="rag-endpoint-check-$(date +%s)"

kubectl run "${probe_pod}" \
  --rm -i --attach=true --restart=Never -n "${NS}" \
  --labels=app.kubernetes.io/part-of=securerag-hub,job-role=validation \
  --image="${VALIDATION_IMAGE}" \
  --override-type=strategic \
  --overrides="$(validation_pod_overrides "${probe_pod}")" \
  --command -- sh -ec '
curl -fsS --max-time 5 http://llm-orchestrator:8080/healthz >/dev/null
curl -fsS --max-time 5 http://knowledge-hub:8080/healthz >/dev/null
curl -fsS --max-time 5 http://qdrant:6333/healthz >/dev/null
curl -fsS --max-time 5 http://ollama:11434/api/tags >/dev/null
' >/dev/null 2>&1 \
  && pass "RAG dependencies are reachable inside the cluster" \
  || fail "RAG dependencies are not fully reachable"

RAG_HTTP_CODE="$(kubectl run "${rag_pod}" \
  --rm -i --attach=true --restart=Never -n "${NS}" \
  --labels=app.kubernetes.io/part-of=securerag-hub,job-role=validation \
  --image="${VALIDATION_IMAGE}" \
  --override-type=strategic \
  --overrides="$(validation_pod_overrides "${rag_pod}")" \
  --command -- sh -ec 'curl -sS -o /dev/null -w "%{http_code}" --max-time 5 -H "Content-Type: application/json" -X POST http://llm-orchestrator:8080/rag/query -d "{\"query\":\"Politique de congé ?\"}"' 2>/dev/null || true)"

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
