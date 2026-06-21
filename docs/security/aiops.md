# SecureRAG Hub — AIOps Anomaly Detection

## Overview

AIOps (Artificial Intelligence for IT Operations) applies statistical and machine learning techniques to operational data for automated anomaly detection, predictive analysis, and root cause identification. This implementation uses Prometheus recording rules to compute statistical baselines and alert on deviations.

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Prometheus                           │
│  ┌──────────────┐  ┌───────────────────────────────┐   │
│  │ Metrics       │  │ Recording Rules               │   │
│  │ (CPU, Memory, │  │ - 7d baselines               │   │
│  │  Latency,     │  │ - Stddev computations         │   │
│  │  Errors)      │  │ - Predictive forecasts        │   │
│  └──────┬───────┘  └───────────┬───────────────────┘   │
│         │                      │                       │
│  ┌──────▼──────────────────────▼───────────────────┐   │
│  │               Alert Rules                       │   │
│  │  - Z-score anomaly (>2σ from baseline)          │   │
│  │  - Ratio-based spikes (>2x or >3x baseline)     │   │
│  │  - Predictive (disk full in 30d)                │   │
│  └──────────────────────┬──────────────────────────┘   │
│                         │                               │
│  ┌──────────────────────▼──────────────────────────┐   │
│  │              Grafana Dashboard                  │   │
│  │  - Timeseries with baseline overlay             │   │
│  │  - Heatmap of anomaly scores                    │   │
│  │  - Predictive gauges                            │   │
│  │  - Alert history table                          │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

## Anomaly Detection Methods

### Statistical Baseline (Z-Score)

The primary method uses a rolling 7-day baseline with standard deviation:

```
anomaly_score = |current_value - avg_7d| / stddev_7d
```

- **Normal**: `anomaly_score < 2` — within expected variance
- **Warning**: `2 <= anomaly_score < 3` — possible anomaly
- **Critical**: `anomaly_score >= 3` — definite anomaly

**Supported metrics**:
- CPU usage rate (`container_cpu_usage_seconds_total`)
- Memory working set (`container_memory_working_set_bytes`)

### Ratio-Based Detection

For metrics without normal distribution, ratio-based detection compares current values to the baseline:

```
ratio = current_value / baseline_7d
```

- **Latency**: Alert if `ratio > 2` (p95 latency > 2x baseline)
- **Error Rate**: Alert if `ratio > 3` (5xx errors > 3x baseline)

### Predictive Analytics

Uses PromQL's `predict_linear` function to forecast future values:

```
predict_linear(metric[6h], 86400 * 30)  # 30-day forecast
```

- **Disk Full Prediction**: Estimates when disk will fill based on 6-hour consumption trend
- **Capacity Planning**: Extrapolates resource usage for cost optimization

## Alert Rules

### CPUAnomalyDetected

| Field | Value |
|-------|-------|
| **Expression** | Z-score of CPU rate > 2 |
| **For** | 10 minutes |
| **Severity** | Warning |
| **Action** | Investigate pod for runaway processes or cryptomining |

### MemoryAnomalyDetected

| Field | Value |
|-------|-------|
| **Expression** | Z-score of memory working set > 2 |
| **For** | 10 minutes |
| **Severity** | Warning |
| **Action** | Check for memory leaks, increase limits |

### LatencySpikeDetected

| Field | Value |
|-------|-------|
| **Expression** | p95 latency > 2x 7-day baseline |
| **For** | 5 minutes |
| **Severity** | Warning |
| **Action** | Check service performance, database queries, upstream dependencies |

### ErrorRateSpikeDetected

| Field | Value |
|-------|-------|
| **Expression** | 5xx error rate > 3x 7-day baseline |
| **For** | 5 minutes |
| **Severity** | Critical |
| **Action** | Immediate investigation — potential service degradation or attack |

### DiskFullPredicted

| Field | Value |
|-------|-------|
| **Expression** | Predicted available bytes in 30 days < 0 |
| **For** | 0 minutes |
| **Severity** | Warning |
| **Action** | Clean up old data, increase volume size, add retention policies |

## Recording Rules

Baseline recording rules are pre-computed every 5 minutes:

| Rule Name | Description | Expression |
|-----------|-------------|------------|
| `aiops:cpu_baseline_7d` | 7-day rolling average CPU | `avg_over_time(rate(container_cpu...[5m])[7d:5m])` |
| `aiops:cpu_stddev_7d` | 7-day rolling stddev CPU | `stddev_over_time(rate(container_cpu...[5m])[7d:5m])` |
| `aiops:memory_baseline_7d` | 7-day rolling average memory | `avg_over_time(container_memory...[7d:5m])` |
| `aiops:memory_stddev_7d` | 7-day rolling stddev memory | `stddev_over_time(container_memory...[7d:5m])` |
| `aiops:predict_disk_full_days` | Disk full prediction | `predict_linear(node_filesystem_avail...[6h]) < 0` |

## Dashboard Interpretation

The AIOps Grafana dashboard (`grafana-dashboard-aiops`) provides the following panels:

### CPU Anomaly Detection
- **Actual**: Raw CPU rate per pod
- **Baseline**: 7-day rolling average (dashed line)
- **Threshold**: +2σ line — deviations above this trigger alerts
- **Interpretation**: Brief spikes above threshold are normal; sustained (>10m) deviations require investigation

### Memory Anomaly Detection
- Same structure as CPU panel
- Watch for step changes that persist — indicative of memory leaks

### Latency Spike Detection
- **p95 Latency**: Current 95th percentile
- **7d Baseline**: Historical average
- **2x Threshold**: Alert trigger line
- **Interpretation**: Latency spikes often correlate with deployment changes or traffic surges

### Error Rate Spike
- **5xx Rate**: Current server error rate
- **3x Threshold**: Alert trigger at 3x baseline
- **Interpretation**: Even small absolute error rates can trigger if baseline is normally zero

### Predictive Disk Full
- Gauge showing predicted available bytes in 30 days
- Red zone (< 0) = disk will fill within 30 days
- Green zone (> 1GB) = safe
- **Interpretation**: Proactive alerting prevents disk-full incidents

### Anomaly Score Heatmap
- Y-axis: pods/services
- X-axis: time
- Color intensity: deviation in sigma units
- **Interpretation**: Hotspots reveal which services are anomalous and when

### Alert History Table
- Shows currently firing AIOps alerts
- Columns: Alert name, severity, pod, anomaly type, deviation value

## Tuning Sensitivity

### Adjusting Z-Score Threshold

The default threshold is 2 sigma. To make detection more or less sensitive, modify the multiplier in `aiops-rules.yaml`:

```yaml
# More sensitive (catches more anomalies, more false positives): 1.5 sigma
expr: "... > 1.5 * stddev_over_time(...)"

# Less sensitive (catches only major anomalies): 3 sigma
expr: "... > 3 * stddev_over_time(...)"
```

### Adjusting Ratio Thresholds

For latency and error rate:

```yaml
# Latency: change from 2x to 1.5x for earlier detection
expr: "... / avg_over_time(...) > 1.5"

# Error rate: change from 3x to 2x for earlier detection
expr: "... / avg_over_time(...) > 2"
```

### Adjusting Baseline Window

The default baseline is 7 days. Change the window for different sensitivity:

| Window | Best For | Trade-off |
|--------|----------|-----------|
| 3 days | Rapidly changing systems | Noisy, weekly patterns missed |
| 7 days | Standard workloads | Default, balances sensitivity |
| 14 days | Stable services | Slower to adapt to changes |
| 30 days | Seasonal patterns | Very slow response to new baselines |

Modify in `aiops-rules.yaml`:
```yaml
# Change [7d:5m] to [14d:5m] for 14-day baseline
avg_over_time(metric[14d:5m])
```

### Adjusting Alert Duration

The `for` field determines how long a condition must persist before alerting:

| Duration | Use Case |
|----------|----------|
| 0m | Instant detection (high false positives) |
| 5m | Quick response for error rates |
| 10m | Standard for CPU/memory anomalies |
| 30m | Only for sustained issues |

### Disabling Rules

To disable a rule, comment it out or set a very high threshold:

```yaml
# - alert: CPUAnomalyDetected
#   expr: ...
```

## Deployment

```bash
# Apply AIOps rules and dashboard
kubectl apply -k infra/k8s/aiops/

# Verify rules are loaded
kubectl get prometheusrule -n securerag-monitoring aiops-anomaly-rules

# Check Grafana dashboard is created
kubectl get configmap -n securerag-monitoring grafana-dashboard-aiops
```

## Required Metrics

For AIOps to function, ensure these metrics are available in Prometheus:

| Metric | Source | Required |
|--------|--------|----------|
| `container_cpu_usage_seconds_total` | kubelet / cAdvisor | CPU/Memory anomaly detection |
| `container_memory_working_set_bytes` | kubelet / cAdvisor | CPU/Memory anomaly detection |
| `http_request_duration_seconds_bucket` | Application / Istio | Latency spike detection |
| `http_requests_total` | Application / Istio | Error rate spike detection |
| `node_filesystem_avail_bytes` | node_exporter | Predictive disk full |

## Limitations

1. **Cold start**: Baselines require 7 days of data before becoming accurate
2. **Seasonal patterns**: Weekly baselines may miss daily spikes (e.g., peak vs. off-peak hours)
3. **Gradual drift**: Slow resource leaks may not trigger 2σ alerts until advanced stages
4. **Metric gaps**: If metrics are missing, baseline computation produces no data
5. **Single-metric focus**: Each anomaly rule evaluates one metric independently — multi-dimensional analysis requires ML models

## Future Enhancements

- Prophet-based forecasting for seasonal anomaly detection
- ML model (Isolation Forest) for multi-dimensional anomaly detection
- Automated root cause analysis via metric correlation
- Integration with OpenSearch SIEM for enriched context
- Feedback loop for alert tuning based on false positive rate
