# Portal / Service Connectivity Proof - SecureRAG Hub

<<<<<<< HEAD
- Generated at: `2026-04-12T22:48:10Z`
=======
- Generated at: `2026-04-12T22:25:48Z`
>>>>>>> 5af92bc (securité)
- Portal backend mode: `auto`
- Timeout: `2s`

## 1. Runtime endpoints

| Component | URL | Status |
|---|---|---:|
<<<<<<< HEAD
| Portal health | `http://localhost:8081/health` | OK |
=======
| Portal health | `http://localhost:8081/health` | PARTIEL_UNREACHABLE |
>>>>>>> 5af92bc (securité)
| auth-users-service | `http://localhost:8091/api/v1/health` | PARTIEL_UNREACHABLE |
| chatbot-manager-service | `http://localhost:8092/api/v1/health` | PARTIEL_UNREACHABLE |
| conversation-service | `http://localhost:8093/api/v1/health` | PARTIEL_UNREACHABLE |
| audit-security-service | `http://localhost:8094/api/v1/health` | PARTIEL_UNREACHABLE |

## 2. Blade pages through portal

| Page | URL | Status |
|---|---|---:|
<<<<<<< HEAD
| Admin users | `http://localhost:8081/admin/users` | PARTIEL_HTTP_404 |
| Admin roles | `http://localhost:8081/admin/roles` | PARTIEL_HTTP_404 |
| Chatbots | `http://localhost:8081/chatbots` | PARTIEL_HTTP_404 |
| Chat | `http://localhost:8081/chat` | PARTIEL_HTTP_404 |
| History | `http://localhost:8081/history` | PARTIEL_HTTP_404 |
| Security | `http://localhost:8081/security` | PARTIEL_HTTP_404 |
=======
| Admin users | `http://localhost:8081/admin/users` | PARTIEL_UNREACHABLE |
| Admin roles | `http://localhost:8081/admin/roles` | PARTIEL_UNREACHABLE |
| Chatbots | `http://localhost:8081/chatbots` | PARTIEL_UNREACHABLE |
| Chat | `http://localhost:8081/chat` | PARTIEL_UNREACHABLE |
| History | `http://localhost:8081/history` | PARTIEL_UNREACHABLE |
| Security | `http://localhost:8081/security` | PARTIEL_UNREACHABLE |
>>>>>>> 5af92bc (securité)

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
