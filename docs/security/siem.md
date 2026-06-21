# SecureRAG Hub — SIEM Centralisé (OpenSearch)

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Data Sources                         │
│  ┌──────┐ ┌─────────┐ ┌─────┐ ┌─────┐ ┌──────┐       │
│  │Falco │ │Tetragon │ │Trivy│ │Wazuh│ │Kyverno│  ...  │
│  └──┬───┘ └────┬────┘ └──┬──┘ └──┬──┘ └───┬───┘       │
│     │          │         │       │         │           │
│  ┌──▼──────────▼─────────▼───────▼─────────▼───┐       │
│  │         Fluentd / Fluentbit                  │       │
│  │         (Log Forwarding Layer)               │       │
│  └──────────────────┬───────────────────────────┘       │
│                     │                                   │
│  ┌──────────────────▼───────────────────────────┐       │
│  │         OpenSearch (SIEM Storage)             │       │
│  │  ┌──────────┬──────────┬────────────────┐    │       │
│  │  │Security  │Runtime   │Compliance      │    │       │
│  │  │Indices   │Indices   │Indices         │    │       │
│  │  │(30d)     │(7d)      │(30d)           │    │       │
│  │  └──────────┴──────────┴────────────────┘    │       │
│  └──────────────────┬───────────────────────────┘       │
│                     │                                   │
│  ┌──────────────────▼───────────────────────────┐       │
│  │    OpenSearch Dashboards (Visualization)      │       │
│  └───────────────────────────────────────────────┘       │
│                                                         │
│  ┌──────────────────┬───────────────────────────┐       │
│  │  Alertmanager    │    Slack / PagerDuty      │       │
│  └──────────────────┴───────────────────────────┘       │
└─────────────────────────────────────────────────────────┘
```

## Data Sources

### Falco — Runtime Security Events
- **Source**: Falco daemon running on each node
- **Index**: `falco-events-*`
- **Retention**: 30 days
- **Key fields**: rule, priority, pod, namespace, container, proc
- **Events**: Shell detection, file system changes, network calls, syscall anomalies

### Tetragon — eBPF-based Monitoring
- **Source**: Tetragon daemon with eBPF hooks
- **Index**: `tetragon-events-*`
- **Retention**: 30 days
- **Key fields**: process, parent_process, capabilities, binary
- **Events**: Process execution, capability usage, network connections

### Trivy — Vulnerability Reports
- **Source**: Trivy Operator scanning Kubernetes workloads
- **Index**: `trivy-reports-*`
- **Retention**: 30 days
- **Key fields**: vulnerability_id, severity, package_name, fixed_version
- **Events**: CVE reports per container image

### Wazuh — Host-based IDS
- **Source**: Wazuh agents via Wazuh manager forwarding to OpenSearch
- **Index**: `wazuh-alerts-*`
- **Retention**: 30 days
- **Key fields**: rule, level, agent, mitre

### Kyverno — Admission Control
- **Source**: Kyverno policy engine metrics/logs
- **Index**: `kyverno-admissions-*`
- **Retention**: 30 days
- **Key fields**: policy, result (pass/fail), resource_kind, resource_namespace
- **Events**: Policy violations, mutation traces

### Kubernetes Audit Logs
- **Source**: Kubernetes API server audit logs
- **Index**: `k8s-audit-*`
- **Retention**: 30 days
- **Key fields**: user, verb, request_uri, response_status, source_ips
- **Events**: API calls, RBAC violations, resource changes

## OpenSearch Deployment

### Prerequisites
```bash
# Increase vm.max_map_count on all nodes
kubectl apply -f infra/k8s/opensearch/patch-sysctl.yaml

# Create admin password secret (optional, default: admin/admin)
kubectl create secret generic opensearch-admin-password \
  --namespace opensearch \
  --from-literal=password=<your-password>
```

### Deploy
```bash
# Using kustomize
kubectl apply -k infra/k8s/opensearch/

# Or using the deploy script
./scripts/opensearch/deploy-opensearch.sh
```

### Access
```bash
# Port-forward OpenSearch Dashboards
kubectl port-forward -n opensearch svc/opensearch-dashboards 5601:5601
# Open http://localhost:5601
# Default credentials: admin / admin
```

## Index Management

### Index Templates
Each data source has a pre-configured index template:
- `falco-events`, `tetragon-events`, `trivy-reports`, `k8s-audit`, `kyverno-admissions`
- Templates define mappings for optimal query performance
- Dynamic strings are mapped as `keyword` for efficient filtering

### ISM Policies (Index State Management)

| Policy | Retention | Action | Indices |
|--------|-----------|--------|---------|
| `security_events_30d` | 30 days | Delete | falco-events, tetragon-events, trivy-reports, k8s-audit, kyverno-admissions |
| `runtime_events_7d` | 7 days | Delete | runtime-events |

Policies are automatically applied to matching indices via index templates.

### Data Pipeline

```bash
# Configure all data pipeline forwarding
./scripts/opensearch/configure-data-pipeline.sh
```

This configures:
- **Fluentd/Fluentbit** → Forwards container logs and Falco events
- **Tetragon output** → Direct OpenSearch sink
- **Trivy CronJob** → Periodically exports vulnerability reports
- **Kyverno webhook** → Forwards admission review events

## Dashboard Usage

OpenSearch Dashboards provides pre-configured visualizations:

### Security Overview
- **Security Events Timeline**: All security events aggregated by source
- **Top Rules by Severity**: Most frequent Falco/Tetragon rules
- **Source Distribution**: Breakdown of events by data source
- **Geographic Map**: Source IP geolocation for K8s audit events (if available)

### Falco Dashboard
- Shell detection timeline
- Priority distribution
- Top offending containers/pods
- Rule firing frequency

### Tetragon Dashboard
- Process execution timeline
- Capability usage analysis
- Binary execution tracking
- Privilege escalation attempts

### Compliance Dashboard
- Trivy vulnerability severity breakdown
- Kyverno policy pass/fail ratio
- K8s audit RBAC violations
- Wazuh CIS benchmark results

## Alerting

### Alertmanager Webhook
OpenSearch alerts integrate with Alertmanager via webhook:
```yaml
receivers:
  - name: opensearch-siem
    webhook_configs:
      - url: "http://opensearch-siem-webhook.opensearch.svc:9200/alerts"
        send_resolved: true
```

### Slack Integration
The `alert-to-slack.py` script queries OpenSearch for critical events and sends them to Slack:
```bash
# As a CronJob
kubectl create cronjob siem-alert-to-slack \
  --image=python:3.12-alpine \
  --schedule="*/5 * * * *" \
  -- python3 /scripts/alert-to-slack.py
```

### Alert Severity Mapping

| Data Source | Critical | Warning | Info |
|-------------|----------|---------|------|
| Falco | Emergency, Alert | Critical, Error | Warning, Notice |
| Tetragon | Privilege escalation | Suspicious process | Normal process |
| Trivy | Critical CVEs | High CVEs | Medium/Low CVEs |
| Kyverno | Policy fail | Policy error | - |
| K8s Audit | Unauthorized access | RBAC violations | Normal API calls |

## Incident Response Workflow

```
1. DETECTION
   ├── Alert fires in Alertmanager or OpenSearch
   ├── Slack notification sent via alert-to-slack.py
   └── Incident created in Opsgenie/PagerDuty (optional)

2. TRIAGE
   ├── Query OpenSearch for related events
   ├── Check Falco/Tetragon logs for process context
   ├── Review K8s audit logs for API activity
   └── Check Trivy for vulnerable packages

3. CONTAINMENT
   ├── Apply Kyverno policy to block (if applicable)
   ├── Use Falco Talon for automated response
   ├── Network policy enforcement via Cilium
   └── Pod isolation or termination

4. ERADICATION
   ├── Remove malicious containers/images
   ├── Rotate compromised credentials via Vault
   ├── Patch vulnerabilities (Trivy findings)
   └── Update security policies

5. RECOVERY
   ├── Restore from backup if needed
   ├── Validate deployment integrity
   └── Verify no persistent threats

6. POST-MORTEM
   ├── Document timeline in OpenSearch
   ├── Update detection rules
   ├── Tune alert thresholds
   └── Update runbooks
```

## Validation

```bash
# Run SIEM validation script
./scripts/opensearch/validate-siem.sh

# Manual health check
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk https://localhost:9200/_cluster/health

# List all indices
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk https://localhost:9200/_cat/indices?v

# Search for security events
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk https://localhost:9200/falco-events-*/_search
```

## Troubleshooting

### OpenSearch won't start
- Check `vm.max_map_count` on the node: `kubectl exec <node> -- sysctl vm.max_map_count`
- Verify PVC is bound: `kubectl get pvc -n opensearch`
- Check logs: `kubectl logs -n opensearch deploy/opensearch`

### No data in indices
- Verify data source agents are running
- Check Fluentd/Fluentbit configuration
- Test connectivity: `kubectl exec -n opensearch deploy/opensearch -- curl -sk https://opensearch:9200`

### High disk usage
- Verify ISM policies are applied: `kubectl exec deploy/opensearch -- curl -sk https://localhost:9200/_plugins/_ism/policies`
- Manually trigger policy: `kubectl exec deploy/opensearch -- curl -sk -X POST https://localhost:9200/_plugins/_ism/_add/security_events_30d`
