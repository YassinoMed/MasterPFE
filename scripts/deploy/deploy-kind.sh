#!/usr/bin/env bash

set -euo pipefail

command -v kubectl >/dev/null 2>&1 || { echo "kubectl is required"; exit 1; }

kubectl apply -k infra/k8s/overlays/dev
kubectl rollout status statefulset/qdrant -n securerag-hub --timeout=300s
kubectl rollout status deployment/ollama -n securerag-hub --timeout=300s
kubectl rollout status deployment/api-gateway -n securerag-hub --timeout=180s
kubectl rollout status deployment/auth-users -n securerag-hub --timeout=180s
kubectl rollout status deployment/chatbot-manager -n securerag-hub --timeout=180s
kubectl rollout status deployment/llm-orchestrator -n securerag-hub --timeout=180s
kubectl rollout status deployment/security-auditor -n securerag-hub --timeout=180s
kubectl rollout status deployment/knowledge-hub -n securerag-hub --timeout=180s
