# Phase 3 — CI/CD Pipeline Analysis

Ce document présente l'évaluation technique approfondie des pipelines d'intégration et de déploiement continus (CI/CD) du projet **SecureRAG Hub**.

---

## 1. Cartographie des Pipelines CI/CD

### 1.1 Jenkins (Moteur de référence)
Jenkins est configuré en mode **Configuration as Code (CasC)** (`infra/jenkins/casc/jenkins.yaml`) et gère les pipelines suivants :
*   **Pipeline CI** (`Jenkinsfile`) : Se déclenche sur commit/PR. Orchestre 15 étapes séquentielles : Lint, Tests PHP, SAST Semgrep, Gitleaks, Trivy FS, Hadolint Docker, SonarQube.
*   **Pipeline CD** (`Jenkinsfile.cd`) : Se déclenche après la CI. Valide les signatures Cosign, promeut les images par Digest cryptographique, génère les SBOMs Syft, déploie sur le cluster local (Kind) via Kustomize et valide l'intégrité post-déploiement.
*   **Pipeline Recette** (`Jenkinsfile.recette`) : Exécute des tests de vulnérabilités dynamiques (DAST OWASP ZAP) en staging.

### 1.2 GitHub Actions (Périmètre Legacy / Inactif)
Les workflows dans `.github/workflows/` (`ci-pr.yml`, `build-sign.yml`) sont conservés mais marqués comme dépréciés. Ils ne participent pas à la chaîne de livraison officielle du projet et doivent être lancés manuellement.

### 1.3 GitLab CI
Aucune configuration GitLab CI n'est présente dans le dépôt.

---

## 2. Évaluation des Performance et Mécanismes d'Optimisation

### 2.1 Temps de Build (Build Times)
*   **Temps moyen du pipeline CI** : ~12-15 minutes.
*   **Goulot d'étranglement principal** : Le pipeline est entièrement séquentiel. De nombreux outils de sécurité scannent le même système de fichiers les uns après les autres.

### 2.2 Parallélisation
*   **Score : 0/10** — Actuellement, aucune étape de `Jenkinsfile` ou `Jenkinsfile.cd` n'utilise la directive `parallel` de Jenkins Declarative Pipeline.
*   **Opportunité** : Les étapes `Static Code Analysis` (Semgrep SAST, Gitleaks, Trivy FS) pourraient s'exécuter en parallèle sur plusieurs agents Jenkins pour réduire le temps de build global de 40%.

### 2.3 Cache et Dépendances
*   **Score : 2/10** — Absence de cache persistant pour les répertoires `vendor/` (Composer) et `node_modules/` (npm) entre les exécutions de conteneurs de build.
*   **Impact** : Chaque exécution du pipeline télécharge l'intégralité des dépendances depuis internet, augmentant inutilement la latence du pipeline et la dépendance au réseau externe.

### 2.4 Optimisation Docker
*   **hadolint** : Actif et bloquant, garantissant l'utilisation de bonnes pratiques d'écriture de Dockerfile (ex. nettoyage du cache apt, utilisation d'images de base minimales).
*   **Multi-stage builds** : Utilisés pour la construction des conteneurs applicatifs Laravel et Python, garantissant que les dépendances de développement (DevDependencies) ne sont pas embarquées en production.

---

## 3. Stratégies de Déploiement et de Validation

### 3.1 Rollback, Canary & Blue-Green
*   **Rollback** : Kubernetes gère les rollbacks de base sur échec de probe. Cependant, le pipeline Jenkins ne dispose pas d'un système de rollback automatisé en cas d'échec des smoke tests ou des tests de sécurité post-déploiement.
*   **Canary & Blue-Green** : Des stratégies Argo Rollouts sont préparées (`infra/k8s/strategies/blue-green-canary.yaml` et `infra/k8s/argo-rollouts/canary-strategy.yaml`), mais elles ne sont pas interfacées de manière dynamique avec les routes de production Kong/API Gateway pour de l'envoi progressif de trafic basé sur des métriques de succès.

### 3.2 Quality Gates
Les barrières de qualité sont nombreuses et robustes :
1.  **Tests unitaires** : Doivent tous réussir.
2.  **Couverture** : `COVERAGE_MIN=85` (Bloquant si < 85%).
3.  **Secrets** : Gitleaks ne tolère aucun leak détecté (mais attention : Gitleaks en CI n'utilise pas `--exit-code 1`, ce qui est une vulnérabilité de configuration).
4.  **SAST** : Semgrep configuré en mode strict.
5.  **IaC** : Checkov configuré avec `--hard-fail-on CRITICAL`.
6.  **K8s Lint** : `kube-score` configuré en mode strict.
7.  **DAST** : ZAP en recette avec `maxHigh=0` et `maxCritical=0`.

---

## 4. Identification des Incohérences et Duplications

*   **Composants orphelins (Dead Code) :**
    *   `[scripts/ci/quality-gate.sh](file:///root/MasterPFE/scripts/ci/quality-gate.sh)` : Legacy quality gate script. Remplacé par `secure-quality-gate.sh` mais toujours présent dans le repo.
    *   `[vars/checkovScan.groovy](file:///root/MasterPFE/vars/checkovScan.groovy)` : Shared library inutilisée, Checkov étant invoqué directement par le Jenkinsfile en ligne de commande.
    *   `.github/workflows/ci-pr.yml` & `build-sign.yml` : Workflows obsolètes introduisant de la confusion dans la gouvernance Git.
*   **Incohérence Gitleaks** :
    *   `Jenkinsfile:128` : La commande Gitleaks n'a pas l'option `--exit-code 1`. En cas de secret détecté, le rapport JSON est écrit, mais le stage Jenkins ne fail pas immédiatement, s'appuyant uniquement sur le script de gate final.

---

## 5. Scoreboard CI/CD

### Note Globale : 85/100

| Critère | Note | Justification |
| :--- | :--- | :--- |
| **Couverture des Scans** | 98/100 | Une des forces majeures du projet. Intègre l'ensemble de la pyramide DevSecOps (SAST, SCA, IaC, Lint, DAST). |
| **Robustesse des Quality Gates** | 90/100 | La quasi-totalité des barrières de sécurité sont bloquantes. Quelques correctifs mineurs requis (Gitleaks exit code, smoke tests recette non-bloquants). |
| **Performance & Parallélisation** | 40/100 | Pipeline entièrement séquentiel. Téléchargement répété des dépendances (pas de cache). |
| **Gouvernance & Nettoyage** | 70/100 | Présence de plusieurs scripts et workflows obsolètes ou doublons (quality-gate.sh, checkovScan.groovy). |
