# SecureRAG Hub — Diagrammes d'architecture (Composants & Déploiement)

> Recueil des diagrammes Mermaid décrivant l'architecture applicative,
> la chaîne CI/CD DevSecOps et le déploiement Kubernetes.
> Périmètre officiel : les 5 microservices Laravel + plateforme de sécurité
> (voir `docs/architecture/official-scope.md`).

## Table des matières

1. [Vue Contexte (C4 — niveau 1)](#1-vue-contexte--c4-niveau-1)
2. [Vue Conteneurs (C4 — niveau 2)](#2-vue-conteneurs--c4-niveau-2)
3. [Vue Composants internes (C4 — niveau 3)](#3-vue-composants-internes--c4-niveau-3)
4. [Chaîne CI/CD DevSecOps](#4-chaîne-cicd-devsecops)
5. [Flux Supply Chain (SBOM · Signature · Promotion)](#5-flux-supply-chain)
6. [Topologie de déploiement Kubernetes](#6-topologie-de-déploiement-kubernetes)
7. [Sécurité réseau (NetworkPolicies)](#7-sécurité-réseau-networkpolicies)
8. [Gestion des secrets](#8-gestion-des-secrets)
9. [Observabilité & détection runtime](#9-observabilité--détection-runtime)
10. [Haute disponibilité & reprise d'activité](#10-haute-disponibilité--reprise-dactivité)

---

## 1. Vue Contexte (C4 — niveau 1)

```mermaid
flowchart LR
    Dev([Développeur]) -->|git push| Repo[(Dépôt Git)]
    Audit([Auditeur / Jury]) -->|consulte| Reports[Rapports & preuves]
    User([Utilisateur final]) -->|HTTP :30081| Portal

    subgraph Platform["SecureRAG Hub"]
        Portal["portal-web (Blade)"]
        API["4 API Laravel métiers"]
        Sec["Couche sécurité DevSecOps"]
    end

    User --> Portal
    Portal --> API
    API --> Sec

    Repo -->|webhook| Jenkins[Jenkins CI/CD]
    Jenkins -->|construit, signe, déploie| Platform

    style Platform fill:#0f172a,stroke:#38bdf8,color:#e2e8f0
```

---

## 2. Vue Conteneurs (C4 — niveau 2)

```mermaid
flowchart TB
    subgraph Clients
        Browser["Navigateur"]
        KCTL["kubectl / ArgoCD"]
    end

    subgraph K8s["Cluster Kubernetes (kind securerag-dev)"]
        subgraph AppNS["Namespace: securerag-hub"]
            Portal["portal-web<br/>(Blade + JS · :8000/NodePort 30081)"]
            Auth["auth-users<br/>(Laravel API · :8000)"]
            Bot["chatbot-manager<br/>(Laravel API · :8000)"]
            Conv["conversation-service<br/>(Laravel API · :8000)"]
            Audit["audit-security-service<br/>(Laravel API · :8000)"]
            PG[("postgres-auth<br/>PostgreSQL 16")]
        end

        subgraph SharedSvc["services-laravel/shared-security"]
            Pkg["Paquet PHP partagé<br/>SecurityHeaders · Middlewares"]
        end
    end

    Browser -->|HTTP| Portal
    KCTL -->|"déploie / vérifie"| K8s

    Portal -->|/api/users| Auth
    Portal -->|/api/chatbots| Bot
    Portal -->|/api/conversations| Conv
    Portal -->|/api/audit| Audit
    Auth --> PG

    Portal -.-> Pkg
    Auth -.-> Pkg
    Bot -.-> Pkg
    Conv -.-> Pkg
    Audit -.-> Pkg

    style AppNS fill:#1e293b,stroke:#22c55e
    style SharedSvc fill:#164e63,stroke:#0891b2
```

---

## 3. Vue Composants internes (C4 — niveau 3)

### 3.1 portal-web

```mermaid
flowchart LR
    subgraph PortalWeb["portal-web"]
        Routes["routes/web.php<br/>routes/api.php"] --> Controllers["Controllers"]
        Controllers --> MW["Middleware<br/>RequireAdminToken<br/>SecurityHeaders"]
        Controllers --> Views["Blade views<br/>(dashboards démo)"]
        Controllers --> Client["PortalBackendClient<br/>(HTTP vers les 4 API)"]
        Controllers --> Demo["DemoPortalData<br/>(données de démonstration)"]
    end
    MW --> Clients["/admin → X-Admin-Token obligatoire"]
```

### 3.2 Microservices métiers (pattern commun)

```mermaid
flowchart TB
    In["HTTP Request"] --> M1["SecurityHeaders + Auth middleware"]
    M1 --> Ctrl["Controllers (auth / chatbots / conversations / audit)"]
    Ctrl --> Model["Eloquent Models"]
    Model --> DB[("postgres-auth<br/>/ SQLite test")]
    Ctrl --> Log["Audit logging transversal"]
    Ctrl --> Resp["API Resource / JsonResponse"]
```

---

## 4. Chaîne CI/CD DevSecOps

### 4.1 Chaîne Jenkins (vue séquence)

```mermaid
sequenceDiagram
    autonumber
    participant D as Développeur
    participant G as Git
    participant J as Jenkins
    participant S as Scanners (Semgrep/Gitleaks/Trivy/Sonar)
    participant R as Registry (localhost:5001)
    participant C as Cosign
    participant K as Kubernetes

    D->>G: git push (branche feature)
    G->>J: webhook → déclenche build
    J->>J: checkout · detect-changes
    J->>S: SAST + secrets + FS scan (parallèle)
    S-->>J: rapports JSON (+ JUnit)
    J->>J: PHPUnit · 98,5% coverage ≥ 95%
    J->>R: docker build + push images: dev
    J->>J: SBOM CycloneDX (Syft) 5/5
    J->>C: cosign sign (key-pair dev / keyless Sigstore prod)
    C-->>J: signatures signées
    J->>J: verify signatures + promote par digest
    J->>K: apply overlay Kustomize + rollout
    J->>J: smoke-tests · smoke-security · adversarial
    alt Échec de portail
        J-->>D: rapport d'échec (jenkins + artefacts)
    end
```

### 4.2 Makefile — chaîne local reproductible

```mermaid
flowchart LR
    subgraph CI["make ci"]
        L[lint] --> T[test + coverage]
        T --> SS[security-scan<br/>Semgrep · Gitleaks · Trivy FS]
    end
    subgraph CD["make cd"]
        B[build] --> IS[image-scan Trivy]
        IS --> SB[sbom Syft]
        SB --> SG[sign Cosign]
        SG --> VF[verify]
        VF --> DP[deploy kind]
    end
    CI --> CD --> VA["make validate<br/>smoke · sec-smoke · e2e · adversarial"]
    VA --> PR["make final-proof<br/>gates obligatoires"]
```

---

## 5. Flux Supply Chain

```mermaid
flowchart LR
    Img(["Images buildées :dev"]) --> Scan["Trivy image scan<br/>0 CRITICAL requis"]
    Scan --> SBOM["SBOM CycloneDX par image<br/>/artifacts/sbom"]
    SBOM --> Sign["Cosign sign<br/>digest sha256"]
    Sign --> Verify["Cosign verify<br/>COSIGN_PUBLIC_KEY<br/>PASS 5/5 obligatoire"]
    Verify --> Promote["promote-by-digest<br/>dev → release-local<br/>promotion-digests.txt"]
    Promote --> Attest["attest SBOM +<br/>provenance SLSA"]
    Attest --> Gate{{"Supply-chain gate<br/>Tous PASS obligatoire"}}
    Gate -->|OK| Release["Release prête"]
    Gate -->|FAIL| Block["STOP — rien ne se déploie"]

    style Gate fill:#7f1d1d,stroke:#ef4444,color:#fff
```

---

## 6. Topologie de déploiement Kubernetes

```mermaid
flowchart TB
    subgraph Cluster["kind: securerag-dev (1 CP + 1 worker)"]
        subgraph NS1["Namespace: securerag-hub"]
            D1["Deployment portal-web · 1r<br/>NodePort 30081<br/>HPA 1→3 (CPU 70%)"]:::app
            D2["Deployment auth-users · HPA"]:::app
            D3["Deployment chatbot-manager · HPA"]:::app
            D4["Deployment conversation-service · HPA"]:::app
            D5["Deployment audit-security-service · HPA"]:::app
            PG[("StatefulSet/Deployment<br/>postgres-auth")]:::data
            S1["Secret portal-admin-token"]:::sec
        end

        subgraph NS2["Namespace: kube-system / infra"]
            MS["metrics-server"]:::infra
        end

        subgraph NS3["Observabilité: monitoring/loki"]
            Prom["Prometheus"]:::infra
            Graf["Grafana"]:::infra
            Loki["Loki"]:::infra
            Alert["Alertmanager"]:::infra
        end

        subgraph NS4["GitOps: argocd"]
            Argo["ArgoCD server<br/>Applications (app-of-apps)"]:::infra
        end
    end

    Ingress(["Ingress / NodePort :30081"]) --> D1
    D1 --> D2 & D3 & D4 & D5
    D2 --> PG
    HPA["metrics-server feed"] -.->|"CPU% → replicas"| D1 & D2 & D3 & D4 & D5
    Prom -.->|scrap /metrics| D1
    Loki -.->|logs stdout| D1 & D2 & D3 & D4 & D5
    Argo -.->|sync gitops| NS1

    classDef app fill:#123c2b,stroke:#22c55e,color:#dcfce7
    classDef data fill:#312e81,stroke:#818cf8,color:#e0e7ff
    classDef infra fill:#334155,stroke:#94a3b8,color:#e2e8f0
    classDef sec fill:#450a0a,stroke:#ef4444,color:#fee2e2
```

---

## 7. Sécurité réseau (NetworkPolicies)

```mermaid
flowchart TB
    %% default-deny
    subgraph N["Namespace securerag-hub (default deny)"]
        direction TB
        P["portal-web"]:::front
        A["auth-users"]:::back
        B["chatbot-manager"]:::back
        C["conversation-service"]:::back
        D["audit-security-service"]:::back
        E[("postgres-auth")]:::db
    end

    World["Extérieur (NodePort)"] -->|"from: any — rôle frontend"| P
    P -->|"to: pods autorisés uniquement"| A & B & C & D
    A -->|"to: postgres-auth:5432"| E
    B -.->|"egress minimal"| A
    C -.->|"egress minimal"| A
    D -.->|"egress minimal"| A
    X["Pod non autorisé"] -. "REQUÊTE BLOQUÉE" .-> A

    classDef front fill:#1e3a8a,stroke:#3b82f6,color:#dbeafe
    classDef back fill:#134e4a,stroke:#14b8a6,color:#ccfbf1
    classDef db fill:#312e81,stroke:#818cf8,color:#e0e7ff
```

---

## 8. Gestion des secrets

```mermaid
flowchart LR
    subgraph Sources["Sources de vérité"]
        SOPS["SOPS + age<br/>(chiffré dans git)"]
        VAULT["HashiCorp Vault"]
        ESO["External Secrets Operator"]
        Local["security/keys/ (dev)"]
    end

    subgraph K8s["Cluster"]
        SA1["Secret: portal-admin-token"]
        SA2["Secret: postgres-auth credentials"]
        SA3["Secret: cosign keypair"]
    end

    SOPS -->|"decrypt + apply"| K8s
    VAULT -->|sync| ESO --> K8s
    Local -->|"kubectl create secret (dev)"| SA3

    SA1 --> Portal["portal-web<br/>RequireAdminToken"]
    SA2 --> Auth["auth-users"]
    SA3 --> CI["Pipeline sign/verify"]

    style Local fill:#422006,stroke:#f59e0b
```

---

## 9. Observabilité & détection runtime

```mermaid
flowchart TB
    subgraph Apps["Pods applicatifs"]
        P1["portal-web + 4 API"]
    end

    subgraph Coll["Collecte"]
        MTX["metrics-server<br/>(HPA)"]
        Prom["Prometheus"]
        Loki["Loki / Promtail"]
        Falco["Falco (syscalls)"]
    end

    subgraph UI["Visualisation & alerte"]
        Graf["Grafana dashboards"]
        Alert["Alertmanager"]
        Sidekick["Falcosidekick"]
    end

    P1 -->|"/metrics"| Prom
    P1 -->|"stdout logs"| Loki
    P1 -->|"syscalls"| Falco
    MTX -->|HPA scaling| P1

    Prom --> Graf
    Loki --> Graf
    Falco --> Sidekick --> Alert
    Prom -.-> Rules["Rules / SLO"]
    Loki -.-> Rules
    Rules --> Alert
```

---

## 10. Haute disponibilité & reprise d'activité

```mermaid
flowchart TB
    subgraph Cluster["Production (overlay production)"]
        subgraph HA["Redondance"]
            Rep["Replicas ≥ 2<br/>antiAffinité"]
            PDB["PodDisruptionBudget"]
            HPA["HPA CPU 70%"] 
        end

        subgraph Data["Données"]
            PG[("PostgreSQL externe ou interne")]
            BCK["Velero backup CronJob"]
        end
    end

    Chaos(("Chaos engineering<br/>Litmus / pod-delete drill")) --> HA
    BCK -->|snapshot| S3["Stockage S3 compatible"]
    DR["make disaster-recovery<br/>restaure le backup le plus récent"] -->|restore| PG

    style HA fill:#064e3b,stroke:#10b981,color:#d1fae5
    style Data fill:#312e81,stroke:#818cf8,color:#e0e7ff
```

---

## Légende

| Couleur | Signification |
|---|---|
| 🟩 vert | Microservices applicatifs |
| 🟪 violet | Données (bases de données) |
| 🔵 bleu | Frontend / exposition |
| ⬜ gris | Infrastructure / plateforme |
| 🟥 rouge | Gates bloquants, secrets |
| ✅ | Check valide / contrôle conforme |
| ❌ | Violation / détecteur d'écart |
| ⏸️ | Composant legacy (hors scope officiel) |

---

*Généré le 22/09/2026 — correspond à l'état de la chaîne après corrections (20/20 tests PASS, note 96/100).*
