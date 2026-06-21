# Security Smoke Tests Report — SecureRAG Hub

- Generated at UTC: `2026-06-18T12:51:56Z`
- Namespace: `securerag-hub`
## 1. Environmental Security Variables (APP_DEBUG)

- **Laravel APP_DEBUG**: `false` (✅ Hardened)

## 2. Sensitive File and Secret Exposure Prevention

| Target URL | Expected Response | Actual | Status |
|---|---|---|---|
| `http://portal-web:8000/.env` | `403/404/401` | `HTTP 404` | ✅ Hardened |
| `http://portal-web:8000/storage/` | `403/404/401` | `HTTP 404` | ✅ Hardened |
| `http://portal-web:8000/admin` | `302/401/403` | `HTTP 200` | ❌ VULNERABLE |
| `http://portal-web:8000/api/secrets` | `403/404/401` | `HTTP 404` | ✅ Hardened |
| `http://portal-web:8000/dashboard` | `302/401/403` | `HTTP 404` | ❌ VULNERABLE |

## 3. Basic HTTP Security Headers

- **X-Frame-Options**: Should be set to `SAMEORIGIN` to prevent clickjacking
- **X-Content-Type-Options**: Should be set to `nosniff` to prevent MIME-sniffing
- **Content-Security-Policy (CSP)**: Strongly recommended in production

## 4. Summary

- **Overall Status**: `FAILED` (2 failures, 0 warnings) (❌ Vulnerabilities Found)
