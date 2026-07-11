import { makeHandleSummary } from './k6-report.js';
import {
  anonymousWorkflow,
  authenticatedWorkflow,
  powerWorkflow,
  attackerWorkflow
} from './campaign-workflows.js';

export const options = {
  discardResponseBodies: true,
  scenarios: {
    anonymous_users: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '1m', target: 53 },
        { duration: '1m', target: 105 },
        { duration: '1m', target: 158 },
        { duration: '1m', target: 210 },
        { duration: '5m', target: 210 },
        { duration: '2m', target: 0 },
      ],
      exec: 'anonRun',
      tags: { role: 'anonymous' },
    },
    authenticated_users: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '1m', target: 88 },
        { duration: '1m', target: 175 },
        { duration: '1m', target: 263 },
        { duration: '1m', target: 350 },
        { duration: '5m', target: 350 },
        { duration: '2m', target: 0 },
      ],
      exec: 'authRun',
      tags: { role: 'authenticated' },
    },
    power_users: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '1m', target: 26 },
        { duration: '1m', target: 53 },
        { duration: '1m', target: 79 },
        { duration: '1m', target: 105 },
        { duration: '5m', target: 105 },
        { duration: '2m', target: 0 },
      ],
      exec: 'powerRun',
      tags: { role: 'power_user' },
    },
    stress_attackers: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '1m', target: 9 },
        { duration: '1m', target: 18 },
        { duration: '1m', target: 26 },
        { duration: '1m', target: 35 },
        { duration: '5m', target: 35 },
        { duration: '2m', target: 0 },
      ],
      exec: 'attackRun',
      tags: { role: 'stress_attacker' },
    },
  },
  thresholds: {
    'http_req_duration': ['p(95)<1500', 'p(99)<3000'],
    'http_req_failed': ['rate<0.02'],
    'request_success_rate': ['rate>0.99'],
  },
};

export function anonRun() { anonymousWorkflow(); }
export function authRun() { authenticatedWorkflow(); }
export function powerRun() { powerWorkflow(); }
export function attackRun() { attackerWorkflow(); }

export const handleSummary = makeHandleSummary('campaign-700', options);
