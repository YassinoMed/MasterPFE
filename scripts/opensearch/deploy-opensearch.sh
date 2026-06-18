#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUSTOMIZE_DIR="${SCRIPT_DIR}/../../infra/k8s/opensearch"
NAMESPACE="opensearch"
OPENSEARCH_SVC="opensearch.${NAMESPACE}.svc"
OPENSEARCH_URL="https://${OPENSEARCH_SVC}:9200"

echo "=== Deploying OpenSearch SIEM ==="

kubectl apply -k "${KUSTOMIZE_DIR}"

echo "Waiting for OpenSearch to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=opensearch -n "${NAMESPACE}" --timeout=300s

echo "Waiting for OpenSearch Dashboards to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=opensearch-dashboards -n "${NAMESPACE}" --timeout=300s

echo "Creating index templates..."
for template in falco-events tetragon-events trivy-reports k8s-audit kyverno-admissions runtime-events; do
  template_file="${KUSTOMIZE_DIR}/../templates/${template}-template.json"
  if [ -f "${template_file}" ]; then
    kubectl exec -n "${NAMESPACE}" deploy/opensearch -- \
      curl -s -k -u admin:admin \
      -X PUT "${OPENSEARCH_URL}/_index_template/${template}" \
      -H "Content-Type: application/json" \
      -d "@${template_file}" || echo "Warning: could not create template ${template}"
  fi
done

echo "Configuring ISM policies..."
kubectl exec -n "${NAMESPACE}" deploy/opensearch -- \
  curl -s -k -u admin:admin \
  -X PUT "${OPENSEARCH_URL}/_plugins/_ism/policies/security_events_30d" \
  -H "Content-Type: application/json" \
  -d '{
    "policy": {
      "description": "Retain security events for 30 days",
      "default_state": "hot",
      "states": [
        {
          "name": "hot",
          "actions": [],
          "transitions": [{"state_name": "delete", "conditions": {"min_index_age": "30d"}}]
        },
        {"name": "delete", "actions": [{"delete": {}}], "transitions": []}
      ]
    }
  }'

kubectl exec -n "${NAMESPACE}" deploy/opensearch -- \
  curl -s -k -u admin:admin \
  -X PUT "${OPENSEARCH_URL}/_plugins/_ism/policies/runtime_events_7d" \
  -H "Content-Type: application/json" \
  -d '{
    "policy": {
      "description": "Retain runtime events for 7 days",
      "default_state": "hot",
      "states": [
        {
          "name": "hot",
          "actions": [],
          "transitions": [{"state_name": "delete", "conditions": {"min_index_age": "7d"}}]
        },
        {"name": "delete", "actions": [{"delete": {}}], "transitions": []}
      ]
    }
  }'

echo "Creating initial indices..."
for index in falco-events tetragon-events trivy-reports k8s-audit kyverno-admissions runtime-events; do
  kubectl exec -n "${NAMESPACE}" deploy/opensearch -- \
    curl -s -k -u admin:admin \
    -X PUT "${OPENSEARCH_URL}/${index}-000001" \
    -H "Content-Type: application/json" \
    -d '{"aliases": {"'"${index}"'": {"is_write_index": true}}}' || true
done

echo "Validating deployment..."
kubectl exec -n "${NAMESPACE}" deploy/opensearch -- \
  curl -s -k -u admin:admin "${OPENSEARCH_URL}/_cluster/health" | python3 -m json.tool

kubectl exec -n "${NAMESPACE}" deploy/opensearch -- \
  curl -s -k -u admin:admin "${OPENSEARCH_URL}/_cat/indices?v"

echo "=== OpenSearch SIEM deployment complete ==="
echo "OpenSearch Dashboards: kubectl port-forward -n ${NAMESPACE} svc/opensearch-dashboards 5601:5601"
