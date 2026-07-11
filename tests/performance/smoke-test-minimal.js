import http from 'k6/http';
import { check, sleep } from 'k6';
import { getBaseUrl, HEADERS, TIMEOUT } from './k6-config.js';

export const options = {
  vus: 10,
  duration: '30s',
  thresholds: {
    // SLO: 95% of requests must complete under 800ms
    http_req_duration: ['p(95)<800'],
    // SLO: Error rate must be under 1%
    http_req_failed: ['rate<0.01'],
  },
};

export default function () {
  const authUrl = getBaseUrl('auth-users');
  const chatbotUrl = getBaseUrl('chatbot-manager');

  // 1. Validate auth-users health endpoint
  const authHealth = http.get(`${authUrl}/api/v1/health`, { headers: HEADERS, timeout: TIMEOUT });
  check(authHealth, {
    'auth-users is healthy (200)': (r) => r.status === 200,
  });

  // 2. Validate chatbot-manager health endpoint
  const chatbotHealth = http.get(`${chatbotUrl}/api/v1/health`, { headers: HEADERS, timeout: TIMEOUT });
  check(chatbotHealth, {
    'chatbot-manager is healthy (200)': (r) => r.status === 200,
  });

  // 3. Simulation of a lightweight public API call
  const chatbotsList = http.get(`${chatbotUrl}/api/v1/chatbots`, { headers: HEADERS, timeout: TIMEOUT });
  check(chatbotsList, {
    'get chatbots returns 2xx/401': (r) => r.status === 200 || r.status === 401,
  });

  sleep(1); // Real-world pacing think time (1s)
}
