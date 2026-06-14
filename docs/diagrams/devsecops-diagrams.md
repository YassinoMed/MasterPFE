# Diagrammes — Chaîne DevSecOps SecureRAG Hub

## 1. Vue d'ensemble
Ce diagramme présente l'architecture globale de la chaîne DevSecOps. Il illustre le parcours du code depuis le dépôt Git jusqu'au déploiement dans le cluster Kubernetes, en traversant les pipelines d'intégration et de déploiement continus. Les connexions transversales avec les outils d'observabilité figurent en bas du schéma.

```mermaid
flowchart LR
    subgraph "Source"
        github["Dépôt GitHub"]
        gitleaks["Gitleaks pre-commit"]
    end

    subgraph "CI — Jenkins"
        ci_tests["Lint & Tests"]
        ci_scans["SAST, SCA, IaC"]
        ci_qg["Quality Gate"]
    end

    subgraph "CD — Jenkins"
        cd_build["Build & Scan"]
        cd_sign["Sign & SBOM"]
        cd_dast["DAST ZAP & Promote"]
    end

    subgraph "Runtime K8s"
        k8s_sync["Argo CD & Admission"]
        k8s_pods["Pods PSS & Falco"]
    end

    obs["Prometheus, Grafana, Loki, Alertmanager, Wazuh, Vault"]

    github --> gitleaks
    gitleaks --> ci_tests
    ci_tests --> ci_scans
    ci_scans --> ci_qg
    ci_qg --> cd_build
    cd_build --> cd_sign
    cd_sign --> cd_dast
    cd_dast --> k8s_sync
    k8s_sync --> k8s_pods

    gitleaks -.->|"logs"| obs
    ci_qg -.->|"métriques"| obs
    cd_dast -.->|"rapports"| obs
    k8s_pods -.->|"métriques & alertes"| obs

    classDef source fill:#F1EFE8,stroke:#5F5E5A
    classDef pipeline fill:#E1F5EE,stroke:#0F6E56
    classDef runtime fill:#FAECE7,stroke:#993C1D
    classDef obs fill:#EEEDFE,stroke:#534AB7

    class github,gitleaks source
    class ci_tests,ci_scans,ci_qg,cd_build,cd_sign,cd_dast pipeline
    class k8s_sync,k8s_pods runtime
    class obs obs
```

## 2. Flux CI/CD détaillé
Ce flux détaille l'exécution séquentielle des étapes des pipelines Jenkins. Les losanges marquent les portes de qualité qui conditionnent la poursuite du déploiement. L'analyse SonarQube figure en pointillés pour indiquer son statut paramétrable.

```mermaid
flowchart TD
    subgraph "Jenkins CI"
        ci1["Checkout & Prepare"]
        ci2["LINT & TESTS"]
        ci3["SECURITY STATIC (SAST, Secrets, SCA)"]
        ci4["IaC & K8S POLICY"]
        ci5["SONAR QUALITY GATE"]
        ci6{"QUALITY GATE"}
        ci_fail["Pipeline bloqué + mail"]
        
        ci1 --> ci2 --> ci3 --> ci4 --> ci5 --> ci6
        ci6 -->|Échec| ci_fail
    end

    subgraph "Jenkins CD"
        cd1["Build & Trivy image"]
        cd2["Signature Cosign (keyless)"]
        cd3["SBOM Syft & Grype"]
        cd4["Supply Chain Evidence"]
        cd5{"DAST ZAP"}
        cd_fail["Pipeline bloqué"]
        cd6["Promote Digest vers Harbor"]
        
        ci6 -->|Succès| cd1
        cd1 --> cd2 --> cd3 --> cd4 --> cd5
        cd5 -->|Échec| cd_fail
        cd5 -->|Succès| cd6
    end

    subgraph "Cluster"
        k8s1["Argo CD sync"]
        k8s2{"Admission Kyverno"}
        k8s_fail["Rejet + alerte"]
        k8s3["Déploiement PSS Restricted + Falco"]
        
        cd6 --> k8s1
        k8s1 --> k8s2
        k8s2 -->|Non conforme| k8s_fail
        k8s2 -->|Conforme| k8s3
    end

    classDef pipeline fill:#E1F5EE,stroke:#0F6E56
    classDef runtime fill:#FAECE7,stroke:#993C1D
    classDef blocked fill:#FCEBEB,stroke:#A32D2D
    classDef planned fill:#E1F5EE,stroke:#0F6E56,stroke-dasharray: 5 5

    class ci1,ci2,ci3,ci4,ci6,cd1,cd2,cd3,cd4,cd5,cd6 pipeline
    class k8s1,k8s2,k8s3 runtime
    class ci_fail,cd_fail,k8s_fail blocked
    class ci5 planned
```

## 3. Flux de rejet et alerte sécurité
Ce schéma modélise les boucles de rétroaction en cas d'anomalie de sécurité. Il distingue le rejet lors du contrôle d'admission par Kyverno et la détection comportementale par Falco. Les événements critiques convergent vers Alertmanager pour déclencher une notification immédiate.

```mermaid
flowchart TD
    subgraph "Scenario C — CI Pre-merge"
        c1["Secret détecté dans un commit"]
        c2["Gitleaks (CI, pre-merge)"]
        c3["Pipeline bloqué — pas de build"]
        c1 --> c2 -->|"Bloque la PR"| c3
    end

    subgraph "Scenario A — Admission"
        a1["Image non signée ou non conforme"]
        a2["Kyverno — contrôle admission (Enforce)"]
        a3["Admission refusée"]
        a4["Événement Kubernetes (rejected)"]
        a5["Promtail / audit log"]
        a1 --> a2 -->|"Rejet"| a3 --> a4 --> a5
    end

    subgraph "Scenario B — Runtime"
        b1["Pod compromis (ex: exec shell inattendu)"]
        b2["Falco — règle déclenchée"]
        b3["falcosidekick"]
        b4["Corrélation SIEM"]
        b1 --> b2 --> b3
        b3 -.->|"événement"| shared_wazuh
        shared_wazuh --> b4
    end

    shared_loki["Loki"]
    shared_am["Alertmanager"]
    shared_slack["Slack #devsecops-alerts"]
    shared_wazuh["Wazuh (VPS)"]

    a5 --> shared_loki --> shared_am
    b3 -->|"webhook"| shared_am
    shared_am -->|"sévérité élevée"| shared_slack

    classDef trigger fill:#FCEBEB,stroke:#A32D2D
    classDef control fill:#FAEEDA,stroke:#854F0B
    classDef sink fill:#EEEDFE,stroke:#534AB7
    classDef blocked fill:#FCEBEB,stroke:#A32D2D

    class c1,a1,b1 trigger
    class c2,a2,b2 control
    class shared_loki,shared_am,shared_slack,shared_wazuh,a4,a5,b3,b4 sink
    class c3,a3 blocked
```

## 4. Architecture cluster
L'architecture du cluster Kubernetes sépare rigoureusement les composants par espace de noms. Les flèches indiquent les interactions clés entre l'infrastructure de sécurité, l'observabilité et les charges de travail applicatives. L'agent Wazuh transmet directement les événements à son gestionnaire hébergé sur le serveur virtuel externe.

```mermaid
flowchart TB
    subgraph "Cluster Kubernetes (Kind / k3s — OVH VPS)"
        subgraph "ns: securerag-prod"
            app_nodes["api-gateway, rag-service, auth-users, services-laravel (PSS Restricted)"]
        end
        subgraph "ns: security"
            falco["Falco DaemonSet & falcosidekick"]
            wazuh_agent["Wazuh agent"]
        end
        subgraph "ns: vault"
            vault["Vault & External Secrets Operator"]
        end
        subgraph "ns: harbor"
            harbor["Harbor core & Trivy"]
        end
        subgraph "ns: jenkins"
            jenkins["Jenkins controller"]
        end
        subgraph "ns: argocd"
            argocd["Argo CD server & repo-server"]
        end
        subgraph "ns: monitoring"
            monitoring["Prometheus, Grafana, Loki, Alertmanager, Pushgateway"]
        end
    end

    vps_wazuh["VPS host — Docker Compose: Wazuh manager"]

    argocd -.->|"sync"| app_nodes
    falco -->|"audit syscalls"| app_nodes
    falco -.->|"events"| monitoring
    wazuh_agent -.->|"events"| vps_wazuh
    vault -->|"secrets"| app_nodes
    harbor -->|"images signées"| app_nodes
    jenkins -->|"deploy via Argo CD"| argocd
    monitoring -.->|"scrape /metrics"| app_nodes

    classDef app fill:#E1F5EE,stroke:#0F6E56
    classDef sec fill:#FAECE7,stroke:#993C1D
    classDef platform fill:#EEEDFE,stroke:#534AB7
    classDef obs fill:#F1EFE8,stroke:#5F5E5A

    class app_nodes app
    class falco,wazuh_agent sec
    class vault,harbor,jenkins,argocd platform
    class monitoring,vps_wazuh obs

    style vps_wazuh stroke-dasharray: 5 5
```

## Légende des couleurs

| Couleur | Signification |
| --- | --- |
| Vert | Pipeline actif, flux applicatif Nominal |
| Rouge/Corail | Déclencheur, rejet de sécurité ou blocage du pipeline |
| Jaune/Orange | Contrôle de sécurité (Admission, Scan) |
| Violet | Composant de plateforme ou d'observabilité (SIEM, Alertmanager) |
| Gris | Code source, structures englobantes ou composants neutres |
