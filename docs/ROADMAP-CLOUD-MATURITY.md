# ROADMAP CLOUD MATURITY — Du PFE (kind/EC2) au niveau Entreprise (AWS/GCP/Azure)

> **Point de départ honnête** : la plateforme actuelle (95/100 DevSecOps,
> 92/100 MLSecOps) a prouvé TOUTE la chaîne sécuritaire sur un contexte
> restreint. Ce document mappe chaque acquis vers son équivalent
> production cloud, résout les 5 chantiers documentés (`SCORE-FINAL.md`)
> et propose 3 vagues d'adoption chiffrées.
>
> **Principe directeur** : ce qui a été prouvé sur kind se transpose ;
> ce qui était bloqué par l'environnement (S3, GPU, runner dédié) devient
> natif sur cloud managé.

---

## 0. Grille de maturité — actuel vs cible entreprise

| Dimension | PFE (actuel) | Cible entreprise | Écart principal |
|---|---|---|---|
| Control plane | kind (apiserver crash documenté) | Managé multi-AZ | Résilience |
| Runtime LLM | Ollama CPU 0.5B | vLLM GPU + autoscale | Capacité |
| Registry | Local HTTP (exception Kyverno) | ECR/AR/ACR (TLS+scan intégré) | Conformité |
| Backup | **Bloqué Phase 10** | S3/GCS/Blob natif | **Résolu par design** |
| CI runners | Pod sur nœud partagé (incident) | Runners éphémères dédiés | **Résolu** |
| PII | Regex (documenté) | Presidio NER multi-langues | Qualité |
| Factuality | Claim-based (documenté) | Embeddings + LLM-judge | Profondeur |
| Monitoring | kubectl top → script | OpenCost/Kubecost + FinOps continu | Automatisation |
| IR | Playbooks manuels | Runbooks automatisés (EventBridge/PubSub) | Temps de réponse |
| Conformité | CIS 93% script manuel | CSPM continu + audit natif | Continuité |

---

## 1. VAGUE 1 — AWS (migration naturelle : vous êtes déjà sur EC2)

### 1.1 Socle (résout 3 chantiers documentés)

| Chantier | Solution AWS | Ce qui change concrètement |
|---|---|---|
| **Phase 10 Velero (−2 pts)** | **S3 natif** + Velero plugin AWS + Kopia pour volumes | Votre `velero-restore-test.sh` s'exécute tel quel : `kubectl apply -f bsl-s3.yaml`. + Option : AWS Backup cross-region pour le pilot-light DR |
| **Runner CI dédié (−1 DevSecOps, −3 MLSecOps)** | **Karpenter** : nodepool `ci-builders` tainté (spot), scale-to-zero | Jenkins k8s plugin (déjà prouvé) provisionne des pods sur nœuds dédiés éphémères — le build torch ne touche plus le control plane (leçon IR-501 appliquée) |
| **Cilium primaire (−1)** | Migration planifiée sur **EKS managé** (l'apiserver n'est plus le vôtre à crasher) | Fenêtre de maintenance : VPC CNI → Cilium, Hubble UI, policies L7 mappées depuis vos NetPols |
| **Registry HTTP local** | **ECR** : TLS natif, scan de vulnérabilités intégré, tags immutables | La dérogation `internal-cleartext-scope` de SECAI disparaît ; les ImageValidatingPolicy CEL de Kyverno 2.x deviennent compatibles (HTTPS) — la Phase 14 que vous aviez revertée se redéploie |
| **etcd encryption manuelle** | **KMS** (encryption at rest native) + kms-provider | `aes-cbc` maison → clés gérées, rotation automatique, audit CloudTrail |

### 1.2 Supply chain — vers SLSA L3 authentique

Vous avez : SBOM → Cosign → SLSA provenance basique. Manquant pour L3 :
- **Rekor** (transparency log) : chaque signature cosign entre dans un log
  public vérifiable — `cosign attest --bundle`
- **In-toto attestations** multi-étapes : build → scan → sign → deploy,
  chaque étape attestée par un builder isolé
- **Kyverno `verifyImages`** avec attestations (remplace votre
  verify-cosign v1 : la vérification devient in-line à l'admission,
  policies par-attestation)
- **VEX** (OpenVEX) : vos 411 ConfigAuditReports Trivy deviennent
  exploitabilité-pilotées — "vulnérable mais non exploitable dans mon
  contexte" tracé et signé (ferme la boucle CVE → décision)

### 1.3 MLSecOps GPU — la montée en gamme du stack IA

| Actuel | Cible | Bénéfice |
|---|---|---|
| Ollama 0.5B CPU (18s/probe) | **vLLM** sur nodegroup `g5.xlarge` (A10G) | Continuous batching, PagedAttention, 10-50× débit ; quantization AWQ |
| Model Registry manuel (sha256 commité) | **SageMaker Model Registry** ou MLflow | Lignage datasets→entraînement→versions, approbations, auto-deploy des versions approuvées via EventBridge→ArgoCD |
| Drift hash/latence | + **évaluation continue LLM-as-judge** (Bedrock/Claude) sur set de test versionné : score de qualité + similarité sémantique (embeddings Titan) | Drift sémantique réel, pas seulement substitution |
| Poisoning check ponctuel | **Event-driven** : Qdrant webhooks → EventBridge → Lambda de quarantaine + notification Slack | Détection < 1s en continu (votre −1 actuel) |
| Garak interrompu (56/256) | **CronJob nightly** sur runner GPU : garak complet + PyRIT (Microsoft) + PromptFoo, rapport MLflow, gate de promotion automatique | Red-team continu, corpus grandissant |

### 1.4 Guardrails niveau entreprise (vos −1 nommés)

- **PII (−1)** : **Presidio** (NER multi-langues, 50+ entités) en sidecar
  du Gateway LiteLLM — remplace le regex GO-05 ; détection d'emails,
  IBAN, SSN, noms propres, avec score de confiance
- **Factuality sémantique (−1)** : embeddings (Titan/Bedrock) :
  similarité réponse↔contexte + votre claim-check conservé comme
  première barrière + citations vérifiées générées
- **Llama Guard 3** en classification input/output (violence, self-harm,
  code malveillant) derrière vos guardrails GI/GO — la couche
  classification ML complète la couche déterministe

---

## 2. VAGUE 2 — Multi-cloud & GCP (différenciation)

### 2.1 GKE : le plus proche de vos acquis
- **Workload Identity Federation** : vos pods SECAI reçoivent des
  credentials cloud temporaires SANS secrets statiques — ça généralise
  votre pattern Vault+ESO au niveau de l'IAM cloud
- **Binary Authorization** : l'équivalent cloud de votre Kyverno
  verify-cosign, mais avec **attestation obligatoire à l'admission du
  déploiement** (images non attestées = jamais schedulées) — la version
  "entreprise managée" de ce que vous avez prouvé
- **Artifact Registry** + analyse de vulnérabilités automatique à
  l'upload (équivalent Trivy-as-a-service)
- **Vertex AI Model Registry** : versioning + evaluation endpoints

### 2.2 DR multi-région actif (votre preuve multi-cluster devient un plan)
Vous avez prouvé : ArgoCD enjambe 2 clusters (primary + DR). Cible :
- **ArgoCD ApplicationSet avec cluster-generator** sur N clusters
  multi-région (us-east-1 + eu-west-1 par exemple)
- **Velero cross-region** : backups S3 répliqués + restore-test en
  **CronJob mensuel automatisé** (votre script devient un Job K8s avec
  rapport DORA-DR : RTO/RPO mesurés et publiés)
- **Pilot-light DR** : la région 2 tourne minimal (secrets répliqués,
  registre répliqué, DB standby) — bascule testée trimestriellement
  (game day, votre expérience Chaos Mesh devient un plan structuré)

### 2.3 Azure (si exigé) : les ajouts distinctifs
- **ACR Quarantine mode** : les images pull-ées par CI sont EN QUARANTAINE
  jusqu'à validation — votre flux Trivy-blocking devient natif au registre
- **Azure Key Vault + Vault seal** : Vault unseal par HSM managé
  (Key Vault) — votre Raft actuel devient multi-région auto-scellé
- **Defender for Cloud** : CSPM continu (votre CIS 93% manuel devient
  un score continu avec remédiations suggérées)

---

## 3. VAGUE 3 — Observabilité, FinOps & gouvernance continues

### 3.1 FinOps (votre script $267/mois → discipline continue)
- **OpenCost/Kubecost** sur les 3 clouds : allocation par namespace→équipe
  (vos namespaces déjà propres), showback mensuel automatisé
- CI runners = **Spot instances** (Karpenter) −70% coût build
- GPU nodegroup = scale-to-zero + 1 instance réservée pour la prod
- **Tagging policy** Kyverno : `cost-center` obligatoire sur tout déploiement
  (votre pattern "8 policies Enforce" s'applique au tagging)

### 3.2 Audit & SIEM (vos 849K lignes deviennent investigables)
- Centralisation : CloudTrail + audit-log K8s + Falco → **Security Hub**
  (AWS) / **Security Command Center** (GCP) / **Sentinel** (Azure)
- Rétention immuable : S3 Object Lock (WORM) pour les audit-logs
- Votre drill de détection Falco (/etc/shadow) devient un **test continu**
  de la chaîne : EventBridge détection → Lambda → ticket + Slack (détails
  d'implémentation dans vos IR-401..501 — le runbook s'automatise)

### 3.3 Conformité IA (au-delà d'OWASP)
- **NIST AI RMF** : mapper vos contrôles OWASP LLM Top 10 sur le cadre
  (Govern/Map/Measure/Manage) — 80% déjà couvert par vos preuves
- **EU AI Act** readiness : logging des décisions (fait), oversight humain
  (votre `requires_human_review` factuality), traçabilité modèles (Registry)
  — vous êtes structurellement bien placés
- **ISO 42001** (SMSI IA) : votre documentation par preuves est le
  socle idéal pour une certification future

---

## 4. Résumé — ce qui change pour le jury

```
PFE (prouvé, restreint)          →    Entreprise (cible)
──────────────────────────────────────────────────────────
kind 2 nœuds EC2                 →    EKS/GKE/AKS multi-AZ multi-région
Ollama CPU, model 0.5B           →    vLLM GPU, registry MLflow/SageMaker
Registry HTTP + exception        →    ECR TLS + Binary Authorization
Velero BLOQUÉ (Phase 10)         →    S3 natif + restore-test automatisé
Runner CI partagé (incident)     →    Karpenter spot éphémère dédié
PII regex                        →    Presidio NER + Llama Guard
Factuality claim-based           →    Embeddings + LLM-judge continu
Red-team ponctuel (garak 56/256) →    PyRIT+garak+PromptFoo nightly GPU
Poisoning check manuel           →    Event-driven quarantaine <1s
$kubectl-top script FinOps       →    Kubecost + showback continu
CIS 93% audit manuel             →    CSPM continu + conformité IA
```

## 5. Effort & priorisation (honnête)

| Priorité | Chantier | Effort | Gain |
|---|---|---|---|
| P0 | EKS + S3 Velero (Phase 10 débloquée) | 1-2 semaines | Restore prouvé, DR réel |
| P0 | Karpenter runners CI dédiés | 1 semaine | Incident IR-501 impossible |
| P1 | ECR + Kyverno 2.x CEL (retry Phase 14) | 1 semaine | Conformité registre |
| P1 | vLLM GPU + MLflow Registry | 2-3 semaines | Capacité + lignage |
| P1 | Presidio + Llama Guard | 1 semaine | PII/factuality niveau ML |
| P2 | Red-team nightly + drift sémantique | 2 semaines | Continuité MLSecOps |
| P2 | Multi-région pilot-light + game days | 3-4 semaines | RTO/RPO mesurés |
| P2 | Kubecost + CSPM + NIST AI RMF mapping | 2 semaines | Gouvernance continue |

**Trajectoire de score projetée** : 93.5 actuel → **~98** après vague 1
(les −5 et −4 documentés se résorbent car les causes étaient
environnementales) ; les derniers points exigent la multi-région et
la conformité certifiante (hors périmètre PFE, bon scope pro).

---

*Document de perspectives soutenance — chaque item cite l'acquis PFE
qu'il généralise. Généré le 2026-09-28.*
