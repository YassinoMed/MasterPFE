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
        { duration: '1m', target: 68 },
        { duration: '1m', target: 135 },
        { duration: '1m', target: 203 },
        { duration: '1m', target: 270 },
        { duration: '5m', target: 270 },
        { duration: '2m', target: 0 },
      ],
      exec: 'anonRun',
      tags: { role: 'anonymous' },
    },
    authenticated_users: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '1m', target: 113 },
        { duration: '1m', target: 225 },
        { duration: '1m', target: 338 },
        { duration: '1m', target: 450 },
        { duration: '5m', target: 450 },
        { duration: '2m', target: 0 },
      ],
      exec: 'authRun',
      tags: { role: 'authenticated' },
    },
    power_users: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '1m', target: 34 },
        { duration: '1m', target: 68 },
        { duration: '1m', target: 101 },
        { duration: '1m', target: 135 },
        { duration: '5m', target: 135 },
        { duration: '2m', target: 0 },
      ],
      exec: 'powerRun',
      tags: { role: 'power_user' },
    },
    stress_attackers: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '1m', target: 11 },
        { duration: '1m', target: 23 },
        { duration: '1m', target: 34 },
        { duration: '1m', target: 45 },
        { duration: '5m', target: 45 },
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

export const handleSummary = makeHandleSummary('campaign-900', options);
