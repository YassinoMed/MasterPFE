import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend } from 'k6/metrics';
import { getBaseUrl, HEADERS, TIMEOUT, allServices, SERVICE_HEALTH_PATHS } from './k6-config.js';
import { LOAD_THRESHOLDS } from './k6-thresholds.js';
import { makeHandleSummary } from './k6-report.js';

const durationTrend = new Trend('request_duration');
const errorRate = new Rate('request_errors');

export const options = {
  scenarios: {
    load: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '1m', target: 25 },
        { duration: '3m', target: 50 },
        { duration: '1m', target: 0 },
      ],
      tags: { test_type: 'load', test_name: 'load' },
      gracefulStop: '30s',
    },
  },
  thresholds: LOAD_THRESHOLDS,
};

function healthCheck(serviceName) {
  const baseUrl = getBaseUrl(serviceName);
  const path = SERVICE_HEALTH_PATHS[serviceName] || '/health';
  const url = `${baseUrl}${path}`;

  const res = http.get(url, {
    headers: HEADERS,
    timeout: TIMEOUT,
    tags: { service: serviceName, endpoint: 'health' },
  });

  const passed = check(res, {
    [`${serviceName} health 200`]: (r) => r.status === 200,
    [`${serviceName} duration < 500ms`]: (r) => r.timings.duration < 500,
  });

  errorRate.add(!passed, { service: serviceName });
  durationTrend.add(res.timings.duration, { service: serviceName });

  return res;
}

function apiEndpoints() {
  const endpoints = [

    { service: 'portal-web', path: '/' },
    { service: 'auth-users', path: '/api/v1/users' },
    { service: 'chatbot-manager', path: '/api/v1/chatbots' },
    { service: 'conversation-service', path: '/api/v1/conversations' },
    { service: 'audit-security-service', path: '/api/v1/audit-logs' },
  ];

  for (const ep of endpoints) {
    const baseUrl = getBaseUrl(ep.service);
    const url = `${baseUrl}${ep.path}`;

    const res = http.get(url, {
      headers: HEADERS,
      timeout: TIMEOUT,
      tags: { service: ep.service, endpoint: ep.path },
    });

    const passed = check(res, {
      [`${ep.service} ${ep.path} 2xx`]: (r) => r.status >= 200 && r.status < 500,
      [`${ep.service} ${ep.path} duration < 1s`]: (r) => r.timings.duration < 1000,
    });

    errorRate.add(!passed, { service: ep.service });
    durationTrend.add(res.timings.duration, { service: ep.service });
  }
}

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
  return { servicesUp: results };
}

export default function (data) {
  if (!data.servicesUp.every((s) => s.healthy)) {
    const down = data.servicesUp.filter((s) => !s.healthy).map((s) => s.name);
    throw new Error(`Services down: ${down.join(', ')}`);
  }

  group('Health Checks', () => {
    for (const svc of allServices()) {
      healthCheck(svc.name);
      sleep(0.2);
    }
  });

  sleep(1);

  group('API Endpoints', () => {
    apiEndpoints();
  });

  sleep(1);
}

export const handleSummary = makeHandleSummary('load', options);
