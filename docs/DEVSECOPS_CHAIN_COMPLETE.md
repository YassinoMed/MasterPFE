# Guide Complet — Chaîne DevSecOps, Stack IA/LLM, Images Distroless & Cluster

> **Projet** : SecureRAG Hub — Architecture DevSecOps  
> **Conformité** : SLSA Level 3/4, Pod Security Standards (PSS) Restricted, OWASP Top 10 API/LLM, Zero Trust Architecture (SPIFFE/SPIRE & Falco Talon).

---

## 1. Vue d'Ensemble & Fonctionnement Général

La chaîne DevSecOps de **SecureRAG Hub** automatise la sécurité à chaque étape du cycle de vie du développement logiciel (*Software Development Life Cycle - SDLC*), depuis la gestion continue des dépendances jusqu'à la remédiation automatique en production sur Kubernetes.

### Architecture Globale du Flux DevSecOps & AI Security

```mermaid
graph TB
    subgraph SCM["1. Gestion Continue & SCM"]
        RENOVATE[Renovate Bot<br/>• Auto-PRs Dépendances<br/>• Pinning SHA256]
        DEV[Développeur] -->|Git Push / PR| GH[GitHub Repository]
        RENOVATE -->|PRs Automatiques| GH
        GH -->|Webhook OIDC| J[Jenkins CI/CD Server]
    end

    subgraph CILayer["2. Intégration Continue (CI) & Quality Gates"]
        J --> PREP[Prepare & Dependencies Cache]
        PREP --> PARALLEL[Parallel Scans & Checks]
        
        subgraph Scans["Analyses Statiques & Sécurité"]
            PARALLEL --> TEST[PHPUnit & Python Tests]
            PARALLEL --> SAST[Semgrep SAST]
            PARALLEL --> SECRETS[Gitleaks Secrets Scan]
            PARALLEL --> SCA[Trivy FS & OWASP DepCheck]
            PARALLEL --> SONAR[SonarQube Quality Gate]
        end

        Scans --> QG1{CI Quality Gate<br/>• Coverage > 70%<br/>• 0 Secrets / 0 SAST Error<br/>• 0 Critical CVE}
        QG1 -->|FAIL| STOP1[❌ Interruption du Pipeline]
    end

    subgraph SupplyChainLayer["3. Supply Chain Security (SLSA L3)"]
        QG1 -->|PASS| BUILD[Docker Multi-Stage Build<br/>Image Finale Distroless SHA256]
        BUILD --> SBOM[Génération SBOM CycloneDX<br/>(Syft)]
        SBOM --> GRYPE[Scan CVE Conteneur<br/>(Grype Fail on High/Critical)]
        GRYPE --> SIGN[Signature Keyless Cosign<br/>(Fulcio OIDC + Rekor)]
        SIGN --> PROV[Génération SLSA Provenance]
    end

    subgraph CDLayer["4. GitOps & Admission Control"]
        PROV --> GITOPS[Update GitOps Manifests<br/>by SHA256 Digest]
        GITOPS --> ARGO[ArgoCD GitOps Engine]
        ARGO --> K8S[Cluster Kubernetes KinD]

        subgraph K8sAdmission["Admission & Workload Identity"]
            K8S --> SPIRE[SPIFFE/SPIRE<br/>Workload Attestation SVID]
            K8S --> KYVERNO[Kyverno Admission Controller<br/>• Verify Cosign Signature<br/>• Enforce PSS Restricted]
            KYVERNO --> PODS[Pods Running Distroless<br/>(UID 10001 / Zero Shell)]
        end
    end

    subgraph RuntimeSecurityLayer["5. Runtime Protection & Remédiation Automatique"]
        PODS --> FALCO[Falco eBPF Detector]
        FALCO -->|Event Trigger| TALON[Falco Talon Engine<br/>• Auto Pod Eviction<br/>• Network Quarantine]
    end

    subgraph AISecurityLayer["6. Stack de Sécurité & Observabilité IA/LLM"]
        PODS --> LITELLM[LiteLLM Gateway]
        LITELLM --> NEMO[NeMo Guardrails]
        NEMO --> GARAK[Garak LLM Red Teaming]
        LITELLM --> LANGFUSE[Langfuse Observability]
    end

    classDef scc fill:#1f2937,stroke:#4b5563,color:#fff;
    classDef ci fill:#1e1b4b,stroke:#6366f1,color:#fff;
    classDef supply fill:#064e3b,stroke:#059669,color:#fff;
    classDef cd fill:#7c2d12,stroke:#ea580c,color:#fff;
    classDef runtime fill:#701a75,stroke:#d946ef,color:#fff;
    classDef ai fill:#0284c7,stroke:#38bdf8,color:#fff;

    class DEV,GH,J,RENOVATE scc;
    class PREP,PARALLEL,TEST,SAST,SECRETS,SCA,SONAR,QG1,STOP1 ci;
    class BUILD,SBOM,GRYPE,SIGN,PROV supply;
    class GITOPS,ARGO,K8S,SPIRE,KYVERNO,PODS cd;
    class FALCO,TALON runtime;
    class LITELLM,NEMO,GARAK,LANGFUSE ai;
```

---

## 2. Détails Exhaustifs des Étapes du Pipeline (`Jenkinsfile`)

Le pipeline régit l'ensemble de la livraison logicielle via **22 stages automatisés**.

### Dépendances Automatisées avec Renovate Bot
- **Renovate Bot** scrute en continu le dépôt pour générer des Pull Requests automatiques de mise à jour.
- Il applique un **pinning strict par hachage SHA256** pour tous les paquets Composer, NPM, et les images de base Docker.

### Table des Étapes du Pipeline

| Étape / Stage | Outil / Technologie | Description & Action Bloquante |
| :--- | :--- | :--- |
| **0. Renovate SCA** | Renovate Bot | Détection continue et mises à jour automatisées par PRs verrouillées SHA256. |
| **1. Prepare Workspace** | `git checkout` | Prépare les répertoires d'artefacts (`artifacts/sbom`, `security/reports`) et permissions. |
| **2. Install Dependencies** | `composer`, `npm` | Restaure les paquets depuis le cache PVC persistant avec validation `md5sum`. |
| **3. Parallel Scans** | Multi-thread | Exécute en parallèle PHPUnit, Semgrep, Gitleaks, Trivy FS et OWASP Dependency-Check. |
| **• Unit Tests & Coverage** | PHPUnit | Exécute les tests unitaires et vérifie la couverture de code ($\ge 70\%$ requis). |
| **• Semgrep SAST** | Semgrep | Analyse statique du code PHP/Python pour intercepter les failles de sécurité (CWE-89, XSS, RCE). |
| **• Gitleaks Secrets Scan** | Gitleaks v8 | Recherche les clés privées, tokens ou secrets commités. **Bloquant**. |
| **• Trivy FS Scan** | Trivy | Scanne le système de fichiers et les dépendances pour détecter les CVEs connues. |
| **4. SonarQube Analysis** | SonarScanner | Calcule la dette technique et valide la Quality Gate SonarQube. |
| **5. Build Docker Images** | Docker Multi-Stage | Compile les images applicatives en utilisant des images de runtime **Distroless**. |
| **6. Génération SBOM** | Syft / CycloneDX | Génère l'inventaire logiciel structuré (SBOM) au format CycloneDX JSON pour chaque image. |
| **7. Scan CVE (Grype)** | Grype | Analyse le SBOM. **Bloque immédiatement le pipeline** sur vulnérabilité `HIGH` ou `CRITICAL`. |
| **8. Signature Cosign** | Cosign Keyless | Signe les images via le protocole Keyless OIDC Sigstore/Fulcio avec transparence Rekor. |
| **9. SLSA Provenance** | Cosign / Provenance | Génère l'attestation SLSA Level 3 décrivant la traçabilité complète du build. |
| **10. AI Security Agents** | Python Agents | Exécute 6 agents IA spécialisés (STRIDE, Secure Code, DAST Fuzzing, Risk Score). |
| **11. AI Risk Analysis** | Risk Engine | Calcule le **Global Risk Score**. Si `Score >= 50.0`, le déploiement est rejeté. |
| **12. GitOps Deploy** | GitOps / Kustomize | Met à jour les digests SHA256 dans Kustomize et rafraîchit ArgoCD. |
| **13. Verify Rollout** | `kubectl rollout` | Valide la disponibilité des Pods sur le cluster Kubernetes KinD (timeout 120s). |
| **14. Smoke Tests** | Shell / cURL | Exécute des tests d'intégration HTTP et de santé sur l'API publique (`/healthz`). |
| **15. k6 Performance Tests** | k6 | Valide les SLOs de performance sous charge (Smoke, Load, Stress). |
| **16. Performance Gate** | Quality Gate | Valide la latence **p95 < 500ms**, le taux d'erreur < 1% et la disponibilité > 99%. |

---

## 3. Stratégie d'Images Distroless & Durcissement des Conteneurs

Conformément à l'**ADR-001 (Utilisation des Images Distroless en Production)**, les images applicatives de production abandonnent les distributions Linux complètes (Debian, Ubuntu, Alpine) au profit d'images **Distroless** (ex. `gcr.io/distroless/php-debian12:8.2` ou `cgr.dev/chainguard/static`).

### Pourquoi le Distroless ?
- **Réduction de la surface d'attaque (>90%)** : Absence totale de shell (`/bin/sh`, `/bin/bash`), de gestionnaire de paquets (`apt`, `apk`), et d'utilitaires système (`curl`, `wget`, `nc`).
- **Immunité contre les Reverse Shells** : Même en cas d'injection de code applicatif, un attaquant ne peut exécuter aucun shell interactif.
- **Réduction du volume d'image** : Passage de ~200 MB à **~65 MB**.

### Dockerfile Officiel de Production Distroless (`docker/portal-web/Dockerfile`)

```dockerfile
# ==========================================
# Étape 1 : Installation des dépendances (deps - SDK)
# ==========================================
FROM composer:2 AS deps
WORKDIR /var/www/html

COPY platform/portal-web/composer.json platform/portal-web/composer.lock ./
COPY services-laravel/shared-security /var/services-laravel/shared-security

RUN composer install --no-dev --no-interaction --prefer-dist --no-scripts --no-autoloader --ignore-platform-reqs

COPY platform/portal-web/app ./app
COPY platform/portal-web/bootstrap ./bootstrap
COPY platform/portal-web/config ./config
COPY platform/portal-web/database ./database
COPY platform/portal-web/public ./public
COPY platform/portal-web/resources ./resources
COPY platform/portal-web/routes ./routes
COPY platform/portal-web/artisan ./

RUN composer dump-autoload --no-dev --optimize --ignore-platform-reqs

# ==========================================
# Étape 2 : Optimisation & Caching (optimizer)
# ==========================================
FROM php:8.2-cli-bookworm AS optimizer
RUN apt-get update && apt-get install -y --no-install-recommends \
    libicu-dev libsqlite3-dev libzip-dev libpq-dev unzip \
    && docker-php-ext-install pdo_sqlite pdo_mysql pdo_pgsql intl \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /var/www/html
COPY --from=deps /var/www/html /var/www/html
COPY --from=deps /var/services-laravel/shared-security /var/services-laravel/shared-security

RUN mkdir -p storage/framework/views storage/framework/cache storage/framework/sessions bootstrap/cache
ENV APP_ENV=production DB_CONNECTION=sqlite DB_DATABASE=:memory:
RUN php artisan config:cache && php artisan route:cache && php artisan view:cache

# ==========================================
# Étape 3 : Runtime Production Distroless (Sans Shell / Non-Root 10001)
# ==========================================
FROM gcr.io/distroless/php-debian12:8.2 AS runtime
WORKDIR /var/www/html

# Copie uniquement les artefacts compilés avec l'utilisateur non-root 10001
COPY --chown=10001:10001 --from=optimizer /var/www/html/app ./app
COPY --chown=10001:10001 --from=optimizer /var/www/html/bootstrap ./bootstrap
COPY --chown=10001:10001 --from=optimizer /var/www/html/config ./config
COPY --chown=10001:10001 --from=optimizer /var/www/html/database ./database
COPY --chown=10001:10001 --from=optimizer /var/www/html/public ./public
COPY --chown=10001:10001 --from=optimizer /var/www/html/resources ./resources
COPY --chown=10001:10001 --from=optimizer /var/www/html/routes ./routes
COPY --chown=10001:10001 --from=optimizer /var/www/html/vendor ./vendor
COPY --chown=10001:10001 --from=optimizer /var/www/html/artisan ./artisan
COPY --chown=10001:10001 --from=optimizer /var/services-laravel/shared-security /var/services-laravel/shared-security

ENV SECURERAG_RUNTIME_ROOT=/tmp/securerag-runtime \
    DB_DATABASE=/tmp/securerag-runtime/database/database.sqlite \
    LARAVEL_STORAGE_PATH=/tmp/securerag-runtime/storage

EXPOSE 9000
USER 10001:10001
ENTRYPOINT ["/usr/sbin/php-fpm8.2", "-F"]
```

---

## 4. Couche de Sécurité & Observabilité IA / LLM Stack

L'interaction avec les modèles de langage (LLM) et le système RAG fait l'objet d'une protection multicouche dédiée pour contrer les risques spécifiques de l'**OWASP Top 10 for LLM Applications**.

```mermaid
graph LR
    USER[Requête Utilisateur] --> LITELLM[LiteLLM Gateway<br/>• Router & Load Balancer<br/>• Rate Limiting & Cost Control]
    LITELLM --> NEMO[NeMo Guardrails<br/>• Input Rails: Prompt Injection<br/>• Output Rails: Fuite PII / Modération]
    NEMO --> GARAK[Garak Red Teaming<br/>• Scan Dynamique Fuzzing<br/>• Détection Jailbreak / Hallucination]
    NEMO --> CHATBOT[chatbot-manager-service]
    CHATBOT --> LANGFUSE[Langfuse Observability<br/>• Tracing Sémantique RAG<br/>• Prompt Metrics & Latence]

    classDef ai fill:#0284c7,stroke:#38bdf8,color:#fff;
    class LITELLM,NEMO,GARAK,CHATBOT,LANGFUSE ai;
```

### Composants de la Couche IA & Modèles

1. **LiteLLM Gateway** : Proxy unifié qui orchestre l'accès aux LLMs (Ollama local ou providers). Il gère le basculement automatique (*failover*), la répartition de charge, le contrôle des quotas et le rate-limiting.
2. **NeMo Guardrails (NVIDIA)** : Moteur de garde programmable qui filtre les entrées (*Input Rails*) pour intercepter les tentatives de prompt-injection et les sorties (*Output Rails*) pour empêcher la divulgation de données PII ou d'informations système confidentielles.
3. **Garak (LLM Vulnerability Scanner)** : Outil de Red Teaming automatisé qui soumet dynamiquement des sondes (*probes*) de fuzzing pour tester la résistance du modèle contre le jailbreak et les attaques adverses.
4. **Langfuse** : Solution d'observabilité LLM open-source assurant le tracing complet des requêtes RAG, le suivi précis de la consommation de tokens et le calcul du coût par utilisateur.

---

## 5. Architecture du Cluster, Identity & Remédiation Automatique

### Identité de Charge de Travail (SPIFFE / SPIRE)
- **SPIFFE/SPIRE** assure l'attestation cryptographique dynamique de chaque Pod sur Kubernetes.
- Il émet des certificats **X.509 SVID** (*SPIFFE Verifiable Identity Document*) à courte durée de vie, permettant une authentification mutuelle mTLS Zero Trust native entre microservices sans aucune clé statique stockée.

### Remédiation Automatique en Temps Réel (Falco Talon)
En complément de la détection d'intrusions par **Falco eBPF**, **Falco Talon** fait office de moteur de réponse automatisée en mode No-code/Low-code :
- **Attaque détectée par Falco** : Exécution d'un binaire suspect ou tentative de modification de binaire système.
- **Réaction automatique de Falco Talon** :
  1. *Eviction du Pod compromis* (`action: terminate_pod`).
  2. *Isolation réseau immédiate via NetworkPolicy* (`action: quarantine_network`).
  3. *Notification d'incident haute priorité* vers Slack / PagerDuty.

```mermaid
graph TB
    subgraph K8sCluster["Cluster Kubernetes (PSS Restricted)"]
        POD[Pod Applicatif Compromis]
        FALCO[Agent Falco eBPF<br/>Détection Appel Système Suspect]
        TALON[Moteur Falco Talon<br/>Réponse Automatisée]
        NETPOL[NetworkPolicy Isolement]
    end

    POD -->|Système Suspect| FALCO
    FALCO -->|Alerte gRPC| TALON
    TALON -->|1. Kill / Terminate Pod| POD
    TALON -->|2. Applique Isolement| NETPOL
```

---

## 6. Cadre de Tests & Quality Gate Consolidée

### Matrice du Quality Gate

```mermaid
graph TD
    subgraph Inputs["Résultats des Scans & Tests"]
        IN_TEST["Tests Unitaires PHPUnit"]
        IN_COV["Couverture de Code"]
        IN_SAST["Scan SAST Semgrep"]
        IN_SEC["Scan Secrets Gitleaks"]
        IN_CVE["Scan CVE Grype/Trivy"]
        IN_K6["Tests de Charge k6"]
    end

    subgraph Thresholds["Seuils d'Acceptation"]
        IN_TEST -->|0 Echecs| GATE{Quality Gate<br/>Consolidée}
        IN_COV -->|>= 70%| GATE
        IN_SAST -->|0 High/Error| GATE
        IN_SEC -->|0 Secret Leaks| GATE
        IN_CVE -->|0 High/Critical| GATE
        IN_K6 -->|p95 < 500ms & Error < 1%| GATE
    end

    GATE -->|CONFORME| PASS["✅ PASS: Release Approuvée"]
    GATE -->|NON CONFORME| FAIL["❌ FAIL: Release Rejetée"]

    classDef pass fill:#065f46,stroke:#10b981,color:#fff;
    classDef fail fill:#991b1b,stroke:#f87171,color:#fff;
    classDef gate fill:#1e3a8a,stroke:#3b82f6,color:#fff;

    class PASS pass;
    class FAIL fail;
    class GATE gate;
```

---

## 7. Synthèse des Fichiers de Référence

- **ADR Images Distroless** : [`docs/ARCHITECTURE-DECISION-RECORDS/ADR-001-distroless-images.md`](file:///root/MasterPFE/docs/ARCHITECTURE-DECISION-RECORDS/ADR-001-distroless-images.md)
- **Dockerfile Distroless Officiel** : [`docker/portal-web/Dockerfile`](file:///root/MasterPFE/docker/portal-web/Dockerfile)
- **Pipeline CI principal** : [`Jenkinsfile`](file:///root/MasterPFE/Jenkinsfile)
- **Script Quality Gate** : [`scripts/ci/quality-gate.sh`](file:///root/MasterPFE/scripts/ci/quality-gate.sh)
- **Document d'Architecture Globale** : [`docs/architecture.md`](file:///root/MasterPFE/docs/architecture.md)
