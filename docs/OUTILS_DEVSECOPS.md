# Cartographie des Outils de la Chaîne DevSecOps - SecureRAG Hub

*Dernière mise à jour : 21 Juillet 2026*

Ce document recense l'ensemble des outils, technologies et agents intégrés dans la chaîne **DevSecOps** du projet **SecureRAG Hub**, classés par phase du cycle de vie logiciel (SDLC).

---

## 1. Intégration & Déploiement Continus (CI/CD & GitOps)
* **Jenkins** : Moteur d'automatisation CI/CD principal (`Jenkinsfile`, `Jenkinsfile.cd`, `Jenkinsfile.recette`, `Jenkinsfile.ai`).
* **ArgoCD** : Déploiement continu automatisé basé sur l'approche **GitOps** (`infra/k8s/argocd/`).
* **Docker Compose** : Orchestration locale des services de développement et de CI.

---

## 2. Construction d'Images & Gestion des Registres
* **Docker / Docker Engine** : Moteur de conteneurisation de référence.
* **Kaniko** : Constructeur d'images conteneurs s'exécutant en mode non-privilégié au sein du cluster Kubernetes (respect PSS Restricted / SOC2).
* **Buildah** : Outil alternatif de construction d'images sans démon Docker.
* **Harbor / Private OCI Registry** : Registre privé d'images conteneurs sécurisé avec balayage des vulnérabilités.

---

## 3. Infrastructure & Orchestration Kubernetes
* **Kind (Kubernetes in Docker)** : Cluster Kubernetes local pour les environnements de développement et de recette.
* **Kubernetes (K8s)** : Orchestrateur de conteneurs (gestion des namespaces, RBAC, NetworkPolicies, PSA/PSS).
* **Helm** : Gestionnaire de paquets Kubernetes pour le déploiement des chartes applicatives.
* **Kustomize** : Outil de personnalisation et de superposition des manifests Kubernetes sans templates.
* **Terraform** : Provisionnement d'infrastructure sous forme de code (IaC).
* **Ansible** : Gestion de configuration et automatisation de l'infrastructure serveur.

---

## 4. Sécurité du Code & Analyse Statique (SAST / SCA / Secrets)
* **Semgrep** : Analyseur statique de sécurité du code (SAST) pour détecter les vulnérabilités applicatives (SQLi, XSS, RCE).
* **Gitleaks & TruffleHog v3** : Détection de secrets en amont et vérification active (*live verification*) des jetons d'API (OpenAI, AWS, GitHub).
* **OWASP Dependency-Check & Renovate** : Analyse de la composition logicielle (SCA) et automatisation des mises à jour de sécurité des dépendances.
* **SonarQube** : Plateforme d'analyse de la qualité du code, de la dette technique et des portes de qualité (Quality Gates).
* **Checkov** : Analyseur de sécurité et de conformité IaC pour Terraform, Helm et manifests Kubernetes.

---

## 5. Sécurité des Conteneurs & de la Chaîne d'Approvisionnement (Supply Chain)
* **Trivy & Grype** : Détecteurs de vulnérabilités pour les images conteneurs, les systèmes de fichiers et les configurations IaC.
* **EPSS & OpenVEX Filter (`epss_vulnerability_filter.py`)** : Filtrage et priorisation dynamique des vulnérabilités basés sur le score d'exploitabilité EPSS et attestations OpenVEX.
* **Syft** : Générateur de nomenclature logicielle (SBOM - Software Bill of Materials) aux formats SPDX et CycloneDX.
* **Cosign (Sigstore)** : Signature et vérification cryptographique des images conteneurs (signature keyless et clés K8s).
* **SLSA Provenance** : Générateur d'attestations de provenance selon le standard SLSA (Supply-chain Levels for Software Artifacts).
* **Rekor / CTLog** : Registre de transparence pour la traçabilité des signatures Sigstore.

---

## 6. Gouvernance Kubernetes & Gestion des Secrets
* **Kyverno** : Moteur de politiques de sécurité Kubernetes (politiques d'admission, vérification de signature Cosign, enforcement PSS).
* **Pod Security Admission (PSA / PSS)** : Enforcing des standards de sécurité des Pods (niveaux *Restricted* et *Baseline*).
* **HashiCorp Vault** : Gestionnaire centralisé des secrets, certificats et clés de chiffrement.
* **External Secrets Operator (ESO)** : Synchronisation automatique des secrets Vault vers les secrets Kubernetes.
* **Cert-Manager** : Gestion automatique du cycle de vie des certificats TLS/SSL dans Kubernetes.

---

## 7. Sécurité au Temps d'Exécution (Runtime) & Observabilité LLM
* **Falco & Falco Talon** : Moteur de détection d'anomalies noyau et module de remédiation automatique au runtime (suppression de Pods compromis).
* **Tetragon** : Outil de sécurité et d'observabilité runtime basé sur eBPF.
* **Istio Service Mesh & Argo Rollouts** : Maillage de services (mTLS strict) et livraisons progressives Canary avec rollback automatique.
* **Prometheus & Grafana** : Collecte des métriques de sécurité/performance et visualisation via des tableaux de bord.
* **OpenTelemetry (OTel) & Langfuse** : Télémétrie distribuée et observabilité native LLM/RAG (tracing de contexte, latence et hallucinations).

---

## 8. Layer IA Native & Security Guardrails
* **LiteLLM Gateway + NeMo Guardrails** : Passerelle de sécurité IA pour l'anonymisation PII et le blocage des injections de prompt en temps réel.
* **Garak (NVIDIA LLM Red Teaming)** : Fuzzer et scanner de vulnérabilités dynamiques ciblant les prompts et interfaces LLM en CI/CD.
* **Secure Coding Agent (`secure_coding_agent.py`)** : Agent IA d'analyse sémantique du code par AST et détection de secrets.
* **Deployment Intelligence Agent (`deployment_intelligence_agent.py`)** : Agent IA d'audit des configurations Kubernetes et calcul du score de risque.
* **AI Testing Agent (`ai_testing_agent.py`)** : Agent IA de fuzzing dynamique (DAST) et d'injection de payloads.
* **AI Operations Agent (`ai_operations_agent.py`)** : Agent IA de corrélation des événements de menaces (Tetragon/Falco/Istio).
* **Build Intelligence Agent (`build_intelligence_agent.py`)** : Agent IA de corrélation des rapports multi-scanners (Trivy, Semgrep, Gitleaks).
* **AI Security Council / Consensus Engine** : Moteur de décision et d'évaluation globale des risques pour la validation des déploiements.

---

## 9. Tests de Performance & Qualité
* **k6 (Grafana k6)** : Outil de tests de charge et de performance dynamique.
* **PHPUnit / Pest** : Cadre de tests unitaires et d'intégration pour les services Laravel.
* **Pytest** : Cadre de tests automatisés pour les scripts et services Python.
* **Flake8** : Linter de conformité du code Python.

---

## Synthèse par Phase du SDLC

| Phase SDLC | Outils Principaux |
| :--- | :--- |
| **Code & Build** | Semgrep, Gitleaks, OWASP Dependency-Check, SonarQube, Flake8, PHPUnit, Secure Coding Agent |
| **Package & Registry** | Docker, Kaniko, Harbor, Trivy, Grype, Syft (SBOM), Cosign (Sigstore), Build Intelligence Agent |
| **Infrastructure & IaC** | Terraform, Ansible, Helm, Kustomize, Checkov |
| **Deploy & GitOps** | Jenkins, ArgoCD, Kind, Kyverno, Cert-Manager, Vault, ESO, Deployment Intelligence Agent |
| **Run & Protect** | Istio, Falco, Tetragon, Prometheus, Grafana, OpenTelemetry, AI Operations Agent, k6 |
