# Trivy Image Scan Summary - SecureRAG Hub

- Generated at UTC: `2026-09-25T05:12:55Z`
- Trivy version: `Version: 0.49.1`
- Reported severities: `HIGH,CRITICAL`
- Blocking severities: `CRITICAL`
- HIGH policy: `reported-non-blocking`

| Service | Image | Status | Critical | High | JSON report | Detail |
|---|---|---:|---:|---:|---|---|
| `auth-users` | `localhost:5001/securerag-hub-auth-users:dev` | `PASS` | 0 | 0 | `security/reports/trivy-image-auth-users.json` | critical=0; high=0; total=0 |
| `chatbot-manager` | `localhost:5001/securerag-hub-chatbot-manager:dev` | `PASS` | 0 | 0 | `security/reports/trivy-image-chatbot-manager.json` | critical=0; high=0; total=0 |
| `conversation-service` | `localhost:5001/securerag-hub-conversation-service:dev` | `PASS` | 0 | 0 | `security/reports/trivy-image-conversation-service.json` | critical=0; high=0; total=0 |
| `audit-security-service` | `localhost:5001/securerag-hub-audit-security-service:dev` | `PASS` | 0 | 0 | `security/reports/trivy-image-audit-security-service.json` | critical=0; high=0; total=0 |
| `portal-web` | `localhost:5001/securerag-hub-portal-web:dev` | `PASS` | 0 | 0 | `security/reports/trivy-image-portal-web.json` | critical=0; high=0; total=0 |

## Gate result

- PASS: `5`
- FAIL: `0`
- SKIP: `0`
- Evidence index: `artifacts/release/image-scan-index.json`
