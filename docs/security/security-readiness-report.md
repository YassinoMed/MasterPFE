# Security Readiness Report — SecureRAG Hub

> **Source de vérité unique** pour la posture sécurité avant soutenance.
> Synchronisé avec `docs/security/security-status-source-of-truth.md` et avec
> les artefacts produits par les pipelines Jenkins CI / CD.
>
> _Convention d'état :_
> - ✅ `TERMINÉ` — implémenté + preuve runtime ou artefact archivé
> - 🟡 `PARTIEL` — présent mais incomplet ou non rejoué dans l'environnement final
> - 🔵 `PRÊT_NON_EXÉCUTÉ` — code/config prêts ; rejouer en environnement
> - ⚪ `OPTIONNEL` — utile mais non critique pour la soutenance

## Résumé exécutif

| Domaine | Maturité | Verdict |
|---------|----------|---------|
| Build & supply chain (CI Jenkins) | 90 % | ✅ TERMINÉ après cette PR |
| Supply chain release (CD Jenkins) | 95 % | ✅ TERMINÉ — Cosign + SBOM + SLSA + digest |
| Admission control (Kyverno) | 80 % | 🟡 PARTIEL — Audit prêt, Enforce planifié |
| Pod Security baseline | 85 % | 🟡 PARTIEL — manifests OK, runtime à valider |
| NetworkPolicies | 75 % | 🟡 PARTIEL — default-deny + DNS, granularité par flux à compléter |
| Secrets management | 60 % | 🟡 PARTIEL — placeholders Git ; SOPS+age ou ESO à activer |
| Runtime detection (Falco) | 50 % | 🔵 PRÊT — config `security/falco`, à brancher Loki |
| Observabilité (Prometheus/Grafana/Loki) | 40 % | 🟡 PARTIEL — metrics-server installé, dashboards à provisionner |
| Backup PostgreSQL | 50 % | 🔵 PRÊT — `infra/k8s/backup/`, restore drill à dérouler |
| Chaos lite | 40 % | 🟡 PARTIEL — flags `RUN_POD_DELETE` etc. à rejouer |
| MITRE ATT&CK mapping | 20 % | 🟡 PARTIEL — ébauche à étendre |
| GitOps single source of truth | 80 % | ✅ Argo CD app-of-apps + sync manuel production |

---

## Cartographie détaillée des 19 contrôles + gouvernance

### P0 — Critiques

#### 1. kube-score bloquant
- **Statut :** ✅ `TERMINÉ` (cette PR)
- **Artefacts :**
  - Script : [`scripts/ci/validate-kube-score.sh`](../../scripts/ci/validate-kube-score.sh)
  - Rapport : `artifacts/security/kube-score-report.md`
  - Status machine : `artifacts/security/kube-score-status.txt`
- **Comportement :** Strict par défaut (`STRICT_KUBE_SCORE=true`), seuils
  `KUBE_SCORE_MAX_CRITICAL=0` et `KUBE_SCORE_MAX_WARNINGS=0`. Échec si binaire
  absent en CI.
- **Preuve live :**
  ```bash
  STRICT_KUBE_SCORE=true bash scripts/ci/validate-kube-score.sh
  cat artifacts/security/kube-score-status.txt   # → TERMINÉ
  ```

#### 2. Quality Gate Jenkins consolidé
- **Statut :** ✅ `TERMINÉ` (cette PR)
- **Artefacts :**
  - Script : [`scripts/ci/quality-gate.sh`](../../scripts/ci/quality-gate.sh)
  - Rapport : `artifacts/security/quality-gate-summary.md`
  - JSON : `artifacts/security/quality-gate-summary.json`
- **Stage Jenkins :** `CI_QUALITY_GATE - Aggregated Verdict` (paramètre `ENFORCE_QUALITY_GATE=true`)
- **Couverture :** unit-tests, coverage ≥ 70 %, semgrep, gitleaks, trivy-fs,
  dependency-audit, kube-score, kyverno-static, sonar (opt-in), cosign (opt-in en CI ; required en CD).
- **Preuve live :**
  ```bash
  bash scripts/ci/quality-gate.sh && echo "PASS" || echo "FAIL"
  cat artifacts/security/quality-gate-summary.md
  ```

#### 3. Séparation CI / CD
- **Statut :** ✅ `TERMINÉ` (préexistant)
- **CI** : `Jenkinsfile` → tests + scans + policy validation + Quality Gate.
  N'écrit aucune image et **ne déploie pas**.
- **CD** : `Jenkinsfile.cd` → scan images RC → sign Cosign → verify → promote
  par digest → SBOM → attestation SBOM → SLSA provenance → deploy kind →
  validation runtime.
- **Preuve live :** lancer `Build with Parameters` sur les 2 jobs Jenkins ;
  artefacts archivés `artifacts/security/**` (CI) vs `artifacts/release/**`,
  `artifacts/sbom/**`, `artifacts/validation/**` (CD).

#### 4. Pinning images par digest
- **Statut :** 🟡 `PARTIEL` — base utilise `:dev` (intentionnel pour dev),
  `Jenkinsfile.cd` produit la promotion par digest dans
  `artifacts/release/promotion-digests.txt`. L'overlay `production` doit consommer
  ce fichier au lieu du tag.
- **Action restante :**
  1. Patch `infra/k8s/overlays/production/kustomization.yaml` pour utiliser
     `images:` avec `digest:` au lieu de `newTag:`.
  2. Job CD post-promotion qui patche `kustomization.yaml` et commit dans le
     repo GitOps (PR auto-mergée par bot ou validation manuelle).
- **Preuve live :**
  ```bash
  kubectl -n securerag-hub get deploy -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.template.spec.containers[*].image}{"\n"}{end}' | grep -v 'sha256:' && echo "DRIFT" || echo "OK"
  ```

#### 5. Kyverno verifyImages (Cosign)
- **Statut :** 🔵 `PRÊT_NON_EXÉCUTÉ` en mode Enforce
- **Politique :** [`infra/k8s/policies/kyverno/verify-cosign-images.yaml`](../../infra/k8s/policies/kyverno/verify-cosign-images.yaml)
- **Overlay Enforce :** [`infra/k8s/policies/kyverno-enforce/kustomization.yaml`](../../infra/k8s/policies/kyverno-enforce/kustomization.yaml)
- **Plan d'activation séquencé :**
  1. Appliquer Audit ; observer `kubectl get policyreport,clusterpolicyreport -A`
  2. Corriger toutes les violations sur namespace `securerag-hub`
  3. Appliquer Enforce **uniquement** sur le namespace `securerag-hub`
     (pas cluster-wide pour ne pas casser kube-system)
  4. Tester admission positive/négative (cf. P0-9)
- **Preuve live :**
  ```bash
  bash scripts/deploy/kyverno-enforce-toggle.sh enforce
  kubectl get clusterpolicies
  bash scripts/validate/test-kyverno-admission.sh
  ```

#### 6. Secrets : SOPS + age
- **Statut :** 🟡 `PARTIEL`
- **Existant :** `infra/secrets/sops/sops-age.example.yaml`,
  `infra/secrets/external-secrets/`
- **Action restante :**
  1. Générer 1 paire age dev + 1 prod (clé prod en HSM ou secret manager)
  2. Créer `.sops.yaml` à la racine avec `creation_rules` par chemin
  3. Encrypter `infra/secrets/production/*.yaml` → `*.enc.yaml`
  4. Job Jenkins agent installe `sops` + clé via Jenkins credential
  5. Argo CD plugin `argocd-vault-plugin` ou `helm-secrets` pour décrypter à l'apply
- **Procédure de rotation documentée :** voir
  [`docs/runbooks/secret-rotation.md`](../runbooks/secret-rotation.md) (à créer ; spec ci-dessous)
- **Test :** `make secrets-management` doit décrypter sans erreur
- **Preuve live :** rotation réelle en démo : changer un secret en clair local,
  re-encrypter, push, sync Argo CD, confirmer rolling restart.

#### 7. Rotation des secrets — procédure
- **Statut :** 🔵 `PRÊT_NON_EXÉCUTÉ`
- **Spécification de runbook :** `docs/runbooks/secret-rotation.md` (à créer)
  - Périodicité : 90 j prod, 30 j dev
  - Steps : générer nouveau secret, encrypter SOPS, push, Argo CD sync,
    rolling restart (`kubectl rollout restart`), invalider l'ancien secret
    après TTL grace period (24 h)
  - **Test automatisable :** script `scripts/secrets/rotate-and-verify.sh`
    qui rejoue le cycle en namespace de test

#### 8. Audit → Enforce progressif
- **Statut :** 🔵 `PRÊT_NON_EXÉCUTÉ`
- **Stratégie :** une politique à la fois, sur namespace `securerag-hub` uniquement.
  Ordre recommandé :
  1. `restrict-image-references` (refuse `:latest`, refuse images sans registry)
  2. `restrict-volume-types` (refuse `hostPath`)
  3. `require-pod-security` (PSS Restricted)
  4. `require-workload-controls` (resources, probes, replicas)
  5. `restrict-service-exposure` (pas de `NodePort` ou `LoadBalancer` non whitelistés)
  6. `verify-cosign-images` (✱ **dernier** — image-signing infra doit être stable)
  7. `audit-cleartext-env-values` (peut rester en Audit jusqu'à migration SOPS complète)
- **Preuve par étape :** snapshot `kubectl get clusterpolicy -o yaml` + policy reports vides

#### 9. Tests admission Kyverno (positifs + négatifs)
- **Statut :** 🔵 `PRÊT_NON_EXÉCUTÉ` — script existant : [`scripts/validate/test-kyverno-admission.sh`](../../scripts/validate/test-kyverno-admission.sh)
- **Cas à étendre :** ajouter dans le script un répertoire `tests/admission/`
  contenant :
  - `negative/` — pods/deploys qui DOIVENT être refusés (privilégié, hostPath, image non signée, image `:latest`, ENV `password=...`)
  - `positive/` — pods conformes qui DOIVENT passer
- **Preuve live :** sortie tabulaire `[REJECT][OK] negative/privileged-pod.yaml` etc.

#### 10. Pod Security strict
- **Statut :** 🟡 `PARTIEL` — script `validate-runtime-security-postdeploy.sh` existe
- **Audit à faire :** vérifier sur tous les `infra/k8s/base/*/deployment.yaml` :
  - `runAsNonRoot: true`
  - `readOnlyRootFilesystem: true`
  - `allowPrivilegeEscalation: false`
  - `capabilities: drop: [ALL]`
  - `seccompProfile.type: RuntimeDefault`
  - `runAsUser` et `runAsGroup` non-root
- **Action :** PR séparée — audit table + patches Kustomize ciblés
- **Preuve live :**
  ```bash
  STRICT=true bash scripts/validate/validate-runtime-security-postdeploy.sh
  cat artifacts/security/runtime-security-postdeploy.md
  ```

#### 11. NetworkPolicies granulaires
- **Statut :** 🟡 `PARTIEL`
- **Existant :** `infra/k8s/base/networkpolicy-default-deny.yaml`,
  `networkpolicy-allow-dns.yaml`, `networkpolicy-validation-egress.yaml`,
  `networkpolicy-validation-ingress.yaml`
- **Manquant :** un fichier `networkpolicy-<service>.yaml` par service avec
  liste explicite **ingress autorisé** (de qui ?) et **egress** (vers qui ?).
  Cible :
  - `portal-web` ← Ingress controller seulement, → `api-gateway` only
  - `api-gateway` ← `portal-web`, → `auth-users`, `chatbot-manager`, `audit-security-service`
  - `chatbot-manager` ← `api-gateway`, → `llm-orchestrator`, `knowledge-hub`, `qdrant`
  - `auth-users` ← `api-gateway`, → DB
  - `qdrant` ← `chatbot-manager`, `knowledge-hub` only
- **Preuve live :** `kubectl exec` dans un pod source autorisé vs un pod non
  autorisé ; `nc -zv target 80` réussit/échoue.

### P1 — Fortement recommandées

#### 12. Falco / Tetragon + Loki + Alertmanager
- **Statut :** 🔵 `PRÊT_NON_EXÉCUTÉ`
- **Existant :** `security/falco/` (rules), `infra/k8s/runtime-detection/`,
  validateur `scripts/ci/validate-falco-rules.sh`
- **À ajouter :**
  - Helm install Falco avec sidecar `falcosidekick` → output Loki
  - Loki Datasource Grafana
  - Alertmanager rules : règle `falco_alert_count{priority="Critical"} > 0`
- **Preuve live :** déclencher un `kubectl exec --it ... sh` dans un pod restreint
  → alerte Falco visible dans Grafana en < 30 s.

#### 13. Alertes sécurité Prometheus
- **Statut :** 🟡 `PARTIEL`
- **Règles à ajouter** (`infra/k8s/observability/alerts.yaml`) :
  - `KubernetesPodCrashLooping` (kube-state-metrics)
  - `KubernetesPodNotReady`
  - `KyvernoPolicyViolation` (depuis `kyverno_policy_results_total{result="fail"}`)
  - `FalcoCriticalEvent`
  - `ArgoCDAppOutOfSync`
  - `JenkinsBuildFailureSecurityStage`

#### 14. Dashboards Grafana SRE / Sécurité
- **Statut :** 🟡 `PARTIEL`
- **À provisionner** (ConfigMap → Grafana operator) :
  - **SRE** : disponibilité par service (probe SLI), latence p50/p95/p99,
    taux d'erreur, saturation CPU/mem
  - **Sécurité** : compteurs Kyverno fail/pass, top events Falco,
    refus admission, vulnérabilités Trivy par sévérité (depuis labels d'images)

#### 15. Drift detection Argo CD
- **Statut :** ✅ `PRÊT` — `ServerSideApply` actif. Manque notification
- **Action :** activer `argocd-notifications-cm` + webhook Slack/Teams sur
  `on-status-unknown` et `on-deployed`.

#### 16. Self-heal contrôlé
- **Statut :** ✅ `TERMINÉ` — `application-production.yaml` n'a pas `automated{}`,
  donc sync **manuel uniquement**. Bonus : `selfHeal: false` explicite dans
  l'app prod si on veut le rendre obvious.

#### 17. Backup PostgreSQL + restore
- **Statut :** 🔵 `PRÊT_NON_EXÉCUTÉ`
- **Existant :** `infra/k8s/backup/` (à inspecter)
- **À ajouter :** CronJob quotidien `pg_dump` → S3/MinIO compatible storage,
  rétention 30 j, **drill de restore mensuel** automatisé qui :
  1. Spawn un pod `postgres-restore-test` dans namespace isolé
  2. Restaure le dernier backup
  3. Lance `psql -c 'SELECT count(*) FROM users'` ≥ N
  4. Logue `RESTORE_OK` ou `RESTORE_FAIL` dans `artifacts/validation/restore-drill.log`
- **Preuve live :** déclencher manuellement le drill, montrer les logs.

#### 18. Chaos Engineering léger
- **Statut :** 🟡 `PARTIEL`
- **Hooks existants :** `RUN_POD_DELETE`, `RUN_ROLLOUT_RESTART`, `RUN_NODE_DRAIN`
  dans `scripts/validate/`
- **Action :** créer `scripts/chaos/pod-delete-and-prove.sh` qui :
  1. `kubectl delete pod -l app=portal-web --grace-period=0`
  2. Attend `kubectl wait --for=condition=Ready` < 60 s
  3. Confirme HTTP 200 sur `/health` durant la perturbation
  4. Écrit `artifacts/validation/chaos-pod-delete.md` avec timeline
- **Preuve live :** lancer en démo, montrer le pod disparaître puis se recréer.

#### 19. Cartographie MITRE ATT&CK Kubernetes
- **Statut :** 🟡 `PARTIEL` (à créer cette PR comme ébauche)
- **Fichier prévu :** `docs/security/mitre-attack-k8s-mapping.md`
- **Tactiques couvertes (mapping initial) :**

| Tactique | Technique | Contrôle SecureRAG |
|----------|-----------|---------------------|
| Initial Access | TA0001 / Compromised image | Kyverno verifyImages + Cosign + Trivy CRITICAL gate |
| Execution | TA0002 / Exec into container | NetworkPolicy default-deny + Falco rule `Terminal shell in container` + RBAC restrictif |
| Persistence | TA0003 / Backdoor container | Kyverno restrict-image-references + readOnlyRootFilesystem |
| Privilege Escalation | TA0004 / Privileged container | Kyverno require-pod-security PSS Restricted |
| Defense Evasion | TA0005 / Disable logging | Falco runtime detection + Loki append-only |
| Credential Access | TA0006 / Mounted SA token | `automountServiceAccountToken: false` + secrets via SOPS/ESO |
| Discovery | TA0007 / Network mapping | NetworkPolicy egress allowlist |
| Lateral Movement | TA0008 / Cluster API access | RBAC least-privilege + audit logs |
| Collection | TA0009 / Data from local volumes | Kyverno restrict-volume-types (no hostPath) |
| Exfiltration | TA0010 / DNS tunneling | NetworkPolicy egress + Falco DNS rule |
| Impact | TA0040 / Resource hijacking | LimitRange + ResourceQuota + HPA + drop ALL caps |

### Gouvernance

#### G1. GitOps single source of truth
- **Statut :** ✅ `TERMINÉ`
- **Argo CD apps :** `application-demo.yaml`, `application-production.yaml`,
  `applicationset-platform.yaml`
- **Convention :** **aucune** modification cluster en `kubectl apply` direct.
  Seule exception documentée : opérations break-glass tracées dans
  `docs/runbooks/break-glass.md`.

#### G2. Security Readiness Report
- **Statut :** ✅ `TERMINÉ` (ce document)
- **Workflow :** mis à jour à chaque PR sécurité ; CI Jenkins peut bloquer
  un merge si la table de couverture régresse (futur).

---

## Plan de soutenance — Live proofs

| Démo | Commande | Durée | Stage Jenkins |
|------|----------|-------|---------------|
| 1. Quality Gate qui PASS | `bash scripts/ci/quality-gate.sh` | 5 s | `CI_QUALITY_GATE` |
| 2. Quality Gate qui FAIL (régression simulée) | corrompre un test → `make test` → `quality-gate.sh` → FAIL | 30 s | id |
| 3. kube-score bloquant | injecter `securityContext: privileged: true` → CI échoue | 1 min | `CI_K8S_POLICY` |
| 4. Cosign signe + verify | `bash scripts/release/sign-images.sh` puis `verify-signatures.sh` | 1 min | CD `Sign Release Candidate Images` |
| 5. Promotion par digest | `bash scripts/release/promote-by-digest.sh` puis `kubectl get deploy -o yaml | grep image:` montre `@sha256:` | 30 s | CD `Promote Verified Images by Digest` |
| 6. Kyverno refuse image non signée | `kubectl apply -f tests/admission/negative/unsigned-image.yaml` → `denied` | 10 s | manuel |
| 7. NetworkPolicy bloque trafic | `kubectl exec qdrant -- nc -zv portal-web 80` → timeout | 10 s | manuel |
| 8. Chaos pod-delete + self-heal | `bash scripts/chaos/pod-delete-and-prove.sh` | 1 min | manuel |
| 9. Falco alerte runtime | `kubectl exec -it ... -- sh` puis voir Grafana | 30 s | manuel |
| 10. Restore drill PostgreSQL | `bash scripts/backup/restore-drill.sh` | 3 min | CronJob mensuel |

---

## Roadmap exécutable post-soutenance

Chaque item ci-dessous est livrable comme **une PR isolée** (≤ 400 lignes) :

1. PR-A : Pinning digest dans overlay production (P0-4) — auto-patcher dans CD
2. PR-B : SOPS + age intégration complète (P0-6) — clés, `.sops.yaml`, doc rotation
3. PR-C : Audit table Pod Security par service (P0-10) — patches Kustomize
4. PR-D : NetworkPolicies par service (P0-11) — 1 fichier par flux
5. PR-E : Kyverno Enforce séquencé (P0-8) — toggle script + tests admission
6. PR-F : Falco + Loki + Alertmanager (P1-12, 13) — Helm values + règles
7. PR-G : Dashboards Grafana SRE/Sécurité (P1-14) — JSON provisioning
8. PR-H : Argo CD notifications drift (P1-15) — `argocd-notifications-cm`
9. PR-I : Backup PG + restore drill (P1-17) — CronJob + script
10. PR-J : Chaos lite scripts + preuves archivées (P1-18)
11. PR-K : MITRE ATT&CK mapping complet (P1-19) — table exhaustive

**Estimation effort :** 2 PR/semaine × 11 PR = **6 semaines**.
