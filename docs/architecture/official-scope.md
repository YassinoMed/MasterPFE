# Official Scope - SecureRAG Hub

## Decision

SecureRAG Hub's official production-like scope is:

- the Laravel portal `platform/portal-web`;
- the Laravel business services `auth-users`, `chatbot-manager`, `conversation-service` and `audit-security-service`;
- the DevSecOps/Kubernetes platform around those services: Jenkins, kind, Kustomize, immutable image deployment, supply-chain evidence, Kyverno, HPA, runtime hardening, backups, observability, support packs and runbooks.

This is the scope that can be defended as the official runtime for the academic demo and production-like evidence chain.

## Legacy Scope

The historical Python/IA/RAG assets under `services/`, plus the old Kubernetes resources for `api-gateway`, `knowledge-hub`, `llm-orchestrator`, `security-auditor`, `qdrant` and `ollama`, are legacy. They are not part of the official Kubernetes graph because their current repository state is not a complete, proven, buildable RAG runtime.

They must not be presented as an active deployed RAG pipeline in the final defense.

## Current Kubernetes Boundary

The official Kustomize base is `infra/k8s/base/kustomization.yaml`. It references only:

- `portal-web`;
- `auth-users`;
- `chatbot-manager`;
- `conversation-service`;
- `audit-security-service`;
- shared namespace, quota, limits, NetworkPolicies, RBAC and validation ServiceAccount.

The legacy overlay at `infra/k8s/overlays/legacy/` intentionally has no deployable `kustomization.yaml`.

## Future RAG Reintroduction

A real RAG pipeline can be reintroduced later as a distinct evolution. The minimum bar is:

- restored source code and tests;
- Dockerfiles that build without placeholders;
- Kustomize resources, probes, resources, securityContext, NetworkPolicies and PDB/HPA where relevant;
- SBOM, Trivy, Cosign signature and provenance evidence;
- Kyverno Audit/Enforce compatibility;
- runtime proof archived in `artifacts/`.

Until that is done, the honest status is `PRÊT_NON_EXÉCUTÉ` for legacy RAG and `TERMINÉ` for the Laravel-first DevSecOps/Kubernetes platform when its proofs are regenerated.
