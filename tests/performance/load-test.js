import http from 'k6/http';
import { check, sleep, group } from 'k6';

// Performance Test — SecureRAG Hub
// Usage: k6 run --vus 100 --duration 60s tests/performance/load-test.js

export const options = {
  stages: [
    { duration: '30s', target: 10 },
    { duration: '1m', target: 100 },
    { duration: '1m', target: 500 },
    { duration: '30s', target: 1000 },
    { duration: '1m', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],
    http_req_failed: ['rate<0.01'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://portal-web.securerag-hub.svc:8081';

export default function () {
  group('Health Check', () => {
    const health = http.get(`${BASE_URL}/health`);
    check(health, { 'status 200': (r) => r.status === 200 });
  });

  group('Dashboard', () => {
    const dashboard = http.get(`${BASE_URL}/`);
    check(dashboard, { 'status 2xx': (r) => r.status >= 200 && r.status < 400 });
  });

  group('API — Users', () => {
    const users = http.get('http://auth-users.securerag-hub.svc:8000/api/v1/health');
    check(users, { 'auth health 200': (r) => r.status === 200 });
  });

  group('API — Chatbots', () => {
    const chatbots = http.get('http://chatbot-manager.securerag-hub.svc:8000/api/v1/health');
    check(chatbots, { 'chatbot health 200': (r) => r.status === 200 });
  });

  sleep(1);
}

export function teardown() {
  console.log('Performance test completed.');
}
