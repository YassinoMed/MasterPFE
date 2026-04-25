# Official Scope Report - SecureRAG Hub

- Generated at UTC: `2026-04-25T20:08:19Z`
- Status: `TERMINÉ`

## 1. Scope decision

The official production-like runtime is Laravel-first: portal, Laravel business services, DevSecOps/Kubernetes, security controls and archived evidence. Historical Python IA/RAG components remain legacy and are excluded from the official deployment graph until their sources, images, policies and runtime proofs are restored together.

| Check | Status | Detail |
|---|---:|---|
| Official Laravel workloads | TERMINÉ | all five official workloads are referenced by `infra/k8s/base/kustomization.yaml` |
| Legacy workloads excluded from official graph | TERMINÉ | no legacy workload is referenced by `infra/k8s/base/kustomization.yaml` |
| Legacy overlay guardrail | TERMINÉ | `infra/k8s/overlays/legacy/README.md` documents that legacy is intentionally non-deployable |
| RAG validation opt-in | TERMINÉ | `scripts/validate/rag-smoke.sh` keeps legacy RAG checks opt-in |
| README scope disclosure | TERMINÉ | README links the official scope and marks Python/RAG as legacy |
| Architecture scope document | TERMINÉ | `docs/architecture/official-scope.md` present |

## 2. Official runtime

- `portal-web`
- `auth-users`
- `chatbot-manager`
- `conversation-service`
- `audit-security-service`

## 3. Legacy / non-official runtime

- `api-gateway`
- `knowledge-hub`
- `llm-orchestrator`
- `ollama`
- `qdrant`
- `security-auditor`

## 4. Future evolution

A real RAG pipeline can be reintroduced as a separate evolution only after source code, Dockerfiles, Kustomize resources, NetworkPolicies, probes, resources, signatures, SBOMs, Kyverno policies and runtime evidence are restored as one coherent scope.
