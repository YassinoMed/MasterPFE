export const SLO_THRESHOLDS = {
  http_req_duration: ['p(95)<500', 'p(99)<1000'],
  http_req_failed: ['rate<0.001'],
};

export const SMOKE_THRESHOLDS = {
  http_req_duration: ['p(95)<1000', 'p(99)<2000'],
  http_req_failed: ['rate<0.01'],
};

export const LOAD_THRESHOLDS = {
  http_req_duration: ['p(95)<500', 'p(99)<1000'],
  http_req_failed: ['rate<0.001'],
};

export const STRESS_THRESHOLDS = {
  http_req_duration: ['p(95)<1000', 'p(99)<2000'],
  http_req_failed: ['rate<0.005'],
};

export const SPIKE_THRESHOLDS = {
  http_req_duration: ['p(95)<2000', 'p(99)<3000'],
  http_req_failed: ['rate<0.01'],
};

export const SOAK_THRESHOLDS = {
  http_req_duration: ['p(95)<500', 'p(99)<1000'],
  http_req_failed: ['rate<0.001'],
};

export const PER_SERVICE_THRESHOLDS = {
  'api-gateway': {
    http_req_duration: ['p(95)<300', 'p(99)<500'],
    http_req_failed: ['rate<0.001'],
  },
  'portal-web': {
    http_req_duration: ['p(95)<500', 'p(99)<1000'],
    http_req_failed: ['rate<0.001'],
  },
  'auth-users': {
    http_req_duration: ['p(95)<400', 'p(99)<800'],
    http_req_failed: ['rate<0.001'],
  },
  'chatbot-manager': {
    http_req_duration: ['p(95)<500', 'p(99)<1000'],
    http_req_failed: ['rate<0.001'],
  },
  'conversation-service': {
    http_req_duration: ['p(95)<500', 'p(99)<1000'],
    http_req_failed: ['rate<0.001'],
  },
  'audit-security-service': {
    http_req_duration: ['p(95)<400', 'p(99)<800'],
    http_req_failed: ['rate<0.001'],
  },
};

export function mergeThresholds(...thresholdSets) {
  const merged = {};
  for (const set of thresholdSets) {
    for (const [key, arr] of Object.entries(set)) {
      if (!merged[key]) merged[key] = [];
      merged[key].push(...arr);
    }
  }
  return merged;
}
