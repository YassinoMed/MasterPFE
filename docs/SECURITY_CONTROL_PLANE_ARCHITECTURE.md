# 🛡️ SecureRAG Hub: Security Control Plane Architecture
**Status:** Architecture Design
**Target Compliance:** SOC2 Type II, SLSA L3/L4, BeyondCorp Enterprise

## 1. 🧠 Security Control Plane (Architecture Globale)

Le **Security Control Plane (SCP)** agit comme le système nerveux central du cluster. Il agrège les signaux de toutes les couches de l'infrastructure (CI, CD, Runtime, Logs) via un bus d'événements asynchrone (NATS JetStream) pour évaluer le risque en temps réel et ordonner des actions de remédiation.

### Architecture (Mermaid)

```mermaid
flowchart TD
    %% Sources d'événements
    subgraph Sources ["Event Sources (Telemetry)"]
        Falco["Falco (Runtime)"]
        Jenkins["Jenkins (CI/Sec Scans)"]
        Argo["ArgoCD (GitOps State)"]
        K8s["K8s Audit API"]
        Loki["Loki / Prom (Logs/Metrics)"]
    end

    %% Bus Asynchrone
    NATS[("NATS JetStream (Event Bus)")]

    %% Cerveau
    subgraph ControlPlane ["Security Control Plane"]
        RiskEngine["Global Risk Engine"]
        PolicyEngine["Unified Policy Engine (OPA++)"]
        AIGovernor["AI Security Governor"]
        EvidenceGraph["Immutable Evidence Graph"]
    end

    %% Sinks / Actions
    subgraph Sinks ["Action & Storage"]
        S3[("S3 Object Lock (WORM)")]
        Kyverno["Kyverno (Admission)"]
        Cilium["Cilium (Network Block)"]
        Grafana["Grafana Heatmap"]
    end

    Sources -->|Publish| NATS
    NATS -->|Subscribe| RiskEngine
    NATS -->|Subscribe| PolicyEngine
    NATS -->|Subscribe| AIGovernor
    NATS -->|Subscribe| EvidenceGraph

    RiskEngine -->|Updates Risk Score| NATS
    PolicyEngine -->|Decision (ALLOW/DENY)| Kyverno
    PolicyEngine -->|Quarantine| Cilium
    AIGovernor -->|Recommendations| NATS
    EvidenceGraph -->|Sign & Archive| S3
    RiskEngine -->|Metrics| Grafana
```

### Data Flow (Step-by-Step)
1. **Ingestion:** Falco détecte un shell dans un conteneur. Il publie un `SecurityEvent` sur NATS (`events.security.runtime`).
2. **Contextualisation:** Le `Risk Engine` consomme l'événement, interroge le `Graph Model` pour déterminer le *Blast Radius* (ex: "ce pod a accès à la BDD via network policy").
3. **Scoring:** Le `Risk Score` passe de 20 à 95. Un `RiskEvent` est publié.
4. **AI Analysis:** L'`AI Governor` lit le `RiskEvent` (en Read-Only), analyse les logs récents depuis Loki (via une API interne) et propose une recommandation de remédiation.
5. **Decision:** Le `Policy Engine` évalue la règle OPA : `Si Risk > 90 -> QUARANTINE`. Il déclenche une NetworkPolicy Cilium restrictive.
6. **Immutability:** L'`Evidence Graph` récupère toute la chaîne d'événements, génère un arbre de Merkle, signe le lot avec Cosign, et l'envoie sur le stockage WORM S3.

### Data Schema (JSON/Protobuf)
```json
{
  "eventId": "uuid-v4",
  "timestamp": "2026-06-25T15:00:00Z",
  "source": "falco.runtime",
  "type": "SecurityEvent",
  "severity": "CRITICAL",
  "payload": {
    "pod": "audit-security-service-xyz",
    "rule": "Terminal shell in container"
  },
  "cryptographicProof": {
    "previousHash": "sha256-...",
    "signature": "sigstore-bundle"
  }
}
```

---

## 2. 📊 Global Risk Engine + Blast Radius Model

Ce composant convertit des événements disparates en un **Risk Score global (0-100)** et calcule le rayon d'impact potentiel (Blast Radius).

### Blast Radius Graph Model
Le graphe est construit en mémoire (ou via Neo4j/RedisGraph) et mis à jour via les événements K8s API :
- **Noeuds:** Pods, Services, Secrets, Ingress, IAM Roles.
- **Arêtes:** NetworkPolicies (Cilium), RBAC (ClusterRoleBindings), Data Flows.
- **Algorithme:** Si le nœud A est compromis, on calcule la fermeture transitive des nœuds accessibles (ex: Pod A -> Service B -> DB C). 

### Algorithme de Scoring
`RiskScore = (BaseSeverity * ContextWeight) + (BlastRadiusScore * Exploitability)`
- *BaseSeverity*: CVSS ou priorité Falco.
- *ContextWeight*: Un pod en `production` vaut 2x plus qu'en `dev`.
- *BlastRadiusScore*: Nombre de ressources critiques accessibles (ex: +20 pts si le pod a un token ServiceAccount root).

### Outputs
- **Grafana Heatmap:** Métriques Prometheus `securerag_risk_score{namespace="x", pod="y"}`.
- **Alerting:** Trigger automatique si `Global_Score > 85`.

---

## 3. 🧾 Immutable Evidence Graph (SOC2 Type II Core)

Pour garantir une preuve d'audit opposable (non-répudiation) exigée par SOC2 et SLSA L4.

### Composants
- **Event Hasher:** Calcule le SHA-256 de chaque `SecurityEvent`.
- **Blockchain Chainer:** Injecte le hash de l'événement précédent dans l'événement actuel (`previousHash`).
- **Signer (Cosign/Sigstore):** Périodiquement (ex: chaque minute), le lot (batch) d'événements est signé via une clé gérée par HashiCorp Vault.
- **WORM Storage:** Les bundles signés sont poussés sur un bucket S3 configuré avec **Object Lock (Mode Compliance)** (les fichiers ne peuvent être ni modifiés ni supprimés avant X années).

### Replay System (SOC2 Audit)
Une API `GET /api/v1/audit/replay?start=X&end=Y` permet aux auditeurs de reconstruire l'état exact du cluster en rejouant la chaîne de hachage. Si un seul événement a été altéré, la vérification de la signature globale échoue.

---

## 4. 🔐 Unified Policy Decision Engine (OPA++)

Fini la logique de sécurité éparpillée. Ce moteur centralise l'arbitrage.

### Pipeline d'évaluation
1. **Input:** Jenkins demande de déployer l'image `securerag-hub-backend:v2`.
2. **Enrichissement:** Le moteur récupère le score SLSA, le résultat Trivy, et le Risk Score actuel du cluster.
3. **OPA Evaluation:** Un ensemble de polices Rego évalue le tout.
4. **Decision Flow:**
   - `ALLOW`: Déploiement autorisé.
   - `DENY`: Bloqué (ex: CVE critique détectée).
   - `QUARANTINE`: Le pod démarre mais avec une NetworkPolicy `Deny-All` (Cilium) en attendant une revue humaine.
   - `REVIEW`: Alerte envoyée sur Slack/Teams pour "Human in the Loop".

### Fallback Mechanism (Fail-Safe)
Si le Policy Engine crash, l'admission K8s passe en mode `Fail-Open` (pour la CI non-critique) ou `Fail-Closed` (pour la production), selon la configuration `FailurePolicy` du ValidatingWebhookConfiguration.

---

## 3. Components Breakdown (Microservices List)

Le Control Plane est implémenté via une architecture microservices (Kubernetes-native) :

1. **`risk-engine-service` (Go/FastAPI)** : Calcule le *Blast Radius* et met à jour le *Global Risk Score*. Lit NATS, expose des métriques Prometheus.
2. **`evidence-graph-service` (Go)** : Reçoit les événements d'audit, les chaîne (hash), les signe via Cosign, et les uploade sur S3.
3. **`policy-decision-service` (Go/OPA)** : Intègre Open Policy Agent. Reçoit les requêtes d'admission via Webhook et les requêtes de décision depuis CI/CD.
4. **`ai-security-governor` (Python)** : Microservice Read-Only. Intègre un proxy DLP (Presidio) et un client LLM. S'abonne aux anomalies NATS.
5. **`event-gateway` (Kong/Envoy)** : Optionnel, pour l'ingestion de logs externes (si NATS n'est pas directement exposé).

---

## 4. APIs (Minimal Design)

### Global Risk Engine API (Internal)
- `GET /api/v1/risk/score` : Retourne le *Global Risk Score* actuel.
- `GET /api/v1/risk/blast-radius?pod={pod_id}` : Calcule le *Blast Radius* d'un pod donné.

### Immutable Evidence Graph API
- `POST /api/v1/audit/event` : Ingestion d'un événement manuel (fallback si NATS est down).
- `GET /api/v1/audit/replay?start={ts}&end={ts}` : Reconstruit la chaîne cryptographique pour SOC2.

### Policy Decision Engine (Webhook)
- `POST /v1/policies/evaluate` : Reçoit un `AdmissionReview` K8s, retourne un verdict `AdmissionResponse` avec `ALLOWED` ou `DENIED`.

---

## 5. 🤖 AI Security Governor (Safe AI Layer)

L'IA est utilisée pour augmenter les capacités des analystes SOC, mais avec des **garde-fous stricts**.

### Constraints & Security
- **READ-ONLY:** L'agent IA n'a **aucune permission d'écriture** (RBAC K8s en lecture seule). Il ne peut que publier des recommandations sur NATS.
- **DLP Proxy (Data Loss Prevention):** Avant d'envoyer des logs Kubernetes à l'API LLM, un filtre Regex/Presidio supprime toutes les PII, mots de passe, et tokens (ex: `Bearer [A-Za-z0-9\-\._~+\/]+=*`).
- **Prompt Injection Protection:** Les inputs utilisateurs (ou logs falsifiés par un attaquant) sont analysés par un classifieur de prompt injection (ex: modèle ML léger local) avant d'atteindre le LLM principal.
- **Circuit Breaker:** Si l'IA commence à générer des recommandations invalides (JSON mal formés) ou si le taux d'erreur de l'API LLM dépasse 10%, l'agent est automatiquement désactivé et le système repasse en mode règles statiques.

### Output
L'IA publie des objets `AIRecommendation` sur NATS, qui sont affichés dans le portail SOC interne pour qu'un ingénieur clique sur "Approve" (Human-in-the-Loop).

---

## 6. 🚨 Modes de Défaillance & Mitigations

| Composant Défaillant | Risque / Conséquence | Atténuation (Mitigation) |
|---|---|---|
| **NATS Event Bus** | Perte de logs / Décisions retardées | Déploiement NATS JetStream en cluster (3 nœuds) avec persistance disque. Retry côté Falco/Jenkins. |
| **Global Risk Engine** | Faux positifs ou score figé | Monitoring Prometheus (`risk_engine_errors_total`). Fallback: les policies OPA utilisent un "score par défaut" statique de sécurité maximale. |
| **Sigstore / Signer** | Impossibilité de signer les logs d'audit | Alerting P1. Mise en cache locale des événements chiffrés. Rotation automatique des clés Vault. |
| **AI Governor** | Hallucinations / Prompt Injection | Mode "Human-in-the-Loop" obligatoire pour toute action. Proxy DLP strict. |

---
*Ce document sert de spécification de niveau TDD/Architecture pour l'implémentation des composants DevSecOps "Next-Gen" de SecureRAG Hub.*
