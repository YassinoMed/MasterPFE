#!/usr/bin/env bash
# generate-dora-evidence.sh — Collects and consolidates evidence documents for pipelines
#
# Usage:
#   bash scripts/dora/generate-dora-evidence.sh

set -euo pipefail

EVIDENCE_DIR="evidence"
mkdir -p "${EVIDENCE_DIR}"

echo "[INFO] Starting DORA evidence collection..."

# 1. build-evidence.json
BUILD_NUM="${BUILD_NUMBER:-$(date +%s)}"
COMMIT_SHA="$(git rev-parse HEAD 2>/dev/null || echo "unknown")"
BRANCH_NAME="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")"
COMMIT_AUTHOR="$(git log -1 --format='%an <%ae>' 2>/dev/null || echo "unknown")"
TIMESTAMP="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

cat <<EOF > "${EVIDENCE_DIR}/build-evidence.json"
{
  "build_number": "${BUILD_NUM}",
  "commit_sha": "${COMMIT_SHA}",
  "branch": "${BRANCH_NAME}",
  "author": "${COMMIT_AUTHOR}",
  "timestamp": "${TIMESTAMP}"
}
EOF

# 2. security-evidence.json
TRIVY_FILE="security/reports/trivy-fs.json"
SEMGREP_FILE="security/reports/semgrep.json"
GITLEAKS_FILE="security/reports/gitleaks.json"
SBOM_DIR="artifacts/sbom"

trivy_issues=$(jq '[.Results[]?.Vulnerabilities[]?] | length' "${TRIVY_FILE}" 2>/dev/null || echo "0")
semgrep_issues=$(jq '.results | length' "${SEMGREP_FILE}" 2>/dev/null || echo "0")
gitleaks_issues=$(jq 'length' "${GITLEAKS_FILE}" 2>/dev/null || echo "0")

# Count Grype vulnerabilities
grype_issues=0
if [ -d "${SBOM_DIR}" ]; then
  for gf in "${SBOM_DIR}"/*.grype.json; do
    if [ -f "$gf" ]; then
      count=$(jq '.matches | length' "$gf" 2>/dev/null || echo "0")
      grype_issues=$((grype_issues + count))
    fi
  done
fi

sbom_files=()
if [ -d "${SBOM_DIR}" ]; then
  for sf in "${SBOM_DIR}"/*.cyclonedx.json; do
    if [ -f "$sf" ]; then
      sbom_files+=("$(basename "$sf")")
    fi
  done
fi

# Cosign check
cosign_signatures=()
if [ -d "artifacts/release" ]; then
  for sig in artifacts/release/*.sig; do
    if [ -f "$sig" ]; then
      cosign_signatures+=("$(basename "$sig")")
    fi
  done
fi

# SLSA Provenance check
slsa_provenance_present="false"
if [ -f "artifacts/release/provenance-statement.json" ] || [ -f "artifacts/release/release-evidence.json" ]; then
  slsa_provenance_present="true"
fi

cat <<EOF > "${EVIDENCE_DIR}/security-evidence.json"
{
  "trivy_fs_vulnerabilities": ${trivy_issues},
  "semgrep_sast_findings": ${semgrep_issues},
  "gitleaks_secret_findings": ${gitleaks_issues},
  "grype_dependency_vulnerabilities": ${grype_issues},
  "sbom_files": $(printf '%s\n' "${sbom_files[@]:-}" | jq -R . | jq -s . 2>/dev/null || echo "[]"),
  "cosign_signatures": $(printf '%s\n' "${cosign_signatures[@]:-}" | jq -R . | jq -s . 2>/dev/null || echo "[]"),
  "slsa_provenance_attestation_present": ${slsa_provenance_present}
}
EOF

# 3. deployment-evidence.json
NS="securerag-hub"
deployments=(
  "portal-web"
  "auth-users"
  "chatbot-manager"
  "conversation-service"
  "audit-security-service"
)

deployed_images=()
rollout_statuses=()
all_healthy="true"

for dep in "${deployments[@]}"; do
  if kubectl get deployment "${dep}" -n "${NS}" >/dev/null 2>&1; then
    img=$(kubectl get deployment "${dep}" -n "${NS}" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "unknown")
    
    # Try getting the imageID/digest from running pods
    pod_digest=$(kubectl get pods -n "${NS}" -l app.kubernetes.io/name="${dep}" -o jsonpath='{.items[0].status.containerStatuses[0].imageID}' 2>/dev/null || echo "unknown")
    
    deployed_images+=("{\"deployment\": \"${dep}\", \"image\": \"${img}\", \"digest\": \"${pod_digest}\"}")
    
    if kubectl rollout status deployment/"${dep}" -n "${NS}" --timeout=5s >/dev/null 2>&1; then
      rollout_statuses+=("{\"deployment\": \"${dep}\", \"status\": \"Success\"}")
    else
      rollout_statuses+=("{\"deployment\": \"${dep}\", \"status\": \"Failed/InProgress\"}")
      all_healthy="false"
    fi
  else
    deployed_images+=("{\"deployment\": \"${dep}\", \"image\": \"absent\", \"digest\": \"none\"}")
    rollout_statuses+=("{\"deployment\": \"${dep}\", \"status\": \"Absent\"}")
    all_healthy="false"
  fi
done

# Smoke test check
smoke_test_success="false"
if [ -f "reports/postdeploy/post-deploy-summary.json" ]; then
  smoke_test_success=$(jq '.status == "OK"' reports/postdeploy/post-deploy-summary.json 2>/dev/null || echo "false")
fi

cat <<EOF > "${EVIDENCE_DIR}/deployment-evidence.json"
{
  "namespace": "${NS}",
  "deployed_images": [$(IFS=,; echo "${deployed_images[*]}")],
  "rollout_status": [$(IFS=,; echo "${rollout_statuses[*]}")],
  "smoke_tests_passed": ${smoke_test_success},
  "overall_deployment_healthy": ${all_healthy}
}
EOF

# 4. compliance-evidence.json
kyverno_policies_count=$(kubectl get clusterpolicies -o json 2>/dev/null | jq '.items | length' || echo "0")
kyverno_violations=$(kubectl get policyreports -n "${NS}" -o json 2>/dev/null | jq '[.items[].summary.fail] | add' || echo "0")

pss_enforce=$(kubectl get ns "${NS}" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null || echo "none")
pss_audit=$(kubectl get ns "${NS}" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/audit}' 2>/dev/null || echo "none")

rbac_sa_count=$(kubectl get serviceaccounts -n "${NS}" -o json 2>/dev/null | jq '.items | length' || echo "0")
netpols_count=$(kubectl get networkpolicies -n "${NS}" -o json 2>/dev/null | jq '.items | length' || echo "0")
externalsecrets_count=$(kubectl get externalsecrets -n "${NS}" -o json 2>/dev/null | jq '.items | length' || echo "0")

cat <<EOF > "${EVIDENCE_DIR}/compliance-evidence.json"
{
  "kyverno_policies_count": ${kyverno_policies_count},
  "kyverno_violations_count": ${kyverno_violations},
  "pod_security_standards": {
    "enforce": "${pss_enforce}",
    "audit": "${pss_audit}"
  },
  "rbac_service_accounts_count": ${rbac_sa_count},
  "network_policies_count": ${netpols_count},
  "external_secrets_count": ${externalsecrets_count}
}
EOF

# 5. audit-evidence.json
git_history=$(git log -n 5 --oneline 2>/dev/null | jq -R . | jq -s . 2>/dev/null || echo "[]")
argocd_app_statuses=$(kubectl get applications -n argocd -o json 2>/dev/null | jq '[.items[] | {name: .metadata.name, sync: .status.sync.status, health: .status.health.status}]' || echo "[]")
k8s_events=$(kubectl get events -n "${NS}" --sort-by=.lastTimestamp -o json 2>/dev/null | jq '[.items[-10:] | .[]? | {time: .lastTimestamp, reason: .reason, message: .message}]' || echo "[]")

# Falco logs checks (count warnings in tail)
falco_warning_count=$(kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=1000 2>/dev/null | grep -ic "warning" || true)
falco_critical_count=$(kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=1000 2>/dev/null | grep -ic "critical" || true)

jenkins_build_url="${BUILD_URL:-http://localhost:8085/job/SecureRAG-Hub/${BUILD_NUM}/}"

cat <<EOF > "${EVIDENCE_DIR}/audit-evidence.json"
{
  "jenkins_build_url": "${jenkins_build_url}",
  "git_history_snippet": ${git_history},
  "argocd_apps_status": ${argocd_app_statuses},
  "kubernetes_recent_events": ${k8s_events},
  "falco_recent_log_warnings": ${falco_warning_count},
  "falco_recent_log_criticals": ${falco_critical_count}
}
EOF

# 6. pipeline-evidence.json
cat <<EOF > "${EVIDENCE_DIR}/pipeline-evidence.json"
{
  "build": $(cat "${EVIDENCE_DIR}/build-evidence.json"),
  "security": $(cat "${EVIDENCE_DIR}/security-evidence.json"),
  "deployment": $(cat "${EVIDENCE_DIR}/deployment-evidence.json"),
  "compliance": $(cat "${EVIDENCE_DIR}/compliance-evidence.json"),
  "audit": $(cat "${EVIDENCE_DIR}/audit-evidence.json")
}
EOF

# Generate Markdown Report
MD_REPORT="${EVIDENCE_DIR}/dora-evidence-consolidated.md"
{
  echo "# SecureRAG Hub - DORA Pipeline Evidence Report"
  echo
  echo "Generated at UTC: \`${TIMESTAMP}\`"
  echo "Pipeline Build: \`#${BUILD_NUM}\`"
  echo
  echo "## 1. Build Metadata"
  echo "| Key | Value |"
  echo "| --- | --- |"
  echo "| Git Commit | \`${COMMIT_SHA}\` |"
  echo "| Branch | \`${BRANCH_NAME}\` |"
  echo "| Author | ${COMMIT_AUTHOR} |"
  echo "| Date | ${TIMESTAMP} |"
  echo
  echo "## 2. Security Scans Summary"
  echo "| Scanner | Finding Count / Status |"
  echo "| --- | --- |"
  echo "| Trivy FS Vulnerabilities | ${trivy_issues} |"
  echo "| Semgrep SAST Findings | ${semgrep_issues} |"
  echo "| Gitleaks Secrets Findings | ${gitleaks_issues} |"
  echo "| Grype Dependency Vulnerabilities | ${grype_issues} |"
  echo "| Cosign Signed Images | $(jq '.cosign_signatures | length' "${EVIDENCE_DIR}/security-evidence.json") |"
  echo "| SLSA Provenance Attestation | ${slsa_provenance_present} |"
  echo
  echo "## 3. Deployment & Orchestration"
  echo "| Deployment | Image | Digest | Rollout Status |"
  echo "| --- | --- | --- | --- |"
  jq -r '.deployed_images[] | "| \(.deployment) | \(.image) | \(.digest) |"' "${EVIDENCE_DIR}/deployment-evidence.json" | while read -r line; do
    dep_name=$(echo "$line" | cut -d '|' -f 2 | xargs)
    status_msg=$(jq -r --arg dep "$dep_name" '.rollout_status[] | select(.deployment==$dep) | .status' "${EVIDENCE_DIR}/deployment-evidence.json")
    echo "$line ${status_msg} |"
  done
  echo
  echo "- Smoke Tests Status: **$(if [ "$smoke_test_success" = "true" ]; then echo "PASSED"; else echo "FAILED"; fi)**"
  echo "- Overall Deployment Health: **$(if [ "$all_healthy" = "true" ]; then echo "HEALTHY"; else echo "DEGRADED"; fi)**"
  echo
  echo "## 4. Compliance & Policy Enforcement"
  echo "- Kyverno Installed Policies: \`${kyverno_policies_count}\`"
  echo "- Kyverno Violations: \`${kyverno_violations}\`"
  echo "- Pod Security Standards (Namespace \`${NS}\`): Enforce=\`${pss_enforce}\` · Audit=\`${pss_audit}\`"
  echo "- NetworkPolicies Count: \`${netpols_count}\`"
  echo "- RBAC ServiceAccounts: \`${rbac_sa_count}\`"
  echo "- External Secrets Configured: \`${externalsecrets_count}\`"
  echo
  echo "## 5. Audit logs & Events"
  echo "- Jenkins Build Logs URL: [${jenkins_build_url}](${jenkins_build_url})"
  echo "- Falco Logs (Recent alerts in daemonset): Warnings=\`${falco_warning_count}\` · Criticals=\`${falco_critical_count}\`"
  echo
  echo "### ArgoCD Applications Sync"
  echo "| Application | Sync Status | Health Status |"
  echo "| --- | --- | --- |"
  jq -r '.argocd_apps_status[] | "| \(.name) | \(.sync) | \(.health) |"' "${EVIDENCE_DIR}/audit-evidence.json"
} > "${MD_REPORT}"

# Generate HTML Report
HTML_REPORT="${EVIDENCE_DIR}/dora-evidence-consolidated.html"
cat <<EOF > "${HTML_REPORT}"
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>DORA Pipeline Evidence - Build #${BUILD_NUM}</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; line-height: 1.6; max-width: 900px; margin: 40px auto; padding: 0 20px; color: #333; background: #fafafa; }
    h1, h2, h3 { color: #111; }
    table { width: 100%; border-collapse: collapse; margin: 20px 0; background: #fff; box-shadow: 0 1px 3px rgba(0,0,0,0.1); border-radius: 4px; overflow: hidden; }
    th, td { padding: 12px 15px; text-align: left; border-bottom: 1px solid #eee; }
    th { background-color: #0076ff; color: white; font-weight: 600; }
    tr:hover { background-color: #f5f5f5; }
    .badge { display: inline-block; padding: 4px 8px; border-radius: 4px; font-size: 12px; font-weight: bold; }
    .badge-success { background: #d4edda; color: #155724; }
    .badge-danger { background: #f8d7da; color: #721c24; }
    pre { background: #f4f4f4; padding: 15px; border-radius: 4px; overflow-x: auto; font-size: 13px; }
  </style>
</head>
<body>
  <h1>SecureRAG Hub - DORA Pipeline Evidence Report</h1>
  <p>Generated at: <strong>${TIMESTAMP}</strong> | Build Number: <strong>#${BUILD_NUM}</strong></p>
  
  <h2>1. Build Metadata</h2>
  <table>
    <tr><th>Metric</th><th>Value</th></tr>
    <tr><td>Git Commit</td><td><code>${COMMIT_SHA}</code></td></tr>
    <tr><td>Branch</td><td><code>${BRANCH_NAME}</code></td></tr>
    <tr><td>Author</td><td><code>${COMMIT_AUTHOR}</code></td></tr>
  </table>

  <h2>2. Security Scans Summary</h2>
  <table>
    <tr><th>Scanner</th><th>Finding Count</th></tr>
    <tr><td>Trivy FS Scan</td><td>${trivy_issues}</td></tr>
    <tr><td>Semgrep SAST</td><td>${semgrep_issues}</td></tr>
    <tr><td>Gitleaks Secrets</td><td>${gitleaks_issues}</td></tr>
    <tr><td>Grype Dependency Scan</td><td>${grype_issues}</td></tr>
    <tr><td>Cosign Signed Images</td><td>$(jq '.cosign_signatures | length' "${EVIDENCE_DIR}/security-evidence.json")</td></tr>
    <tr><td>SLSA Provenance</td><td>${slsa_provenance_present}</td></tr>
  </table>

  <h2>3. Deployment Status</h2>
  <table>
    <tr><th>Deployment</th><th>Status</th></tr>
    <tr><td>Overall Health</td><td><span class="badge $([ "$all_healthy" = "true" ] && echo "badge-success" || echo "badge-danger")">$([ "$all_healthy" = "true" ] && echo "Healthy" || echo "Degraded")</span></td></tr>
    <tr><td>Smoke Tests</td><td><span class="badge $([ "$smoke_test_success" = "true" ] && echo "badge-success" || echo "badge-danger")">$([ "$smoke_test_success" = "true" ] && echo "Passed" || echo "Failed")</span></td></tr>
  </table>

  <h2>4. Compliance & Policy</h2>
  <table>
    <tr><th>Control</th><th>Count / Value</th></tr>
    <tr><td>Kyverno Policies</td><td>${kyverno_policies_count}</td></tr>
    <tr><td>Kyverno Violations</td><td>${kyverno_violations}</td></tr>
    <tr><td>Pod Security Standard</td><td>Enforce: ${pss_enforce} | Audit: ${pss_audit}</td></tr>
    <tr><td>NetworkPolicies</td><td>${netpols_count}</td></tr>
  </table>

  <h2>5. Audit logs</h2>
  <p>Jenkins Build URL: <a href="${jenkins_build_url}">${jenkins_build_url}</a></p>
  <p>Falco alerts logged: Warnings=<strong>${falco_warning_count}</strong>, Criticals=<strong>${falco_critical_count}</strong></p>
</body>
</html>
EOF

echo "[OK] Consolidated evidence files generated in '${EVIDENCE_DIR}/'"
