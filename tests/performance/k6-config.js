import http from 'k6/http';

const {
  NAMESPACE = 'securerag-hub',
  PORTAL_PORT = '8000',
  LARAVEL_PORT = '8000',
  GATEWAY_PORT = '8080',
} = __ENV;

const svc = (name, port) =>
  `http://${name}.${NAMESPACE}.svc.cluster.local:${port}`;

export const SERVICE_HEALTH_PATHS = {
  'api-gateway': '/health',
  'portal-web': '/health',
  'auth-users': '/api/v1/health',
  'chatbot-manager': '/api/v1/health',
  'conversation-service': '/api/v1/health',
  'audit-security-service': '/api/v1/health',
};

export const SERVICES = {
  'api-gateway': {
    url: svc('api-gateway', GATEWAY_PORT),
    tags: { service: 'api-gateway', type: 'python' },
  },
  'portal-web': {
    url: svc('portal-web', PORTAL_PORT),
    tags: { service: 'portal-web', type: 'laravel' },
  },
  'auth-users': {
    url: svc('auth-users', LARAVEL_PORT),
    tags: { service: 'auth-users', type: 'laravel' },
  },
  'chatbot-manager': {
    url: svc('chatbot-manager', LARAVEL_PORT),
    tags: { service: 'chatbot-manager', type: 'laravel' },
  },
  'conversation-service': {
    url: svc('conversation-service', LARAVEL_PORT),
    tags: { service: 'conversation-service', type: 'laravel' },
  },
  'audit-security-service': {
    url: svc('audit-security-service', LARAVEL_PORT),
    tags: { service: 'audit-security-service', type: 'laravel' },
  },
};

export function getBaseUrl(serviceName) {
  const service = SERVICES[serviceName];
  if (!service) {
    throw new Error(`Unknown service: ${serviceName}`);
  }
  return service.url;
}

export function allServices() {
  return Object.entries(SERVICES).map(([name, cfg]) => Object.assign({ name: name }, cfg));
}

export const HEADERS = {
  'Content-Type': 'application/json',
  'Accept': 'application/json',
};

export const TIMEOUT = '30s';
