#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="opensearch"
OPENSEARCH_URL="https://opensearch.${NAMESPACE}.svc:9200"

echo "=== Configuring SIEM Data Pipeline ==="

configure_falco_pipeline() {
  echo "Configuring Falco event forwarding to OpenSearch..."
  kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: falco-opensearch-config
  namespace: falco
data:
  falco-opensearch.yaml: |
    - name: opensearch
      opensearch:
        host: opensearch.${NAMESPACE}.svc
        port: 9200
        index: falco-events
        type: falco
        tls:
          verify: false
        username: admin
        password: admin
EOF
}

configure_tetragon_pipeline() {
  echo "Configuring Tetragon event forwarding to OpenSearch..."
  kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: tetragon-opensearch-config
  namespace: tetragon
data:
  tetragon-opensearch.yaml: |
    opensearch:
      url: "${OPENSEARCH_URL}"
      index: tetragon-events
      tls_insecure: true
      username: admin
      password: admin
EOF
}

configure_trivy_pipeline() {
  echo "Configuring Trivy report forwarding to OpenSearch..."
  kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: CronJob
metadata:
  name: trivy-to-opensearch
  namespace: trivy-system
spec:
  schedule: "0 */6 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: trivy-operator
          containers:
            - name: trivy-exporter
              image: bitnami/kubectl:latest
              command:
                - /bin/sh
                - -c
                - |
                  kubectl get vulnerabilityreports -A -o json | \
                  curl -s -k -X POST "${OPENSEARCH_URL}/trivy-reports/_doc" \
                    -H "Content-Type: application/json" \
                    -u admin:admin \
                    -d @-
          restartPolicy: OnFailure
EOF
}

configure_k8s_audit_pipeline() {
  echo "Configuring K8s audit log forwarding to OpenSearch..."
  kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluentbit-opensearch-config
  namespace: kube-system
data:
  fluentbit-opensearch.conf: |
    [INPUT]
        Name              tail
        Path              /var/log/kubernetes/audit/audit.log
        Parser            json
        Tag               k8s-audit
        Mem_Buf_Limit     50MB

    [OUTPUT]
        Name              opensearch
        Match             k8s-audit
        Host              opensearch.${NAMESPACE}.svc
        Port              9200
        Index             k8s-audit
        Type              _doc
        HTTP_User         admin
        HTTP_Passwd       admin
        tls               On
        tls.verify        Off
        Suppress_Type_Name On
EOF
}

configure_kyverno_pipeline() {
  echo "Configuring Kyverno admission forwarding to OpenSearch..."
  kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: kyverno-opensearch-config
  namespace: kyverno
data:
  kyverno-opensearch.yaml: |
    opensearch:
      url: "${OPENSEARCH_URL}"
      index: kyverno-admissions
      tls_insecure: true
      username: admin
      password: admin
EOF
}

configure_alertmanager_webhook() {
  echo "Configuring Alertmanager webhook to OpenSearch..."
  kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-opensearch-webhook
  namespace: securerag-monitoring
data:
  alertmanager-opensearch-webhook.yaml: |
    webhook:
      - name: opensearch-siem
        url: "https://opensearch-siem-webhook.${NAMESPACE}.svc:9200/alerts"
        send_resolved: true
EOF
}

create_dashboards() {
  echo "Creating OpenSearch Dashboards for each data source..."
  local indices=("falco-events" "tetragon-events" "trivy-reports" "k8s-audit" "kyverno-admissions" "runtime-events")
  for index in "${indices[@]}"; do
    kubectl exec -n "${NAMESPACE}" deploy/opensearch-dashboards -- \
      curl -s -k -X POST "${OPENSEARCH_URL}/.kibana/_doc/index-pattern:${index}" \
      -H "Content-Type: application/json" \
      -u admin:admin \
      -d '{"type":"index-pattern","index-pattern":{"title":"'"${index}"'-*","timeFieldName":"@timestamp"}}' || true
  done
}

configure_falco_pipeline
configure_tetragon_pipeline
configure_trivy_pipeline
configure_k8s_audit_pipeline
configure_kyverno_pipeline
configure_alertmanager_webhook
create_dashboards

echo "=== Data pipeline configuration complete ==="
