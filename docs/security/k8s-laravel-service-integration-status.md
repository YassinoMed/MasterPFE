# Kubernetes Integration Status — Laravel Business Services

## Objectif
Clarifier l’état réel du runtime Kubernetes officiel afin d’éviter toute surdéclaration dans les preuves sécurité, la soutenance et les scripts de release.

## État officiel actuel
Le runtime Kubernetes officiel `dev`/`demo` est Laravel-first et correspond aux composants réellement buildables dans le dépôt.

| Workload | Chemin source | Manifests K8s | État |
|---|---|---|---:|
| `portal-web` | `platform/portal-web` | `infra/k8s/base/portal-web/*` | TERMINÉ |
| `auth-users` | `services-laravel/auth-users-service` | `infra/k8s/base/auth-users/*` | TERMINÉ |
| `chatbot-manager` | `services-laravel/chatbot-manager-service` | `infra/k8s/base/chatbot-manager/*` | TERMINÉ |
| `conversation-service` | `services-laravel/conversation-service` | `infra/k8s/base/conversation-service/*` | TERMINÉ |
| `audit-security-service` | `services-laravel/audit-security-service` | `infra/k8s/base/audit-security-service/*` | TERMINÉ |

Chaque workload officiel possède `Deployment`, `Service`, `ServiceAccount`, probes, `resources` CPU/mémoire/`ephemeral-storage`, `PodDisruptionBudget`, `NetworkPolicy` et `securityContext` durci.

Un overlay `production` est maintenant disponible sous `infra/k8s/overlays/production`. Il conserve le périmètre Laravel officiel et ajoute une posture HA statique : replicas `>=2`, `portal-web` à `3`, PDB adaptés, rolling update `maxUnavailable=0`, anti-affinity, topology spread et HPA CPU/mémoire pour tous les services officiels. Le mode `demo` reste inchangé.

L'overlay `production` expose officiellement le portail par `Service/portal-web` en `NodePort` `30081`. Le cluster kind production-like `infra/kind/kind-production.yaml` mappe ce NodePort vers `http://localhost:8081/health`. Cette exposition remplace les conteneurs de forward ad hoc dans le scénario production.

Le namespace est rendu avec Pod Security Admission `restricted` en `enforce`, `audit` et `warn`. Les pods de validation éphémères utilisent désormais un ServiceAccount dédié `sa-validation`, sans token monté automatiquement, avec `runAsNonRoot`, `seccomp RuntimeDefault`, `allowPrivilegeEscalation=false`, `readOnlyRootFilesystem=true`, `capabilities.drop=["ALL"]` et des ressources bornées.

## Périmètre legacy exclu
Les dossiers sous `services/` sont conservés comme historique mais ne sont plus build/deploy officiels :

- `api-gateway`
- `auth-users`
- `chatbot-manager`
- `llm-orchestrator`
- `security-auditor`
- `knowledge-hub`

Cause : les sources applicatives Python `.py` ne sont plus présentes. Un Dockerfile/requirements sans sources exploitables ne doit pas être présenté comme workload runtime validé.

Les composants `qdrant` et `ollama` ne sont plus dans `infra/k8s/base/kustomization.yaml`. Toute réintégration doit être une évolution explicite avec manifests, NetworkPolicies et preuves runtime dédiées.

## Validation non destructive
```bash
kubectl kustomize infra/k8s/overlays/dev >/tmp/securerag-dev.yaml
kubectl kustomize infra/k8s/overlays/demo >/tmp/securerag-demo.yaml
bash scripts/validate/validate-k8s-cleartext-scope.sh
bash scripts/validate/validate-k8s-resource-guards.sh
bash scripts/validate/validate-k8s-ultra-hardening.sh
STATIC_ONLY=true bash scripts/validate/validate-production-cluster-clean.sh
```

## Validation runtime si cluster actif
```bash
kubectl get deploy,svc,networkpolicy,pdb,hpa -n securerag-hub
kubectl get pods -n securerag-hub -o wide
kubectl get svc portal-web -n securerag-hub -o wide
curl -fsS http://localhost:8081/health
bash scripts/validate/validate-production-cluster-clean.sh
kubectl logs -n securerag-hub deploy/conversation-service --tail=80
kubectl logs -n securerag-hub deploy/audit-security-service --tail=80
bash scripts/validate/smoke-tests.sh
bash scripts/validate/security-smoke.sh
bash scripts/validate/e2e-functional-flow.sh
```

## Lecture sécurité
- `TERMINÉ` : manifests et validations de rendu sont présents.
- `DÉPENDANT_DE_L_ENVIRONNEMENT` : preuve de pods `Ready`, logs runtime, HPA metrics, Kyverno reports.
- `PRÊT_NON_EXÉCUTÉ` : promotion digest, signatures Cosign et preuves cluster si Docker/kind/registry/Cosign/Kyverno/metrics-server ne sont pas actifs.
