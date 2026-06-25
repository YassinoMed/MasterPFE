import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend, Gauge } from 'k6/metrics';
import { getBaseUrl, HEADERS, TIMEOUT, allServices, SERVICE_HEALTH_PATHS } from './k6-config.js';
import { SOAK_THRESHOLDS } from './k6-thresholds.js';
import { makeHandleSummary } from './k6-report.js';

const endurErrorRate = new Rate('endurance_errors');
const endurTrend = new Trend('endurance_duration');
const endurMemoryGauge = new Gauge('endurance_memory_samples');

export const options = {
  scenarios: {
    endurance: {
      executor: 'constant-vus',
      vus: 50,
      duration: '30m',
      tags: { test_type: 'endurance', test_name: 'endurance' },
    },
  },
  thresholds: Object.assign({}, SOAK_THRESHOLDS, {
    http_req_duration: ['p(95)<500', 'p(99)<1000', 'max<5000'],
    http_req_failed: ['rate<0.001'],
    iterations: ['count>100'],
  }),
};

let iterationCount = 0;

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
  return { servicesUp: results, startTime: Date.now() };
}

export default function (data) {
  if (!data.servicesUp.every((s) => s.healthy)) {
    return;
  }

  iterationCount++;

  group(`Endurance #${iterationCount} - Health Checks`, () => {
    for (const svc of allServices()) {
      const url = `${svc.url}${SERVICE_HEALTH_PATHS[svc.name] || '/health'}`;
      const res = http.get(url, {
        headers: HEADERS,
        timeout: TIMEOUT,
        tags: { service: svc.name, endpoint: 'health' },
      });

      const passed = check(res, {
        [`${svc.name} endurance health 200`]: (r) => r.status === 200,
        [`${svc.name} endurance duration < 1500ms`]: (r) => r.timings.duration < 1500,
      });

      endurErrorRate.add(!passed, { service: svc.name });
      endurTrend.add(res.timings.duration, { service: svc.name });
      endurMemoryGauge.add(res.timings.duration);

      sleep(0.1);
    }
  });

  sleep(1);

  group(`Endurance #${iterationCount} - API Endpoints`, () => {
    const endpoints = [
      { service: 'portal-web', path: '/' },
      { service: 'auth-users', path: '/api/v1/users' },
      { service: 'chatbot-manager', path: '/api/v1/chatbots' },
      { service: 'conversation-service', path: '/api/v1/conversations' },
      { service: 'audit-security-service', path: '/api/v1/audit-logs' },
    ];

    for (const ep of endpoints) {
      const baseUrl = getBaseUrl(ep.service);
      const res = http.get(`${baseUrl}${ep.path}`, {
        headers: HEADERS,
        timeout: TIMEOUT,
        tags: { service: ep.service, endpoint: ep.path },
      });

      const passed = check(res, {
        [`${ep.service} endurance ${ep.path} 2xx`]: (r) => r.status >= 200 && r.status < 500,
        [`${ep.service} endurance ${ep.path} duration < 2.5s`]: (r) => r.timings.duration < 2500,
      });

      endurErrorRate.add(!passed, { service: ep.service });
      endurTrend.add(res.timings.duration, { service: ep.service });

      sleep(0.1);
    }
  });

  sleep(2);

  if (iterationCount % 10 === 0) {
    console.log(
      `[Endurance] Iteration ${iterationCount} at ${new Date().toISOString()} ` +
      `- elapsed: ${(Date.now() - data.startTime) / 1000}s`
    );
  }
}

export function teardown(data) {
  const elapsed = (Date.now() - data.startTime) / 1000;
  console.log(`[Endurance] Completed ${iterationCount} iterations in ${elapsed}s`);

  if (data.servicesUp.some((s) => !s.healthy)) {
    console.warn('[Endurance] Some services were unhealthy during setup');
  }
}

export const handleSummary = makeHandleSummary('endurance', options);
