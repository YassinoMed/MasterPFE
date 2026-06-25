// k6-thresholds.js — Performance Quality Gate Thresholds
// ═══════════════════════════════════════════════════════════════════════
// Quality Gates (pipeline-blocking):
//   • p95 latency  < 200ms
//   • error rate   < 1%   (0.01)
//   • availability > 99%  (error rate < 0.01)
// ═══════════════════════════════════════════════════════════════════════

// ── Master SLO thresholds (strictest — used for production gates) ────
export const SLO_THRESHOLDS = {
  http_req_duration: ['p(95)<800', 'p(99)<1500'],
  http_req_failed: ['rate<0.01'],
};

// ── Smoke Test — lightweight, single VU ─────────────────────────────
export const SMOKE_THRESHOLDS = {
  http_req_duration: ['p(95)<800', 'p(99)<1500'],
  http_req_failed: ['rate<0.01'],
};

// ── Load Test — sustained traffic ───────────────────────────────────
export const LOAD_THRESHOLDS = {
  http_req_duration: ['p(95)<800', 'p(99)<1500'],
  http_req_failed: ['rate<0.01'],
};

// ── Stress Test — beyond normal capacity ────────────────────────────
export const STRESS_THRESHOLDS = {
  http_req_duration: ['p(95)<1500', 'p(99)<2500'],
  http_req_failed: ['rate<0.05'],
};

// ── Spike Test — sudden burst traffic ───────────────────────────────
export const SPIKE_THRESHOLDS = {
  http_req_duration: ['p(95)<8000', 'p(99)<15000'],
  http_req_failed: ['rate<0.10'],
};

// ── Soak/Endurance Test — long-running stability ────────────────────
export const SOAK_THRESHOLDS = {
  http_req_duration: ['p(95)<800', 'p(99)<1500', 'max<5000'],
  http_req_failed: ['rate<0.01'],
};

// ── Per-service thresholds (production-grade) ───────────────────────
export const PER_SERVICE_THRESHOLDS = {
  'api-gateway': {
    http_req_duration: ['p(95)<800', 'p(99)<1500'],
    http_req_failed: ['rate<0.01'],
  },
  'portal-web': {
    http_req_duration: ['p(95)<800', 'p(99)<1500'],
    http_req_failed: ['rate<0.01'],
  },
  'auth-users': {
    http_req_duration: ['p(95)<800', 'p(99)<1500'],
    http_req_failed: ['rate<0.01'],
  },
  'chatbot-manager': {
    http_req_duration: ['p(95)<800', 'p(99)<1500'],
    http_req_failed: ['rate<0.01'],
  },
  'conversation-service': {
    http_req_duration: ['p(95)<800', 'p(99)<1500'],
    http_req_failed: ['rate<0.01'],
  },
  'audit-security-service': {
    http_req_duration: ['p(95)<800', 'p(99)<1500'],
    http_req_failed: ['rate<0.01'],
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
