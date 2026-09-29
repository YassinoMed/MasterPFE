# ROADMAP CLOUD ENTERPRISE v2 — De 98.5/100 au niveau Production Grade

> **Évolution depuis la v1** : Phase 10 résolue (BSL Available, backup
> Completed), drift sémantique transformer (Sentence-Transformers),
> Ratify Running, pipeline Jenkins 6/6 SUCCESS, 117 tests, 20/20 final.
> La plateforme est à **98.5/100** — les 2 derniers points sont
> purement infrastructurels (cloud managé requis).
>
> Ce document est la **section Perspectives** de votre soutenance :
> chaque item cite l'acquis PFE qu'il généralise vers son équivalent
> managé sur AWS/GCP/Azure.

---

## 0. Les 2 derniers points — résolus par design cloud

| Point perdu | Pourquoi c'est bloqué sur kind | Résolution cloud | Effort |
|---|---|---|---|
| **-1 mTLS universel** | SPIRE tourne (3 pods) mais l'imposition mTLS nécessite un proxy sidecar par pod — trop de ressources pour kind | **Istio** ou **App Mesh** injecte le sidecar automatiquement, SPIRE fournit les identités | 1 semaine |
| **-1 Runner CI dédié** | Le build kaniko torch a crashé l'apiserver (IR-501 documenté) — impossible d'isoler sur un nœud partagé | **Karpenter** provisionne un nodepool CI tainté Spot, scale-to-zero après build | 1 semaine |

**Trajectoire : 98.5 → 100/100 en 2 semaines sur EKS/GKE/AKS.**

---

## 1. VAGUE 1 — AWS (migration naturelle : vous êtes déjà sur EC2)

### 1.1 Mapping complet : votre preuve → service AWS managé

| Votre preuve PFE (vérifiée live) | Service AWS | Ce qui change |
|---|---|---|
| Harbor 7 pods + Trivy scanning intégré | **ECR** (TLS, scan natif, tags immutables) | Dérogation `internal-cleartext-scope` supprimée — HTTPS natif partout |
| Kyverno 8 policies Enforce + Cosign v3 | **Kyverno 2.x** (compatible HTTPS) + **Signer** | Votre ImageValidatingPolicy CEL (Phase 14 revertée sur HTTP) se redéploie avec HTTPS |
| Vault Raft + unseal manuel avec 3 clés Shamir | **Vault Enterprise** + **KMS auto-unseal** | Plus jamais de `vault operator unseal` manuel (votre IR-501) |
| BSL Available + backup Completed + restore exécuté | **S3 natif** + Velero plugin AWS + cross-region | Votre `velero-restore-test.sh` devient un test restore RÉEL cross-region |
| Falco 2/2 + Tetragon 2 agents eBPF | **GuardDuty** + **Security Hub** + Tetragon conservé | Détection managée + vos policies L7 restent actives |
| Trivy Operator 411 ConfigAudits | **Inspector** (agentless, continu) | Scan sans DaemonSet, patching via Systems Manager |
| SPIRE 3 pods + CRD ClusterSPIFFEID | **SPIRE conservé** + **IAM Roles Anywhere** | Pod → IAM Role temporaire SANS secrets statiques |
| LiteLLM Gateway (auth 401, "Bonjour!") | **API Gateway** + **Bedrock** | Rate limiting global, WAF, quotas par key |
| Qdrant + RAG + poisoning check + baseline hash | **OpenSearch** ou **Aurora pgvector** | VPC-isolé, backup automatique, réplication multi-AZ |
| CronJobs poisoning/drift/registry (3 jobs) | **EventBridge Scheduler** + **Step Functions** | Serverless, retry, DLQ, alerting SNS natif |
| IR playbooks ×6 + IR-501 (cas réel) | **SSM Automation** + **PagerDuty** | Détection → isolation → notification en <5 min automatique |
| Transparency Log (11 tests, chaînage SHA-256) | **Rekor managé** (sigstore public) | PKI publique, witness signing, vérifiabilité internet |
| Presidio PII NER (10 tests) | **Comprehend** PII + votre Presidio conservé | 30+ langues, entités médicales, financières |
| Factuality TF-IDF + claims (19 tests) | **Titan Embeddings** + **LLM-as-judge** nightly | Similarité sémantique transformer en production |
| Drift transformer all-MiniLM-L6-v2 (8 tests) | **Bedrock** + évaluation continue | Score de qualité + similarité en continu |
| Pipeline Jenkins 6/6 SUCCESS (30 builds) | **CodeBuild** ou GitHub Actions + Karpenter | Runners éphémères Spot dédiés, pas de nœud partagé |

### 1.2 MLSecOps GPU — la montée en gamme du stack IA

| Actuel PFE (prouvé) | Cible AWS | Bénéfice |
|---|---|---|
| Ollama 0.5B CPU (18s/probe) | **vLLM** sur `g5.xlarge` (A10G) | Continuous batching, PagedAttention, 10-50× débit |
| Model Registry manuel (sha256 commité) | **SageMaker Model Registry** | Lignage datasets→versions, approbations, auto-deploy EventBridge→ArgoCD |
| Garak interrompu (2075 requêtes, 56/256) | **CronJob GPU nightly** : garak + PyRIT + PromptFoo | Red-team continu, corpus grandissant, gate de promotion |
| Poisoning check ponctuel (CronJob 15min) | **Qdrant/OpenSearch webhooks → Lambda quarantaine** | Détection <1s en continu (plus de batch) |
| Presidio NER (10 tests, en_core_web_lg) | **Comprehend** PII multi-langues | FR + EN + DE + ES + 30 autres, entités médicales |
| Factuality TF-IDF + claims (19 tests) | **Titan Embeddings + Claude LLM-judge** | Grounding transformer, calibration, citations vérifiées |
| Llama Guard absent | **Llama Guard 3** sur Bedrock | Classification violence/self-harm/code malveillant/mineur |
| Agent-vs-Agent absent | **Bedrock Agent** attaquant vs **Bedrock Agent** défenseur | Red-team ML automatisé, sans intervention humaine |

### 1.3 Supply Chain niveau SLSA L3 authentique

Vous avez prouvé : SBOM → Cosign v3 → Trivy → Pipeline SUCCESS → Supply Chain Validation 4/4.

| Composant SLSA L3 | Manquant | Service AWS |
|---|---|---|
| **Rekor** (transparency log public) | Votre Python log est privé (cluster-only) | **Sigstore Rekor managé** — PKI publique, witness |
| **In-toto attestations** multi-étapes | Build→scan→sign→deploy non encore attestés séparément | **CodeBuild** génère des attestations par étape |
| **VEX (OpenVEX)** | 302 keywords detect-secrets sans exploitabilité tracée | VEX statements : "vulnérable mais non exploitable dans mon contexte" signé |
| **AWS Signer** | — | Signature des artefacts non-conteneur (binaires, JAR) |
| **SLSA provenance** | SLSA provenance basique | **CodeBuild SLSA L3** avec builder isolé non falsifiable |

---

## 2. VAGUE 2 — GCP (différenciation forte pour un jury)

| Domaine | Votre preuve PFE | Service GCP | Ce que GCP apporte UNIQUEMENT |
|---|---|---|---|
| Admission control | Kyverno 8 policies Enforce, unsigned→BLOCKED | **Binary Authorization** | Attestation **OBLIGATOIRE** à l'admission — version managée et inflexible de votre verify-cosign |
| Identité workload | Vault + ESO (kubernetes-auth) | **Workload Identity Federation** | Pods → credentials cloud temporaires SANS aucun secret (généralise votre pattern Vault+ESO au niveau IAM cloud) |
| Registry | Harbor 7 pods + Trivy | **Artifact Registry** + analyse à l'upload | Votre Trivy-as-a-service → managé, sans DaemonSet |
| ML Platform | Ollama + Qdrant + LiteLLM | **Vertex AI** : Model Registry + Endpoints + evaluations | GPU auto-scale, A/B testing, drift detection intégré |
| PII | Presidio NER (10 tests) | **Sensitive Data Protection (DLP)** | 100+ types, 50 langues, détection dans BigQuery/Storage |
| Security | CIS 93% script manuel | **Security Command Center** (CSPM) | Score continu + remédiations suggérées + compliance |
| DR | ArgoCD multi-cluster prouvé | **GKE multi-région + Cloud DNS** | Fleet management actif/passif, game days trimestriels |
| Audit | 849K lignes audit-log | **Cloud Audit Logs + BigQuery** | Investigation SQL < 1s sur des Téraoctets |
| AI Guardrails | GI/GO modules (deterministes) | **Vertex AI safety filters** | Classification ML intégrée au runtime (en plus de vos guardrails) |

### Ce que GCP apporte que AWS n'a PAS :
- **Confidential Computing** : VMs avec mémoire chiffrée (N2D instances)
- **Assured Workloads** : conformité FedRAMP/ITAR/sovereignty par namespace K8s
- **Vertex AI Prompt Safety** : filtres safety natifs dans l'API (pas besoin de sidecar)

---

## 3. VAGUE 3 — Azure (si exigé)

| Domaine | Service Azure | Particularité |
|---|---|---|
| Registry | **ACR Quarantine Mode** | Les images CI sont **EN QUARANTAINE** jusqu'à validation — votre flux Trivy-blocking devient **natif au registre** |
| Secrets | **Key Vault + Vault seal HSM** | Votre Vault Raft → unseal par **HSM managé** (multi-région auto-scellé) |
| Security | **Defender for Cloud** + **Sentinel** | CSPM + **SIEM** natif (vos Falco/Tetragon → SOC intégré avec ML) |
| ML | **Azure ML** + **Prompt Flow** | Orchestration LLM avec évaluation intégrée + responsible AI dashboard |
| Policy | **Azure Policy** pour AKS | Équivalent Kyverno mais **natif cloud** (pas de CRD à gérer) |
| Backup | **Azure Backup** + Velero Blob | Équivalent S3/GCS avec immutability policy |

---

## 4. Conformité & Gouvernance IA (transverse aux 3 clouds)

### 4.1 Framework mapping — votre preuve = socle de certification

| Framework | Couvert par vos preuves | Manquant pour certification | Effort |
|---|---|---|---|
| **NIST AI RMF** | **80%** — vos contrôles OWASP LLM = evidence directe pour Govern/Map/Measure/Manage | Mapping formel + risk register documenté + processus d'amélioration continue | 2 semaines (documentation) |
| **EU AI Act** | Logging ✓ (audit-log 849K), oversight ✓ (`requires_human_review` factuality), traçabilité ✓ (Model Registry sha256) | Annex IV (documentation technique) + conformity assessment + registration | 3 semaines |
| **ISO 42001** (SMSI IA) | Documentation par preuves = socle idéal pour un système de management | Audit externe + gestion formelle des risques IA + processus PDCA | 4-6 semaines |
| **SOC 2 Type II** | Encryption ✓, access control ✓, monitoring ✓, incident response ✓ (IR playbooks) | Période d'observation 6 mois + audit externe | 6 mois d'observation |
| **ISO 27001** | CIS 93% + hardening + policies = 70% des contrôles | Gestion formelle des risques + audit externe | 8-12 semaines |
| **PCI-DSS** | Vault + encryption + access control + network segmentation | Scope definition + QSA audit | Variable |

### 4.2 AI Safety niveau recherche (au-delà d'OWASP)

| Contrôle | Votre implémentation | Niveau entreprise | Service |
|---|---|---|---|
| Red-teaming continu | garak 2075 req + 16/16 CI payloads | **Agent vs Agent** : un LLM attaquant vs un LLM défenseur, évaluation automatisée nightly | Bedrock Agents / Vertex |
| Hallucination | Factuality claims + TF-IDF + transformer (27 tests) | **Llama Guard 3** + **ShieldGemma** : classification ML multi-risque (violence, self-harm, hate) | Bedrock / Vertex |
| Prompt extraction | Règle GI-02 (reveal → BLOCK) | **Canary tokens** dans les system prompts : détection par corrélation automatique | Custom |
| Model theft | — (pas d'exposition publique) | **Watermarking** (SynthID de Google) : signature invisible dans chaque output | Vertex AI |
| Data poisoning | Baseline hash + check + attaque détectée live | **Provenance complète** : chaque point tracé à sa source via lineage (SageMaker/Vertex) | Cloud ML |
| Adversarial inputs | Guardrails GI/GO (deterministes) | **Adversarial robustness testing** : PGD, FGSM, C&W sur le modèle | SageMaker Clarify |

---

## 5. FinOps cloud-native

| Actuel (script $267/mois) | Cible | Impact |
|---|---|---|
| `kubectl top` → script manuel | **Kubecost/OpenCost** + AWS CUR | Allocation par namespace→équipe, showback mensuel automatisé |
| CI sur nœud partagé (IR-501) | Runners **Spot** (Karpenter, scale-to-zero) | **-70%** coût build CI |
| GPU 0 (CPU only) | `g5.xlarge` scale-to-zero + 1 instance réservée prod | Pay-per-use, pas de capacity planning |
| Tagging absent | **Kyverno policy** `cost-center` obligatoire | Vos 8 policies Enforce s'appliquent au tagging |
| Aucun budget alerting | **AWS Budgets** + **Cost Anomaly Detection** | Alerte Slack automatique si dépassement |

---

## 6. Multi-région & DR avancé

Votre preuve : ArgoCD enjambe 2 clusters (primary + DR), BSL Available, backup Completed.

| Étape | Description | Effort |
|---|---|---|
| **1. Pilot-light DR** | Région 2 : secrets répliqués (Vault), registre répliqué (ECR cross-region), DB standby (RDS cross-region read replica), ArgoCD pointe vers les deux | 2 semaines |
| **2. Warm standby** | Région 2 : services tourne en mode réduit (1 réplique par service), bascule en <15 min | 2 semaines |
| **3. Active-active** | Route53/Cloud DNS répartit le trafic, les deux régions servent en parallèle | 4 semaines |
| **4. Game days trimestriels** | Votre script `velero-restore-test.sh` devient un CronJob mensuel cross-region avec rapport RTO/RPO automatique | 1 semaine |

---

## 7. Plan d'action priorisé (P0 → P3)

| Priorité | Chantier | Effort | Gain | Prérequis |
|---|---|---|---|---|
| **P0** | **EKS + mTLS** (Istio/App Mesh + SPIRE→IAM) | 1 sem | **+1 → 99.5** | Compte AWS |
| **P0** | **Karpenter runners CI** (nodepool Spot tainté) | 1 sem | **+1 → 100** | EKS |
| **P1** | **ECR** + Kyverno 2.x (retry Phase 14 CEL) | 1 sem | Conformité registre | EKS |
| **P1** | **S3 Velero** + restore-test automatisé cross-region | 1 sem | RTO/RPO mesurés | EKS |
| **P1** | **vLLM GPU** + SageMaker/Bedrock | 2-3 sem | Capacité ×50 | Nodegroup GPU |
| **P1** | **Titan Embeddings + LLM-judge** (drift + factuality) | 1 sem | MLSecOps profondeur | Bedrock |
| **P2** | **Rekor + in-toto + VEX** (SLSA L3) | 2 sem | Supply chain enterprise | PKI |
| **P2** | **Event-driven poisoning** + IR automatisé EventBridge | 2 sem | MLSecOps continuité | EventBridge |
| **P2** | **Multi-région pilot-light** + game days | 3-4 sem | RTO/RPO prouvés | 2 régions |
| **P2** | **NIST AI RMF + EU AI Act** mapping formel | 3 sem | Certifiabilité | Documentation |
| **P3** | **GKE Binary Authorization** + Workload Identity | 2 sem | Multi-cloud | Projet GCP |
| **P3** | **Kubecost + CSPM + SOC2 readiness** | 4 sem | Gouvernance | 6 mois données |
| **P3** | **Llama Guard + Agent-vs-Agent** red-team ML | 3 sem | AI Safety recherche | Bedrock/Vertex |

---

## 8. Ce qui change pour le jury

```
PFE 2026 (prouvé, 98.5/100)     →    Entreprise cloud-native (100+)
───────────────────────────────────────────────────────────────────────
kind 2 nœuds EC2                     EKS/GKE/AKS multi-AZ multi-région
Ollama CPU 0.5B (18s)               vLLM GPU / Bedrock / SageMaker
Harbor local HTTP + exception       ECR TLS + Binary Authorization
BSL moto S3 (backup Completed)      S3 natif + restore cross-region
Runner CI partagé (IR-501 crash)    Karpenter Spot éphémère dédié
PII Presidio NER (10 tests)         + Comprehend/DLP (30+ langues)
Factuality TF-IDF + transformer     + Titan Embeddings + LLM-judge
Red-team garak 2075 req + CI 16/16  PyRIT + garak + PromptFoo nightly GPU
Poisoning CronJob 15min             EventBridge quarantaine <1s continue
$kubectl-top script FinOps          Kubecost + CUR + showback continu
CIS 93% audit manuel script          Security Hub / SCC / Defender continu
IR playbooks + 1 cas réel (IR-501)   SSM Automation + PagerDuty <5min
Transparency Log Python (11 tests)   Rekor managé (PKI publique)
OWASP LLM 10/10 preuves              + NIST AI RMF + EU AI Act + ISO 42001
```

**L'argument central pour la soutenance** :

> « Mes 140+ commits prouvent que chaque compétence existe déjà :
> je peux signer des images, détecter du poisoning, mesurer du drift,
> orchestrer une réponse à incident, écrire des policies d'admission,
> faire du red-teaming LLM, et valider une chaîne d'approvisionnement.
> Le cloud managé ne fait que retirer les contraintes qui m'ont forcé
> à documenter des limites. C'est un socle à faire fructifier,
> pas un écart à combler. »

---

*Document de perspectives soutenance — généré le 2026-09-29, basé
sur l'état 98.5/100, 117 tests, 20/20 PASS, Pipeline BUILD #30 SUCCESS,
BSL Available, Ratify Running, Tetragon 2 agents, Harbor 7 pods.*
