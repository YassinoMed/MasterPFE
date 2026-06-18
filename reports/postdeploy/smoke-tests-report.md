# Application Smoke Tests Report — SecureRAG Hub

- Generated at UTC: `2026-06-18T12:51:56Z`
- Namespace: `securerag-hub`
## 1. Workload Rollout Status Check

- **portal-web**: `Active` (✅ Rollout OK)
- **auth-users**: `Active` (✅ Rollout OK)
- **chatbot-manager**: `Active` (✅ Rollout OK)
- **conversation-service**: `Active` (✅ Rollout OK)
- **audit-security-service**: `Active` (✅ Rollout OK)

## 2. HTTP Connectivity and Route Verification

| Route URL | Expected | Result | Status |
|---|---|---|---|
| `http://portal-web:8000/` | `200/302` | `HTTP 200` | ✅ OK |
| `http://auth-users:8000/health` | `200/302` | `HTTP 200` | ✅ OK |
| `http://chatbot-manager:8000/health` | `200/302` | `HTTP 200` | ✅ OK |
| `http://conversation-service:8000/health` | `200/302` | `HTTP 200` | ✅ OK |
| `http://audit-security-service:8000/health` | `200/302` | `HTTP 200` | ✅ OK |

## 3. Summary

- **Overall Status**: `OK` (✅ Compliant)
