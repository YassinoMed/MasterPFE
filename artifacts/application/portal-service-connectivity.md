# Portal / Service Connectivity Proof - SecureRAG Hub

- Generated at: `2026-04-12T22:18:46Z`
- Portal backend mode: `api`
- Timeout: `2s`

## 1. Runtime endpoints

| Component | URL | Status |
|---|---|---:|
| Portal health | `http://127.0.0.1:8081/health` | OK |
| auth-users-service | `http://127.0.0.1:8091/api/v1/health` | OK |
| chatbot-manager-service | `http://127.0.0.1:8092/api/v1/health` | OK |
| conversation-service | `http://127.0.0.1:8093/api/v1/health` | OK |
| audit-security-service | `http://127.0.0.1:8094/api/v1/health` | OK |

## 2. Blade pages through portal

| Page | URL | Status |
|---|---|---:|
| Admin users | `http://127.0.0.1:8081/admin/users` | OK |
| Admin roles | `http://127.0.0.1:8081/admin/roles` | OK |
| Chatbots | `http://127.0.0.1:8081/chatbots` | OK |
| Chat | `http://127.0.0.1:8081/chat` | OK |
| History | `http://127.0.0.1:8081/history` | OK |
| Security | `http://127.0.0.1:8081/security` | OK |

## 3. Portal integration files

| File | Status |
|---|---:|
| `platform/portal-web/app/Services/PortalBackendClient.php` | present |
| `platform/portal-web/app/Support/DemoPortalData.php` | present |
| `platform/portal-web/config/services.php` | present |
| `platform/portal-web/routes/web.php` | present |

## 4. Laravel service directories

| Service | Directory | API contract |
|---|---:|---:|
| auth-users-service | present | present |
| chatbot-manager-service | present | present |
| conversation-service | present | present |
| audit-security-service | present | present |

## 5. Interpretation

- `OK` means the API is reachable in the current environment.
- `PARTIEL_UNREACHABLE` usually means the local Laravel service is not running, not that the code is missing.
- In `auto` mode, the Blade portal can fallback to deterministic mock data when APIs are unavailable.
- In `api` mode, API failures are intentionally surfaced to prove real integration readiness.
