# Audit des parties manquantes — SecureRAG Hub / SecureRAG Chatbot

> **But :** cartographier l'état réel du dépôt par rapport au cahier des charges
> "SecureRAG Hub / SecureRAG Chatbot — chatbot RAG sécurisé".
> **Convention :** ✅ PASS · 🟡 PARTIAL · ❌ MISSING.
>
> _Source de vérité complémentaire :_
> - [`docs/security/security-status-source-of-truth.md`](security/security-status-source-of-truth.md)
> - [`docs/security/security-readiness-report.md`](security/security-readiness-report.md)

## Décision d'architecture

Le dépôt comporte **deux runtimes** historiques :
- **Runtime Laravel officiel** sous `services-laravel/` + `platform/portal-web` —
  c'est lui qui produit les preuves runtime (HPA, Kyverno reports, Falco, etc.).
- **Runtime Python `services/`** — squelettes Dockerfile sans code source,
  marqués `PRÊT_NON_EXÉCUTÉ` dans la source-of-truth.

Le cahier des charges actuel cible **un chatbot RAG en FastAPI Python**.
**Action retenue :** compléter les services Python `services/*/` (sans
toucher au Laravel) en livrant le code applicatif manquant. Le runtime
Laravel reste hors-scope de cet ajout — il n'est pas remis en cause.

> ⚠️ La structure de répertoire dans le cahier des charges (`k8s/`, `ci/`,
> `argocd/` à la racine) **n'est pas adoptée** — elle dupliquerait
> l'arborescence existante (`infra/k8s/`, `Jenkinsfile`, `infra/k8s/argocd/`).
> Le cahier des charges autorise explicitement de "respecter les noms,
> dossiers, conventions et technologies déjà utilisés".

## Tableau de couverture

### A. Microservices applicatifs (Python FastAPI)

| Partie | Existe ? | État | Action nécessaire |
|--------|:--------:|:----:|-------------------|
| `services/api-gateway/` (Dockerfile + requirements) | ✅ | 🟡 | Ajouter `src/main.py` (FastAPI), JWT, routing, timeout, rate-limit |
| `services/auth-users/` | ✅ | 🟡 | Ajouter `src/main.py`, modèles, JWT, bcrypt, RBAC |
| `services/llm-orchestrator/` | ✅ | 🟡 | Ajouter `src/main.py`, RAG pipeline, mock LLM |
| `services/security-auditor/` | ✅ | 🟡 | Ajouter `src/main.py`, règles, scoring, hash logs |
| `services/vectorstore-service/` | ❌ | ❌ | Créer entièrement (chunking + embeddings + Qdrant + RBAC vectoriel) |
| `services/chatbot-manager/` (Laravel) | ✅ | ✅ | Hors-scope — runtime Laravel, à conserver |
| `services/knowledge-hub/` (Laravel) | ✅ | ✅ | Hors-scope — idem |

### B. Tests Python

| Partie | Existe ? | État | Action |
|--------|:--------:|:----:|--------|
| `pytest.ini` (testpaths services + tests) | ✅ | ✅ | OK |
| Tests health par service | ❌ | ❌ | À créer dans `services/<svc>/tests/` |
| Tests auth-users (register, login, RBAC) | ❌ | ❌ | À créer |
| Tests security-auditor (5 cas obligatoires) | ❌ | ❌ | À créer |
| Tests vectorstore-service (chunk, embed, RBAC) | ❌ | ❌ | À créer |
| Tests llm-orchestrator (mock LLM, audit pipeline) | ❌ | ❌ | À créer |
| Tests api-gateway (JWT, routing) | ❌ | ❌ | À créer |
| Tests intégration end-to-end | ❌ | ❌ | À créer dans `tests/integration/` |
| Coverage ≥ 70 % | ❌ | ❌ | Atteindre via les tests ci-dessus |

### C. Conteneurs / Compose

| Partie | Existe ? | État | Action |
|--------|:--------:|:----:|--------|
| Dockerfile par service Python | ✅ | ✅ | Préexistants (multi-stage, non-root) |
| `docker-compose.yml` à la racine | ❌ | ❌ | À créer (Postgres + Qdrant + Ollama optionnel + 5 services) |
| `.env.example` | ❌ | ❌ | À créer (placeholders, **0 secret réel**) |
| `platform/docker-compose.yml` (Laravel) | ✅ | ✅ | Distinct, conservé tel quel |

### D. Kubernetes

| Partie | Existe ? | État | Action |
|--------|:--------:|:----:|--------|
| `infra/k8s/base/` namespace, RBAC, NetworkPolicy default-deny, allow-DNS | ✅ | ✅ | OK |
| Per-service Deployment + Service + ServiceAccount | ✅ | 🟡 | Existant pour Laravel ; **ajouter** pour les nouveaux services Python |
| NetworkPolicies par flux | ✅ | 🟡 | Existantes par service Laravel ; à étendre aux services Python |
| Pod Security strict (RO rootfs, dropAll, seccomp) | ✅ | ✅ | Vérifié par `audit-pod-security.sh` |
| ConfigMap + Secret placeholders | ✅ | ✅ | OK |

### E. Kyverno

| Partie | Existe ? | État | Action |
|--------|:--------:|:----:|--------|
| `disallow-latest-tag` | ✅ | ✅ | `restrict-image-references.yaml` |
| `require-image-digest` | ✅ | ✅ | idem |
| `require-runAsNonRoot` | ✅ | ✅ | `require-pod-security.yaml` |
| `require-readOnlyRootFilesystem` | ✅ | ✅ | idem |
| `disallow-allowPrivilegeEscalation` | ✅ | ✅ | idem |
| `require-resources-requests-limits` | ✅ | ✅ | `require-workload-controls.yaml` |
| `verify-cosign-images` | ✅ | 🟡 | Existe en Audit ; bascule Enforce via `kyverno-enforce-sequenced.sh` |
| Tests admission positifs/négatifs | ✅ | ✅ | `tests/admission/` (1 positive + 5 negative) + runner `test-kyverno-fixtures.sh` |
| Rapport `artifacts/validation/kyverno-admission-tests.md` | ❌ | ❌ | À générer (ou pointer vers `artifacts/security/kyverno-fixtures-tests.md`) |

### F. Jenkins CI/CD

| Stage | Existe ? | État | Action |
|-------|:--------:|:----:|--------|
| Checkout SCM | ✅ | ✅ | `Jenkinsfile` |
| Setup | ✅ | ✅ | idem |
| Lint (black/isort/flake8 ou make lint) | ✅ | ✅ | `make lint` |
| Tests + coverage ≥ 70% | ✅ | 🟡 | Stage présent ; **dépendra du nouveau code** Python |
| Semgrep SAST | ✅ | ✅ | OK |
| Gitleaks | ✅ | ✅ | OK |
| Trivy fs / dependency | ✅ | ✅ | OK |
| Docker build | 🟡 | 🟡 | CD pipeline scanne ; build = orchestré par `make` |
| Trivy image scan | ✅ | ✅ | `Jenkinsfile.cd` |
| **kube-score bloquant** | ✅ | ✅ | **Cette branche** : `validate-kube-score.sh` strict + seuils |
| **Quality Gate consolidé** | ✅ | ✅ | **Cette branche** : `quality-gate.sh` |
| SBOM Syft | ✅ | ✅ | `Jenkinsfile.cd` `Generate SBOM` |
| Cosign sign + verify | ✅ | ✅ | `Jenkinsfile.cd` |
| Digest pinning image@sha256 | ✅ | ✅ | `pin-overlay-digests.sh` (cette branche) |
| Deploy kind | ✅ | ✅ | `verify-and-deploy-kind.sh` |
| Kyverno admission tests | ✅ | ✅ | `test-kyverno-admission.sh` + fixtures |
| Smoke tests | ✅ | ✅ | `smoke-tests.sh` |
| Final summary | ✅ | 🟡 | **Manque** : `docs/final-validation-summary.md` |

### G. Supply chain

| Partie | Existe ? | État | Action |
|--------|:--------:|:----:|--------|
| Trivy fs | ✅ | ✅ | OK |
| Trivy image | ✅ | ✅ | OK |
| Syft SBOM | ✅ | ✅ | OK |
| Cosign sign | ✅ | ✅ | OK |
| Cosign verify | ✅ | ✅ | OK |
| Digest pinning | ✅ | ✅ | OK |
| `cosign-verification-report.md` | ✅ | ✅ | Généré par CD pipeline (`verify-summary.txt/.md`) |
| `digest-runtime-report.md` | ✅ | ✅ | `runtime-image-rollout-proof.md` |

### H. Runtime security (Falco / Loki / Alertmanager)

| Partie | Existe ? | État | Action |
|--------|:--------:|:----:|--------|
| Falco DaemonSet + rules | ✅ | ✅ | `infra/k8s/runtime-detection/` |
| Falcosidekick → Loki + Alertmgr | ✅ | ✅ | Cette branche : `falcosidekick.yaml` |
| `runtime-detection-proof.md` | ❌ | ❌ | À générer après `falco-up` runtime |

### I. Observabilité

| Partie | Existe ? | État | Action |
|--------|:--------:|:----:|--------|
| Prometheus + RBAC + config + rules SLO | ✅ | ✅ | `infra/k8s/observability/` |
| **Prometheus security alerts** | ✅ | ✅ | Cette branche : `prometheus-rules-security.yaml` |
| Grafana | ✅ | ✅ | Deployment + Datasources |
| **Grafana dashboards SRE+Sécurité** | ✅ | ✅ | Cette branche : `grafana-dashboards.yaml` |
| Alertmanager | ✅ | ✅ | OK |
| Loki | ✅ | ✅ | OK |
| `observability/README.md` | ❌ | ❌ | À créer (référencer dashboards et alertes) |
| `slo-summary.md` | ❌ | ❌ | À générer |

### J. Argo CD

| Partie | Existe ? | État | Action |
|--------|:--------:|:----:|--------|
| `Application` (demo, production) | ✅ | ✅ | `infra/k8s/argocd/` |
| ApplicationSet | ✅ | ✅ | OK |
| Notifications drift detection | ✅ | ✅ | Cette branche : `notifications-cm.yaml` |
| `argocd-sync.md` | ❌ | ❌ | À générer après sync réelle (sinon PARTIAL) |
| `drift-proof.md` | ❌ | ❌ | À générer après scénario drift (sinon PARTIAL) |

### K. Backup / Restore

| Partie | Existe ? | État | Action |
|--------|:--------:|:----:|--------|
| CronJob `pg-backup` | ✅ | ✅ | Cette branche : `postgres-backup-cronjob.yaml` |
| Script restore drill | ✅ | ✅ | Cette branche : `restore-drill.sh` |
| `scheduled-backup-proof.md` | ❌ | ❌ | À générer après exécution (sinon PARTIAL) |
| `restore-report.md` | ❌ | ❌ | id |

### L. Secrets management

| Partie | Existe ? | État | Action |
|--------|:--------:|:----:|--------|
| `.sops.yaml` | ✅ | ✅ | Cette branche |
| Runbook rotation | ✅ | ✅ | `docs/runbooks/secret-rotation.md` |
| Drill rotation script | ✅ | ✅ | `rotate-and-verify.sh` |
| `docs/secrets-management.md` | ✅ | ✅ | `docs/security/secrets-management-hardening.md` (équivalent) |
| `secret-rotation-proof.md` | ❌ | ❌ | À générer après drill (sinon PARTIAL) |

### M. Chaos lite

| Partie | Existe ? | État | Action |
|--------|:--------:|:----:|--------|
| Script pod-delete avec preuve self-heal | ✅ | ✅ | Cette branche : `pod-delete-and-prove.sh` |
| `chaos-lite-proof.md` | ❌ | ❌ | À générer après exécution |

### N. MITRE ATT&CK

| Partie | Existe ? | État | Action |
|--------|:--------:|:----:|--------|
| Mapping détaillé 37 techniques | ✅ | ✅ | `docs/security/mitre-attack-k8s-mapping.md` |
| `docs/mitre-attack-report.md` | ❌ | ❌ | Lien/alias vers le mapping existant + extension scope chatbot |

### O. Documentation

| Doc | Existe ? | État | Action |
|-----|:--------:|:----:|--------|
| `README.md` racine | ✅ | 🟡 | À enrichir (présentation chatbot RAG) |
| `docs/architecture.md` | 🟡 | 🟡 | `docs/architecture/` existe ; ajouter `architecture.md` index |
| `docs/api-contracts.md` | ❌ | ❌ | À créer (OpenAPI deja sous `docs/openapi/`) |
| `docs/security-model.md` | 🟡 | 🟡 | `control-matrix.md` couvre l'essentiel |
| `docs/rag-design.md` | ❌ | ❌ | À créer |
| `docs/devsecops-pipeline.md` | 🟡 | 🟡 | `architecture/jenkins-devsecops.md` couvre |
| `docs/kubernetes-security.md` | 🟡 | 🟡 | `security/devsecops-hardening-applied.md` couvre |
| `docs/threat-model.md` | ❌ | ❌ | À créer |
| `docs/installation-guide.md` | ❌ | ❌ | À créer |
| `docs/user-guide.md` | ❌ | ❌ | À créer |
| `docs/final-validation-summary.md` | ❌ | ❌ | À générer |

## Plan d'action condensé

| Ordre | Tâche | Fichiers principaux | Effort |
|-------|-------|---------------------|-------:|
| 1 | Compléter src/ Python `auth-users` + tests | `services/auth-users/src/` + `tests/` | M |
| 2 | Compléter src/ Python `security-auditor` + tests | id | M |
| 3 | **Créer** `services/vectorstore-service/` (manquant) | nouveau service complet | L |
| 4 | Compléter `services/llm-orchestrator/` + mock LLM | id | M |
| 5 | Compléter `services/api-gateway/` (JWT + routing) | id | M |
| 6 | Tests intégration `tests/integration/` | nouveau | M |
| 7 | `docker-compose.yml` racine + `.env.example` | racine | S |
| 8 | Manifests K8s pour 5 services Python | `infra/k8s/base/python-services/` | M |
| 9 | Rapports `artifacts/validation/*.md` (final-summary, runtime, mitre alias) | docs + artifacts | S |
| 10 | Docs manquantes (rag-design, threat-model, install, user) | docs/ | M |

> **Effort :** S < 100 lignes · M ≤ 400 · L > 400.

## Statut global de l'audit

- **Code applicatif Python** : 🟡 PARTIAL (squelette OK, code source à livrer)
- **Pipeline DevSecOps** : ✅ PASS (CI + CD + Quality Gate déjà solides)
- **Infrastructure K8s/Kyverno** : ✅ PASS (à étendre pour services Python)
- **Supply chain** : ✅ PASS
- **Observabilité + alertes** : ✅ PASS
- **Documentation soutenance** : 🟡 PARTIAL (manque docs spécifiques chatbot)
- **Preuves runtime (artifacts/validation)** : 🟡 PARTIAL (à générer après exécutions)

**Verdict :** ce qui manque est essentiellement le **code applicatif Python**
(les 5 microservices + tests + docker-compose) et **quelques rapports
manquants** (`final-validation-summary.md`, `argocd-sync.md`, etc.). Le
DevSecOps + supply chain + K8s sont déjà au niveau cible.
