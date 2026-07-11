# SecureRAG Hub - DORA Pipeline Evidence Report

Generated at UTC: `2026-07-11T07:23:48Z`
Pipeline Build: `#1783754628`

## 1. Build Metadata
| Key | Value |
| --- | --- |
| Git Commit | `90a6b7a34327c6c9a4e34048d673d9930286c9c9` |
| Branch | `main` |
| Author | Jenkins GitOps Bot <jenkins@securerag.local> |
| Date | 2026-07-11T07:23:48Z |

## 2. Security Scans Summary
| Scanner | Finding Count / Status |
| --- | --- |
| Trivy FS Vulnerabilities | 0 |
| Semgrep SAST Findings | 0 |
| Gitleaks Secrets Findings | 0 |
| Grype Dependency Vulnerabilities | 0 |
| Cosign Signed Images | 1 |
| SLSA Provenance Attestation | false |

## 3. Deployment & Orchestration
| Deployment | Image | Digest | Rollout Status |
| --- | --- | --- | --- |
| portal-web | localhost:5001/securerag-hub-portal-web:demo | localhost:5001/securerag-hub-portal-web@sha256:f9be42bd70b1fd9467c5f99e7453d8a0d911571cb91c007b44493ba129d4d12e | Success |
| auth-users | localhost:5001/securerag-hub-auth-users:demo | localhost:5001/securerag-hub-auth-users@sha256:4612ed10fb2793c5c246f02c446d861f21a9c87ecf8b3b53032307f388c75006 | Success |
| chatbot-manager | localhost:5001/securerag-hub-chatbot-manager:demo | localhost:5001/securerag-hub-chatbot-manager@sha256:54dc18c5a52d9233d692039160858568e45baafd60c3df669188895e6e735167 | Success |
| conversation-service | localhost:5001/securerag-hub-conversation-service:demo | localhost:5001/securerag-hub-conversation-service@sha256:31fec2e7395963f7aae5efd909ad73d90c4126505eb231234a9cea886dda4072 | Success |
| audit-security-service | localhost:5001/securerag-hub-audit-security-service:demo | localhost:5001/securerag-hub-audit-security-service@sha256:dfc420d534411f8a6256ef36c2ca5b8d82ad5e1af8ee1d7886ae5363b8804f16 | Success |

- Smoke Tests Status: **FAILED**
- Overall Deployment Health: **HEALTHY**

## 4. Compliance & Policy Enforcement
- Kyverno Installed Policies: `8`
- Kyverno Violations: `1`
- Pod Security Standards (Namespace `securerag-hub`): Enforce=`restricted` · Audit=`restricted`
- NetworkPolicies Count: `11`
- RBAC ServiceAccounts: `8`
- External Secrets Configured: `3`

## 5. Audit logs & Events
- Jenkins Build Logs URL: [http://localhost:8085/job/SecureRAG-Hub/1783754628/](http://localhost:8085/job/SecureRAG-Hub/1783754628/)
- Falco Logs (Recent alerts in daemonset): Warnings=`0` · Criticals=`1516`

### ArgoCD Applications Sync
| Application | Sync Status | Health Status |
| --- | --- | --- |
| securerag-backup | Synced | Healthy |
| securerag-cert-manager | Synced | Healthy |
| securerag-demo | Synced | Healthy |
| securerag-dev | Unknown | Unknown |
| securerag-dr | Unknown | Unknown |
| securerag-eso | OutOfSync | Healthy |
| securerag-falco-talon | Synced | Healthy |
| securerag-harbor | Synced | Healthy |
| securerag-image-updater | Synced | Healthy |
| securerag-kyverno | Synced | Degraded |
| securerag-kyverno-policies | OutOfSync | Healthy |
| securerag-metrics-server | Synced | Healthy |
| securerag-observability | OutOfSync | Healthy |
| securerag-otel | Synced | Healthy |
| securerag-production | Unknown | Unknown |
| securerag-psa-policies | OutOfSync | Healthy |
| securerag-recette | Unknown | Unknown |
| securerag-root | OutOfSync | Healthy |
| securerag-runtime-detection | Synced | Healthy |
| securerag-secrets | OutOfSync | Healthy |
| securerag-staging | Unknown | Unknown |
| securerag-vault | OutOfSync | Healthy |
| securerag-velero | Synced | Healthy |
