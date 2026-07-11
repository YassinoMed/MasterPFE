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
        { duration: '1m', target: 60 },
        { duration: '1m', target: 120 },
        { duration: '1m', target: 180 },
        { duration: '1m', target: 240 },
        { duration: '5m', target: 240 },
        { duration: '2m', target: 0 },
      ],
      exec: 'anonRun',
      tags: { role: 'anonymous' },
    },
    authenticated_users: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '1m', target: 100 },
        { duration: '1m', target: 200 },
        { duration: '1m', target: 300 },
        { duration: '1m', target: 400 },
        { duration: '5m', target: 400 },
        { duration: '2m', target: 0 },
      ],
      exec: 'authRun',
      tags: { role: 'authenticated' },
    },
    power_users: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '1m', target: 30 },
        { duration: '1m', target: 60 },
        { duration: '1m', target: 90 },
        { duration: '1m', target: 120 },
        { duration: '5m', target: 120 },
        { duration: '2m', target: 0 },
      ],
      exec: 'powerRun',
      tags: { role: 'power_user' },
    },
    stress_attackers: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '1m', target: 10 },
        { duration: '1m', target: 20 },
        { duration: '1m', target: 30 },
        { duration: '1m', target: 40 },
        { duration: '5m', target: 40 },
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

export const handleSummary = makeHandleSummary('campaign-800', options);
