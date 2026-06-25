import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend } from 'k6/metrics';
import { getBaseUrl, HEADERS, TIMEOUT, allServices, SERVICE_HEALTH_PATHS } from './k6-config.js';
import { SPIKE_THRESHOLDS } from './k6-thresholds.js';
import { makeHandleSummary } from './k6-report.js';

const spikeErrorRate = new Rate('spike_errors');
const spikeTrend = new Trend('spike_duration');

export const options = {
  scenarios: {
    spike: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '30s', target: 1000 },
        { duration: '1m', target: 1000 },
        { duration: '30s', target: 0 },
      ],
      tags: { test_type: 'spike', test_name: 'spike' },
      gracefulStop: '30s',
    },
  },
  thresholds: SPIKE_THRESHOLDS,
};

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
  return { servicesUp: results, allHealthy };
}

export default function (data) {
  if (!data.allHealthy) {
    const down = data.servicesUp.filter((s) => !s.healthy).map((s) => s.name);
    throw new Error(`Pre-check failed — services down: ${down.join(', ')}`);
  }

  group('Spike - Health Check All Services', () => {
    for (const svc of allServices()) {
      const url = `${svc.url}${SERVICE_HEALTH_PATHS[svc.name] || '/health'}`;
      const res = http.get(url, {
        headers: HEADERS,
        timeout: TIMEOUT,
        tags: { service: svc.name, endpoint: 'health' },
      });

      const passed = check(res, {
        [`${svc.name} spike health 200`]: (r) => r.status === 200,
        [`${svc.name} spike duration < 2s`]: (r) => r.timings.duration < 2000,
      });

      spikeErrorRate.add(!passed, { service: svc.name });
      spikeTrend.add(res.timings.duration, { service: svc.name });

      sleep(0.05);
    }
  });

  sleep(0.5);

  group('Spike - API Endpoints', () => {
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
        [`${ep.service} spike ${ep.path} 2xx`]: (r) => r.status >= 200 && r.status < 500,
        [`${ep.service} spike ${ep.path} duration < 3s`]: (r) => r.timings.duration < 3000,
      });

      spikeErrorRate.add(!passed, { service: ep.service });
      spikeTrend.add(res.timings.duration, { service: ep.service });
    }
  });
}

export const handleSummary = makeHandleSummary('spike', options);
