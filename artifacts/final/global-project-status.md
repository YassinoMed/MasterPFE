# Global Project Status - SecureRAG Hub

<<<<<<< HEAD
- Generated at: `2026-04-12T22:48:13Z`
- Git commit: `09b4c07aead711dc91baf789ccfcf653f9a65516`
=======
- Generated at: `2026-04-12T22:25:54Z`
- Git commit: `80549b817e83e8283452538de818f722a96daa0d`
>>>>>>> 5af92bc (securité)
- Git branch: `main`
- Official scenario: `demo`

## 1. Architecture and governance

| Element | Status | Note |
|---|---:|---|
| Jenkins official CI/CD | TERMINÉ | Jenkins remains the source of truth. |
| GitHub Actions legacy | TERMINÉ | Historical workflows only. |
| Kustomize demo overlay | TERMINÉ | Official soutenance scenario. |
| Kustomize dev overlay | TERMINÉ | Local development path. |

## 2. Application layer

| Component | Status | Evidence |
|---|---:|---|
| Blade portal | TERMINÉ | `platform/portal-web` |
| Portal API adapter | TERMINÉ | `PortalBackendClient.php` |
| auth-users-service | TERMINÉ | Laravel business service |
| chatbot-manager-service | TERMINÉ | Laravel business service |
| conversation-service | TERMINÉ | Laravel business service |
| audit-security-service | TERMINÉ | Laravel business service |

## 3. API contracts

| Contract | Status |
|---|---:|
| auth-users OpenAPI | TERMINÉ |
| chatbot-manager OpenAPI | TERMINÉ |
| conversation OpenAPI | TERMINÉ |
| audit-security OpenAPI | TERMINÉ |

## 4. DevSecOps evidence

| Evidence | Status |
|---|---:|
| Final validation summary | PREUVE_PRÉSENTE |
| DevSecOps final proof | PREUVE_PRÉSENTE |
| Release attestation | PREUVE_PRÉSENTE |
| Supply chain evidence | PREUVE_PRÉSENTE |
| Observability snapshot | PREUVE_PRÉSENTE |
| Portal-service connectivity | PREUVE_PRÉSENTE |
<<<<<<< HEAD
| Latest support pack | artifacts/support-pack/20260412T224812Z.tar.gz |
=======
| Latest support pack | artifacts/support-pack/20260412T222547Z.tar.gz |
>>>>>>> 5af92bc (securité)

## 5. Honest remaining dependencies

- Jenkins webhook and CI push proof require Jenkins to be publicly reachable from GitHub.
- Full supply chain execute requires Docker images, local registry, Syft, Cosign keys and network reachability.
- HPA and Kyverno runtime proof require an active kind cluster with metrics-server and Kyverno installed.
- The portal can run in `auto` mode with fallback mock data, or `api` mode for strict integration proof.

## 6. Final interpretation

SecureRAG Hub is now structured as a strong demo-grade platform with a credible path toward quasi pre-production. The remaining gaps are mostly runtime proofs and environment-dependent execute paths, not missing core design artefacts.
