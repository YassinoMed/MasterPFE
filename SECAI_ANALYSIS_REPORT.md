# SECAI — Rapport d'analyse initiale

**Date** : 23/09/2026
**Statut** : Analyse uniquement — aucune modification

## 1. Architecture actuelle

```
MasterPFE/
├── ai-security-service/        ← couche IA existante (FastAPI, 4 couches)
│   ├── api/main.py             (PromptInjection, Jailbreak, Router, CyberAgent, DevOpsAgent)
│   ├── models/                 (cybersecurity_agent.py, prompt_injection.py, jailbreak_detector.py)
│   ├── security/guardrails.py
│   ├── routing/semantic_router.py
│   ├── k8s/                    (Deployment, Service, PVC, HPA, PDB, NetworkPolicy, ConfigMap)
│   ├── tests/                  (10 fichiers de tests pytest)
│   └── Dockerfile
├── ai-security/                (outils IA: xai_explainer, r_workload_calculator, qdrant_rbac_filter)
├── scripts/ai-agents/          (ai_testing, build_intelligence, deployment_intelligence, secure_coding, ai_operations)
├── Jenkinsfile                 (10 stages dont un stage 'AI Security Governance')
├── Makefile                    (160+ targets)
└── services-laravel/           (5 services métier — pas d'IA)
```

## 2. Stack technique actuelle

| Composant | Version | État |
|---|---|---|
| Python | 3.13.5 | ✅ |
| PyTorch | ❌ absent du venv host | à installer |
| Transformers | ❌ absent du venv host | à installer |
| FastAPI | ❌ absent du venv host | venv nécessaire |
| GPU | Non présent (nvidia-smi missing) | CPU only |
| Modèle SecureBERT2.0-base | À attacher | cisco-ai/SecureBERT2.0-base |

## 3. Points d'intégration existants (à conserver, pas remplacer)

1. **CI ：** `Jenkinsfile` stage `AI Security Governance` (lines ~285-343) — relie 4 agents (Planning, Code Review, Manifest Audit, MLSecOps Fuzzing)
2. **Runtime：** `ai-security-service/` — service K8s déployé sur namespace `securerag-hub`
3. **Outils IA：** `ai-security/` contient déjà xai_explainer.py et r_workload_calculator.py
4. **Security layer：** `security/guardrails.py` de ai-security-service/ fait déjà du détecteur d'injection et jailbreak

## 4. Proposition d'architecture SECAI (différentielle vs existant)

**Règle : lever la couche existante, pas la remplacer.**

```
SECAI ne doit PAS créer un quatrième service IA.
SECAI = une couche d'analyse **offline/batch** qui consomme les rapports
déjà produits par les scanners et produit des verdicts consolidés.
+----------------+     +-------------------------+     +-------------------+
|  ai-security-  |-----|       SECAI (ce projet) |----|                      |
|  service       |     |  - Analyse Semgrep      |----|   secai-report.json |
|  (Layer 4 exé) |     |  - Analyse Trivy        |----|   secai-report.md   |
|                |     |  - Analyse Falco        |     |                     |
|  ai-security/  |     |  - Analysis Kyverno     |     |   artifacts/release/|
|  (tools)       |     |  - Corrélation          |     |                     |
+----------------+     |  - Scoring consolidé    |     +-------------------+
                       |  - XAI explications     |
                       +-------------------------+
                                    │
                                    ▼
                          Jenkins stage
                          "SECAI Security Analysis"
                          (après tous les autres stages,
                           scan existing artifacts only)
```

## 5. Fichiers à CRÉER (pas de modification)

| Fichier | Contenu |
|---|---|
| `secai/` | Package Python racine |
| `secai/api/main.py` | FastAPI app (health, ready, analyze, correlate, explain) |
| `secai/api/schemas.py` | Pydantic models (Finding, SecAIReport) |
| `secai/api/routes.py` | Endpoints |
| `secai/models/securebert_loader.py` | Loader avec fallback if model indisponible |
| `secai/models/embedding_service.py` | Pooling embeddings via SecureBERT 2.0-base (via mean pooling — modèle base, pas fine-tuné) |
| `secai/models/classifier.py` | Classifier rule-based + embedding similarity (pas de classification supervisée brute) |
| `secai/pipelines/security_analysis.py` | Pipeline principal (stable) |
| `secai/pipelines/alert_correlation.py` | Grouper par label/pod/image/rule |
| `secai/pipelines/risk_scoring.py` | Consolidation deterministic + AI |
| `secai/pipelines/explanation.py` | XAI human-readable |
| `secai/integrations/semgrep.py` | Parser rapport Semgrep |
| `secai/integrations/trivy.py` | Parser rapport Trivy |
| `secai/integrations/falco.py` | Parser alertes Falco (logs K8s) |
| `secai/integrations/kyverno.py` | Parser policy reports |
| `secai/integrations/sonarqube.py` | Parser Sonar issues |
| `secai/policies/thresholds.yaml` | Seuils configurables par catégorie |
| `secai/policies/decision_policy.py` | PASS/REVIEW/BLOCK/INCONCLUSIVE |
| `secai/tests/` | Tests unitaires + fixtures |
| `infra/k8s/base/secai/` | Deployment, Service, NetworkPolicy, RBAC |
| `infra/k8s/overlays/demo/kustomization.yaml` | Ajout du service + HPA |
| `Jenkinsfile` | Stage SECAI (modification mineure) |

## 6. Fichiers à MODIFIER uniquement

| Fichier | Changement | Pourquoi minimal |
|---|---|---|
| `Jenkinsfile` | Ajouter stage `SECAI Security Analysis` (en parallèle, après autres stages, avant déploiement) | L'intégration se contente de lire les artifacts |
| `Makefile` (optionnel) | Target `make secai-report` pour régénérer rapport hors CI | Convenance |
| ` security/reports/` les fichiers sont lus ARGUMENTO | pas de modif |

## 7. Risques de compatibilité

| Risque | Niveau | Mitigation |
|---|---|---|
| SecureBERT2.0-base est un encodeur BERT (pas fine-tuné) | Moyen | Ne pas prétendre classifier avec le modèle brut : utiliser comme générateur embeddings + règles déterministes |
| Hardware en CI (pas GPU) | Faible | Fallback CPU auto, cache des modèles |
| Taille inputs (logs Falco)) | Faible | SECAI_MAX_LENGTH=1024, truncate log |
| Secrets sensibles dans les rapports d'analyse | Moyen | Redaction PII Mitre + jamais écrire de secrets dans la sortie |
| Déjà ai-security-service avec un modèle GGUF (Seneca) | Moyen | SECAI = offline analysis only, pas de prédéployment runtime |
| Dockerfiles utilisant Python 3.11 | Faible | SECAI utilise python3.11-slim (compatibles) |

## 8. Décisions principales (proposal)

1. **SECAI s'intègre dans Jenkins à travers un stage OFFLINIS batch** — cela ne touche pas les stages existants
2. **Détection = regles déterministes (JSON sémantique) + embeddings** — on n'affirme jamais que le modèle fait de la vraie classification supervisée
3. **Mode ADvisory par défaut**, strict optionnel
4. **Déploiement K8s** comme un service indépendant, `resources.limits.cpu=500m, memory=1Gi`, pas de root
5. **Jamais de retry sur Hollow verts qui restent Gated par Trivy**

## 9. Plan d'implémentation par phases

### Phase A — Fondation (création package + tests unitaires)
- Créer `secai/` scaffold complet
- requirements.txt avec versions fixes
- Tests pytest (chargement du modèle, entrées invalides, valeurs inconnues)
- Healthcheck + readiness

### Phase B — Intégrations (parsers)
- semgrep.py, trivy.py, falco.py, kyverno.py, sonarqube.py
- Lecture des artifacts JSON existants (pas d'exécution)
- Fixtures de test avec exemples de rapports

### Phase C — Pipelines (analyse + correlation + scoring)
- security_analysis.py (ingest + normalize)
- alert_correlation.py (grouper par label/pod/image/rule)
- risk_scoring.py (score consolidé avec règles heuristiques)
- explanation.py (placeholder texte + headline + recommandation)

### Phase D — API + policy
- FastAPI endpoints (analyze, correlate, explain)
- decision_policy.py avec `SECAI_MODE=advisory`
- seatails openapi.json

### Phase E — Jenkins + K8s
- Stage `SECAI Security Analysis` (consomme artifacts existants)
- Deploiement K8s : Deployment, Service, ServiceAccount dédié, NetworkPolicy, probes, resource limits
- HPA existant reste limité sur le service SECAI

### Phase F — Validation complète
- Tests unitaires + APIs + sécurité
- Intégration Jenkins → rapport SECAI
- Benchmarks perf (latence, RAM)
- Dossier final `artifacts/final/secai-validation-report.json` + `reports/secai/`

---

**Statut** : préparation à l'implémentation.. ↓
Attente de confirmation pour lancer Phase A.