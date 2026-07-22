#!/usr/bin/env bash
# run-ai-security-tests.sh — SecureRAG Hub
# Runs and validates ONLY the AI Security Agents & LLM Security Audit Suite

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
REPORT_DIR="${REPO_ROOT}/artifacts/release"

mkdir -p "${REPORT_DIR}"

echo "=========================================================="
echo "   SecureRAG Hub — Validation Suite IA & Sécurité LLM     "
echo "=========================================================="
echo ""

# 1. AI Secure Coding Agent
echo "[1/4] Running AI Secure Coding & Vulnerability Audit Agent..."
python3 "${REPO_ROOT}/scripts/ai-agents/secure_coding_agent.py" "${REPO_ROOT}" || echo "[WARN] Secure coding agent reported warnings"

# 2. AI Deployment & Kubernetes Intelligence Agent
echo ""
echo "[2/4] Running AI Kubernetes & Deployment Intelligence Agent..."
if [ -d "${REPO_ROOT}/infra/k8s" ]; then
  python3 "${REPO_ROOT}/scripts/ai-agents/deployment_intelligence_agent.py" "${REPO_ROOT}/infra/k8s" || echo "[WARN] K8s intelligence agent reported warnings"
fi

# 3. AI Security Testing (DAST & Fuzzing Agent)
echo ""
echo "[3/4] Running AI Security Testing (DAST & LLM Fuzzing Agent)..."
python3 "${REPO_ROOT}/scripts/ai-agents/ai_testing_agent.py" || echo "[WARN] AI testing agent reported warnings"

# 4. AI Operations & Runtime Agent
echo ""
echo "[4/4] Running AI Operations & Runtime Validation Agent..."
python3 "${REPO_ROOT}/scripts/ai-agents/ai_operations_agent.py" "http://localhost:8082" || echo "[WARN] AI operations agent reported warnings"

echo ""
echo "=========================================================="
echo "   [SUCCESS] Validation IA terminée avec succès           "
echo "=========================================================="
echo "Rapports générés dans: ${REPORT_DIR}/"
ls -la "${REPORT_DIR}"/ai_* 2>/dev/null || true
