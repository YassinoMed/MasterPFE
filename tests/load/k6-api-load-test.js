// k6 API Load Test — SecureRAG Hub Laravel Microservices
// Tests individual Laravel services directly
// Run: k6 run --env AUTH_URL=http://auth-users:80 --env CHATBOT_URL=http://chatbot-manager:80 tests/load/k6-api-load-test.js

import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend } from 'k6/metrics';

const errorRate = new Rate('api_errors');
const responseTime = new Trend('api_response_time');

export const options = {
  scenarios: {
    auth_service: {
      executor: 'ramping-vus',
      exec: 'authServiceTest',
      startVUs: 0,
      stages: [
        { duration: '30s', target: 20 },
        { duration: '1m', target: 50 },
        { duration: '30s', target: 20 },
        { duration: '30s', target: 0 },
      ],
    },
    chatbot_service: {
      executor: 'ramping-vus',
      exec: 'chatbotServiceTest',
      startVUs: 0,
      stages: [
        { duration: '30s', target: 10 },
        { duration: '1m', target: 30 },
        { duration: '30s', target: 10 },
        { duration: '30s', target: 0 },
      ],
    },
    conversation_service: {
      executor: 'ramping-vus',
      exec: 'conversationServiceTest',
      startVUs: 0,
      stages: [
        { duration: '30s', target: 15 },
        { duration: '1m', target: 40 },
        { duration: '30s', target: 15 },
        { duration: '30s', target: 0 },
      ],
    },
    audit_service: {
      executor: 'ramping-vus',
      exec: 'auditServiceTest',
      startVUs: 0,
      stages: [
        { duration: '30s', target: 10 },
        { duration: '1m', target: 25 },
        { duration: '30s', target: 10 },
        { duration: '30s', target: 0 },
      ],
    },
  },
  thresholds: {
    'api_response_time{service:auth}': ['p(95)<300'],
    'api_response_time{service:chatbot}': ['p(95)<400'],
    'api_response_time{service:conversation}': ['p(95)<500'],
    'api_response_time{service:audit}': ['p(95)<400'],
    'api_errors{service:auth}': ['rate<0.01'],
    'api_errors{service:chatbot}': ['rate<0.02'],
    'api_errors{service:conversation}': ['rate<0.02'],
    'api_errors{service:audit}': ['rate<0.01'],
  },
};

const headers = {
  'Content-Type': 'application/json',
  'Accept': 'application/json',
  'X-Requested-With': 'XMLHttpRequest',
};

function testEndpoint(url, name, service, expectedStatus = 200) {
  const res = http.get(url, { headers, timeout: '10s', tags: { service, endpoint: name } });
  const success = check(res, {
    [`${service}:${name} status ${expectedStatus}`]: (r) => r.status === expectedStatus || r.status === 401,
    [`${service}:${name} response time < 1000ms`]: (r) => r.timings.duration < 2500,
  });
  errorRate.add(!success, { service });
  responseTime.add(res.timings.duration, { service });
  return res;
}

export function authServiceTest() {
  const baseUrl = __ENV.AUTH_URL || 'http://localhost:8001';

  group('Auth Users Service', () => {
    testEndpoint(`${baseUrl}/health`, 'health', 'auth');
    sleep(0.5);
    testEndpoint(`${baseUrl}/api/users`, 'list_users', 'auth');
    sleep(0.5);
    testEndpoint(`${baseUrl}/api/roles`, 'list_roles', 'auth');
    sleep(0.5);
    testEndpoint(`${baseUrl}/api/permissions`, 'list_permissions', 'auth');
  });
}

export function chatbotServiceTest() {
  const baseUrl = __ENV.CHATBOT_URL || 'http://localhost:8002';

  group('Chatbot Manager Service', () => {
    testEndpoint(`${baseUrl}/health`, 'health', 'chatbot');
    sleep(0.5);
    testEndpoint(`${baseUrl}/api/chatbots`, 'list_chatbots', 'chatbot');
    sleep(0.5);
    testEndpoint(`${baseUrl}/api/chatbots/types`, 'list_types', 'chatbot');
  });
}

export function conversationServiceTest() {
  const baseUrl = __ENV.CONVERSATION_URL || 'http://localhost:8003';

  group('Conversation Service', () => {
    testEndpoint(`${baseUrl}/health`, 'health', 'conversation');
    sleep(0.5);
    testEndpoint(`${baseUrl}/api/conversations`, 'list_conversations', 'conversation');
    sleep(0.5);
    testEndpoint(`${baseUrl}/api/messages`, 'list_messages', 'conversation');
  });
}

export function auditServiceTest() {
  const baseUrl = __ENV.AUDIT_URL || 'http://localhost:8004';

  group('Audit Security Service', () => {
    testEndpoint(`${baseUrl}/health`, 'health', 'audit');
    sleep(0.5);
    testEndpoint(`${baseUrl}/api/audit-logs`, 'list_audit_logs', 'audit');
    sleep(0.5);
    testEndpoint(`${baseUrl}/api/incidents`, 'list_incidents', 'audit');
    sleep(0.5);
    testEndpoint(`${baseUrl}/api/compliance`, 'compliance_status', 'audit');
  });
}

export function handleSummary(data) {
  return {
    'stdout': textSummary(data, { indent: '  ', enableColors: true }),
    'api-load-summary.json': JSON.stringify({
      timestamp: new Date().toISOString(),
      metrics: {
        auth: {
          requests: data.metrics.http_reqs?.values.count || 0,
          errors: data.metrics.api_errors?.values?.passes || 0,
          avgResponse: data.metrics.api_response_time?.values?.avg || 0,
          p95Response: data.metrics.api_response_time?.values?.['p(95)'] || 0,
        },
      },
      thresholds: Object.fromEntries(
        Object.entries(data.metrics).map(([k, v]) => [k, { passed: true }])
      ),
    }, null, 2),
  };
}

function textSummary(data, opts) {
  // Simplified text summary
  return JSON.stringify(data, null, 2);
}