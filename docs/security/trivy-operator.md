# Trivy Operator — Vulnerability Scanning Pipeline

**Version:** 1.0  
**Last updated:** June 2026  
**Component:** `infra/k8s/trivy-operator/`

---

## Architecture

The Trivy Operator follows a operator-based scanning architecture. It watches Kubernetes workloads and automatically triggers vulnerability scans whenever new pods or images are detected.

```
┌─────────────────────────────────────────────────────────────┐
│                    Trivy Operator (Deployment)               │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │ Workload    │  │ Scan Job     │  │ Report           │   │
│  │ Watcher     │──│ Controller   │──│ Aggregator       │   │
│  └──────┬──────┘  └──────┬───────┘  └────────┬─────────┘   │
│         │                │                    │             │
└─────────┼────────────────┼────────────────────┼─────────────┘
          │                │                    │
    ┌─────▼─────┐   ┌──────▼───────┐   ┌───────▼────────┐
    │ Kubernetes │   │  Scan Jobs   │   │ Vulnerability  │
    │ API        │   │  (batch)     │   │ Reports (CRDs) │
    │ (pods,     │   │              │   │                │
    │  nodes)    │   │ job/scan-    │   │ Vulnerability  │
    └───────────┘   │ <hash>       │   │ Report CRD     │
                    └──────────────┘   └────────────────┘
```

### Components

| Component | Type | Description |
|-----------|------|-------------|
| `trivy-operator` | Deployment (1 replica) | Controller that manages scan lifecycle |
| `trivy-scanner` | Job (ephemeral) | Per-image scan job; runs `trivy image` |
| `VulnerabilityReport` | CRD | Per-image vulnerability findings |
| `ConfigAuditReport` | CRD | Kubernetes configuration audit results |
| `ClusterComplianceReport` | CRD | Aggregate compliance (CIS, NSA, MITRE) |
| `ClusterSbomReport` | CRD | SBOM generation per node/image |
| `ClusterRbacAssessment` | CRD | RBAC assessment report per namespace |

### Supported Workloads

Trivy Operator automatically detects and scans:
- Deployments, StatefulSets, DaemonSets
- Jobs, CronJobs
- ReplicaSets, ReplicationControllers
- Pods (standalone)

---

## Deployment

### Prerequisites

- Kubernetes 1.24+
- Helm 3.8+ or Kustomize
- Prometheus Operator (for ServiceMonitor integration)

### Option 1: Helm (Recommended)

```bash
# Add Trivy Operator Helm repository
helm repo add aqua https://aquasecurity.github.io/helm-charts
helm repo update

# Install Trivy Operator
helm upgrade --install trivy-operator aqua/trivy-operator \
  --namespace trivy-system --create-namespace \
  --values infra/k8s/trivy-operator/values.yaml \
  --set="trivy.ignoreFile=.trivyignore" \
  --set="trivy.ignoreUnfixed=true" \
  --set="operator.scanJob.podTemplateHostPID=true" \
  --set="operator.scanJob.tolerations[0].key=node-role.kubernetes.io/control-plane" \
  --set="operator.scanJob.tolerations[0].operator=Exists" \
  --set="operator.scanJob.tolerations[0].effect=NoSchedule"
```

### Option 2: Kustomize

```bash
kubectl apply -k infra/k8s/trivy-operator/
```

### Option 3: ArgoCD

The `securerag-trivy-operator` ApplicationSet deploys the operator via GitOps (sync-wave 25):

```bash
kubectl apply -f infra/k8s/argocd/application-trivy-operator.yaml
```

### Verify Deployment

```bash
# Check operator pod
kubectl get pods -n trivy-system -l app.kubernetes.io/name=trivy-operator

# Check CRDs are installed
kubectl get crd | grep -E "vulnerabilityreports|configauditreports|clustercompliancereports"

# Verify operator logs
kubectl logs -n trivy-system deployment/trivy-operator --tail=20
```

---

## Vulnerability Scanning Pipeline

### 1. Workload Detection

The operator watches for pod creation events. When a new pod is detected, it:
1. Extracts the container image reference
2. Deduplicates across replicas (scans once per unique image)
3. Creates a scan Job for each unique image

### 2. Scan Execution

Each scan Job runs `trivy image` against the target image:

```bash
trivy image --severity CRITICAL,HIGH,MEDIUM \
  --ignore-unfixed \
  --ignorefile=/tmp/trivyignore \
  --format=json \
  --output=/tmp/report.json \
  registry.example.com/secure-rag-hub/portal-web:v1.2.3
```

### 3. Report Generation

The scan Job outputs a JSON report. The operator converts this into a `VulnerabilityReport` CRD:

```yaml
apiVersion: aquasecurity.github.io/v1alpha1
kind: VulnerabilityReport
metadata:
  name: portal-web-v1-2-3
  namespace: securerag-hub
  labels:
    trivy-operator.container.name: portal-web
    trivy-operator.resource.name: portal-web-v1-2-3
    trivy-operator.resource.namespace: securerag-hub
report:
  artifact:
    repository: registry.example.com/secure-rag-hub/portal-web
    tag: v1.2.3
  registry:
    server: registry.example.com
  scanner:
    name: Trivy
    vendor: Aqua Security
    version: 0.54.1
  summary:
    criticalCount: 2
    highCount: 7
    mediumCount: 15
    lowCount: 32
  vulnerabilities:
    - vulnerabilityID: CVE-2026-12345
      resource: libssl3
      installedVersion: 3.0.12
      fixedVersion: 3.0.13
      severity: CRITICAL
      title: "OpenSSL: Buffer overflow in X.509 certificate verification"
      primaryLink: https://avd.aquasec.com/nvd/cve-2026-12345
      score:
        cvss_source: nvd
        cvss_version: "3.1"
        cvss_score: 9.8
```

### 4. Report Aggregation

The operator aggregates reports across:
- **VulnerabilityReport** — per-image findings
- **ConfigAuditReport** — per-workload Kubernetes configuration audit
- **ClusterComplianceReport** — cluster-wide compliance checks
- **ClusterRbacAssessment** — RBAC best practice assessment

---

## ConfigAudit Scanning

ConfigAuditReports evaluate Kubernetes resource configurations against best practices.

### Checks Performed

| Category | Check | Severity |
|----------|-------|----------|
| Security Context | Container runs as non-root | CRITICAL |
| Security Context | ReadOnlyRootFilesystem | HIGH |
| Security Context | Privilege escalation allowed | CRITICAL |
| Resources | CPU/memory limits set | MEDIUM |
| Resources | CPU/memory requests set | LOW |
| Network | Host network/port access | HIGH |
| Volumes | HostPath volumes | CRITICAL |
| Probes | Liveness/readiness probes | MEDIUM |

### Viewing Reports

```bash
# List all ConfigAuditReports
kubectl get configauditreports -A

# View details for a specific workload
kubectl get configauditreport -n securerag-hub replicaset-portal-web-7d8f9 -o yaml

# Check pass/fail summary
kubectl get configauditreport -n securerag-hub replicaset-portal-web-7d8f9 \
  -o jsonpath='{.report.summary}'
```

---

## ClusterCompliance Reporting

ClusterComplianceReports run predefined compliance benchmarks against the cluster.

### Supported Benchmarks

| Benchmark | Focus | Controls |
|-----------|-------|----------|
| **CIS Kubernetes Benchmark v1.9** | Cluster security posture | 150+ checks |
| **NSA Kubernetes Hardening Guide** | US National Security Agency | 50+ checks |
| **MITRE ATT&CK for K8s** | Threat-based assessment | 30+ techniques |
| **NIST SP 800-190** | Container security standards | 40+ controls |

### Running Compliance Scans

Compliance scans run on a schedule. Trigger an on-demand scan:

```bash
# Trigger CIS benchmark scan
kubectl apply -f infra/k8s/trivy-operator/compliance-cis.yaml

# Check scan status
kubectl get clustercompliancereport cis-benchmark -o wide

# View detailed results
kubectl get clustercompliancereport cis-benchmark -o jsonpath='{.status}' | jq .
```

### Compliance Scan Configuration

```yaml
# infra/k8s/trivy-operator/compliance-cis.yaml
apiVersion: aquasecurity.github.io/v1alpha1
kind: ClusterComplianceReport
metadata:
  name: cis-benchmark
spec:
  name: cis-benchmark
  description: "CIS Kubernetes Benchmark v1.9"
  cron: "0 6 * * 1"   # Every Monday at 06:00
  reportType: summary
  controls:
    - id: 1.1.1  # Ensure API server runs on non-root
    - id: 1.2.1  # Ensure kubelet anonymous auth disabled
    - id: 1.2.2  # Ensure kubelet webhook auth enabled
    - id: 4.2.1  # Ensure etcd peer TLS enabled
```

---

## Integration with Prometheus / Grafana

### Prometheus Metrics Exposure

Trivy Operator exposes metrics via the `/metrics` endpoint on port `8080`:

```yaml
# ServiceMonitor (auto-created by Helm)
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: trivy-operator
  namespace: trivy-system
spec:
  endpoints:
    - port: metrics
      interval: 30s
      path: /metrics
  selector:
    matchLabels:
      app.kubernetes.io/name: trivy-operator
```

### Key Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `trivy_vulnerability_critical` | Gauge | Number of CRITICAL vulnerabilities |
| `trivy_vulnerability_high` | Gauge | Number of HIGH vulnerabilities |
| `trivy_vulnerability_medium` | Gauge | Number of MEDIUM vulnerabilities |
| `trivy_vulnerability_low` | Gauge | Number of LOW vulnerabilities |
| `trivy_scan_job_total` | Counter | Total scan jobs created |
| `trivy_scan_job_failed` | Counter | Failed scan jobs |
| `trivy_scan_duration_seconds` | Histogram | Scan job duration |
| `trivy_fixed_total` | Counter | Fixed vulnerabilities (rescan) |
| `trivy_configaudit_fail_total` | Counter | ConfigAudit failures |
| `trivy_compliance_pass_percent` | Gauge | Compliance pass rate |

### Grafana Dashboard

A pre-configured dashboard is available at `infra/k8s/monitoring/dashboards/trivy-scans.json`:

```bash
# Import dashboard to Grafana
kubectl create configmap trivy-grafana-dashboard \
  --namespace monitoring \
  --from-file=infra/k8s/monitoring/dashboards/trivy-scans.json \
  --dry-run=client -o yaml | kubectl apply -f -
```

Dashboard panels include:
- **Vulnerability Overview** — Severity breakdown (pie chart)
- **Vulnerability Trends** — Count over time (line chart)
- **Top CVEs by Severity** — Highest impact vulnerabilities (table)
- **Most Affected Images** — Images with most CVEs (bar chart)
- **ConfigAudit Failures** — Failed checks by namespace (heatmap)
- **Compliance Score** — Pass/fail by benchmark (gauge)
- **Scan Duration** — P50/P95/P99 scan times (stat panel)

### Alerting Rules

Prometheus rules at `infra/k8s/monitoring/security-scan-alerts.yaml`:

```yaml
# Critical vulnerability threshold alert
- alert: CriticalVulnerabilityDetected
  expr: trivy_vulnerability_critical > 0
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "Critical vulnerabilities detected in {{ $labels.image }}"
    description: "Image {{ $labels.image }} has {{ $value }} critical CVEs"

# Scan failure alert
- alert: TrivyScanFailed
  expr: rate(trivy_scan_job_failed[15m]) > 0
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Trivy scan jobs failing"
    description: "Scan failure rate is {{ $value | humanize }} per second"

# Compliance threshold alert
- alert: ComplianceScoreDropped
  expr: trivy_compliance_pass_percent < 95
  for: 10m
  labels:
    severity: warning
  annotations:
    summary: "Compliance score below 95%"
    description: "CIS benchmark compliance is at {{ $value }}%"
```

---

## RBAC Assessment

ClusterRbacAssessment reports analyze RBAC configurations for over-provisioned permissions.

### Assessment Scope

| Check | Description |
|-------|-------------|
| Wildcard verbs | Roles using `*` verbs unnecessarily |
| Cluster-admin binding | Service accounts bound to `cluster-admin` |
| Pod exec access | RBAC rules granting `pods/exec` |
| Secret read access | RBAC rules granting `secrets` get |
| Impersonation | Roles granting `impersonate` |
| Wide API group access | Roles with broad API group matches |

### Viewing RBAC Reports

```bash
# List RBAC assessments
kubectl get clusterrbacassessment -A

# Get detailed report
kubectl get clusterrbacassessment securerag-hub -o yaml

# Filter for failures only
kubectl get clusterrbacassessment -o json | \
  jq '.items[] | select(.report.summary.failCount > 0) | .metadata.name'
```

### Fixing RBAC Issues

When RBAC assessments detect over-provisioning:

1. Review the specific Role/ClusterRole identified
2. Replace wildcards with explicit verb lists: `["get", "list", "watch"]`
3. Remove `cluster-admin` bindings for service accounts
4. Apply least-privilege roles using dedicated service accounts
5. Re-scan: delete the old assessment report to trigger a new scan

---

## Dashboard Usage

### Pre-configured Dashboard

Access via Grafana → Dashboards → `SecureRAG Security / Trivy Scans`

**Home Panel — Vulnerability Summary:**
- Total CVEs by severity (CRITICAL, HIGH, MEDIUM, LOW)
- Change rate compared to previous scan
- Images with highest vulnerability density

**Image Inventory Panel:**
- All scanned images with tag, registry, scan time
- Filter by namespace, severity threshold, image name
- Drill-down to specific VulnerabilityReport

**Vulnerability Details Panel:**
- Per-CVE detail: package, installed version, fixed version, severity score
- Links to NVD / Aqua Security AVD
- Fix version recommendation

**ConfigAudit Panel:**
- Failed checks by namespace and severity
- Trend: pass rate over the last 30 days
- Top failing check categories

**Compliance Panel:**
- CIS benchmark overall pass percentage
- Fail count by control ID
- Historical compliance trend

---

## Remediation Workflow

### Standard Remediation Process

```
1. DETECTION
   ├── Trivy Operator scans image
   ├── VulnerabilityReport CRD created
   ├── Prometheus alert fires (if CRITICAL)
   └── Slack/PagerDuty notified

2. TRIAGE
   ├── View VulnerabilityReport: kubectl get vulnerabilityreport -n <ns> <name> -o yaml
   ├── Check if CVE has a fix: look for `fixedVersion` field
   ├── Check severity and CVSS score
   └── Determine exploitability (does it affect the runtime path?)

3. REMEDIATION
   ├── If fix available: update base image or dependency
   │   └── Patch: bump package version in Dockerfile / requirements.txt
   ├── If no fix available:
   │   ├── Document in .trivyignore + trivy-accepted-risks.md
   │   └── Apply compensating control (NetworkPolicy, seccomp, AppArmor)
   └── Rebuild image: pipeline triggers automated build

4. VERIFICATION
   ├── New image scanned by Trivy Operator
   ├── Old VulnerabilityReport replaced
   ├── Alert resolves automatically
   └── Compliance score updated
```

### Automated Remediation

The CI pipeline includes a `trivyScan` shared library step (`vars/trivyScan.groovy`) that:

```groovy
// Jenkins shared library — vars/trivyScan.groovy
def call(Map params = [:]) {
    def severity = params.severity ?: "CRITICAL,HIGH"
    def ignoreFile = params.ignoreFile ?: ".trivyignore"

    sh """
    trivy image \
      --severity ${severity} \
      --ignore-unfixed \
      --ignorefile=${ignoreFile} \
      --exit-code 1 \
      --format sarif \
      --output trivy-results.sarif \
      ${params.image}
    """
}
```

### Blocking Policy

The pipeline quality gate enforces:

| Gate | Policy | Action |
|------|--------|--------|
| CRITICAL CVE | Block if any unfixed CRITICAL not in `.trivyignore` | Pipeline FAILURE |
| HIGH CVE | Block if > 5 unfixed HIGH CVEs | Pipeline UNSTABLE |
| ConfigAudit | Block if CRITICAL severity checks fail | Pipeline FAILURE |
| Compliance | Block if CIS pass rate < 80% | Pipeline FAILURE |

---

## Image Scanning Policies

### Scan Configuration

The operator is configured via `infra/k8s/trivy-operator/values.yaml`:

```yaml
# Key configuration values
operator:
  scanJob:
    podTemplateHostPID: false
    tolerations: []
    priorityClassName: system-cluster-critical
  batchDeleteLimit: 10
  vulnerabilityScannerEnabled: true
  configAuditScannerEnabled: true
  clusterComplianceEnabled: true
  rbacAssessmentEnabled: true
  sbomGenerationEnabled: false

trivy:
  image:
    registry: docker.io
    repository: aquasec/trivy
    tag: 0.54.1
  mode: Standalone      # Standalone or ClientServer
  severity: CRITICAL,HIGH,MEDIUM
  ignoreUnfixed: true
  ignoreFile: .trivyignore
  timeout: 10m
  slow: true
  dbRepository: ghcr.io/aquasecurity/trivy-db
  server:
    addr: http://trivy-server.trivy-system.svc:4954
    customHeaders: []
```

### Scanning Modes

| Mode | Description | Use Case |
|------|-------------|----------|
| **Standalone** | Each scan Job downloads the Trivy DB independently | Small clusters (< 10 nodes) |
| **ClientServer** | Scan Jobs query a central Trivy Server | Large clusters, reduced network egress |

### Namespace Exclusions

Namespaces can be excluded from scanning:

```yaml
# ConfigMap to exclude specific namespaces
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

### Scan Schedule

| Scan Type | Trigger | Interval |
|-----------|---------|----------|
| Vulnerability | Pod creation | Immediate |
| Vulnerability | Rescan | Every 24h (configurable) |
| ConfigAudit | On change | Immediate |
| Compliance | Cron schedule | Weekly (Monday 06:00) |
| RBAC | On change | Immediate |
| SBOM | Cron schedule | Daily (02:00) |

---

## Excluding False Positives

### When to Exclude

A CVE should only be excluded when:
1. **Not exploitable** — The vulnerable code path is never reached
2. **Build-time only** — The dependency is not shipped to runtime
3. **Compensating control** — NetworkPolicy, seccomp, AppArmor mitigate the risk
4. **No fix available** — Upstream patch not yet released (0-day)

### Process

```yaml
# .trivyignore — Add new exclusion
CVE-2026-67890  # Expires: 2026-09-30 Ticket: SEC-015
```

Each exclusion must be documented in `docs/security/trivy-accepted-risks.md`:

| CVE | Package | Justification | Atténuation | Expiration | Ticket |
|-----|---------|---------------|-------------|:----------:|:------:|
| CVE-2026-67890 | libcurl | Build-time only, not in runtime image | Multi-stage build | 2026-09-30 | SEC-015 |

### CI Enforcement

The pipeline validates that:
1. Every `.trivyignore` entry has a corresponding entry in `trivy-accepted-risks.md`
2. No exclusion exceeds 90-day expiration
3. Expired exclusions cause pipeline failure
4. CRITICAL CVEs without documented exclusion cause pipeline failure

### False Positive Review Process

```bash
# Monthly review checklist
# 1. List all current exclusions
grep "^CVE-" .trivyignore

# 2. Check if fixes are now available
for cve in $(grep "^CVE-" .trivyignore | cut -d' ' -f1); do
  echo "Checking $cve ..."
  # Query NVD API or Trivy DB
done

# 3. Remove fixed CVEs
# 4. Extend expirations if still not fixed
# 5. Commit changes to .trivyignore and trivy-accepted-risks.md
```

---

## Troubleshooting

### Scan Job Stuck in Pending

```bash
# Check pending scan jobs
kubectl get jobs -n trivy-system

# Describe pending job for events
kubectl describe job -n trivy-system trivy-scan-<hash>

# Common causes:
# - Resource constraints: check node resources
# - Image pull secret missing: ensure imagePullSecrets configured
# - Trivy DB download timeout: check network egress
```

### VulnerabilityReport Not Created

```bash
# Check operator logs
kubectl logs -n trivy-system deployment/trivy-operator --tail=50

# Verify scan job completed successfully
kubectl logs -n trivy-system job/trivy-scan-<hash>

# Check CRD exists
kubectl get crd vulnerabilityreports.aquasecurity.github.io
```

### High Memory Usage

```bash
# Limit scan job resources in values.yaml
operator:
  scanJob:
    resources:
      requests:
        cpu: 100m
        memory: 256Mi
      limits:
        cpu: 500m
        memory: 1Gi
```

### Compliance Report Stale

```bash
# Delete old report to trigger new scan
kubectl delete clustercompliancereport cis-benchmark

# Verify new scan started
kubectl get clustercompliancereport cis-benchmark -w
```

### Prometheus Metrics Not Appearing

```bash
# Verify ServiceMonitor exists
kubectl get servicemonitor -n trivy-system

# Check metric endpoint directly
kubectl port-forward -n trivy-system svc/trivy-operator 8080:8080
curl http://localhost:8080/metrics | grep trivy_
```

---

## Maintenance

### Updating Trivy Scanner Version

```bash
# Update the Trivy image tag in values.yaml
trivy:
  image:
    tag: 0.55.0   # Latest stable

# Apply changes
helm upgrade --install trivy-operator aqua/trivy-operator \
  --namespace trivy-system --reuse-values \
  --set trivy.image.tag=0.55.0

# Verify new version
kubectl logs -n trivy-system deployment/trivy-operator --tail=5 | grep version
```

### Database Updates

The Trivy vulnerability database is automatically downloaded by each scan job. Use the ClientServer mode with a persistent Trivy server to reduce bandwidth:

```bash
# Deploy Trivy server
helm upgrade --install trivy-server aqua/trivy-operator \
  --namespace trivy-system \
  --set="trivy.mode=ClientServer" \
  --set="trivy.server.addr=http://trivy-server.trivy-system.svc:4954"
```

### Cleanup Old Reports

```yaml
# infra/k8s/trivy-operator/cleanup-cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: trivy-report-cleanup
  namespace: trivy-system
spec:
  schedule: "0 3 * * 0"  # Weekly on Sunday 03:00
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: trivy-operator
          containers:
            - name: cleanup
              image: bitnami/kubectl:latest
              command:
                - /bin/sh
                - -c
                - |
                  # Delete reports older than 90 days
                  kubectl delete vulnerabilityreport \
                    --all-namespaces \
                    --field-selector=metadata.creationTimestamp<$(date -d '-90 days' -I)
          restartPolicy: OnFailure
```

---

## Reference

### Key Files

| File | Purpose |
|------|---------|
| `infra/k8s/trivy-operator/values.yaml` | Helm values for operator configuration |
| `infra/k8s/trivy-operator/compliance-cis.yaml` | CIS benchmark compliance CRD |
| `infra/k8s/monitoring/dashboards/trivy-scans.json` | Grafana dashboard JSON |
| `infra/k8s/monitoring/security-scan-alerts.yaml` | Prometheus alerting rules |
| `.trivyignore` | Accepted CVE exclusions |
| `docs/security/trivy-accepted-risks.md` | Documentation for each excluded CVE |
| `vars/trivyScan.groovy` | Jenkins shared library for CI scanning |

### Useful Commands

```bash
# List all vulnerability reports
kubectl get vulnerabilityreport -A

# List all config audit reports
kubectl get configauditreport -A

# List compliance reports
kubectl get clustercompliancereport

# Get detailed vulnerability report
kubectl get vulnerabilityreport -n securerag-hub <name> -o yaml

# Check operator health
kubectl get pods -n trivy-system -l app.kubernetes.io/name=trivy-operator

# View operator logs
kubectl logs -n trivy-system deployment/trivy-operator -f

# Trigger rescan of all images
kubectl delete pod -n trivy-system -l app.kubernetes.io/name=trivy-operator
```
