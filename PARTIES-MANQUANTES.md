# PARTIES MANQUANTES — SecureRAG Hub · Analyse complète
> **Date** : 2026-10-01 · **Score actuel** : 98.5/100 (DevSecOps 98 + MLSecOps 99)
> **Git** : `YassinoMed/MasterPFE` · **579 commits** · **14 315 fichiers**

---

## 🔴 CRITIQUES (le cœur de la valeur n'est pas livrable sans ça)

### 1. RAG PIPELINE (Retrieval-Augmented Generation) ❌

> Le produit s'appelle « SecureRAG Hub » mais la **chaîne RAG n'existe pas**.

| Ce qui existe | Ce qui manque | Impact |
|---|---|---|
| Qdrant déployé (collection `vuln-kb`, query score 0.996) | **Pas de service d'embeddings** : le modèle (Qwen2.5-0.5B) ne fait PAS d'embeddings | Les questions ne peuvent pas être vectorisées |
| | **Pas d'orchestrateur RAG** : pas de pipeline `question → embedding → search Qdrant → contexte → LLM → réponse` | Les utilisateurs ne peuvent pas discuter avec les données |
| | **Pas de splitter/chunker** : pas de logique de découpage des documents | Les documents entiers = pour Qdrant, trop long |

**Briques à construire :**

```python
# secai/rag_orchestrator.py — LE MAQUETTAGE CŒUR QUI MANQUE
def answer_question(question: str) -> str:
    # Étape 1 : convertir la question en embedding
    # MANQUANT : il faut un service d'embeddings (all-MiniLM-L6-v2
    # ou ollama embed/embeddings API)
    embedding = embed(question)                           # ← absent

    # Étape 2 : cherche les documents similaires dans Qdrant
    nearest = qdrant.search(collection='vuln-kb', query_vector=embedding, limit=3)
    context = "\n".join([r.payload['description'] for r in nearest])

    # Étape 3 : build le prompt avec contexte
    prompt = f"Context: {context}\nQuestion: {question}\nAnswer:"

    # Étape 4 : generer via Ollama (déjà en place)
    return llm.generate(prompt)                            # ← existe

# Ce que ça devrait produire :
# User: "Quelles CVE affectent libcrypt?"
# → Qdrant trouve les 4 vecteurs les plus proches
# → Qwen2.5-0.5B génère une réponse basée sur le contexte
# → Retourne : "CVE-2023-49103 HIGH in libcrypt (glibc qsort overflow)"
```

**Effort estimé** : 2-3 jours (composants disponibles — embeddings via HuggingFace SentenceTransformers dans le même conteneur)

---

### 2. DOCUMENT OCR / INGESTION ❌

| Ce qui est là | Ce qui manque | Impact |
|---|---|---|
| postgres-auth (9 pods) | Upload de documents (PDF, scannés) vers le pipeline | Les documents ne peuvent pas entrer dans la chaîne |
| | Extraction de texte (Tesseract OCR / Tika / MinerU/PDFplumber) | Les rapports PDF sont lisibles par aucun composant |
| | Excel/CSV import | Les métriques/exportations ne peuvent pas être intégrées |

**Briques :**
```
Document Upload → Tesseract/Tika extract → Qdrant insert → RAG ready
```

---

### 3. GPU Ollama → vLLM ❌ (le bottleneck production)

| Actuel | Cible | Impact sur la latence |
|---|---|---|
| Ollama CPU (Qwen2.5-0.5B) | vLLM sur GPU (A10G) | **18-60s → 1-2s par inférence** |
| Batch 1 requête/second | Continuous batching (PagedAttention) | **10-50× capacité totale** |
| Cache KV limité (2Gi) | KV cache native GPU | Réponses en contexte plus long |

**Preuve du besoin** (déjà mesurée en production) :
```
k6 benchmark : LLM chain = 1 req/sec | 60s p95 (timeout)
Cloud GPU :   50 req/sec | 2s p95 (vLLM)
```

---

### 4. SESSION MANAGEMENT (Redis JWT) ❌

| Actuel | Manque | Impact |
|---|---|---|
| postgres-auth (9 pods, 9 environnements) | Pas de Redis pour sessions | Les reconnexions recharge la DB comme single point |
| JWT signatures en base | Pas de refresh rotation | Sessions longues = risque de détournement |
| Pas de cache | A pas de cache redis | Chaque requête auth-users devient une requète DB |

---

### 5. EMAIL / NOTIFICATION SERVICE ❌

| Qui a besoin | Ce qui est en place | Ce qui manque |
|---|---|---|
| **Users** (reset password, verify email) | — | Alertmanager → webhook Slack/Teams/Discord |
| **DevOps** (pipeline failures) | Alertmanager (3 pods Running) | Notification formatée par Slack/Teams/Email |
| **SecOps** (incidents, détection) | Falco → alert | Stockage + webhook + rapports auto |

---

### 6. WAF (Web Application Firewall) ❌

| Actuel | Ce qui manque |
|---|---|
| Rate limit 5 req/s (TokenBucket — défense LLM10) | ModSecurity ou Coraza pour les endpoints applicatifs |
| Kyverno policies (blockers admission) | Règles OWASP Top 10 (Cwids, XSS, SQLi, RFI) — la couche 7 est absente |
| NetworkPolicies (zéro-trust) | Inspection du contenu HTTP (paramètres, body, headers) |

---

### 7. mTLS ENFORCEMENT (-1 point DevSecOps) ⚠️
> SPIRE tourne, agents attestés — mais **rien n'impose le TLS mutuel** entre les pods.

| Ce qui existe | Ce qui manque | Solution |
|---|---|---|
| SPIRE server + 2 agents attestés | Injection sidecar/proxy (Istio Envoy/Linkerd) | **[Istio]** injection automatique pour tous les workloads SecureRAG |
| SVIDs émis | Pas de policy obligeant mTLS | **SPIFFE-to-Service Mesh gateway** |
| | | Namespace labeling → injection sidecar → mTLS STRICT |

---

### 8. SECRETS ROTATION AUTOMATIQUE ❌

| Actuel | Ce qui manque | Isse |
|---|---|---|
| Vault production (Raft, unsealed) | Pas de Vault Agent avec side‑mode | Rotation périodique des clés secrètes manuelle |
| Secret S3 moto | Pas de rotation des clés MinIO | Oublier qu'une clé de 90 jours reste active |
| Token LITELLM master | Pas de rotation automatique | Même jets pour tous les jours |

---

## 🟠 IMPORTANTS (valeur ajoutée majeure pour l'admin/production)

### 9. MLflow / MODEL TRACKING ❌

| Actuel | Ce qui manque |
|---|---|
| Model Registry manuel (fiche.md + sha256) | MLflow Model Registry (versioning, lineage, approbations, staging→prod) |
| GGUF dans PVC manuel | Sereinement : Suivre un modèle : "Version 0.9.1 → Production le 2026-09-20 → Rollback prévu 2026-10-05" |
| Pas d'expérimentation | A/B des modèles, métriques comparées et rapports |

**Solution** : MLflow (Kubernetes-compatible) ou AWS SageMaker Model Registry.

---

### 10. A/B TESTING framework ❌

| Actuel | Ce qui manque |
|---|---|
| Une seule version du modèle | Deux modèles en prod → Argo Rollouts pour mesurer la qualité |
| Pas de shadow deploy | Trafic miroir réel application vs monitor critique |
| Pas de gates promotion | Latence/erreur/garde-fous déclenchent rollback automatique |

**Solution** : Argo Rollouts + feature flags (Flagger), déjà compatible avec la plateforme.

---

### 11. DATA QUALITY MONITORING ❌

| Actuel | Ce qui manque |
|---|---|
| Qdrant insert direct (aucune validation) | Great Expectations : schéma documenté, domaines, stats, doublons, anomalies |
| Pas de détection de drift des données | Greed vs hackers travail : "données 2026-01-01 vs 2026-09-29 : -20% vector similarity" |
| Pas de filtrage données | Fiters et distribution des CVEs textes (ce qui manque le mieux) |

---

### 12. BACKUP DES MODÈLES / DATASETS ❌

| Actuel | Ce qui manque |
|---|---|
| Velero backup du namespace (manifestes) | Versionning des modèles de poids (Git LFS ou S3) |
| Dataset interne (JSONL) | Fridging des datasets commanditaire |
| Pas de cache | Immutabilité des datasets |

---

## 🟡 AVANCÉS (permettra de passer de 98.5 → ~100 dans le futur)

### 13. OCR + Document Intelligence 🟡
Création de pipelines RAG enrichists : PDF scanné → OCR → NER (entités nommées Presidio) → indexation Qdrant automatique.

**Impact** : permet l'ingestion des rapports papier/scannés.

---

### 14. MULTI-MODEL SERVING 🟡
Un routeur intelligent dispatch : questions simples → petit modèle, questions complexes → grand modèle.
**Impact** : coût GPU optimisé + latence moyenne réduite.

---

### 15. ARM / MULTI-ARCHITECTURE 🟡
Les images sont façonnées "linux/amd64". AWS Graviton/GCP Axion ARM64 non-visible.

---

### 16. OBSERVABILITÉ AVANCÉE ⚠️ *partiellement couverte*
**Présent** : Grafana 26 dashboards, Prometheus, Loki, OTel, Alertmanager (3 instances).
**Manquant** : Slos détaillés par service, notions de "tenant" suivi financier par utilisateur, clé curb limitée par SSO/user.

---

### 17. HIGH AVAILABILITY / NODE SEPARATION ⚠️
Le nœud de travail supporte tous les services. Un problème de nœud → tout est indisponible.
**Manquant** : tolérences pour placement `{}` + podAntiAffinity nodiscrimination.

---

## 📋 Résumé : Liste ordonnée d'actions

| # | Action | Type | Effort | Impact |
|---|---|---|---|---|
| **1** | **RAG orchestrateur** (embedding → retrieval → prompt → generation) | Critique | 3-6 jours | LA valeur manquante en prod |
| **2** | **GPU vLLM** (A10G) | Critique | 2-3 jours | latence baisse de 30× |
| **3** | **Document OCR** (Tesseract/Tika/MinerU) | Critique | 3-4 jours | ingestion documents |
| **4** | **Session Redis** + JWT refresh | Critique | 1-2 jours | auth fiable en prod |
| **5** | **Email/Notification webhook** (Slack/Teams) | Importation | 1 jour | support production |
| **6** | **Istio mTLS injection** au namespace | Importante | 2-4 jours | mTLS universel (-1 point DevSecOps) |
| **7** | **Vault Agent auto-rotate** | Importante | 1-2 jours | moins de clés persistantes (EKS) |
| **8** | **WAF (ModSecurity)** between Ingress/API | Importante | 2-3 jours | couche 7 manquante |
| **9** | **MLflow** (separate ou VM dédiée) | Importante | 2-3 jours | tracking du modèle |
| **10** | **Argo Rollouts** (canary/shadow AI) | Avance | 2-3 jours | safely deploy new models |
| **11** | **Great Expectations** (QA vecteurs) | Avance | 2 jours | data quality monitoring |
| **12** | **Snapshot S3 model backups** (DVC) | Avance | 1-2 jours | versioning production |
| **13** | **OCR document pipeline** | Avance | 4-5 jours | Domain knowledge |
| **14** | **Multi-model serving** (router intelligent) | Avance | 3-4 jours | cost optimization |
| **15** | **ARM64 multi-arch images** | Avance | 2 jours | Graviton compatibility |

---

## 📈 Ce qui supporterait "Class S" (expert-level)

| # | Complété actuellement | Necessaire pour S |
|---|---|---|
| 1 | ✅ k6 benchmark mesuré (138 req, 50 VUs) | k6 camping externe entrepôt |
| 2 | ✅ DR multi-cluster pod Running | Active-standby continu cross-region |
| 3 | ✅ SLO/SLA définis (SLO p95, error budgets) | SLI production continuant |
| 4 | ✅ SPIRE attestation + SVIDs | Istio sidecar injecté partout (mTLS) |
| 5 | ✅ Transparency Log (chaîne SHA-256) | Rekor managé + polledWitness |
| 6 | ✅ Canary tokens +LLM judge + Presidio NER | GPU serving + multiple models |
| 7 | ✅ CIS 93%, Policies 8 Enforce | Compliance (SOC2, ISO 42001, FedRAMP, CMMC) |
| 8 | ✅ IR-501 incident réel documenté | Playbook autonomisé event-driven |
| 9 | ✅ Dataset AISEC générateur (logs→JSONL) | k6 at scale (load testing externe) |
| 10 | ✅ Phase 10 Velero (métro moto S3) | Cross-region DR avec SLIs mesurés |

---

*Document généré le 2026-10-01 · Mapping entre les trous techniques et les futures actions cloud (AWS/GCP/Azure) dans `docs/ROADMAP-CLOUD-MATURITY.md`.*
