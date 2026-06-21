# Kubernetes Hardening Report — SecureRAG Hub

- Generated at UTC: `2026-06-18T16:08:45Z`
- Namespace: `securerag-hub`
- Cluster context: `kind-securerag-dev`

## 1. Namespace-Level Hardening

- **Pod Security Enforce**: `restricted` (✅ Compliant)
- **ResourceQuota**: `Active` (✅ Compliant)
- **LimitRange**: `Active` (✅ Compliant)

## 2. Workload Hardening Checks

| Workload | ServiceAccount | NonRoot | ReadOnlyFS | NoPrivEsc | Drop Caps | Seccomp | Probes (L/R/S) | Resources (Req/Lim) | Status |
|---|---|---|---|---|---|---|---|---|---|
| `portal-web` | ✅ (no-token) | ✅ | ✅ | ✅ | ✅ | ✅ | `LRS` | ✅ | ✅ OK |
| `auth-users` | ✅ (no-token) | ✅ | ✅ | ✅ | ✅ | ✅ | `LRS` | ✅ | ✅ OK |
| `chatbot-manager` | ✅ (no-token) | ✅ | ✅ | ✅ | ✅ | ✅ | `LRS` | ✅ | ✅ OK |
| `conversation-service` | ✅ (no-token) | ✅ | ✅ | ✅ | ✅ | ✅ | `LRS` | ✅ | ✅ OK |
| `audit-security-service` | ✅ (no-token) | ✅ | ✅ | ✅ | ✅ | ✅ | `LRS` | ✅ | ✅ OK |

## 3. Network-Level Isolation

- **Default-Deny Policy**: `Active` (✅ Compliant)
- **PodDisruptionBudget**: `Active` (5 configured) (✅ Compliant)

## 4. Summary

- **Status**: `OK` (0 warnings)
- **Hardening compliance**: `100%` of critical checks passed
