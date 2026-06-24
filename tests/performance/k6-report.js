import { textSummary } from './k6-summary.js';

export function buildReportData(data, testName) {
  const httpReqs = data.metrics.http_reqs;
  const httpReqDur = data.metrics.http_req_duration;
  const httpReqFailed = data.metrics.http_req_failed;

  const report = {
    meta: {
      test_name: testName,
      timestamp: new Date().toISOString(),
      k6_version: data.metrics?.k6_version || 'unknown',
      scenario: __ENV.SCENARIO || 'default',
      base_url: __ENV.BASE_URL || 'not-set',
      namespace: __ENV.NAMESPACE || 'securerag-hub',
    },
    summary: {
      total_requests: httpReqs?.values?.count || 0,
      total_failed: httpReqFailed?.values?.passes || 0,
      failure_rate: httpReqFailed?.values?.rate ?? -1,
      avg_latency_ms: httpReqDur?.values?.avg ?? -1,
      min_latency_ms: httpReqDur?.values?.min ?? -1,
      med_latency_ms: httpReqDur?.values?.med ?? -1,
      p90_latency_ms: httpReqDur?.values?.['p(90)'] ?? -1,
      p95_latency_ms: httpReqDur?.values?.['p(95)'] ?? -1,
      p99_latency_ms: httpReqDur?.values?.['p(99)'] ?? -1,
      max_latency_ms: httpReqDur?.values?.max ?? -1,
    },
    thresholds: {},
    per_service: {},
    slo_passed: true,
  };

  for (const [metricName, metric] of Object.entries(data.metrics)) {
    if (metric.type === 'rate') {
      report.per_service[metricName] = {
        type: 'rate',
        rate: metric.values?.rate ?? -1,
        passes: metric.values?.passes ?? 0,
        fails: metric.values?.fails ?? 0,
      };
    }
    if (metric.type === 'trend') {
      report.per_service[metricName] = {
        type: 'trend',
        avg: metric.values?.avg ?? -1,
        min: metric.values?.min ?? -1,
        med: metric.values?.med ?? -1,
        p90: metric.values?.['p(90)'] ?? -1,
        p95: metric.values?.['p(95)'] ?? -1,
        p99: metric.values?.['p(99)'] ?? -1,
        max: metric.values?.max ?? -1,
      };
    }
    if (metric.type === 'counter') {
      report.per_service[metricName] = {
        type: 'counter',
        count: metric.values?.count ?? 0,
        rate: metric.values?.rate ?? -1,
      };
    }
  }

  if (data.metrics?.thresholds) {
    for (const [metricName, threshold] of Object.entries(data.metrics.thresholds)) {
      report.thresholds[metricName] = {
        threshold: data.metrics.thresholds[metricName]?.threshold ?? '',
        passed: threshold?.ok ?? false,
      };
      if (!report.slo_passed && !threshold?.ok) {
        report.slo_passed = false;
      }
    }
  }

  return report;
}

export function makeHandleSummary(testName, options) {
  return function handleSummary(data) {
    const reportData = buildReportData(data, testName);

    const outputs = {
      'stdout': textSummary(data, { indent: '  ', enableColors: true }),
      [`k6-report-${testName}.json`]: JSON.stringify(reportData, null, 2),
    };

    outputs[`k6-report-${testName}.html`] = generateHtmlReport(reportData);

    return outputs;
  };
}

function generateHtmlReport(report) {
  const meta = report.meta;
  const summary = report.summary;

  const sloBadge = report.slo_passed
    ? '<span style="color:#fff;background:#28a745;padding:4px 12px;border-radius:12px;font-weight:bold">PASSED</span>'
    : '<span style="color:#fff;background:#dc3545;padding:4px 12px;border-radius:12px;font-weight:bold">FAILED</span>';

  const thresholdRows = Object.entries(report.thresholds)
    .map(
      ([name, t]) =>
        `<tr><td>${name}</td><td>${t.threshold}</td><td>${t.passed ? '✅' : '❌'}</td></tr>`
    )
    .join('\n');

  const serviceRows = Object.entries(report.per_service)
    .filter(([, m]) => m.type === 'trend')
    .map(
      ([name, m]) =>
        `<tr><td>${name}</td><td>${m.avg.toFixed(2)}</td><td>${m.p95.toFixed(2)}</td><td>${m.p99.toFixed(2)}</td><td>${m.max.toFixed(2)}</td></tr>`
    )
    .join('\n');

  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>k6 Report - ${meta.test_name}</title>
<style>
  body { font-family: -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif; margin: 0; padding: 20px; background: #f8f9fa; color: #333; }
  h1 { color: #1a1a2e; }
  .card { background: #fff; border-radius: 8px; padding: 20px; margin-bottom: 20px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
  table { width: 100%; border-collapse: collapse; }
  th, td { text-align: left; padding: 8px 12px; border-bottom: 1px solid #dee2e6; }
  th { background: #f1f3f5; font-weight: 600; }
  .meta-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px,1fr)); gap: 10px; }
  .meta-item { background: #e9ecef; padding: 8px 12px; border-radius: 4px; }
  .meta-item strong { display: block; font-size: 0.8em; color: #666; }
  .value { font-weight: 700; color: #1a1a2e; }
  .slo-summary { font-size: 1.2em; margin: 10px 0; }
</style>
</head>
<body>
<h1>k6 Performance Report: ${meta.test_name}</h1>
<div class="slo-summary">SLO Gate: ${sloBadge} ${new Date(meta.timestamp).toLocaleString()}</div>

<div class="card">
  <h2>Metadata</h2>
  <div class="meta-grid">
    <div class="meta-item"><strong>Test Name</strong><span class="value">${meta.test_name}</span></div>
    <div class="meta-item"><strong>Timestamp</strong><span class="value">${meta.timestamp}</span></div>
    <div class="meta-item"><strong>Scenario</strong><span class="value">${meta.scenario}</span></div>
    <div class="meta-item"><strong>Namespace</strong><span class="value">${meta.namespace}</span></div>
    <div class="meta-item"><strong>k6 Version</strong><span class="value">${meta.k6_version}</span></div>
  </div>
</div>

<div class="card">
  <h2>Summary</h2>
  <table>
    <tr><th>Metric</th><th>Value</th></tr>
    <tr><td>Total Requests</td><td>${summary.total_requests}</td></tr>
    <tr><td>Failed Requests</td><td>${summary.total_failed}</td></tr>
    <tr><td>Failure Rate</td><td>${(summary.failure_rate * 100).toFixed(2)}%</td></tr>
    <tr><td>Avg Latency</td><td>${summary.avg_latency_ms.toFixed(2)} ms</td></tr>
    <tr><td>p95 Latency</td><td>${summary.p95_latency_ms.toFixed(2)} ms</td></tr>
    <tr><td>p99 Latency</td><td>${summary.p99_latency_ms.toFixed(2)} ms</td></tr>
    <tr><td>Max Latency</td><td>${summary.max_latency_ms.toFixed(2)} ms</td></tr>
  </table>
</div>

<div class="card">
  <h2>Per-Service Latency (ms)</h2>
  <table>
    <tr><th>Metric</th><th>Avg</th><th>p95</th><th>p99</th><th>Max</th></tr>
    ${serviceRows || '<tr><td colspan="5">No trend metrics available</td></tr>'}
  </table>
</div>

<div class="card">
  <h2>Thresholds</h2>
  <table>
    <tr><th>Metric</th><th>Threshold</th><th>Status</th></tr>
    ${thresholdRows || '<tr><td colspan="3">No thresholds evaluated</td></tr>'}
  </table>
</div>
</body>
</html>`;
}
