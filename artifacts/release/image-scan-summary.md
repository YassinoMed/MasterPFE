# Trivy Image Scan Summary - SecureRAG Hub

- Generated at UTC: `2026-09-23T03:58:18Z`
- Trivy version: `Version: 0.49.1`
- Reported severities: `HIGH,CRITICAL`
- Blocking severities: `CRITICAL`
- HIGH policy: `reported-non-blocking`

| Service | Image | Status | Critical | High | JSON report | Detail |
|---|---|---:|---:|---:|---|---|
| `auth-users` | `localhost:5001/securerag-hub-auth-users:dev` | `WARN` | 0 | 13 | `security/reports/trivy-image-auth-users.json` | critical=0; high=13; total=13; HIGH findings are reported but non-blocking by policy |
| `chatbot-manager` | `localhost:5001/securerag-hub-chatbot-manager:dev` | `WARN` | 0 | 13 | `security/reports/trivy-image-chatbot-manager.json` | critical=0; high=13; total=13; HIGH findings are reported but non-blocking by policy |
| `conversation-service` | `localhost:5001/securerag-hub-conversation-service:dev` | `WARN` | 0 | 13 | `security/reports/trivy-image-conversation-service.json` | critical=0; high=13; total=13; HIGH findings are reported but non-blocking by policy |
| `audit-security-service` | `localhost:5001/securerag-hub-audit-security-service:dev` | `WARN` | 0 | 13 | `security/reports/trivy-image-audit-security-service.json` | critical=0; high=13; total=13; HIGH findings are reported but non-blocking by policy |
| `portal-web` | `localhost:5001/securerag-hub-portal-web:dev` | `WARN` | 0 | 13 | `security/reports/trivy-image-portal-web.json` | critical=0; high=13; total=13; HIGH findings are reported but non-blocking by policy |

## Gate result

- PASS: `5`
- FAIL: `0`
- SKIP: `0`
- Evidence index: `artifacts/release/image-scan-index.json`
