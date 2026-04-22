# Legacy Services Local Launcher

- Generated at: `2026-04-22T14:32:26Z`
- Action: `status`
- Host: `127.0.0.1`
- Official runtime note: `legacy Python services are excluded from the official Laravel-first runtime until sources are intentionally restored`

| Service | Status | Detail | URL |
|---|---:|---|---|
| api-gateway | PRÊT_NON_EXÉCUTÉ | src/main.py absent; legacy service excluded from the official Laravel-first runtime until sources are restored | - |
| auth-users | PRÊT_NON_EXÉCUTÉ | src/main.py absent; legacy Python service superseded by the official Laravel runtime | - |
| chatbot-manager | PRÊT_NON_EXÉCUTÉ | src/main.py absent; legacy Python service superseded by the official Laravel runtime | - |
| knowledge-hub | PRÊT_NON_EXÉCUTÉ | src/main.py absent; legacy service excluded from the official Laravel-first runtime until sources are restored | - |
| llm-orchestrator | PRÊT_NON_EXÉCUTÉ | src/main.py absent; legacy service excluded from the official Laravel-first runtime until sources are restored | - |
| security-auditor | PRÊT_NON_EXÉCUTÉ | src/main.py absent; legacy service excluded from the official Laravel-first runtime until sources are restored | - |

## Interpretation

- `LANCÉ` means a local uvicorn process is alive for this service.
- `PRÊT_NON_EXÉCUTÉ` means the service source entrypoint is still absent.
- `PARTIEL` means the service exists conceptually but could not be fully started or proved.
- This launcher does not change the official runtime scope of SecureRAG Hub.
