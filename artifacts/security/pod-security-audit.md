# Pod Security Strict — Audit statique

_Generated UTC: 2026-09-23T04:45:27Z_  · Status: `TERMINÉ`

Contrôles vérifiés : runAsNonRoot, runAsUser≠0, seccompProfile=RuntimeDefault,
automountServiceAccountToken=false, allowPrivilegeEscalation=false,
readOnlyRootFilesystem=true, capabilities.drop⊇[ALL], resources requests+limits.

| Result | Service | Issues |
|:------:|---------|--------|
| ⏸️ SKIP | `ai-knowledge-graph` | legacy/out-of-scope (per docs/architecture/official-scope.md) |
| ⏸️ SKIP | `ai-security-orchestrator` | legacy/out-of-scope (per docs/architecture/official-scope.md) |
| ⏸️ SKIP | `api-gateway` | legacy/out-of-scope (per docs/architecture/official-scope.md) |
| ✅ OK | `audit-security-service` | - |
| ✅ OK | `auth-users` | - |
| ✅ OK | `chatbot-manager` | - |
| ✅ OK | `conversation-service` | - |
| ⏸️ SKIP | `knowledge-hub` | legacy/out-of-scope (per docs/architecture/official-scope.md) |
| ⏸️ SKIP | `llm-orchestrator` | legacy/out-of-scope (per docs/architecture/official-scope.md) |
| ⏸️ SKIP | `ollama` | legacy/out-of-scope (per docs/architecture/official-scope.md) |
| ✅ OK | `portal-web` | - |
| ✅ OK | `postgres-auth` | - |
| ⏸️ SKIP | `qdrant` | legacy/out-of-scope (per docs/architecture/official-scope.md) |
| ⏸️ SKIP | `security-auditor` | legacy/out-of-scope (per docs/architecture/official-scope.md) |
