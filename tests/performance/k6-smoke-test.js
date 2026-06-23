import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';
import { getBaseUrl, HEADERS, TIMEOUT, SERVICE_HEALTH_PATHS } from './k6-config.js';
import { SMOKE_THRESHOLDS } from './k6-thresholds.js';
import { makeHandleSummary } from './k6-report.js';

const smokeErrorRate = new Rate('smoke_errors');
const smokeTrend = new Trend('smoke_duration');

const SERVICES = [
  'api-gateway',
  'portal-web',
  'auth-users',
  'chatbot-manager',
  'conversation-service',
  'audit-security-service',
];

export const options = {
  vus: 1,
  duration: '30s',
  thresholds: SMOKE_THRESHOLDS,
  tags: { test_name: 'smoke' },
};

export default function () {
  for (const name of SERVICES) {
    const baseUrl = getBaseUrl(name);
    const path = SERVICE_HEALTH_PATHS[name] || '/health';
    const url = `${baseUrl}${path}`;

    const res = http.get(url, {
      headers: HEADERS,
      timeout: TIMEOUT,
      tags: { service: name, endpoint: 'health' },
    });

    const passed = check(res, {
      [`${name} health status 200`]: (r) => r.status === 200,
      [`${name} health duration < 1s`]: (r) => r.timings.duration < 1000,
    });

    smokeErrorRate.add(!passed);
    smokeTrend.add(res.timings.duration);

    sleep(0.1);
  }
}

export const handleSummary = makeHandleSummary('smoke', options);
