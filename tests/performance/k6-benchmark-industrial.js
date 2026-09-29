import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

var errorRate = new Rate('errors');
var latencyGW = new Trend('latency_gateway');
var latencySECAI = new Trend('latency_secai_health');
var latencyLLM = new Trend('latency_llm_analyze');
var requestsTotal = new Counter('requests_total');

var BASE_GW = __ENV.BASE_GW || 'http://localhost:18040';
var BASE_SECAI = __ENV.BASE_SECAI || 'http://localhost:18001';
var AUTH_TOKEN = __ENV.AUTH_TOKEN || '';

export const options = {
  scenarios: {
    smoke: {
      executor: 'constant-vus',
      vus: 1,
      duration: '30s',
      tags: { scenario: 'smoke' }
    },
    ramp_up: {
      executor: 'ramping-vus',
      startVUs: 1,
      stages: [
        { duration: '30s', target: 10 },
        { duration: '30s', target: 20 },
        { duration: '30s', target: 50 },
        { duration: '30s', target: 0 }
      ],
      gracefulRampDown: '10s',
      startTime: '35s',
      tags: { scenario: 'ramp_up' }
    }
  },
  thresholds: {
    'http_req_duration{scenario:smoke}': ['p(99)<500'],
    'http_req_duration{scenario:ramp_up}': ['p(95)<1000'],
    'errors': ['rate<0.05']
  }
};

export function setup() {
  console.log('Gateway: ' + BASE_GW);
  console.log('SECAI: ' + BASE_SECAI);
  var gwRes = http.get(BASE_GW + '/v1/models', {
    headers: { Authorization: 'Bearer ' + AUTH_TOKEN }
  });
  check(gwRes, { 'gateway reachable': function(r) { return r.status === 200 || r.status === 401; } });
  var secaiRes = http.get(BASE_SECAI + '/health');
  check(secaiRes, { 'secai reachable': function(r) { return r.status === 200; } });
  return { token: AUTH_TOKEN };
}

export default function(data) {
  var headers = {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ' + data.token
  };

  var secaiRes = http.get(BASE_SECAI + '/health');
  latencySECAI.add(secaiRes.timings.duration);
  errorRate.add(secaiRes.status !== 200);
  requestsTotal.add(1);

  var gwRes = http.get(BASE_GW + '/v1/models', { headers: headers });
  latencyGW.add(gwRes.timings.duration);
  errorRate.add(gwRes.status !== 200 && gwRes.status !== 401);
  requestsTotal.add(1);

  var llmRes = http.post(
    BASE_SECAI + '/llm/analyze',
    JSON.stringify({
      prompt: 'Analyze this security report: CVE-2023-49103 HIGH in libcrypt',
      client_id: 'k6-vu-' + __VU
    }),
    { headers: { 'Content-Type': 'application/json' } }
  );
  latencyLLM.add(llmRes.timings.duration);
  errorRate.add(llmRes.status !== 200 && llmRes.status !== 429);
  requestsTotal.add(1);

  sleep(0.5);
}

export function handleSummary(data) {
  var lines = [];
  lines.push('');
  lines.push('========================================================');
  lines.push('  BENCHMARK INDUSTRIEL - SecureRAG Hub AI Stack');
  lines.push('========================================================');

  var m = data.metrics;
  if (m.http_req_duration && m.http_req_duration.values) {
    lines.push('  http_req_duration:');
    lines.push('    avg=' + m.http_req_duration.values.avg + 'ms');
    lines.push('    p50=' + m.http_req_duration.values.med + 'ms');
    lines.push('    p95=' + m.http_req_duration.values['p(95)'] + 'ms');
    lines.push('    p99=' + m.http_req_duration.values['p(99)'] + 'ms');
  }
  if (m.latency_gateway && m.latency_gateway.values) {
    lines.push('  latency_gateway:');
    lines.push('    avg=' + m.latency_gateway.values.avg + 'ms');
    lines.push('    p95=' + m.latency_gateway.values['p(95)'] + 'ms');
  }
  if (m.latency_secai_health && m.latency_secai_health.values) {
    lines.push('  latency_secai_health:');
    lines.push('    avg=' + m.latency_secai_health.values.avg + 'ms');
    lines.push('    p95=' + m.latency_secai_health.values['p(95)'] + 'ms');
  }
  if (m.latency_llm_analyze && m.latency_llm_analyze.values) {
    lines.push('  latency_llm_analyze:');
    lines.push('    avg=' + m.latency_llm_analyze.values.avg + 'ms');
    lines.push('    p95=' + m.latency_llm_analyze.values['p(95)'] + 'ms');
  }
  if (m.errors && m.errors.values) {
    lines.push('  error_rate: ' + (m.errors.values.rate * 100).toFixed(2) + '%');
  }
  if (m.http_reqs && m.http_reqs.values) {
    lines.push('  total_requests: ' + m.http_reqs.values.count);
    lines.push('  total_rps: ' + m.http_reqs.values.rate);
  }

  lines.push('========================================================');

  return {
    stdout: lines.join('\n'),
    'reports/k6/benchmark-results.json': JSON.stringify(data, null, 2)
  };
}
