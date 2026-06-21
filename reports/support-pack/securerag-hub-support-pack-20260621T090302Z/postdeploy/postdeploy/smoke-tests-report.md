# Application Smoke Tests Report — SecureRAG Hub

- Generated at UTC: `2026-06-21T08:50:04Z`
- Namespace: `securerag-hub`
## 1. Workload Rollout Status Check

- **portal-web**: `Unavailable` (❌ Rollout FAILED)
- **auth-users**: `Unavailable` (❌ Rollout FAILED)
- **chatbot-manager**: `Unavailable` (❌ Rollout FAILED)
- **conversation-service**: `Unavailable` (❌ Rollout FAILED)
- **audit-security-service**: `Unavailable` (❌ Rollout FAILED)

## 2. HTTP Connectivity and Route Verification

| Route URL | Expected | Result | Status |
|---|---|---|---|
| `http://portal-web:8000/health` | `200/302` | `HTTP 000ERR` | ❌ FAILED |
| `http://portal-web:8000/` | `200/302` | `HTTP 000ERR` | ❌ FAILED |
| `http://auth-users:8000/health` | `200/302` | `HTTP 000ERR` | ❌ FAILED |
| `http://chatbot-manager:8000/health` | `200/302` | `HTTP 000ERR` | ❌ FAILED |
| `http://conversation-service:8000/health` | `200/302` | `HTTP 000ERR` | ❌ FAILED |
| `http://audit-security-service:8000/health` | `200/302` | `HTTP 000ERR` | ❌ FAILED |

## 3. Summary

- **Overall Status**: `FAILED` (11 errors) (❌ Non-Compliant)
