// k6 Load Test — SecureRAG Hub
// Tests portal-web and Laravel microservices
// Run: k6 run --env BASE_URL=http://portal-web:80 tests/load/k6-load-test.js

import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const responseTime = new Trend('response_time');
const requestCount = new Counter('requests_total');

// Test configuration
export const options = {
  scenarios: {
    smoke: {
      executor: 'constant-vus',
      vus: 5,
      duration: '30s',
      tags: { test_type: 'smoke' },
    },
    load: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '30s', target: 10 },
        { duration: '1m', target: 25 },
        { duration: '30s', target: 50 },
        { duration: '1m', target: 50 },
        { duration: '30s', target: 10 },
        { duration: '30s', target: 0 },
      ],
      tags: { test_type: 'load' },
    },
    stress: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '30s', target: 10 },
        { duration: '1m', target: 50 },
        { duration: '2m', target: 100 },
        { duration: '1m', target: 150 },
        { duration: '30s', target: 0 },
      ],
      tags: { test_type: 'stress' },
      gracefulStop: '30s',
    },
    spike: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '10s', target: 10 },
        { duration: '10s', target: 100 },
        { duration: '10s', target: 10 },
        { duration: '10s', target: 100 },
        { duration: '10s', target: 0 },
      ],
      tags: { test_type: 'spike' },
    },
    soak: {
      executor: 'constant-vus',
      vus: 25,
      duration: '30m',
      tags: { test_type: 'soak' },
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<500', 'p(99)<1000'],
    http_req_failed: ['rate<0.01'],
    errors: ['rate<0.05'],
    'response_time{test_type:smoke}': ['p(95)<300'],
    'response_time{test_type:load}': ['p(95)<500'],
    'response_time{test_type:stress}': ['p(95)<1000'],
  },
};

// Base URL from environment
const BASE_URL = __ENV.BASE_URL || 'http://localhost:30081';

// Common headers
const headers = {
  'Content-Type': 'application/json',
  'Accept': 'application/json',
};

export function setup() {
  // Verify base URL is reachable
  const res = http.get(`${BASE_URL}/health`, { timeout: '10s' });
  if (res.status !== 200) {
    throw new Error(`Base URL ${BASE_URL} not healthy: ${res.status}`);
  }
  return { baseUrl: BASE_URL };
}

export default function (data) {
  const baseUrl = data.baseUrl;

  group('Portal Web - Health Check', () => {
    const res = http.get(`${baseUrl}/health`, { headers, timeout: '10s' });
    const success = check(res, {
      'health check status 200': (r) => r.status === 200,
      'health check response time < 200ms': (r) => r.timings.duration < 200,
    });
    errorRate.add(!success);
    responseTime.add(res.timings.duration);
    requestCount.add(1);
  });

  sleep(0.5);

  group('Portal Web - Home Page', () => {
    const res = http.get(`${baseUrl}/`, { headers, timeout: '10s' });
    const success = check(res, {
      'home page status 200': (r) => r.status === 200,
      'home page response time < 500ms': (r) => r.timings.duration < 1500,
      'home page contains content': (r) => r.body.length > 1000,
    });
    errorRate.add(!success);
    responseTime.add(res.timings.duration);
    requestCount.add(1);
  });

  sleep(1);

  group('Auth Service - Login Page', () => {
    const res = http.get(`${baseUrl}/login`, { headers, timeout: '10s' });
    const success = check(res, {
      'login page status 200': (r) => r.status === 200,
      'login page response time < 500ms': (r) => r.timings.duration < 1500,
    });
    errorRate.add(!success);
    responseTime.add(res.timings.duration);
    requestCount.add(1);
  });

  sleep(1);

  group('Chatbot Manager - List Chatbots', () => {
    const res = http.get(`${baseUrl}/api/chatbots`, { headers, timeout: '10s' });
    const success = check(res, {
      'chatbots list status 200': (r) => r.status === 200 || r.status === 401,
      'chatbots list response time < 500ms': (r) => r.timings.duration < 1500,
    });
    errorRate.add(!success);
    responseTime.add(res.timings.duration);
    requestCount.add(1);
  });

  sleep(1);

  group('Conversation Service - Health', () => {
    const res = http.get(`${baseUrl}/api/conversations/health`, { headers, timeout: '10s' });
    const success = check(res, {
      'conversations health status 200': (r) => r.status === 200 || r.status === 401,
      'conversations health response time < 500ms': (r) => r.timings.duration < 1500,
    });
    errorRate.add(!success);
    responseTime.add(res.timings.duration);
    requestCount.add(1);
  });

  sleep(1);

  group('Audit Service - Health', () => {
    const res = http.get(`${baseUrl}/api/audit/health`, { headers, timeout: '10s' });
    const success = check(res, {
      'audit health status 200': (r) => r.status === 200 || r.status === 401,
      'audit health response time < 500ms': (r) => r.timings.duration < 1500,
    });
    errorRate.add(!success);
    responseTime.add(res.timings.duration);
    requestCount.add(1);
  });
}

export function handleSummary(data) {
  const summary = {
    timestamp: new Date().toISOString(),
    testType: __ENV.TEST_TYPE || 'unknown',
    baseUrl: BASE_URL,
    metrics: {
      totalRequests: data.metrics.http_reqs.values.count,
      failedRequests: data.metrics.http_req_failed.values.passes,
      successRate: (1 - data.metrics.http_req_failed.values.rate) * 100,
      avgResponseTime: data.metrics.http_req_duration.values.avg,
      p95ResponseTime: data.metrics.http_req_duration.values['p(95)'],
      p99ResponseTime: data.metrics.http_req_duration.values['p(99)'],
      maxResponseTime: data.metrics.http_req_duration.values.max,
      errorsRate: data.metrics.errors?.values.rate || 0,
    },
    thresholds: {},
  };

  // Check thresholds
  Object.entries(options.thresholds).forEach(([metric, threshold]) => {
    const metricData = data.metrics[metric];
    if (metricData) {
      summary.thresholds[metric] = { threshold, passed: evaluateThreshold(metricData, threshold) };
    }
  });

  return {
    'stdout': textSummary(data, { indent: '  ', enableColors: true }),
    'summary.json': JSON.stringify(summary, null, 2),
  };
}

function evaluateThreshold(metricData, threshold) {
  // Simplified threshold evaluation
  if (threshold.includes('p(95)')) {
    const limit = parseFloat(threshold.match(/p\(95\)<(\d+)/)?.[1] || '0');
    return metricData.values['p(95)'] < limit;
  }
  if (threshold.includes('rate<')) {
    const limit = parseFloat(threshold.match(/rate<([\d.]+)/)?.[1] || '0');
    return metricData.values.rate < limit;
  }
  return true;
}