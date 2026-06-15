#!/usr/bin/env bash
# File: infra/wazuh/active-response/isolate-pod.sh
# Description: Active response playbook triggered by Wazuh to isolate compromised pods in securerag-hub.
# Handles json parsing for pod name/namespace, labels the pod, and applies a dynamic deny-all NetworkPolicy.

set -euo pipefail

# Log active response execution
exec 3>&1 1>>/var/ossec/logs/active-responses.log 2>&1
echo "[$(date)] Active response triggered: isolate-pod.sh started."

# Read alert JSON from stdin
ALERT_JSON=$(cat -)

# Extract pod name, namespace, rule desc, and level
# Supports both jq-enabled and fallback shell parsing environments
if command -v jq >/dev/null 2>&1; then
  POD_NAME=$(echo "$ALERT_JSON" | jq -r '.parameters.alert.data.output_fields."k8s.pod.name" // .parameters.alert.data."k8s.pod.name" // empty')
  NAMESPACE=$(echo "$ALERT_JSON" | jq -r '.parameters.alert.data.output_fields."k8s.ns.name" // .parameters.alert.data."k8s.ns.name" // "securerag-hub"')
  RULE_DESC=$(echo "$ALERT_JSON" | jq -r '.parameters.alert.rule.description // "Suspicious runtime activity"')
  ALERT_LEVEL=$(echo "$ALERT_JSON" | jq -r '.parameters.alert.rule.level // "12"')
else
  # Grep fallbacks if jq is absent
  POD_NAME=$(echo "$ALERT_JSON" | grep -oP '"k8s.pod.name":"[^"]+"' | head -n1 | cut -d'"' -f4 || echo "")
  NAMESPACE=$(echo "$ALERT_JSON" | grep -oP '"k8s.ns.name":"[^"]+"' | head -n1 | cut -d'"' -f4 || echo "securerag-hub")
  RULE_DESC=$(echo "$ALERT_JSON" | grep -oP '"description":"[^"]+"' | head -n1 | cut -d'"' -f4 || echo "Suspicious runtime activity")
  ALERT_LEVEL=$(echo "$ALERT_JSON" | grep -oP '"level":[0-9]+' | head -n1 | cut -d':' -f2 || echo "12")
fi

if [ -z "$POD_NAME" ]; then
  echo "[ERROR] Could not extract pod name from alert JSON. Exiting." >&2
  exit 1
fi

echo "[INFO] Commencing isolation of pod '${POD_NAME}' in namespace '${NAMESPACE}' (Alert Level: ${ALERT_LEVEL})."

# Step 1: Label the pod to select it in the isolation network policy
kubectl label pod "${POD_NAME}" -n "${NAMESPACE}" "security.securerag.dev/isolated=${POD_NAME}" --overwrite

# Step 2: Apply the dynamic zero-trust NetworkPolicy targeting the isolated pod label
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: emergency-isolate-${POD_NAME}
  namespace: ${NAMESPACE}
spec:
  podSelector:
    matchLabels:
      security.securerag.dev/isolated: "${POD_NAME}"
  policyTypes:
    - Ingress
    - Egress
EOF

echo "[INFO] Network isolation policy 'emergency-isolate-${POD_NAME}' applied successfully."

# Step 3: Slack Notification Escalation
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/TXXXXX/BXXXXX/XXXXXXXX"
curl -s -X POST -H 'Content-type: application/json' --data "{
  \"text\": \"🚨 *EMERGENCY ISOLATION TRIGGERED* 🚨\n*Action:* Pod Isolated\n*Pod:* \`${POD_NAME}\`\n*Namespace:* \`${NAMESPACE}\`\n*Reason:* ${RULE_DESC} (Wazuh Rule Level ${ALERT_LEVEL})\"
}" "${SLACK_WEBHOOK_URL}" || echo "[WARN] Slack notification dispatch failed."

echo "[SUCCESS] Active response playbook execution complete."
