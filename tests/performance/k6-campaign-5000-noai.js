import { makeHandleSummary } from './k6-report.js';
import {
  anonymousWorkflow,
  authenticatedWorkflow,
} from './campaign-workflows.js';

// ─────────────────────────────────────────────────────────────────────────────
// Campaign 5000 VUs — NO AI / NO LLM / NO MLSecOps
//
// Variante « infrastructure pure » de la campagne de charge :
//   ✅ inclus  : anonymousWorkflow (portal + listing chatbots)
//                authenticatedWorkflow (users / conversations / chatbots)
//   ❌ exclus  : powerWorkflow        (RAG : create conversation + messages → ollama/ai-gateway)
//                attackerWorkflow     (prompt injection + audit sécurité → SecAI/MLSecOps)
//
// Objectif : mesurer la capacité du tier web/DB (Laravel + PostgreSQL)
// indépendamment de la saturation du stack IA (ollama, LiteLLM, qdrant).
//
// Répartition 5000 VUs (ratio 3:5 hérité des campagnes 300→900) :
//   anonymous_users    : 1875 VUs (37.5%)
//   authenticated_users : 3125 VUs (62.5%)
// ─────────────────────────────────────────────────────────────────────────────

export const options = {
  discardResponseBodies: true,
  scenarios: {
    anonymous_users: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '1m', target: 470 },   // 25%
        { duration: '1m', target: 940 },   // 50%
        { duration: '1m', target: 1405 },  // 75%
        { duration: '1m', target: 1875 }, // 100%
        { duration: '5m', target: 1875 },  // plateau
        { duration: '2m', target: 0 },     // ramp-down
      ],
      exec: 'anonRun',
      tags: { role: 'anonymous' },
    },
    authenticated_users: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '1m', target: 780 },   // 25%
        { duration: '1m', target: 1560 },  // 50%
        { duration: '1m', target: 2340 },  // 75%
        { duration: '1m', target: 3125 },  // 100%
        { duration: '5m', target: 3125 },  // plateau
        { duration: '2m', target: 0 },     // ramp-down
      ],
      exec: 'authRun',
      tags: { role: 'authenticated' },
    },
  },
  thresholds: {
    // Seuils identiques aux campagnes 300→900 pour comparabilité
    'http_req_duration': ['p(95)<1500', 'p(99)<3000'],
    'http_req_failed': ['rate<0.02'],
    'request_success_rate': ['rate>0.99'],
  },
};

export function anonRun() { anonymousWorkflow(); }
export function authRun() { authenticatedWorkflow(); }

export const handleSummary = makeHandleSummary('campaign-5000-noai', options);
