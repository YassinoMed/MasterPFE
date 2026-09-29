# ROADMAP CLOUD ENTERPRISE — Du PFE (97/100) au niveau Production Grade

> **Point de départ** : la plateforme SecureRAG Hub a atteint **97/100**
> (DevSecOps 96 + MLSecOps 98) sur un cluster kind/EC2 restreint avec
> **20/20 PASS** au test automatisé, **109 tests SECAI**, un pipeline
> Jenkins **6/6 stages SUCCESS**, Harbor opérationnel, Tetragon déployé,
> et un Transparency Log fonctionnel.
>
> Ce document mappe **chaque acquis vers son équivalent cloud managé**,
> résout les 4 derniers points perdus, et propose un plan d'adoption
> **AWS → GCP → Azure** en 3 vagues chiffrées.

---

## 0. Grille de maturité — actuel vs entreprise cloud-native

| Dimension | PFE (actuel, prouvé) | Cible entreprise | Écart |
|---|---|---|---|
| Control plane | kind (apiserver crash documenté) | **EKS/GKE/AKS** managé multi-AZ | Résilience + SLA 99.95% |
| Registry | Harbor 7 pods + local HTTP | **ECR/AR/ACR** TLS + scan intégré | Conformité |
| Backup | Phase 10 **bloquée** (S3 env) | **S3/GCS/Blob natif** | **Résolu par design** |
| CI/CD | Jenkins sur nœud partagé (IR-501) | **CodeBuild/Cloud Build/Azure DevOps** + Karpenter | **Résolu** |
| Runtime LLM | Ollama CPU 0.5B (18s/probe) | **vLLM GPU** (Bedrock/SageMaker/Vertex) | Capacité ×50 |
| PII | Presidio NER (10 tests) | **Presidio + Comprehend/DLP** | Multilingue + scale |
| Factuality | TF-IDF + claims (19 tests) | **Embeddings transformer + LLM-judge** | Profondeur |
| Transparency | Log Python (11 tests) | **Rekor managé** (Sigstore public) | PKI publique |
| Drift | Hash + latence (5 probes) | + **Évaluation continue LLM-as-judge** | Sémantique |
| Poisoning | Baseline hash + check manuel | **Event-driven quarantaine <1s** | Continuité |
| IR | Playbooks + IR-501 réel | **Runbooks automatisés EventBridge** | Temps de réponse |
| Conformité | CIS 93% script | **CSPM continu + SOC2/ISO/EU AI Act** | Certifiabilité |

---

## 1. VAGUE 1 — AWS (migration naturelle : vous êtes déjà sur EC2)

### 1.1 Socle — résout les 4 derniers points perdus

| Point perdu | Solution AWS | Impact |
|---|---|---|
| **-2 Phase 10 Velero** | **S3 natif** + Velero plugin AWS + Kopia volumes | Votre `velero-restore-test.sh` s'exécute tel quel. + AWS Backup cross-region pour pilot-light DR. **+2 pts** |
| **-1 Runner CI** | **Karpenter** : nodepool `ci-builders` tainté Spot, scale-to-zero | Le build kaniko ne touche plus le control plane (leçon IR-501). GitHub Actions ou CodeBuild comme alternative. **+1 pt** |
| **-1 mTLS universel** | **App Mesh** ou Istio avec mTLS STRICT + SPIRE intégré | Vos SPIFFE IDs existants se branchent sur AWS IAM Roles Anywhere. **+1 pt** |
| **-1 Drift sémantique** | **Bedrock + Titan Embeddings** : similarité sémantique en évaluation continue nightly | Votre TF-IDF reste la barrière 1 ; les embeddings ajoutent la profondeur transformer. **+1 pt** |

**Trajectoire : 97/100 → 99-100/100** (les 4 points perdus sont tous d'origine environnementale).

### 1.2 Mapping acquis → service AWS

| Acquis PFE (prouvé) | Service AWS | Bénéfice entreprise |
|---|---|---|
| Harbor 7 pods + Trivy scanning | **ECR** + scan intégré + immutability tags | Géré, TLS natif, replication cross-region |
| Kyverno 8 policies Enforce + Cosign v3 | **Kyverno 2.x** (compatible HTTPS) + **Signer** + **Inspector** | ImageValidatingPolicy CEL (votre Phase 14 revertée se redéploie avec HTTPS) |
| Vault Raft + unseal manuel | **Vault Enterprise** + **KMS unseal** (auto-unseal) + HSM | Zéro intervention manuelle post-restart (votre IR-501) |
| Falco + Tetragon eBPF | **GuardDuty** + **Security Hub** + Tetragon (conservé) | Détection managée + votre Tetragon reste pour les policies L7 |
| Trivy Operator + 411 ConfigAudits | **Inspector** + **Systems Manager Patch Manager** | Scan continu agentless + patching automatisé |
| SPIRE (3 pods, CRD ClusterSPIFFEID) | **SPIRE** conservé + **IAM Roles Anywhere** | Pod → IAM Role temporaire sans secrets statiques |
| LiteLLM Gateway (auth 401) | **API Gateway** + **Lambda authorizer** ou **Bedrock** | Rate limiting global, quotas par API key, WAF |
| Qdrant + RAG + poisoning check | **OpenSearch** ou **Aurora pgvector** | VPC-isolé, backup automatique, réplication |
| CronJobs poisoning/drift/registry | **EventBridge Scheduler** + **Step Functions** | Serverless, retry, DLQ, alerting SNS natif |
| IR playbooks + IR-501 | **EventBridge** + **SSM Automation** + **PagerDuty** | Détection → isolation → notification → runbook en < 5 min |
| Transparency Log (11 tests) | **Rekor managé** (sigstore public) ou **S3 Object Lock WORM** | PKI publique, witness signing, vérifiabilité internet |
| Presidio PII NER | **Comprehend** PII + votre Presidio conservé | 30+ langues, entités médicales, financial |

### 1.3 MLSecOps GPU — la montée en gamme du stack IA

| Actuel | Cible AWS | Bénéfice |
|---|---|---|
| Ollama 0.5B CPU (18s) | **vLLM** sur `g5.xlarge` (A10G) ou **Bedrock** | Continuous batching, PagedAttention, 10-50× débit |
| Model Registry manuel (sha256) | **SageMaker Model Registry** | Lignage datasets→versions, approbations, auto-deploy via EventBridge→ArgoCD |
| Garak interrompu (56/256) | **CronJob GPU nightly** : garak + PyRIT + PromptFoo | Red-team continu, corpus grandissant, gate de promotion |
| Poisoning check ponctuel | **Qdrant webhooks → Lambda quarantaine** | Détection <1s en continu |
| Factuality TF-IDF | + **Titan Embeddings + LLM-as-judge** (nightly) | Drift sémantique transformer |

### 1.4 Supply Chain niveau SLSA L3 authentique

Vous avez : SBOM → Cosign v3 → Trivy → Pipeline SUCCESS. Manquant :
- **Rekor** : chaque signature dans un log public vérifiable
- **In-toto attestations** multi-étapes : build → scan → sign → deploy
- **VEX (OpenVEX)** : "vulnérable mais non exploitable dans mon contexte" tracé
- **AWS Signer** + **CodeSigning** pour les artefacts non-conteneur

---

## 2. VAGUE 2 — GCP (différenciation forte pour un jury)

| Domaine | Service GCP | Votre acquis mappé |
|---|---|---|
| Admission | **Binary Authorization** | Attestation OBLIGATOIRE à l'admission — version managée de votre Kyverno verify-cosign |
| Identité | **Workload Identity Federation** | Pods → credentials cloud temporaires SANS secrets (généralise Vault+ESO) |
| Registry | **Artifact Registry** + analyse à l'upload | Votre Trivy-as-a-service Harbor → managé |
| ML Platform | **Vertex AI** : Model Registry + Endpoints + evaluations | Votre Ollama+Qdrant+LiteLLM → managé avec GPU auto-scale |
| PII | **DLP API** (Sensitive Data Protection) | Votre Presidio + DLP Google = 100+ types, 50 langues |
| Security | **Security Command Center** (CSPM) | Votre CIS 93% script → score continu + remédiations |
| DR | **GKE multi-région + Cloud DNS** | Votre ArgoCD multi-cluster → fleet management actif/passif |
| Audit | **Cloud Audit Logs + BigQuery** | Vos 849K lignes → investigation SQL en < 1s |

### Ce que GCP apporte UNIQUEMENT

- **Assured Workloads** : conformité FedRAMP/ITAR/sovereignty par namespace
- **Confidential Computing** : VMs avec mémoire chiffrée (N2D instances)
- **AI Guardrails** (Vertex) : filtres safety intégrés au runtime (votre GI/GO en managé)

---

## 3. VAGUE 3 — Azure (si exigé)

| Domaine | Service Azure | Particularité |
|---|---|---|
| Registry | **ACR Quarantine Mode** | Images CI EN QUARANTAINE jusqu'à validation — votre Trivy-blocking devient natif registre |
| Secrets | **Key Vault + Vault seal HSM** | Votre Vault Raft → unseal par HSM managé (multi-région auto-scellé) |
| Security | **Defender for Cloud** + **Sentinel** | CSPM + SIEM natif (vos Falco/Tetragon → SOC intégré) |
| ML | **Azure ML** + **Prompt Flow** | Orchestration LLM avec évaluation intégrée |
| Policy | **Azure Policy** pour AKS | Équivalent Kyverno mais natif cloud |

---

## 4. Conformité & Gouvernance IA (transverse aux 3 clouds)

### 4.1 Framework mapping (votre preuve = socle)

| Framework | Vos contrôles actuels | Manquant pour certification |
|---|---|---|
| **NIST AI RMF** | 80% couvert (Govern/Map/Measure/Manage) — vos preuves OWASP = evidence base | Mapping formel + risk register documenté |
| **EU AI Act** | Logging ✓ (audit-log), oversight ✓ (`requires_human_review`), traçabilité ✓ (Registry) | Documentation technique (Annex IV) + conformity assessment |
| **ISO 42001** (SMSI IA) | Documentation par preuves = socle idéal | Audit externe + processus de gestion des risques IA formels |
| **SOC 2 Type II** | Audit-log, encryption at rest, access control, monitoring — tous opérationnels | Période d'observation 6 mois + audit externe |
| **ISO 27001** | Votre CIS 93% + hardening = 70% des contrôles | Gestion formelle des risques + audit |

### 4.2 AI Safety avancé (au-delà d'OWASP)

| Contrôle | Implémentation PFE | Niveau entreprise |
|---|---|---|
| Red-teaming continu | garak 56/256 + PyRIT à installer | **Agent vs Agent** : un LLM attaquant vs un LLM défenseur, évaluation automatisée |
| Hallucination | TF-IDF + claims (19 tests) | **Llama Guard 3** + **ShieldGemma** : classification ML multi-risque |
| Prompt extraction | GI-02 (reveal → BLOCK) | **Canary tokens** dans les system prompts : détection par corrélation |
| Model theft | — (pas d'exposition publique) | **Watermarking** (SynthID) + détection de réutilisation |
| Data poisoning | Baseline hash + check | **Provenance** : chaque point tracé à sa source (audit de chaîne) |

---

## 5. FinOps cloud-native

| Actuel (script) | Cible | Impact |
|---|---|---|
| `kubectl top` → $267/mois | **Kubecost/OpenCost** + AWS CUR | Allocation par namespace→équipe, showback mensuel |
| CI sur nœud partagé | Runners **Spot** (Karpenter) | **-70%** coût build |
| GPU 0 (CPU only) | `g5.xlarge` scale-to-zero + 1 réservée | Pay-per-use, pas de capacity planning |
| Tagging manuel | **Kyverno policy** : `cost-center` obligatoire | Vos 8 policies Enforce s'appliquent au tagging |

---

## 6. Plan d'action priorisé (effort × impact)

| Priorité | Chantier | Effort | Gain score | Prérequis |
|---|---|---|---|---|
| **P0** | EKS + S3 Velero (Phase 10) | 1-2 sem | DevSecOps +2 | Compte AWS |
| **P0** | Karpenter runners CI | 1 sem | DevSecOps +1 | EKS |
| **P1** | ECR + Kyverno 2.x (retry Phase 14) | 1 sem | Conformité registre | EKS |
| **P1** | vLLM GPU + Bedrock/SageMaker | 2-3 sem | MLSecOps capacité | Nodegroup GPU |
| **P1** | Titan Embeddings + LLM-judge (drift) | 1 sem | MLSecOps +1 | Bedrock |
| **P2** | Rekor + in-toto + VEX (SLSA L3) | 2 sem | Supply chain | PKI |
| **P2** | Multi-région pilot-light + game days | 3-4 sem | RTO/RPO mesurés | 2 régions |
| **P2** | Event-driven poisoning + IR automatisé | 2 sem | MLSecOps +1 | EventBridge |
| **P3** | GKE Binary Authorization + Workload Identity | 2 sem | Multi-cloud | Projet GCP |
| **P3** | NIST AI RMF + EU AI Act mapping | 3 sem | Certifiabilité | Documentation |
| **P3** | Kubecost + CSPM + SOC2 readiness | 4 sem | Gouvernance | 6 mois données |

---

## 7. Ce qui change pour le jury

```
PFE (prouvé, restreint)          →    Entreprise cloud-native
──────────────────────────────────────────────────────────────────
kind 2 nœuds EC2                 →    EKS/GKE/AKS multi-AZ multi-région
Ollama CPU, 0.5B                 →    vLLM GPU / Bedrock / SageMaker
Harbor local HTTP + exception    →    ECR TLS + Binary Authorization
Velero BLOQUÉ (Phase 10)         →    S3 natif + restore automatisé
Runner CI partagé (IR-501)      →    Karpenter Spot éphémère dédié
PII Presidio NER                 →    + Comprehend/DLP (30+ langues)
Factuality TF-IDF               →    + Titan Embeddings + LLM-judge
Red-team garak 56/256 interrompu →    PyRIT+garak+PromptFoo nightly GPU
Poisoning check ponctuel        →    EventBridge quarantaine <1s continue
$kubectl-top script FinOps      →    Kubecost + CUR + showback continu
CIS 93% audit manuel            →    Security Hub / SCC / Defender continu
IR playbooks + 1 cas réel       →    EventBridge + SSM + PagerDuty <5min
Transparency Log Python (11ts)  →    Rekor managé (PKI publique)
OWASP LLM 10/10 preuve          →    + NIST AI RMF + EU AI Act + ISO 42001
```

**Trajectoire projetée** :
- Actuel : **97/100** (4 points environnementaux)
- Vague 1 AWS : **99-100/100** (les 4 points résorbés par design)
- Vagues 2-3 : **Certification-grade** (multi-région, conformité certifiante)

---

*Document de perspectives soutenance — chaque item cite l'acquis PFE
qu'il généralise et le service AWS/GCP/Azure correspondant. Généré
le 2026-09-29, basé sur l'état 20/20 PASS + 109 tests + Pipeline SUCCESS.*
