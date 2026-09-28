# 🗺️ ROADMAP — Prochaines Phases SecureRAG Hub

**Date** : 2026-09-27 · **Base** : `docs/security/current-state.md` (audit Phase 0) + `RECAP-PHASES.md`
**Règle d'honnêteté** : aucun statut `TERMINÉ` sans preuve réelle et re-jouable (cf. `docs/security/security-status-source-of-truth.md`).
**Priorités** : `SECURITY > CORRECTNESS > REPRODUCIBILITY > AVAILABILITY > PERFORMANCE > VITESSE`

> ⚠️ **MLSecOps n'est PAS encore réalisé.** C'est le chantier principal de cette roadmap.

---

## 0. Point de départ (audit 2026-09-27)

| Axe | État |
|---|---|
| GitOps / Kustomize (6 envs) | ✅ validé (`kubectl kustomize` 6/6) |
| CI/CD + Supply chain (SBOM, Cosign key-based, SLSA) | ✅ implémenté — **keyless non migré** |
| Admission Kyverno (8 policies v1) | ✅ actif — **API v1 dépréciée** |
| Vault (Raft+HA, descellé) / ESO | ✅ observé — KMS auto-unseal + dyn creds non confirmés |
| Runtime (Falco + Talon) | ✅ testé par drill réel |
| Observabilité (Prom/Loki/Tempo/Grafana/OTel) | ✅ actif — dashboards ML/RAG/DORA manquants |
| DORA (4/4) / FinOps / Evidence | ✅ mesurés sur données réelles |
| SPIRE | ⚠️ infra déployée, **1 seule SVID**, mTLS non généralisé |
| DR multi-cluster | ⚠️ GitOps DR validé — **Velero BSL Unavailable → backups KO** |
| Chaos Mesh | ✅ déployé — scénarios à exécuter en env de test |
| **MLSecOps complet** | ❌ **NON RÉALISÉ** (runtime RAG absent, scans simulés, aucun gate dataset/modèle) |

---

## 1. Remédiations P0 — corriger avant de construire (1-3 jours)

| # | Action | Pourquoi | Preuve de sortie |
|---|---|---|---|
| P0.1 | **Secret MinIO en clair** (`infra/k8s/backup/s3-backup-credentials.yaml`) → SOPS/ESO + retrait de la valeur + rotation | R1 : secret commité en clair | gitleaks propre, Secret géré par ESO |
| P0.2 | **Conflit ArgoCD `securerag-production` vs `securerag-prod`** (~35 ressources partagées) : analyser → garder **une seule** Application | R2 : dernière écriture gagne | `kubectl get applications` sans SharedResourceWarning |
| P0.3 | **Réparer Velero** : MinIO `ImagePullBackOff` → image accessible ou backend S3 réel → backup + **restore test** | R3 : aucune restauration possible | BSL `Available`, 1 `Backup` Completed, rapport restore |
| P0.4 | Diagnostiquer `securerag-observability`, `securerag-root`, `securerag-secrets` (Degraded) | R7 | 3 apps Healthy ou cause documentée |
| P0.5 | Nettoyage git : fichiers `-` et `1`, décision `.ovpn` | R9 | git propre, règle .gitignore |
| P0.6 | Épingler l'image agent Jenkins par **digest** (pas `:latest`) | R8 | Jenkinsfile avec `@sha256:…` |

---

## 2. Programme MLSecOps — le chantier principal (2-4 semaines)

> Objectif : chaîne `DATASET → VALIDATION → TRAINING → MODÈLE → ÉVALUATION → REGISTRY →
> SIGNATURE → DÉPLOIEMENT → RAG/LLM → MONITORING`, sans preuve inventée.

### Étape M1 — Déployer le runtime RAG (prérequis)
- Activer `ollama`, `qdrant`, `rag-service`, `llm-orchestrator`, `knowledge-hub` (manifests présents dans `infra/k8s/base/`, images présentes dans `services/*/Dockerfile`).
- **Sortie** : pods RAG Running dans `securerag-hub`, service `qdrant`/`ollama` joignables.

### Étape M2 — Data Security (`scripts/mlsecops/data-security/`)
- CI de dataset : détection **PII**, **secrets/tokens**, scan fichiers, **dédup**, **anomalies**, checks **data poisoning**.
- Versioning dataset : `dataset_id`, `version`, `hash`, `source`.
- **Sortie** : rapport par dataset ; blocage si dataset non identifié en prod.

### Étape M3 — Pipeline ML dédiée (Jenkinsfile.ml)
```
Dataset ingestion → validation → PII → secrets → malware scan → data quality →
poisoning checks → training/fine-tuning → model evaluation → model security scan →
provenance → signature → registry → deployment approval
```

### Étape M4 — Model Security
- Scan de dépendances Python (PyTorch, Transformers, …) via Trivy/Grype/pip-audit.
- Scan de désérialisation **réel** : ModelScan/PickleScan **sans fallback simulé**.
- Emploi de **safetensors** quand possible.
- Fiche modèle : `model_id, version, hash, source, dataset_version, training_commit, dependencies, evaluation_results, security_results, signature, provenance`.

### Étape M5 — Model Evaluation Gate (seuils versionnés dans git)
```yaml
# configs/ml-security-gate.yaml (à créer et justifier)
security_gate:
  max_critical_vulnerabilities: 0
  max_high_vulnerabilities: 0
  max_prompt_injection_rate: <à définir et justifier>
  max_data_leakage_rate: 0
  min_f1: <défini par le projet>
```
- Bloquer la promotion si seuil dépassé (pas de transformation d'erreur en warning).

### Étape M6 — LLM / RAG Security (réel, pas simulé)
- **Garak réel** ou tests maison versionnés : prompt-injection, indirect injection, jailbreak, PII leakage, hallucination.
- Pipeline : `USER INPUT → input security → retrieval → document validation → context security → LLM → output security → response`.
- RAG data : documents **authentifiés, autorisés, scannés, classifiés, versionnés** ; document révoqué → non récupérable.
- **Remplacer le fallback garak simulé** de `scripts/ci/run-mlsecops-scans.sh` par un vrai scan ou un statut `NON VALIDÉ` explicite.

### Étape M7 — Supply chain modèle
- SBOM **modèle** ( CycloneDX/ML-BOM ) signé Cosign, publié avec `image digest + model hash + provenance`.
- Provenance répond : qui / quand / code / dataset / dépendances / config / hash.

**Sortie MLSecOps :** pipeline M1→M7 verte sur 1 modèle pilote, avec `security-evidence/` rempli (éval, garak, datasets, signatures).

---

## 3. Consolidation DevSecOps restante (parallèle, 1-2 semaines)

| # | Sujet | Action | État visé |
|---|---|---|---|
| C1 | **Cosign keyless (OIDC)** | migrer de la clé fichier vers keyless ; ne jamais logger la clé | signature keyless vérifiée |
| C2 | **Ratify** | déployer `scripts/ratify/deploy-ratify.sh` : vérifier signature + SBOM + provenance avant admission | admission ALLOW/DENY prouvée |
| C3 | **Tetragon** | déployer `infra/k8s/tetragon/`, politiques réseau/process, tests (shell, escalade, connexion) | événements→preuve dans evidence/ |
| C4 | **Kyverno CEL** (phase 14) | upgrade Kyverno ≥ 2.0 en env de test, migrer les 8 policies, puis supprimer v1 | 0 ClusterPolicy v1, VAP Ready |
| C5 | **SPIRE — généralisation** | enroll des autres services (1→N), mesurer latence/rotation/échec | N services avec SVID |
| C6 | **Cilium/Hubble (phase 7)** | nouveau cluster de test, plan de rollback, policies L7 | CNI Cilium + Hubble validés (hors cluster critique) |
| C7 | **Vault avancé** | KMS auto-unseal + audit logs + **dynamic DB credentials** (TTL) | app → creds temporaires → DB |
| C8 | **Chaos (env test)** | exécuter pod-kill/latence/partition ; mesurer dispo/latence/recover | rapport chaos + métriques |
| C9 | **Dashboards manquants** | DevSecOps, MLSecOps, RAG Security, Runtime, Supply Chain, DR, FinOps | dashboards dans Grafana |
| C10 | **security_pipeline_duration_seconds** | métrique durée de chaque stage Jenkins + cache deps + parallélisation | métrique exportée Prometheus |

---

## 4. Gates de sécurité continus (comportement cible)

`BLOCK` si : vuln CRITICAL, HIGH non acceptée, signature invalide, SBOM manquant,
provenance invalide, test sécu KO, éval modèle KO, prompt-injection, data leakage,
accès RAG non autorisé, violation policy, test de déploiement KO.
`WARN` / `ACCEPT` uniquement via policy documentée (jamais pour masquer un échec).

---

## 5. Definition of Done (par phase)

1. Code/manifests commités (atomiques, pas de `git add .`).
2. Overlay concerné build (`kubectl kustomize`).
3. Aucun env ne passe en `Degraded/OutOfSync/CrashLoopBackOff` sans justification.
4. Preuve dans `evidence/` (timestamp, commit, env, outil+version, résultat, sévérité).
5. Doc mise à jour (architecture/devsecops/**mlsecops**/security/…).
6. Rollback documenté.

---

## 6. Ordre d'exécution proposé

```
Semaine 1 : P0.1 → P0.5 (remédiations) + M1 (runtime RAG)
Semaine 2 : M2 → M4 (data security, pipeline ML, model security) + C3 (Tetragon)
Semaine 3 : M5 → M7 (gates, RAG security, supply chain modèle) + C1, C2 (keyless, Ratify)
Semaine 4 : C5, C6 (SPIRE général, Cilium test) + C8, C9, C10 + rapport final honnête
```

> Dates indicatives. Chaque phase livrée avec son bloc : `PHASE / STATUS / FILES MODIFIED /
> SECURITY IMPACT / FUNCTIONAL IMPACT / TESTS / RESULTS / EVIDENCE / RISKS / ROLLBACK / NEXT`.
