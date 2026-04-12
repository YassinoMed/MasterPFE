# Portal / Service Connectivity Proof - SecureRAG Hub

- Generated at: `2026-04-12T22:11:45Z`
- Portal backend mode: `auto`
- Timeout: `2s`

## 1. Runtime endpoints

| Component | URL | Status |
|---|---|---:|
| Portal health | `http://localhost:8081/health` | PARTIEL_UNREACHABLE |
| auth-users-service | `http://localhost:8091/api/v1/health` | PARTIEL_UNREACHABLE |
| chatbot-manager-service | `http://localhost:8092/api/v1/health` | PARTIEL_UNREACHABLE |
| conversation-service | `http://localhost:8093/api/v1/health` | PARTIEL_UNREACHABLE |
| audit-security-service | `http://localhost:8094/api/v1/health` | PARTIEL_UNREACHABLE |

## 2. Portal integration files

| File | Status |
|---|---:|
| `platform/portal-web/app/Services/PortalBackendClient.php` | present |
| `platform/portal-web/app/Support/DemoPortalData.php` | present |
| `platform/portal-web/config/services.php` | present |
| `platform/portal-web/routes/web.php` | present |

## 3. Laravel service directories

| Service | Directory | API contract |
|---|---:|---:|
| auth-users-service | present | present |
| chatbot-manager-service | present | present |
| conversation-service | present | present |
| audit-security-service | present | present |

## 4. Interpretation

- `OK` means the API is reachable in the current environment.
- `PARTIEL_UNREACHABLE` usually means the local Laravel service is not running, not that the code is missing.
- In `auto` mode, the Blade portal can fallback to deterministic mock data when APIs are unavailable.
- In `api` mode, API failures are intentionally surfaced to prove real integration readiness.
