# Diagnostic DevSecOps — SecureRAG Hub

**Date** : 2026-09-23
**Type** : Diagnostic complet (analyse statique + exécution réelle des outils + audit du cluster live `securerag-dev` Kind v1.33.1)
**Périmètre** : Jenkinsfile ×8, GitHub Actions ×6, pre-commit, shared library `vars/`, Dockerfiles ×21, IaC Terraform, manifests K8s/Kyverno/NetworkPolicies, cluster live, scripts shell ×278, Makefile.
**Méthode** : chaque constat est adossé à une preuve (fichier:ligne, sortie de commande exécutée le jour du diagnostic).

---

## 1. Score global

| Pilier | Note | Commentaire |
|---|---|---|
| Hygiène Git & pre-commit | **3/5** | Gitleaks + TruffleHog + shellcheck en local,… mais l'allowlist masque des **secrets réels** |
| CI statique (SAST / secrets / SCA) | **2,5/5** | Outils présents, mais chaîne **fail-open** et gate unifié **jamais branché** |
| Supply chain (SBOM, signature, promotion) | **3,5/5** | Design excellent (SBOM CycloneDX, Cosign, promotion par digest), exécution affaiblie par les fallbacks |
| IaC (Terraform / K8s) | **2/5** | 32 CRITICAL Terraform scannés, Checkov rendu muet par `--soft-fail` |
| Admission & Runtime K8s | **3/5** | 8 ClusterPolicies **Enforce**, PSS `restricted`, netpols default-deny — mais Falco/Tetragon absents du cluster live, vérification Cosign jamais exercée sur les pods en cours |
| Observabilité & DR | **4/5** | Prometheus/Grafana/Alertmanager/Loki/Tempo/ArgoCD Running, Velero scripté, DORA evidence |
| **Global** | **≈ 3/5** | **Une chaîne architecturalement riche mais dont les portes ont été récemment déverrouillées pour tolérer l'indisponibilité des outils.** |

**Constat n°1, transversal** : les 3 derniers commits CI (`62b3dd48`, `211dba5c`, `07c627f6`) ont chacun assoupli un gate (signature → SKIP, Checkov → soft-fail, Sonar → optionnel). Le `Jenkinsfile` principal contient **24 occurrences** de `|| true` / `|| echo "[WARN]"`. La chaîne passe au vert **même quand les outils de sécurité sont absents ou échouent**.

---

## 2. Findings critiques (P0 — traiter sous 48 h)

### C1. Des secrets réels sont versionnés… et explicitement masqués au scanner
**Preuves exécutées** :
- `trivy fs --scanners secret` détecte une **clé privée inline dans `SRV_VPN_medysbneb.ovpn:71`** (`-----BEGIN PRIVATE KEY-----`, remote `41.229.78.31:1194`).
- `infra/terraform/securerag-dev-config` (tracké) est un **kubeconfig complet** : contient `client-key-data` (= clé privée client), `client-certificate-data`, `certificate-authority-data`.
- `gitleaks_results.json` (tracké à la racine) **contient une clé RSA privée** (HIGH ×2 confirmés par Trivy).
- Les 3 fichiers figurent dans l'allowlist de `.gitleaks.toml` :
  ```
  '''(^|/)SRV_VPN_medysbneb\.ovpn$'''
  '''(^|/)gitleaks_results\.json$'''
  '''(^|/)infra/terraform/securerag-dev-config$'''
  ```
  → Gitleaks ne les signalera **jamais**, ni en pre-commit ni en CI.
- Historique contaminé depuis le **2026-07-05** (`git log -- SRV_VPN_medysbneb.ovpn` → `ad6584ac`). La suppression seule ne suffit pas : le secret reste dans l'historique.

**Impact** : compromission VPN + accès cluster complet via kubeconfig. Si ce dépôt est poussé/publié (y compris en archive PFE), exposition directe.
**Remédiation** :
1. **Révoquer et régénérer** immédiatement : clé/certificat VPN et les credentials du cluster (`client-key-data`).
2. Purger l'historique : `git filter-repo --path SRV_VPN_medysbneb.ovpn --path infra/terraform/securerag-dev-config --path gitleaks_results.json --invert-paths` puis force-push coordonné.
3. Retirer ces 3 entrées de l'allowlist `.gitleaks.toml`. Une allowlist ne doit servir qu'à des *fixtures/synthétiques* — jamais à des artefacts contenant des vraies clés.
4. Déplacer vers Vault/SOPS (la stack est déjà prévue : `.sops.yaml`, ESO).

### C2. Chaîne « fail-open » : les gates passent au vert quand les outils échouent
**Preuves** (toutes du code actuel) :
| Gate | Preuve | Comportement actuel |
|---|---|---|
| Signature Cosign | `scripts/release/sign-images.sh:28` → `ALLOW_SIGN_FALLBACK=true` par défaut | Images **non signées → SKIP, build vert** |
| Checkov IaC | `Jenkinsfile:198` `--soft-fail` | Les **32 CRITICAL Terraform** ne bloquent rien |
| SonarQube | `Jenkinsfile:221` `REQUIRE_SONAR:-false` | Sonar offline → stage vert |
| Trivy FS scan | `vars/trivyScan.groovy` : `... || true` + placeholder `{"Results": []}` si Trivy absent | Jamais d'échec, **pas de seuil CVE** |
| Grype CVE gate | `Jenkinsfile:262` guard `command -v grype` | Grype absent → scan silencieusement sauté |
| AI Risk gate | `Jenkinsfile:357` : si les services IA (localhost:8091/8092) sont down → risque `15.0 LOW` | **Indisponibilité = approbation** |
| Smoke / k6 / MLSecOps / Enterprise health | `Jenkinsfile:399,402,338,436` — `|| echo "[WARN]"` | Gates de validation jamais bloquants |
| Dépendances | `Jenkinsfile:115,128` `composer install … \|\| true`, `npm ci … \|\| npm install … \|\| true` | Build peut continuer sans deps |

**Impact** : le pipeline peut rapporter 100 % vert sur un build non signé, non scanné, non testé. C'est un *security theater* : la confiance affichée n'est pas la confiance réelle.
**Remédiation** :
- Inverser les valeurs par défaut : `ALLOW_SIGN_FALLBACK:-false`, `REQUIRE_SONAR:-true`, suppression de `--soft-fail` (ou seuil `--hard-fail-on CRITICAL`).
- Politique explicite : le mode « dégradé toléré » ne doit exister que via un paramètre explicite du build (`params.ALLOW_DEGRADED_DEV`) et jamais sur `main`/release.
- AI Risk gate : fallback → `risk = 100` (fail-closed), pas `LOW`.

### C3. Terraform : exposition publique critique des clusters
**Preuve** : `trivy config infra/terraform` (exécuté) :
- `aws/eks.tf:174-179` — **CRITICAL** : API EKS publique sur `0.0.0.0/0` ; secrets etcd non chiffrés (HIGH) ; metadata endpoints legacy (HIGH).
- `azure/aks.tf:69-141` — **CRITICAL** : API AKS sans restriction d'IP.
- `modules/security/main.tf` — **32 CRITICAL** : règles de security groups en egress vers `0.0.0.0/0` (loadbalancer l.46, worker l.176, …), subnets à IP publiques, load balancers publics.

**Remédiation** : restreindre `cluster_endpoint_public_access_cidrs` au CIDR VPN/bastion, activer `encryption_config` (KMS) sur EKS, scoper les egress SG aux ports/destinations réels, alimenter `docs/security/trivy-accepted-risks.md` pour tout écart assumé.

---

## 3. Findings élevés (P1 — semaine)

### E1. Le moteur de gate unifié existe… mais n'est branché nulle part
`vars/securityGate.groovy` (« FAANG-grade scope-aware security gate ») : **`grep -l securityGate Jenkinsfile*` → ABSENT de tous les pipelines**. Il n'y a donc **aucune décision de gate consolidée** Trivy+Semgrep+Gitleaks en CI. Brancher `securityGate(failOnHigh: true, failOnCritical: true)` après le stage `Parallel Scans & Tests`.

### E2. Gitleaks CI ne scanne pas l'historique
`vars/runSastScan.groovy:34` : `gitleaks detect --no-git` → scanne uniquement la copie de travail. C'est exactement ainsi que C1 est passé inaperçu. Ajouter un job (par ex. `Jenkinsfile.weekly`) en `gitleaks git --log-opts="--all"` sur l'historique complet.

### E3. La vérification Cosign d'admission est inopérante sur le cluster actuel
Preuve exécutée — tentative de création d'un pod `localhost:5001/securerag-hub-portal-web:dev` :
```
admission webhook "mutate.kyverno.svc-fail" denied:
securerag-verify-cosign-images: Get "https://localhost:5001/v2/": dial tcp [::1]:5001: connection refused
```
Points à noter :
- ✅ La policy est **fail-closed** (bonne posture) et **Enforce**.
- ❌ Mais le registry `localhost:5001` est **injoignable depuis le cluster Kind** → la vérification ne peut aboutir → **tout redéploiement/scale dans `securerag-hub` sera bloqué** en l'état.
- ❌ Tous les pods applicatifs ont été créés **avant** la policy (`portal-web` 03h20, policy 03h56, `background: false`) → **aucune image en cours d'exécution n'a jamais été vérifiée**.
- ❌ `portal-web` tourne sur le tag **mutable** `:dev` tandis que les 4 autres services sont épinglés par `@sha256:` (incohérence avec le principe « no-rebuild deploy » du Makefile).
- ℹ️ Drift doc/réalité : le README vante la signature *keyless* (Keycloak/Fulcio/Rekor) ; la policy live est en **clé statique** (les fichiers `k8s/kyverno-policies/*.yaml` sont des templates `@FULCIO_ROOT@` non substituables tels quels — YAML invalide sans le script `scripts/kyverno-verify/apply-verify-policies.sh`, qui existe ✔).

**Remédiation** : rendre le registry joignable depuis le CNI Kind (adresse `kind-registry` / `registry.securerag.local` résolvable dans-cluster), ré-admissionner les workloads après vérification (rollout restart), épingler `portal-web` par digest, documenter le mode statique vs keyless.

### E4. Détection runtime absente du cluster live
Falco/Tetragon : manifests présents (`security/falco/`, `infra/k8s/security/falco/`, `infra/k8s/argocd/application-falco-talon.yaml`) mais **aucun pod Falco/Tetragon** dans le cluster (`kubectl get pods -A`). La couche « Surveillance Runtime » du README (Falco → Sidekick → Slack) n'est pas active dans ce contexte. À déployer via ArgoCD ou à documenter comme « prod-only ».

### E5. Scripts shell cassés — `make lint` échoue
`bash -n` sur 278 scripts → **2 échecs** :
- `scripts/finops/generate-cost-report.sh:91` (erreur de quoting du heredoc Python),
- `scripts/validate/worldclass-validation.sh:335` (parenthèse non fermée en amont).
→ Le script de validation « world-class » **ne peut pas s'exécuter** ; corriger puis réactiver dans `make lint`.

---

## 4. Findings moyens (P2)

| # | Constat | Preuve | Remédiation |
|---|---|---|---|
| M1 | XXE : `xml` natif Python | Semgrep exécuté : `python.lang.security.use-defused-xml-parse` — `scripts/ai/analyze-security-reports.py:94` | `defusedxml` + test de régression |
| M2 | JWT en clair dans le code | Semgrep : JWT détecté — `scripts/ai-agents/ai_testing_agent.py:39` | Si token de test : fixture + commentaire ; sinon rotation |
| M3 | `Dockerfile.unified` tourne en **root** | aucun `USER` (multistage CI) | Si image CI-only : le documenter ; sinon `USER` non-root |
| M4 | Base non pinnée | `docker/portal-web/Dockerfile` : `FROM composer:2` (les `services-laravel/*/Dockerfile` sont eux épinglés par `@sha256:` ✔) | Épingler par digest |
| M5 | `readOnlyRootFilesystem` absent | Trivy config : ollama, openwebui, backstage, cluster-autoscaler, CronJob `aiops-log-analyzer` | Ajouter `securityContext.readOnlyRootFilesystem: true` |
| M6 | RBAC trop large | Trivy config **CRITICAL** : ClusterRole `securerag-backup-argocd-reader` peut « manage secrets » | Restreindre à `get/list` ciblé |
| M7 | ConfigMaps Argocd à contenu credentials | Trivy config HIGH : `argocd-image-updater-config` (`credentials`), `argocd-cm-health-checks` | Migrer en Secrets/ESO |
| M8 | `HEALTHCHECK` absent de ~20 Dockerfiles | audit statique (seul `ai-security-service` en a un) | Ajouter ou documenter (géré par probes K8s) |
| M9 | PSS restrictif limité à `securerag-hub` | `kubectl get ns -L …enforce` : `argocd`, `monitoring`, `loki`, `tempo` sans label | Appliquer `baseline`/`restricted` aux namespaces d'infra |
| M10 | TruffleHog pre-commit limité | `.pre-commit-config.yaml:30` `--since-commit HEAD` → un merge/rebase échappe au scan | Utiliser `--since-commit origin/main` ou un hook `pre-push` |
| M11 | Sémantique pre-commit obsolète | `stages: [commit]` (v3+) | Remplacer par `stages: [pre-commit]` |
| M12 | Renovate `automerge` minor/patch | `renovate.json` | Exiger les checks Jenkins en branch protection avant automerge |
| M13 | API Kyverno dépréciée | warning cluster : `ClusterPolicy` deprecated → `ValidatingPolicy`/`ImageValidatingPolicy` (CEL) | Planifier la migration |

---

## 5. Points forts à préserver (constats positifs vérifiables)

- ✅ **Admission K8s réellement durcie** : 8 ClusterPolicies `validationFailureAction: Enforce`, namespace `securerag-hub` en PSS `enforce=restricted`, 11 NetworkPolicies avec `00-default-deny-all`.
- ✅ **Supply chain bien conçue** : SBOM CycloneDX généré **et validé** (`validate-sbom-cyclonedx.sh`), Cosign attest, promotion **par digest** enregistrée (`promotion-digests.txt`), déploiement sans rebuild.
- ✅ **Images de bonne facture** : multi-stage, non-root (`USER 10001`, distroless `:nonroot` sur api-gateway), bases pinnées par digest sur les services métier.
- ✅ **Cluster live sain** : 6/6 pods applicatifs Running, stack observabilité complète (Prometheus, Grafana, Alertmanager, Loki, Tempo), ArgoCD opérationnel.
- ✅ **Test d'admission Cosign exécuté** : le refus est effectif et fail-closed.
- ✅ **Gestion des exceptions mature** : `.trivyignore` avec dates d'expiration + tickets (`SEC-NNN`) — excellente pratique, à conserver.
- ✅ **6 workflows GitHub YAML valides**, renders Kustomize des 6 overlays/policies valides, actions épinglées par SHA dans `ci-pr.yml`/`build-sign.yml`.
- ✅ `.gitleaks.toml` utilise des regexes de *placeholders* et l'allowlist est commentée — le cadre est bon, seul l'abus sur secrets réels (C1) est à corriger.
- ✅ Gates récents renforcés : couverture globale 95 % effective (`d5264c98`), DORA evidence, k6 SLO, DR Velero scripté.

---

## 6. Plan de remédiation priorisé

### P0 — 48 h
1. **C1** : rotation VPN + kubeconfig, purge historique Git, nettoyage allowlist gitleaks.
2. **C2** : repasser les gates en fail-closed (`ALLOW_SIGN_FALLBACK=false`, `REQUIRE_SONAR=true`, retrait `--soft-fail` ou seuil CRITICAL, AI risk fallback = blocage).
3. **C3** : restreindre l'exposition publique EKS/AKS + egress SG.
4. **E1** : brancher `securityGate()` dans le Jenkinsfile après les scans.

### P1 — semaine
5. **E2** : job hebdo `gitleaks git --log-opts=--all` (historique).
6. **E3** : connectivité registry↔kind pour Kyverno, rollout restart post-vérification, `portal-web` par digest.
7. **E4** : activer Falco via ArgoCD (ou documenter la non-applicabilité dev).
8. **E5** : corriger les 2 scripts shell, réactiver `make lint` en pre-merge.

### P2 — sprint
9. M1–M13 (XXE, JWT, USER/HEALTHCHECK, readOnlyRootFilesystem, RBAC backup, PSS autres namespaces, hooks pre-push, Renovate+branch protection, migration Kyverno CEL).

---

## 7. Annexes — commandes de vérification

```bash
# Rejouer les preuves de ce diagnostic
trivy fs --scanners secret --severity HIGH,CRITICAL --skip-dirs node_modules --skip-dirs vendor --skip-dirs .git .
trivy config --severity CRITICAL infra/terraform
for f in $(find scripts -name '*.sh'); do bash -n "$f" || echo "FAIL $f"; done
semgrep scan --config p/default --severity ERROR --json scripts/
kubectl get cpol -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.validationFailureAction}{"\n"}{end}'
kubectl run cosign-test --image=localhost:5001/securerag-hub-portal-web:dev --restart=Never -n securerag-hub --dry-run=server
kubectl get ns -L pod-security.kubernetes.io/enforce
```

*Rapport généré à partir d'une analyse réelle du dépôt et du cluster — aucune donnée simulée.*
