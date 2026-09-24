# SecureRAG Hub — Diagramme de fonctionnement
# Date : 24 septembre 2026

## Vue d'ensemble du pipeline DevSecOps

Le schéma ci-dessous retrace le voyage d'un commit jusqu'à la mise en production, intégrant les outils de l'écodeployeur : Jenkins, Trivy, Semgrep, Gitleaks, SonarQube, Cosign, SBOM, Kyverno, Kubernetes, et la couche AI/Securité NOUVELLE (SECAI).

## Diagramme

```mermaid
flowchart TD
    %% ─── Côté développeur ───
    subgraph DEV["🖥️ Poste développeur"]
        Code["Code source<br/>PHP / Laravel"]
        PreCommit["pre-commit<br/>gitleaks · shellcheck · shfmt"]
        Code --> PreCommit
    end

    PreCommit -->|git push origin feature/xx| Hub[(GitHub)]

    %% ─── CI Jenkins ───
    subgraph CI["🔧 CI — Jenkins (:8085)"]
        direction TB
        Webhook["Webhook GitHub / Poll SCM<br/>déclenche build stage"]
        QG["Quality gates<br/>lint · tests · coverage 98.39 %"]
        Scanners["Scanners sécurité<br/>• Semgrep SAST<br/>• Gitleaks secrets<br/>• Trivy FS"
        ]
        Build["Docker Build ×5<br/>portal-web · auth-users<br/>chatbot-manager · conversation-service · audit-security-service"]

        Webhook --> QG --> Scanners --> Build
    end

    Hub --> Webhook

    %% ─── Supply Chain Security ───
    subgraph SC["🔒 Supply Chain (SLSA)"]
        direction TB
        TrivyImg["Trivy image scan<br/>0 CRITICAL= obligatoire"]
        SBOMGen["SBOM CycloneDX<br/>127 components par image"]
        Sign["Cosign sign<br/>5/5 images"]
        Verify["Cosign verify<br/>par digest"]
        Promote["Promote (no rebuild)<br/>dev → release-local"]
        FVeX["Analyse VEX<br/>triaged + recommendations"]

        TrivyImg --> SBOMGen --> Sign --> Verify --> Promote --> FVeX
    end

    Build --> TrivyImg

    %% ─── SECAI — Security AI Layer ───
    subgraph AI["🤖 SECAI (Security Intelligence)"]
        batch["Jenkins Stage:<br/>SECAI Security Analysis"]
        embedding["SecureBERT2.0-base<br/>embeddings saisonnals"]
        policy["Policy décisionnelle<br/>PASS · REVIEW · BLOCK · INCONCLUSIVE"]

        batch --> embedding --> policy
    end

    Scanners --> AI
    FVeX --> DecK8S["Deploy to K8s"]

    %% ─── Kubernetes ───
    subgraph K8S["☸️ Kubernetes (kind: securerag-dev)"]
        direction TB
        Apply["kustomize apply<br/>overlay dev/prod"]
        Kyverno["Kyverno admission<br/>✓ 8 policies (Enforce)<br/>✓ signaturés checked"]
        Pods["6/6 pods Running<br/>• PSS restricted<br/>• Safety/ NetworkPolicies<br/>• seccomp"]
        HPA["5 HPA actifs<br/>CPU target 70%"]

        Apply --> Kyverno --> Pods
    end

    DecK8S --> K8S

    %% ─── Observabilité ───
    subgraph RUN["🔍 Runtime & Monitoring"]
        Falco["Falco (syscalls)<br/>runtime protection"]
        Metrics["metrics-server<br/>+ Promtail/Prometheus"]
        Grafana["Grafana dashboards"]
        Alerts["Alertmanager<br/>→ Slack"]
    end

    Pods --> Falco
    Pods --> Metrics
    Metrics --> Grafana
    Falco --> Alerts
    Metrics --> Alerts

    %% ─── Validation & Preuves ───
    subgraph VALID["✅ Validation post-deploy"]
        Smoke["smoke-tests"]
        SecSmoke["security-smoke<br/>exposure test, admin token"]
        E2E["e2e functional flows"]
        Adv["adversarial tests<br/>SQLi · XSS · prompt injection"]
        FP["final-proof<br/>13 checks obligatoires"]
    end

    HPA --> Smoke
    Smoke --> SecSmoke --> E2E --> Adv --> FP
    FP --> Report["Rapports & preuves<br/>artifacts/ + release/ + jenkins/"]

    %% ─── Styles ───
    classDef dev fill:#0a2540,stroke:#38bdf8,color:#dbeafe
    classDef ci fill:#1e293b,stroke:#22c55e,color:#dcfce7
    classDef sc fill:#0f172a,stroke:#6ee7b7,color:#d1fae5
    classDef ai fill:#3b0764,stroke:#a855f7,color:#f3e8ff
    classDef k8s fill:#134e4a,stroke:#14b8a6,color:#ccfbf1
    classDef run fill:#451a03,stroke:#f59e0b,color:#fef3c7
    classDef valid fill:#0c4a6e,stroke:#38bdf8,color:#e0f2fe

    class DEV dev
    class CI ci
    class SC sc
    class AI ai
    class K8S k8s
    class RUN run
    class VALID valid
```

## Les points de contrôle de la chaîne (gates inarrêtable)

| Phase | Gate | Bloquer si |
|---|---|---|
| Pre-commit | gitleaks | Fuite de secrets staged |
| CI | lint + tests + coverage | plugins en échec, coverage < 95% |
| CI | Semgrep/Gitleaks/Trivy FS | HIGH/CRITICAL susceptibles |
| CI | SonarQube | Quality Gate failed |
| CD | Trivy image | CRITICAL = exit status |
| CD | Cosign verify | signatures non valides (5/5 requis) |
| CD | Promotion digest | digest mismatch → abort |
| K8s | Kyverno admission | policy violation (8 politiques Enforce) |
| Runtime | Falco alerts | dépend sur la politique (irreversible actions) |
| Post | make final-proof | gate incomplet → exit 1 |

## Commandes maîtresses pour rejouer

```bash
# chaîne complète
make ci && make cd && make validate
make final-proof        # le gate noble

# points de dépannage
make security-scan
make verify
make benchmark-k6
```

## État au moment de la génération

- **6/6 pods Running** — scalabilité prête 5 HPA opérationnels
- **5/5 images signées Cosign** — digest verification PASS
- **98,39 % coverage gates** — le mise à jour quality gates
- **0 HIGH/CRITICAL** après patch VEX (league/commonmark, guzzle, openssl)
- **Prompt cryptographedible** : Les messages SAST sont normalisés par SE sur la majorité des vendors.

---

**Fichier généré le : 24 septembre 2026** (série flash délié de la version ensemble)
