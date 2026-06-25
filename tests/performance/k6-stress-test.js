import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';
import { getBaseUrl, HEADERS, TIMEOUT, allServices, SERVICE_HEALTH_PATHS } from './k6-config.js';
import { STRESS_THRESHOLDS } from './k6-thresholds.js';
import { makeHandleSummary } from './k6-report.js';

// ═══════════════════════════════════════════════════════════════════════
// k6 Stress Test — SecureRAG Hub
// ═══════════════════════════════════════════════════════════════════════
// Purpose: Determine the system's breaking point by progressively
//          increasing load beyond normal operating capacity.
//
// Pattern:
//   0 → 50 VUs (1m) → 100 VUs (2m) → 200 VUs (2m) → 300 VUs (1m) → 0
//
// Quality Gates (stress-specific):
//   • p95 < 500ms
//   • error rate < 5%
//   • availability > 95%
// ═══════════════════════════════════════════════════════════════════════

const stressErrorRate = new Rate('stress_errors');
const stressTrend = new Trend('stress_duration');
const stressRequests = new Counter('stress_total_requests');

export const options = {
  scenarios: {
    stress_rampup: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '1m', target: 50 },     // Ramp to normal load
        { duration: '2m', target: 100 },    // Beyond normal
        { duration: '2m', target: 200 },    // Stress zone
        { duration: '1m', target: 300 },    // Breaking point probe
        { duration: '1m', target: 0 },      // Recovery
      ],
      tags: { test_type: 'stress', test_name: 'stress' },
      gracefulStop: '30s',
    },
  },
  thresholds: Object.assign({}, STRESS_THRESHOLDS, {
    stress_errors: ['rate<0.05'],
    stress_duration: ['p(95)<500', 'p(99)<1000'],
    iterations: ['count>100'],
  }),
};

const API_ENDPOINTS = [
  { service: 'portal-web', path: '/' },
  { service: 'auth-users', path: '/api/v1/users' },
  { service: 'chatbot-manager', path: '/api/v1/chatbots' },
  { service: 'conversation-service', path: '/api/v1/conversations' },
  { service: 'audit-security-service', path: '/api/v1/audit-logs' },
];

export function setup() {
  const results = [];
  for (const svc of allServices()) {
    try {
      const path = SERVICE_HEALTH_PATHS[svc.name] || '/health';
      const res = http.get(`${svc.url}${path}`, {
        headers: HEADERS,
        timeout: '10s',
      });
      results.push({ name: svc.name, healthy: res.status === 200 });
    } catch {
      results.push({ name: svc.name, healthy: false });
    }
  }

  const allHealthy = results.every((s) => s.healthy);
  console.log(`[Stress] Setup: ${results.filter((s) => s.healthy).length}/${results.length} services healthy`);
  return { servicesUp: results, allHealthy, startTime: Date.now() };
}

export default function (data) {
  if (!data.allHealthy) {
    const down = data.servicesUp.filter((s) => !s.healthy).map((s) => s.name);
    throw new Error(`Pre-check failed — services down: ${down.join(', ')}`);
  }

  // ── Health checks under stress ──────────────────────────────────
  group('Stress - Health Checks', () => {
    for (const svc of allServices()) {
      const url = `${svc.url}${SERVICE_HEALTH_PATHS[svc.name] || '/health'}`;
      const res = http.get(url, {
        headers: HEADERS,
        timeout: TIMEOUT,
        tags: { service: svc.name, endpoint: 'health' },
      });

      const passed = check(res, {
        [`${svc.name} stress health 2xx`]: (r) => r.status >= 200 && r.status < 400,
        [`${svc.name} stress duration < 500ms`]: (r) => r.timings.duration < 500,
      });

      stressErrorRate.add(!passed, { service: svc.name });
      stressTrend.add(res.timings.duration, { service: svc.name });
      stressRequests.add(1, { service: svc.name });

      sleep(0.05);
    }
  });

  sleep(0.5);

  // ── API endpoints under stress ──────────────────────────────────
  group('Stress - API Endpoints', () => {
    for (const ep of API_ENDPOINTS) {
      const baseUrl = getBaseUrl(ep.service);
      const res = http.get(`${baseUrl}${ep.path}`, {
        headers: HEADERS,
        timeout: TIMEOUT,
        tags: { service: ep.service, endpoint: ep.path },
      });

      const passed = check(res, {
        [`${ep.service} stress ${ep.path} 2xx`]: (r) => r.status >= 200 && r.status < 500,
        [`${ep.service} stress ${ep.path} duration < 1s`]: (r) => r.timings.duration < 1000,
      });

      stressErrorRate.add(!passed, { service: ep.service });
      stressTrend.add(res.timings.duration, { service: ep.service });
      stressRequests.add(1, { service: ep.service });
    }
  });

  sleep(0.5);
}

export function teardown(data) {
  const elapsed = (Date.now() - data.startTime) / 1000;
  console.log(`[Stress] Completed in ${elapsed.toFixed(1)}s`);

  if (data.servicesUp.some((s) => !s.healthy)) {
    console.warn('[Stress] Some services were unhealthy during setup');
  }
}

export const handleSummary = makeHandleSummary('stress', options);
