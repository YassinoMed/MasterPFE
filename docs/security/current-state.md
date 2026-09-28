# SecureRAG Hub — État réel (Phase 0 : Audit complet)

> **Date d'audit : 2026-09-27** — Méthode : lecture seule (git, kubectl, kustomize).
> Aucune modification effectuée pendant cet audit.
> Discipline de statuts : `OBSERVÉ` (vu en cluster), `VALIDÉ` (test exécuté avec succès),
> `IMPLÉMENTÉ` (code/manifests présents), `PARTIEL`, `NON VALIDÉ`, `ABSENT`, `BLOQUÉ`.

---

## 1. Contexte Git

| Élément | Valeur observée |
|---|---|
| Branche | `main` |
| HEAD | `946a5e91 feat(spire+velero): Phase 8 FULLY REALIZED + Phase 10 documented` |
| Remote | `git@github.com:YassinoMed/MasterPFE.git` |
| Working tree | propre |
| Fichiers trackés | 14 258 |
| Fichiers parasites trackés | `-` et `1` (fichiers vides commités à la racine) |

**Règle Git confirmée :** jamais `git add .`, commits atomiques, `git add <fichier précis>`.

---

## 2. État réel du cluster (`kind-securerag-dev`, k8s v1.33.1, 2 nœuds) — OBSERVÉ

### 2.1 ArgoCD — 29 Applications

**Saines (26) :** Synced+Healthy — backup, cert-manager, demo, dev, dr (+dr-cluster), eso,
falco-talon, harbor, image-updater, ingress-nginx, kyverno, metrics-server, otel, pki,
preprod, recette, runtime-detection, staging, test, trivy-operator, vault, velero.

**Anomalies pré-existantes** (antérieures à cet audit) :

| Application | État | Cause observée |
|---|---|---|
| `securerag-observability` | **Degraded** | à diagnostiquer |
| `securerag-root` | **Degraded** | à diagnostiquer |
| `securerag-secrets` | **Degraded** | à diagnostiquer |
| `securerag-kyverno-policies` | **OutOfSync** | 5 ressources orphelines |
| `securerag-production` | **OutOfSync + Progressing** | Conflit de propriété : ~35 ressources (Deployments, HPA, PDB, NetworkPolicies, ServiceAccounts…) réclamées par `securerag-production` **ET** `securerag-prod` → doublon d'Application ArgoCD |

### 2.2 Pods problématiques — OBSERVÉ

| Composant | État | Impact |
|---|---|---|
| `velero/minio-v`, `velero/minio-v-post-job` | **ImagePullBackOff** | `BackupStorageLocation default = Unavailable` → **sauvegardes Velero non fonctionnelles** (3 schedules, 0 objet Backup) |
| `securerag-backup` CronJobs (etcd/vault/argocd) | Completed | sauvegardes internes OK (distinctes de Velero) |

### 2.3 Composants RUNNING — OBSERVÉ ✓

ArgoCD (+ image-updater), cert-manager, ESO (external-secrets), **Falco + Talon +
falcosidekick**, Harbor (core/db/registry/trivy/jobservice/nginx/portal), ingress-nginx,
**Jenkins** (2/2), **Kyverno** (4 contrôleurs, ~10 restarts chacun — à surveiller), Loki,
Prometheus + Grafana + Alertmanager, OTel Collector + Tempo, **Chaos Mesh**, **SPIRE**
(server + 2 agents), Trivy operator (scans actifs observés), **Vault**, Velero server.

### 2.4 Vault — OBSERVÉ

✅ Sorti du dev mode : **Raft, HA enabled**, initialisé, descellé (shamir 5/3), v1.18.1.
Non confirmé : KMS auto-unseal, audit logs, dynamic DB credentials.

### 2.5 SPIRE — OBSERVÉ

Server + 2 agents Running (9 h). **1 seule registration entry**
(`spiffe://cluster.local/ns/securerag-hub/sa/sa-auth-users`). Généralisation non faite.

### 2.6 Composants ABSENTS du cluster (présents dans le repo, NON déployés)

| Composant | Repo | Cluster |
|---|---|---|
| **Ratify** | `scripts/ratify/deploy-ratify.sh` | ABSENT (0 CRD) |
| **Tetragon** | `infra/k8s/tetragon/`, `scripts/tetragon/` | ABSENT |
| **Cilium/Hubble** | `infra/k8s/cilium/`, rôle ansible, 4 CiliumNetworkPolicy | ABSENT — **CNI réel = kindnet**, les CNP ne sont pas appliquables |
| **SonarQube** | `infra/sonarqube/` | ABSENT (pas de namespace) |
| **Ollama / Qdrant / runtime RAG/LLM** | `infra/k8s/base/{ollama,qdrant,llm-orchestrator}`, `services/{rag-service,llm-orchestrator,knowledge-hub}` | ABSENT — aucun pod RAG/LLM |
| **DORA exporter** | `infra/k8s/observability/dora-exporter` | ABSENT |
| Kyverno CEL (`ValidatingPolicy`) | `infra/k8s/policies/kyverno-cel/disallow-root-containers.yaml` | ABSENT — 0 ValidatingPolicy |

Le namespace `securerag-hub` héberge : portal-web, auth-users (×3), chatbot-manager,
conversation-service, audit-security-service, postgres-auth, **secai** — 6 microservices +
moteur d'analyse. **Pas de pile RAG déployée.**

---

## 3. Validation Kustomize — VALIDÉ ✓

```
dev ✓  demo ✓  recette ✓  staging ✓  production ✓  dr ✓   (6/6 build OK)
```

Note : **12 overlays existent** (en plus : `preprod`, `test`, `legacy`,
`production-external-db`, `_hub-foundation`) — au-delà des 6 attendus. Périmètre officiel
à confirmer.

---

## 4. DevSecOps — État réel

### 4.1 Pipeline Jenkins principal (`Jenkinsfile`, 7 stages)

`Validate Manifests → SECAI (never blocks) → SBOM+Grype → Cosign Sign → SLSA Provenance →
Quality Gate + Promotion (8 gates) → Deploy verify`

- ✅ SBOM CycloneDX + Grype (`--fail-on high,critical`), Cosign, provenance SLSA,
  quality gate avec `exit 1` réel.
- ⚠️ Pas de stage SAST/SCA/tests unitaires dans le Jenkinsfile principal (Semgrep/gitleaks/
  tests existent en scripts, consommés par `scripts/ci/quality-gate.sh` via artefacts).
- ⚠️ **Cosign = clé fichier** (`SKIP_SIGNING`, clé du cluster). Keyless documenté
  (`docs/security/cosign-keyless-migration.md`) mais **non implémenté**.
- ⚠️ Image agent Jenkins : `mohamedyassinebouneb/securerag-hub-unified:latest` —
  **non épinglée par digest**, `imagePullPolicy: Always`.
- ⚠️ Stage SECAI explicitement « never blocks ».
- Jenkinsfiles annexes : `.ai`, `.cd`, `.dr`, `.nightly`, `.perf`, `.recette`, `.weekly` +
  3 jobs DSL (`infra/jenkins/jobs/`).

### 4.2 Secrets dans Git — CONSTAT CRITIQUE

| Fichier tracké | Verdict |
|---|---|
| `infra/k8s/backup/s3-backup-credentials.yaml` | 🔴 **Identifiants en clair commités** (`minioadmin`/`minioadmin` + `ENCRYPTION_PASSWORD`). Cible locale/faible valeur, mais viole « aucun secret en clair ». Rotation + migration SOPS/ESO requise |
| `ai-security-service/k8s/secret.yaml` | ✅ `HF_TOKEN` = placeholder — pas de fuite, structure à revoir |
| `infra/k8s/argocd/applicationsets/platform.yaml` | ✅ bénin (ignoreDifferences sur Secret) |
| `cosign.key` / `cosign.pub` | ✅ sur disque mais **gitignorés** (non trackés) |
| `SRV_VPN_medysbneb.ovpn` | ⚠️ configuration VPN commitée |

### 4.3 Kyverno — OBSERVÉ

8 `ClusterPolicy` Ready : audit-cleartext-env-values, disallow-host-network,
disallow-root-containers, require-workload-controls, restrict-image-references,
restrict-service-exposure, restrict-volume-types, verify-cosign-images.
⚠️ API `kyverno.io/v1` **dépréciée** ; migration `ValidatingPolicy`/CEL non appliquée.
38 `NetworkPolicy` + 1 `PolicyException` (postgres-auth-nodeport).

### 4.4 Preuves (evidence/)

28 fichiers, dont snapshots 2026-09-27 : vault-status, falco-events-24h,
trivy-vulnreports, pods-all, dora-metrics-report, spire-deployment-status,
security-benchmark (CIS 14/15 = 93 %), drill de détection, finops-cost-allocation.
Le repo possède `docs/security/security-status-source-of-truth.md` (discipline
TERMINÉ/PARTIEL/PRÊT_NON_EXÉCUTÉ) — référentiel d'honnêteté à respecter.

---

## 5. MLSecOps — État réel (domaine le plus éloigné de la cible)

| Capacité | État réel | Verdict |
|---|---|---|
| Script MLSecOps | `scripts/ci/run-mlsecops-scans.sh` existe, **non appelé par le Jenkinsfile principal** | PARTIEL |
| Model scan (ModelScan/PickleScan) | implémenté avec fallback heuristique maison | PARTIEL — NON VALIDÉ |
| LLM red-teaming (Garak) | **fallback SIMULÉ** : JSON « PASSED » codé en dur si garak absent | 🔴 NON VALIDÉ — preuve simulée |
| ML supply chain audit | JSON codé en dur (`mlsecops_status: COMPLIANT`) | 🔴 SIMULÉ |
| Pipeline dataset (PII/secrets/poisoning) | `scripts/mlsecops/data-security/` inexistant | ABSENT |
| Model registry / signature / provenance modèle | absent (seule la provenance *image* existe) | ABSENT |
| Model evaluation gate (F1, injection, leakage) | absent | ABSENT |
| RAG security (input/context/output) | `ai-security/` (qdrant_rbac_filter, xai_explainer, MITRE mapping), `tests/admission/` pos/neg | PARTIEL — runtime non déployé |
| Code RAG (rag-service, llm-orchestrator, knowledge-hub) | Dockerfiles + requirements | code seul, non déployé |
| `secai` | package Python réel, service Running, pipelines (security_analysis, alert_correlation, evaluation, remediation) | IMPLÉMENTÉ ✓ déployé ✓ |

---

## 6. Synthèse par domaine

| Domaine | Verdict honnête |
|---|---|
| GitOps/ArgoCD | IMPLÉMENTÉ — avec conflit de propriété prod/production + 3 apps Degraded |
| Kustomize 6 envs | VALIDÉ (build 6/6) |
| CI/CD Jenkins | IMPLÉMENTÉ — tests/SAST absents du pipeline principal ; agent non épinglé |
| Supply chain (SBOM/sign/provenance) | IMPLÉMENTÉ (key-based) — keyless non migré |
| Admission (Kyverno) | IMPLÉMENTÉ — API dépréciée ; Ratify absent |
| Secrets (Vault/ESO) | Vault HA/Raft OBSERVÉ ✓ — KMS/dyn-creds NON CONFIRMÉS — 1 secret en clair dans git |
| Runtime (Falco+Talon) | IMPLÉMENTÉ ✓ — Tetragon absent |
| Réseau zero-trust | NetworkPolicies présentes — CNI kindnet, pas de Cilium/Hubble/L7 |
| SPIFFE/SPIRE | PARTIEL (1 seule SVID) |
| DR/Backup | 🔴 **Velero cassé (storage Unavailable)** — DR documenté mais sauvegarde inopérante |
| Observabilité | IMPLÉMENTÉ ✓ — dashboards ML/RAG/DORA absents |
| Chaos | Chaos Mesh OBSERVÉ |
| MLSecOps / RAG security | 🔴 **Point le plus faible** — scans simulés, runtime RAG absent, aucun gate modèle/dataset |
| Evidence | IMPLÉMENTÉ (28 artefacts) |

---

## 7. Risques identifiés (ordre de priorité proposé)

| # | Risque | Gravité |
|---|---|---|
| R1 | Secret MinIO en clair commité dans git | Haute |
| R2 | Conflit de propriété ArgoCD prod ↔ production (dernière écriture gagne) | Haute |
| R3 | Velero inopérant → aucune restauration possible aujourd'hui | Haute |
| R4 | MLSecOps « simulé » → risque de sur-déclaration | Haute |
| R5 | Kyverno `ClusterPolicy` v1 déprécié (suppression annoncée) | Moyenne |
| R6 | Aucune pipeline dataset/modèle (PII, poisoning, évaluation) | Haute |
| R7 | 3 Applications Degraded non diagnostiquées | Moyenne |
| R8 | Image agent Jenkins `:latest` non épinglée | Moyenne |
| R9 | Fichiers parasites `-` et `1` + `.ovpn` trackés | Faible |

---

## 8. Commandes de validation exécutées (re-jouables)

```bash
git status --short && git branch --show-current && git log --oneline -10 && git remote -v
kubectl get applications -n argocd
kubectl get pods -A
kubectl get nodes
kubectl get events -A --sort-by=.lastTimestamp
kubectl get ns
kubectl get clusterpolicies
kubectl get validatingadmissionpolicy,validatingadmissionpolicybinding
kubectl exec -n vault securerag-vault-0 -- vault status
kubectl exec -n spire-system deploy/spire-server -- /opt/spire/bin/spire-server entry show
kubectl get backups,backupstoragelocation,schedule -n velero
kubectl kustomize infra/k8s/overlays/{dev,demo,recette,staging,production,dr}
git ls-files | grep -E '(cosign\.key|\.ovpn|secret)'
```

---

## 9. Next

- PHASE 1 — Cartographie des flux (CODE→CI→…→RUNTIME et DATASET→…→MONITORING),
  points de confiance.
- Remédiations P0 proposées : secret MinIO en clair, conflit ArgoCD prod, réparation
  Velero, honnêteté MLSecOps, diagnostic des 3 apps Degraded.

*Document généré à l'issue de la PHASE 0 (audit en lecture seule). Aucun fichier du repo
n'a été modifié ou supprimé pendant l'audit ; ce document est la seule écriture.*
