# OpenSearch SIEM Runbook — Security Event Operations

**Component:** OpenSearch + OpenSearch Dashboards  
**Namespace:** `opensearch`  
**Key files:** `infra/k8s/opensearch/`, `scripts/opensearch/`  
**Version:** 2.16.x

---

## 1. Checking Cluster Health

### Cluster Status

```bash
# Quick health check
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk https://localhost:9200/_cluster/health

# Expected output:
# {
#   "cluster_name": "securerag-siem",
#   "status": "green",
#   "timed_out": false,
#   "number_of_nodes": 3,
#   "number_of_data_nodes": 3,
#   "active_primary_shards": 45,
#   "active_shards": 90,
#   "relocating_shards": 0,
#   "initializing_shards": 0,
#   "unassigned_shards": 0
# }

# Status values:
# - green:  All shards allocated and working
# - yellow: Primary shards allocated, replicas not
# - red:    Some primary shards not allocated (DATA LOSS RISK)
```

### Pod Status

```bash
# Check all OpenSearch pods
kubectl get pods -n opensearch -l app.kubernetes.io/name=opensearch

# Check Dashboards
kubectl get pods -n opensearch -l app.kubernetes.io/name=opensearch-dashboards

# Check PersistentVolumeClaims
kubectl get pvc -n opensearch
```

### Node Health

```bash
# List cluster nodes
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk https://localhost:9200/_cat/nodes?v

# Check node disk usage
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk https://localhost:9200/_cat/allocation?v

# Check shard distribution
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk https://localhost:9200/_cat/shards?v
```

### Cluster Stats

```bash
# Detailed cluster statistics
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk https://localhost:9200/_cluster/stats

# Index statistics
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk https://localhost:9200/_cat/indices?v

# Pending tasks
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk https://localhost:9200/_cluster/pending_tasks
```

### Automated Health Check

```bash
# Run validation script
bash scripts/opensearch/validate-siem.sh
```

### Dashboards Health

```bash
# Port-forward and check Dashboards
kubectl port-forward -n opensearch svc/opensearch-dashboards 5601:5601 &

# Check Dashboards API
curl -s http://localhost:5601/api/status | \
  python3 -m json.tool | grep -E "state|status"

# Expected: "state": "green"
```

### Prometheus Alerts

```yaml
- alert: OpenSearchClusterRed
  expr: opensearch_cluster_status{status="red"} == 1
  for: 2m
  labels:
    severity: critical
  annotations:
    summary: "OpenSearch cluster status is RED"
    description: "Some primary shards are not allocated. Risk of data loss."

- alert: OpenSearchDiskUsageHigh
  expr: opensearch_filesystem_data_usage_percent > 85
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "OpenSearch disk usage > 85%"
    description: "Node {{ $labels.node }} disk usage at {{ $value }}%"
```

---

## 2. Querying Security Events

### Basic Queries via API

```bash
# Search all indices for CRITICAL Falco events in last hour
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk -X POST https://localhost:9200/falco-events-*/_search \
  -H 'Content-Type: application/json' \
  -d '{
    "query": {
      "bool": {
        "must": [
          { "match": { "priority": "Critical" } },
          { "range": { "@timestamp": { "gte": "now-1h" } } }
        ]
      }
    },
    "sort": [{ "@timestamp": "desc" }],
    "size": 20
  }' | python3 -m json.tool
```

### Query Templates

#### Latest CRITICAL Security Events

```bash
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk -X POST https://localhost:9200/-events-*/_search \
  -H 'Content-Type: application/json' \
  -d '{
    "query": {
      "bool": {
        "must": [
          { "match": { "severity": "CRITICAL" } },
          { "range": { "@timestamp": { "gte": "now-24h" } } }
        ]
      }
    },
    "sort": [{ "@timestamp": "desc" }],
    "size": 50
  }' | python3 -c "import sys,json; data=json.load(sys.stdin); [print(h['_source']['@timestamp'], h['_source'].get('message','')) for h in data['hits']['hits']]"
```

#### Falco Events by Rule

```bash
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk -X POST https://localhost:9200/falco-events-*/_search \
  -H 'Content-Type: application/json' \
  -d '{
    "size": 0,
    "query": { "range": { "@timestamp": { "gte": "now-24h" } } },
    "aggs": {
      "by_rule": {
        "terms": { "field": "rule.keyword", "size": 20 }
      }
    }
  }' | python3 -c "
import sys,json
data=json.load(sys.stdin)
for bucket in data['aggregations']['by_rule']['buckets']:
    print(f\"{bucket['key']:50s} {bucket['doc_count']:5d} events\")"
```

#### Tetragon Privilege Escalation Events

```bash
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk -X POST https://localhost:9200/tetragon-events-*/_search \
  -H 'Content-Type: application/json' \
  -d '{
    "query": {
      "bool": {
        "must": [
          { "exists": { "field": "capabilities.privileged" } },
          { "range": { "@timestamp": { "gte": "now-7d" } } }
        ]
      }
    },
    "sort": [{ "@timestamp": "desc" }],
    "size": 20
  }' | python3 -m json.tool
```

#### Kubernetes Audit — Failed API Calls

```bash
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk -X POST https://localhost:9200/k8s-audit-*/_search \
  -H 'Content-Type: application/json' \
  -d '{
    "query": {
      "bool": {
        "must": [
          { "range": { "response_status": { "gte": 400 } } },
          { "range": { "@timestamp": { "gte": "now-24h" } } }
        ]
      }
    },
    "sort": [{ "@timestamp": "desc" }],
    "size": 50
  }' | python3 -c "
import sys,json
data=json.load(sys.stdin)
for h in data['hits']['hits']:
    s = h['_source']
    print(f\"{s.get('@timestamp','')} | {s.get('user',''):30s} | {s.get('verb',''):10s} | {s.get('request_uri','')}\")"
```

#### Trivy — Critical Vulnerabilities

```bash
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk -X POST https://localhost:9200/trivy-reports-*/_search \
  -H 'Content-Type: application/json' \
  -d '{
    "query": {
      "bool": {
        "must": [
          { "match": { "severity": "CRITICAL" } },
          { "range": { "@timestamp": { "gte": "now-7d" } } }
        ]
      }
    },
    "sort": [{ "cvss_score": "desc" }],
    "size": 20
  }' | python3 -m json.tool
```

### Using OpenSearch Dashboards for Queries

1. Access Dashboards: `http://localhost:5601` (after port-forward)
2. Go to **Discover** → Select index pattern
3. Use DQL (Dashboards Query Language):
   - `severity : CRITICAL`
   - `priority : "Emergency"`
   - `@timestamp >= now-24h`
   - `kubernetes.pod.name : portal-web*`
   - `rule : "Terminal shell"`

---

## 3. Creating New Dashboards

### Via Dashboards UI

```bash
# Port-forward
kubectl port-forward -n opensearch svc/opensearch-dashboards 5601:5601 &

# Open http://localhost:5601
# Default login: admin / admin
```

**Steps to create a dashboard:**

1. **Stack Management** → **Index Patterns** → Create data views for each source
2. **Visualize** → Create visualizations (bar charts, line charts, tables, heat maps)
3. **Dashboard** → **Create dashboard** → Add visualizations

### Export Dashboard as JSON

```bash
# Export dashboard via API
curl -s -X GET http://localhost:5601/api/saved_objects/_export \
  -H 'Content-Type: application/json' \
  -H 'osd-xsrf: true' \
  -d '{
    "type": "dashboard",
    "includeReferencesDeep": true
  }' > /tmp/opensearch-dashboards-export.json
```

### Import Dashboard from JSON

```bash
# Import saved objects
curl -s -X POST http://localhost:5601/api/saved_objects/_import \
  -H 'osd-xsrf: true' \
  --form file=@/tmp/dashboard-export.ndjson
```

### Pre-built Dashboards

The following dashboards are pre-configured:

| Dashboard | Description | Index Pattern |
|-----------|-------------|---------------|
| **Security Overview** | All security events aggregated | `*-events-*` |
| **Falco Dashboard** | Falco runtime events | `falco-events-*` |
| **Tetragon Dashboard** | eBPF process monitoring | `tetragon-events-*` |
| **Compliance Dashboard** | Trivy + Kyverno compliance | `trivy-reports-*`, `kyverno-admissions-*` |
| **K8s Audit Dashboard** | API server audit logs | `k8s-audit-*` |
| **Wazuh Dashboard** | Host-based IDS alerts | `wazuh-alerts-*` |

### Restore Pre-built Dashboards

```bash
# Import pre-built dashboards from infra
kubectl exec -n opensearch deploy/opensearch-dashboards -- \
  /usr/share/opensearch-dashboards/bin/opensearch-dashboards-import \
  -f /tmp/dashboards/security-overview.ndjson
```

---

## 4. Managing Index Retention

### View Current ISM Policies

```bash
# List all ISM policies
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk https://localhost:9200/_plugins/_ism/policies

# Get a specific policy
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk https://localhost:9200/_plugins/_ism/policies/security_events_30d
```

### Current Retention Policies

| Policy | Retention | Action | Indices |
|--------|:---------:|--------|---------|
| `security_events_30d` | 30 days | Delete | `falco-events-*`, `tetragon-events-*`, `trivy-reports-*`, `k8s-audit-*` |
| `runtime_events_7d` | 7 days | Delete | `runtime-events-*` |
| `kyverno_admissions_90d` | 90 days | Delete | `kyverno-admissions-*` |
| `wazuh_alerts_30d` | 30 days | Delete | `wazuh-alerts-*` |

### Modify Retention Policy

```yaml
# Example: Change Falco retention from 30 to 60 days
PUT _plugins/_ism/policies/security_events_30d
{
  "policy": {
    "description": "Security events retention policy",
    "default_state": "hot",
    "states": [
      {
        "name": "hot",
        "actions": [],
        "transitions": [
          {
            "state_name": "delete",
            "conditions": {
              "min_index_age": "60d"   # Changed from 30d
            }
          }
        ]
      },
      {
        "name": "delete",
        "actions": [
          {
            "delete": {}
          }
        ]
      }
    ],
    "ism_template": {
      "index_patterns": ["falco-events-*", "tetragon-events-*", "trivy-reports-*", "k8s-audit-*"]
    }
  }
}
```

```bash
# Apply modified policy via curl
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk -X PUT https://localhost:9200/_plugins/_ism/policies/security_events_30d \
  -H 'Content-Type: application/json' \
  -d '{
    "policy": {
      "description": "Security events retention policy",
      "default_state": "hot",
      "states": [
        {
          "name": "hot",
          "actions": [],
          "transitions": [
            {
              "state_name": "delete",
              "conditions": { "min_index_age": "60d" }
            }
          ]
        },
        {
          "name": "delete",
          "actions": [{ "delete": {} }]
        }
      ],
      "ism_template": {
        "index_patterns": ["falco-events-*"]
      }
    }
  }'
```

### Create a New Retention Policy

```yaml
# New policy for extended compliance audit logs
PUT _plugins/_ism/policies/compliance_audit_1y
{
  "policy": {
    "description": "Compliance audit logs — 1 year retention",
    "default_state": "hot",
    "states": [
      {
        "name": "hot",
        "actions": [],
        "transitions": [
          {
            "state_name": "warm",
            "conditions": { "min_index_age": "90d" }
          }
        ]
      },
      {
        "name": "warm",
        "actions": [
          { "replica_count": { "number_of_replicas": 1 } }
        ],
        "transitions": [
          {
            "state_name": "delete",
            "conditions": { "min_index_age": "365d" }
          }
        ]
      },
      {
        "name": "delete",
        "actions": [{ "delete": {} }]
      }
    ],
    "ism_template": {
      "index_patterns": ["compliance-audit-*"]
    }
  }
}
```

### Manual Index Management

```bash
# Manually delete old indices
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk -X DELETE https://localhost:9200/falco-events-2026-04-*

# Force ISM policy rollover
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk -X POST https://localhost:9200/_plugins/_ism/_rollover/falco-events-000001

# Check policy state for a specific index
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk https://localhost:9200/_plugins/_ism/explain/falco-events-2026-06-15

# Manually apply a policy to an index
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk -X POST https://localhost:9200/_plugins/_ism/_add/falco-events-2026-06-01 \
  -H 'Content-Type: application/json' \
  -d '{
    "policy_id": "security_events_30d"
  }'
```

### Freeze/Close Old Indices

```bash
# Freeze old indices (reduce memory usage)
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk -X POST https://localhost:9200/falco-events-2026-04-*/_freeze

# Close indices (remove from memory, keep on disk)
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk -X POST https://localhost:9200/falco-events-2026-03-*/_close

# Reopen if needed for investigation
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk -X POST https://localhost:9200/falco-events-2026-03-*/_open
```

### Check Disk Usage

```bash
# Index-level disk usage
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk https://localhost:9200/_cat/indices?v | \
  awk '{print $1, $3, $9, $10}' | sort -k3 -rn | head -20

# Node-level disk usage
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk https://localhost:9200/_nodes/stats/fs | \
  python3 -c "
import sys,json
data=json.load(sys.stdin)
for node_id, node in data['nodes'].items():
    fs = node['fs']
    total = fs['total']['total_in_bytes']
    available = fs['total']['available_in_bytes']
    used_pct = round((1 - available/total) * 100, 1)
    print(f\"{node['name']:30s} Used: {used_pct}%\")
"
```

---

## 5. Troubleshooting Ingestion

### No Data in Indices

**Symptoms:**
- OpenSearch Dashboards shows "No results"
- `_cat/indices` shows zero documents

**Diagnosis:**

```bash
# Step 1: Check if indices exist
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk https://localhost:9200/_cat/indices?v

# Step 2: Check if data sources are running
kubectl get pods -n falco -l app.kubernetes.io/name=falco
kubectl get pods -n kube-system -l app.kubernetes.io/name=tetragon
kubectl get pods -n trivy-system -l app.kubernetes.io/name=trivy-operator

# Step 3: Check Fluentd/Fluentbit configuration
kubectl get pods -n opensearch -l app.kubernetes.io/name=fluentd

# Step 4: Verify OpenSearch is accepting connections
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk https://localhost:9200

# Step 5: Check data pipeline connectivity
kubectl exec -n falco ds/falco -- \
  curl -sk https://opensearch.opensearch.svc:9200
```

**Common Causes and Resolutions:**

| Cause | Check | Fix |
|-------|-------|-----|
| Fluentd not running | `kubectl get pods -n opensearch` | Restart Fluentd |
| Network policy blocking | `hubble observe --verdict DROPPED` | Add egress rule to OpenSearch |
| OpenSearch rejecting data | Check logs: `kubectl logs -n opensearch deploy/opensearch` | Check index mappings |
| Data source not generating events | `kubectl logs -n falco ds/falco` | Restart data source |
| Index pattern mismatch | Check Dashboards index patterns | Update data view |

### Falco Events Not Reaching OpenSearch

```bash
# Check Falco output configuration
kubectl get configmap -n falco falco-config -o yaml | grep -A10 output

# Check Falco logs for output errors
kubectl logs -n falco -l app.kubernetes.io/name=falco --tail=50 | \
  grep -i "error\|fail\|output"

# Test Falco event generation
kubectl exec -n falco ds/falco -- touch /tmp/test-alert
sleep 10

# Check if event arrived in OpenSearch
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk https://localhost:9200/falco-events-*/_search | \
  python3 -c "import sys,json; print(json.load(sys.stdin)['hits']['total']['value'])" 2>/dev/null || echo "no events"
```

### Tetragon Events Not Reaching OpenSearch

```bash
# Check Tetragon output configuration
kubectl get configmap -n kube-system tetragon-config -o yaml | grep -A10 openSearch

# Check Tetragon logs
kubectl logs -n kube-system -l app.kubernetes.io/name=tetragon --tail=50 | \
  grep -i "error\|openSearch\|output"

# Verify Tetragon is generating events
kubectl logs -n kube-system -l app.kubernetes.io/name=tetragon --tail=100 | \
  grep "event"
```

### OpenSearch Rejecting Documents

```bash
# Check for rejected documents
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk https://localhost:9200/_cat/thread_pool?v

# Check logs for rejection errors
kubectl logs -n opensearch deploy/opensearch --tail=50 | \
  grep -i "reject\|circuit_breaking\|too_many"

# Increase queue size if needed
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk -X PUT https://localhost:9200/_cluster/settings \
  -H 'Content-Type: application/json' \
  -d '{
    "persistent": {
      "thread_pool.write.queue_size": 2000,
      "thread_pool.search.queue_size": 2000
    }
  }'
```

### Index Read-Only Due to Low Disk

```bash
# Check for read-only indices
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk https://localhost:9200/_all/_settings | \
  python3 -c "
import sys,json
data=json.load(sys.stdin)
for idx, settings in data.items():
    if settings.get('index',{}).get('settings',{}).get('index.blocks.read_only_allow_delete'):
        print(f'Read-only: {idx}')
    if settings.get('index',{}).get('settings',{}).get('index.blocks.read_only'):
        print(f'Read-only (block): {idx}')
"

# Free up space by deleting old indices
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk -X DELETE https://localhost:9200/falco-events-2026-04-*

# Remove read-only block
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk -X PUT https://localhost:9200/_all/_settings \
  -H 'Content-Type: application/json' \
  -d '{"index.blocks.read_only_allow_delete": null}'
```

---

## 6. Alert Management

### Configure Alertmanager Webhook

```yaml
# infra/k8s/opensearch/alertmanager-webhook.yaml
apiVersion: v1
kind: Secret
metadata:
  name: opensearch-alert-webhook
  namespace: opensearch
type: Opaque
stringData:
  webhook-url: "http://opensearch-siem-webhook.opensearch.svc:9200/alerts"
```

```bash
# Apply webhook configuration
kubectl apply -f infra/k8s/opensearch/alertmanager-webhook.yaml
```

### Create Alert via OpenSearch API

```yaml
# Create a monitor with trigger
POST _plugins/_alerting/monitors
{
  "name": "CRITICAL Falco Events",
  "type": "monitor",
  "schedule": { "period": { "interval": 5, "unit": "MINUTES" } },
  "inputs": [
    {
      "search": {
        "indices": ["falco-events-*"],
        "query": {
          "size": 0,
          "query": {
            "bool": {
              "must": [
                { "match": { "priority": "Critical" } },
                { "range": { "@timestamp": { "gte": "now-5m" } } }
              ]
            }
          }
        }
      }
    }
  ],
  "triggers": [
    {
      "name": "CRITICAL Alert Trigger",
      "severity": "critical",
      "condition": { "script": { "source": "ctx.results[0].hits.total.value > 0" } },
      "actions": [
        {
          "name": "Slack Notification",
          "destination_id": "<slack-destination-id>",
          "subject": "CRITICAL Falco Event Detected",
          "message": "{{ctx.results.[0].hits.hits.[0]._source.message}}"
        }
      ]
    }
  ]
}
```

### Create Alert via Dashboards UI

1. Open Dashboards → **Alerting** → **Monitors**
2. **Create monitor** → Name: `CRITICAL Falco Events`
3. **Define trigger**: `results[0].hits.total.value > 0`
4. **Frequency**: Every 5 minutes
5. **Action**: Send to Slack webhook
6. **Save**

### List and Manage Alerts

```bash
# List all monitors
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk https://localhost:9200/_plugins/_alerting/monitors/_search

# List all alerts
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk https://localhost:9200/_plugins/_alerting/alerts

# Acknowledge an alert
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk -X POST https://localhost:9200/_plugins/_alerting/alerts/<alert-id>/ack

# Delete a monitor
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk -X DELETE https://localhost:9200/_plugins/_alerting/monitors/<monitor-id>
```

### Slack Integration

```bash
# Create Slack destination
curl -sk -X POST https://localhost:9200/_plugins/_alerting/destinations \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "slack-security-alerts",
    "type": "slack",
    "slack": {
      "url": "https://hooks.slack.com/services/T00/B00/xxxxx"
    }
  }'
```

### Alert Notification Channels

| Channel | Type | Use Case |
|---------|------|----------|
| **Slack** | Webhook | Real-time security team notifications |
| **PagerDuty** | Webhook | On-call escalation for CRITICAL events |
| **Email** | SMTP | Daily digest for non-critical events |
| **Custom Webhook** | HTTP | Integration with ticketing systems |

### Alert Severity Mapping

| Data Source | CRITICAL | HIGH | WARNING |
|-------------|:--------:|:----:|:-------:|
| Falco | Emergency, Alert | Critical | Error, Warning |
| Tetragon | Privilege escalation | Suspicious process | Unusual capability |
| Trivy | Critical CVEs | High CVEs | Medium CVEs |
| Kyverno | Policy fail | Policy error | Policy warn |
| K8s Audit | Unauthorized access | RBAC violations | Anomalous API calls |
| Wazuh | Level 15+ | Level 10-14 | Level 5-9 |

---

## Quick Reference

```bash
# Health
kubectl exec -n opensearch deploy/opensearch -- curl -sk https://localhost:9200/_cluster/health

# List indices
kubectl exec -n opensearch deploy/opensearch -- curl -sk https://localhost:9200/_cat/indices?v

# Search last 10 Falco events
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk -X POST https://localhost:9200/falco-events-*/_search \
  -H 'Content-Type: application/json' \
  -d '{"size":10,"sort":[{"@timestamp":"desc"}]}'

# Retention policies
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk https://localhost:9200/_plugins/_ism/policies

# Disk usage
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk https://localhost:9200/_cat/allocation?v

# Port-forward Dashboards
kubectl port-forward -n opensearch svc/opensearch-dashboards 5601:5601

# View logs
kubectl logs -n opensearch deploy/opensearch --tail=50
kubectl logs -n opensearch deploy/opensearch-dashboards --tail=50

# Restart
kubectl rollout restart -n opensearch statefulset/opensearch
kubectl rollout restart -n opensearch deployment/opensearch-dashboards

# Force policy on index
kubectl exec -n opensearch deploy/opensearch -- \
  curl -sk -X POST https://localhost:9200/_plugins/_ism/_add/<index> \
  -H 'Content-Type: application/json' \
  -d '{"policy_id": "security_events_30d"}'
```
