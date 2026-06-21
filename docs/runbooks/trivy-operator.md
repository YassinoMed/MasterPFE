# Trivy Operator Runbook — Vulnerability Scanning Operations

**Component:** Trivy Operator  
**Namespace:** `trivy-system`  
**CRDs:** `vulnerabilityreport`, `configauditreport`, `clustercompliancereport`, `clusterrbacassessment`  
**Version:** 0.54.x

---

## 1. Viewing Vulnerability Reports

### List All Reports

```bash
# List all vulnerability reports across all namespaces
kubectl get vulnerabilityreport -A

# Output:
# NAMESPACE       NAME                                   REPOSITORY                                         TAG      SCANNER   AGE
# securerag-hub   portal-web-v1-2-3                      registry.example.com/portal-web                    v1.2.3   Trivy     2d
# securerag-hub   auth-users-v2-0-1                      registry.example.com/auth-users                    v2.0.1   Trivy     1d
# monitoring      prometheus-server-v2-53-0               quay.io/prometheus/prometheus                      v2.53.0  Trivy     5h

# Filter by namespace
kubectl get vulnerabilityreport -n securerag-hub

# Filter by severity count
kubectl get vulnerabilityreport -A -o json | \
  jq '.items[] | select(.report.summary.criticalCount > 0) | [.metadata.namespace, .metadata.name, .report.summary.criticalCount]'
```

### View Detailed Report

```bash
# Get full report as YAML
kubectl get vulnerabilityreport -n securerag-hub portal-web-v1-2-3 -o yaml

# Get summary only
kubectl get vulnerabilityreport -n securerag-hub portal-web-v1-2-3 \
  -o jsonpath='{.report.summary}'

# Get list of vulnerabilities with severity
kubectl get vulnerabilityreport -n securerag-hub portal-web-v1-2-3 \
  -o jsonpath='{.report.vulnerabilities[?(@.severity=="CRITICAL")].vulnerabilityID}'

# Get fix versions for critical CVEs
kubectl get vulnerabilityreport -n securerag-hub portal-web-v1-2-3 \
  -o json | jq '.report.vulnerabilities[] | select(.severity == "CRITICAL") | {vuln: .vulnerabilityID, pkg: .resource, fixed: .fixedVersion}'
```

### Count Vulnerabilities by Severity

```bash
# Quick count across all namespaces
kubectl get vulnerabilityreport -A -o json | \
  jq '[.items[].report.summary] | {critical: map(.criticalCount) | add, high: map(.highCount) | add, medium: map(.mediumCount) | add, low: map(.lowCount) | add}'

# Example output:
# {
#   "critical": 2,
#   "high": 8,
#   "medium": 23,
#   "low": 47
# }
```

### View ConfigAudit Reports

```bash
# List config audit reports
kubectl get configauditreport -A

# View details
kubectl get configauditreport -n securerag-hub replicaset-portal-web-7d8f9 -o yaml

# Show failed checks
kubectl get configauditreport -n securerag-hub replicaset-portal-web-7d8f9 \
  -o json | jq '.report.checks[] | select(.success == false) | {id: .checkID, severity: .severity, message: .message}'
```

---

## 2. Investigating CRITICAL Vulnerabilities

### Step-by-Step Investigation

```bash
# Step 1: Find all CRITICAL CVEs across all images
kubectl get vulnerabilityreport -A -o json | \
  jq '.items[] | {image: .report.artifact.repository + ":" + .report.artifact.tag, critical_vulns: [.report.vulnerabilities[] | select(.severity == "CRITICAL") | {cve: .vulnerabilityID, pkg: .resource, fixed: .fixedVersion}]} | select(.critical_vulns | length > 0)'

# Step 2: Get detailed information for a specific CVE
kubectl get vulnerabilityreport -n securerag-hub portal-web-v1-2-3 -o json | \
  jq '.report.vulnerabilities[] | select(.vulnerabilityID == "CVE-2026-12345")'

# Step 3: Check exploitability
# Look for: cvss_score, primaryLink, title, fixedVersion
# If CVSS > 9.0 AND fix exists: critical priority
# If CVSS < 4.0 AND no exploit path: low priority
```

### CVE Severity Assessment Matrix

| CVSS Score | Severity | Action | SLA |
|:----------:|----------|--------|:---:|
| 9.0 - 10.0 | **CRITICAL** | Patch within 24 hours | < 24h |
| 7.0 - 8.9 | **HIGH** | Patch within 7 days | < 7d |
| 4.0 - 6.9 | **MEDIUM** | Patch within 30 days | < 30d |
| 0.1 - 3.9 | **LOW** | Track for next release | Next release |

### Triage Decision Tree

```
CRITICAL CVE detected
│
├── Does fixVersion exist?
│   ├── YES → Is patch available in base image/package repo?
│   │   ├── YES → Update Dockerfile, rebuild, deploy
│   │   └── NO  → Check for workaround / mitigation
│   │
│   └── NO (0-day) → Is it exploitable in this context?
│       ├── YES → Apply compensating control (NetworkPolicy, seccomp)
│       │         Document risk acceptance
│       └── NO  → Add to .trivyignore with justification
│
└── Is this in a build-time only dependency?
    ├── YES → Add to .trivyignore (build-time)
    └── NO  → Follow the patch flow
```

### Compensating Controls for Unpatchable CVEs

When a CVE cannot be patched (e.g., 0-day, no fix), apply compensating controls:

```yaml
# NetworkPolicy to restrict egress (mitigates network-based exploits)
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: mitigate-cve-2026-xxxxx
  namespace: securerag-hub
spec:
  endpointSelector:
    matchLabels:
      app.kubernetes.io/name: affected-service
  egress:
    - toPorts:
        - ports:
            - port: "443"
              protocol: TCP
      toFQDNs:
        - matchPattern: "*.api.internal.example.com"
```

---

## 3. Managing Scan Jobs

### List and Inspect Scan Jobs

```bash
# List recent scan jobs
kubectl get jobs -n trivy-system

# Describe a specific scan job
kubectl describe job -n trivy-system trivy-scan-abc123

# View scan job logs
kubectl logs -n trivy-system job/trivy-scan-abc123

# Check scan job status
kubectl get job -n trivy-system trivy-scan-abc123 \
  -o jsonpath='{.status}'
```

### Troubleshooting Failed Scan Jobs

```bash
# Find failed jobs
kubectl get jobs -n trivy-system | grep -E "Failed|Error"

# View failure reason
kubectl describe job -n trivy-system trivy-scan-abc123 | grep -A10 "Conditions:"

# Common failure causes:
# 1. Image pull failure → check registry credentials
kubectl logs -n trivy-system job/trivy-scan-abc123 | grep "image pull"

# 2. Trivy DB download timeout → check network egress
kubectl logs -n trivy-system job/trivy-scan-abc123 | grep "DB update"

# 3. OOM → increase scan job resources
kubectl logs -n trivy-system job/trivy-scan-abc123 | grep "OOM"
```

### Force Rescan of a Specific Image

```bash
# Delete the VulnerabilityReport to trigger a new scan
kubectl delete vulnerabilityreport -n securerag-hub portal-web-v1-2-3

# Or restart the operator to force rescan all images
kubectl rollout restart -n trivy-system deployment/trivy-operator

# Manually trigger a scan via the CLI
kubectl exec -n trivy-system deploy/trivy-operator -- \
  /usr/local/bin/trivy-operator scan \
  --namespace securerag-hub \
  --resource portal-web-v1-2-3
```

### Cleanup Old Scan Jobs

```bash
# Manual cleanup of completed jobs
kubectl delete jobs -n trivy-system -l trivy-operator.scanner=trivy

# Or use TTL controller (set in values.yaml)
# operator:
#   scanJob:
#     ttlSecondsAfterFinished: 3600  # 1 hour
```

---

## 4. Configuring Scan Schedules

### Vulnerability Rescan Interval

Configure how often Trivy Operator rescans existing images:

```yaml
# In infra/k8s/trivy-operator/values.yaml
operator:
  scanJob:
    # Rescan existing workloads every 24 hours
    metricsScanInterval: "24h"
    # Scan newly created workloads immediately
    scanWorkloads: true
```

### Compliance Scan Schedule

```yaml
# infra/k8s/trivy-operator/compliance-cis.yaml
apiVersion: aquasecurity.github.io/v1alpha1
kind: ClusterComplianceReport
metadata:
  name: cis-benchmark
spec:
  cron: "0 6 * * 1"   # Every Monday 06:00
  reportType: summary
  controls:
    - id: 1.1.1
    - id: 1.2.1
    # ... more controls
```

```yaml
# infra/k8s/trivy-operator/compliance-nsa.yaml
apiVersion: aquasecurity.github.io/v1alpha1
kind: ClusterComplianceReport
metadata:
  name: nsa-kubernetes-hardening
spec:
  cron: "0 6 * * 3"   # Every Wednesday 06:00
  reportType: summary
```

### Configure Exclusion Windows

```yaml
# Skip scanning during business hours (maintenance window)
operator:
  scanJob:
    scanSchedule:
      disabledTimeWindows:
        - start: "09:00"
          end: "17:00"
          timezone: "UTC"
          dayOfWeek:
            - "monday"
            - "tuesday"
            - "wednesday"
            - "thursday"
            - "friday"
```

---

## 5. Handling False Positives

### Evaluate if a CVE is a False Positive

Use the following decision tree:

```
Is the CVE in a package that's actually used at runtime?
│
├── NO → The package is only used at build time
│   └── → Safe to exclude (build-time only)
│
├── YES → Is the vulnerable code path reachable?
│   ├── NO → Compensating control blocks the path
│   │   └── → Safe to exclude with documented compensation
│   └── YES → Is there a fix available?
│       ├── YES → Apply the fix, do not exclude
│       └── NO → Document risk acceptance, set expiration
│
└── Is the CVE scored incorrectly for this context?
    ├── YES → Document reasoning, add with expiration
    └── NO → Must fix or accept
```

### Add CVE to Exclusion List

**Step 1: Add to `.trivyignore`**

```bash
# .trivyignore
CVE-2026-67890  # Expires: 2026-09-30 Ticket: SEC-015
```

**Step 2: Document in `docs/security/trivy-accepted-risks.md`**

```markdown
| CVE | Package | Justification | Atténuation | Expiration | Ticket |
|-----|---------|---------------|-------------|:----------:|:------:|
| CVE-2026-67890 | libcurl | Build-time only, not in runtime image | Multi-stage build | 2026-09-30 | SEC-015 |
```

**Step 3: Commit and push**

```bash
git add .trivyignore docs/security/trivy-accepted-risks.md
git commit -m "docs: accept CVE-2026-67890 (build-time only)"
git push
```

### Excluding Entire Packages

If a package consistently produces false positives, exclude it at the Trivy configuration level:

```bash
# In values.yaml or trivy config
trivy:
  ignoreUnfixed: true
  ignoredLicenses: ["AGPL-3.0-only"]
  # Additional ignore via --ignore-policy
  ignorePolicy: |
    package "libapparmor" {
      ignore = true
    }
```

### Excluding by Namespace

Some namespaces (e.g., `kube-system`) may be excluded from scanning:

```yaml
# ConfigMap trivy-operator-exclusions
apiVersion: v1
kind: ConfigMap
metadata:
  name: trivy-operator-exclusions
  namespace: trivy-system
data:
  exclude.namespaces: |
    kube-system
    kube-public
    local-path-storage
```

### Periodic Review Process

Run a monthly review of all accepted CVEs:

```bash
# List all accepted CVEs with their expiration dates
grep "^CVE-" .trivyignore

# Check if fixes are now available
for cve in $(grep "^CVE-" .trivyignore | cut -d' ' -f1); do
  echo "--- $cve ---"
  kubectl exec -n trivy-system job/trivy-scan-abc123 -- \
    trivy image --list-all-pkgs alpine:3.18 2>/dev/null | \
    grep -i "$cve" || echo "No longer in DB (may be fixed)"
done

# Remove fixed CVEs and update documentation
# Extend expirations for still-unfixed CVEs
```

---

## 6. Updating Trivy Scanner

### Check Current Version

```bash
# Check Trivy Operator version
kubectl exec -n trivy-system deploy/trivy-operator -- \
  /usr/local/bin/trivy-operator --version

# Check Trivy scanner version
kubectl logs -n trivy-system -l trivy-operator.scanner=trivy --tail=1 | \
  grep -oP "Trivy v\d+\.\d+\.\d+"
```

### Update Operator via Helm

```bash
# Update Helm repository
helm repo update aqua

# Check available versions
helm search repo aqua/trivy-operator --versions

# Upgrade to latest
helm upgrade --install trivy-operator aqua/trivy-operator \
  --namespace trivy-system \
  --reuse-values \
  --version 0.55.0

# Verify upgrade
kubectl rollout status -n trivy-system deployment/trivy-operator
kubectl logs -n trivy-system deploy/trivy-operator --tail=5 | grep version
```

### Update Trivy DB (Standalone Mode)

In standalone mode, each scan job downloads the latest vulnerability database:

```bash
# Force DB update by running a dummy scan
kubectl run trivy-db-update --image=aquasec/trivy:0.54.1 \
  --restart=Never -- trivy image --download-db-only

# Clean up
kubectl delete pod trivy-db-update
```

### Update Trivy DB (ClientServer Mode)

In ClientServer mode, the central Trivy Server maintains the database:

```bash
# Restart Trivy server to trigger DB update
kubectl rollout restart -n trivy-system deployment/trivy-server

# Monitor DB download
kubectl logs -n trivy-system -l app.kubernetes.io/name=trivy-server --tail=50 | \
  grep -E "DB|update|download"

# Verify DB age
kubectl exec -n trivy-system deploy/trivy-server -- \
  trivy image --server http://localhost:4954 --list-all-pkgs alpine:latest
```

### Rollback if Update Fails

```bash
# Rollback Helm release
helm rollback trivy-operator -n trivy-system 1

# Or specify a previous version
helm upgrade --install trivy-operator aqua/trivy-operator \
  --namespace trivy-system \
  --reuse-values \
  --version 0.53.0

# Verify rollback
kubectl rollout status -n trivy-system deployment/trivy-operator
```

---

## Quick Reference

```bash
# List reports
kubectl get vulnerabilityreport -A
kubectl get configauditreport -A
kubectl get clustercompliancereport

# View detailed report
kubectl get vulnerabilityreport -n <ns> <name> -o yaml

# Get vulnerability count
kubectl get vulnerabilityreport -A -o json | \
  jq '[.items[].report.summary] | {critical: map(.criticalCount) | add}'

# List scan jobs
kubectl get jobs -n trivy-system

# View scan logs
kubectl logs -n trivy-system job/<scan-job-name>

# Force rescan
kubectl delete vulnerabilityreport -n <ns> <name>
kubectl rollout restart -n trivy-system deploy/trivy-operator

# Check operator health
kubectl get pods -n trivy-system -l app.kubernetes.io/name=trivy-operator
kubectl logs -n trivy-system deploy/trivy-operator --tail=20

# Update operator
helm upgrade --install trivy-operator aqua/trivy-operator \
  --namespace trivy-system --reuse-values --version <new-version>

# Compliance scans
kubectl apply -f infra/k8s/trivy-operator/compliance-cis.yaml
kubectl get clustercompliancereport cis-benchmark -o yaml

# Prometheus metrics
kubectl port-forward -n trivy-system svc/trivy-operator 8080:8080
curl http://localhost:8080/metrics | grep trivy_
```
