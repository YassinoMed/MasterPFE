# Matrice de Conformité de Sécurité — SecureRAG Hub

Ce document synthétise la conformité de SecureRAG Hub par rapport aux trois référentiels majeurs visés par l'architecture DevSecOps : **SLSA Level 3**, **Pod Security Standards (PSS) Restricted**, et **ISO 27001:2022**.

---

## 1. Conformité SLSA (Supply chain Levels for Software Artifacts) — Level 3

La conformité SLSA 3 garantit l'intégrité des builds contre les altérations de la chaîne d'approvisionnement en imposant des builds automatisés et isolés avec génération de provenance signée et infalsifiable.

| Exigence SLSA v1.0 | Contrôle Implémenté dans SecureRAG Hub | Fichier(s) de Configuration Associé(s) | Statut |
| :--- | :--- | :--- | :--- |
| **Scripted Build** (Build scripté) | Toutes les étapes de construction d'images Docker, de test et de signature sont définies sous forme de pipelines Jenkins. | [Jenkinsfile](file:///root/MasterPFE/Jenkinsfile), [Jenkinsfile.recette](file:///root/MasterPFE/Jenkinsfile.recette), [Jenkinsfile.cd](file:///root/MasterPFE/Jenkinsfile.cd) | ✅ Implémenté |
| **Build Service** (Service de Build) | Les builds sont exécutés de façon centralisée par une plateforme d'intégration continue orchestrée. | [Jenkinsfile](file:///root/MasterPFE/Jenkinsfile) | ✅ Implémenté |
| **Isolated Build Env** (Environnement de build isolé) | Chaque exécution de build tourne dans un Pod Kubernetes éphémère dédié contenant les outils requis. | Spécification de l'agent K8s dans `Jenkinsfile` | ✅ Implémenté |
| **Parameterless Build** (Build sans paramètre influent) | Les pipelines de production s'exécutent de façon non interactive en s'appuyant uniquement sur les sources Git. | Déclencheurs Webhook de Jenkins | ✅ Implémenté |
| **Hermetic Build** (Build hermétique) | Exclusion de téléchargements non vérifiés pendant le build. Les images de base utilisent des digests figés. Cependant, certains packages Python/NPM sont encore résolus dynamiquement à l'externe sans proxy local. | [renovate.json](file:///root/MasterPFE/renovate.json), Dockerfiles | 🔄 En cours |
| **Provenance Generation** (Génération de provenance) | Génération automatique d'attestations in-toto et SLSA détaillant les sources et les étapes de build. | [sign-images.sh](file:///root/MasterPFE/scripts/release/sign-images.sh) | ✅ Implémenté |
| **Non-falsifiable Provenance** (Provenance infalsifiable) | Signature cryptographique des images et de la provenance via Sigstore Cosign (intégration keyless OIDC via Keycloak/Fulcio/Rekor). | [sign-images.sh](file:///root/MasterPFE/scripts/release/sign-images.sh), [verify-image-signatures.yaml](file:///root/MasterPFE/k8s/kyverno-policies/verify-image-signature-keyless.yaml) | ✅ Implémenté |

---

## 2. Conformité PSS (Pod Security Standards) — Profil Restricted

Le profil `Restricted` de Kubernetes impose des restrictions très strictes sur le durcissement des conteneurs pour prévenir l'élévation de privilèges et l'évasion de conteneur.

| Contrainte PSS Restricted | Implémentation / Politique Kyverno | Fichier(s) de Configuration Concerné(s) | Statut |
| :--- | :--- | :--- | :--- |
| **No Privileged Containers** (Pas de conteneur privilégié) | Interdiction de la directive `privileged: true` via Kyverno. | [06-no-privileged-containers-enforce.yaml](file:///root/MasterPFE/k8s/kyverno-policies/enforce/06-no-privileged-containers-enforce.yaml) | ✅ Implémenté |
| **Host Namespaces** (Pas de partage d'espace hôte) | Interdiction de `hostNetwork`, `hostPID` et `hostIPC`. | Appliqué globalement via le profil restricted. | ✅ Implémenté |
| **Host Ports** (Pas d'utilisation de ports de l'hôte) | Interdiction de mapper des conteneurs directement sur les ports physiques de l'hôte (`hostPort`). | Kyverno bloquant l'usage de `hostPort`. | ✅ Implémenté |
| **Volume Types** (Types de volumes autorisés) | Interdiction de `hostPath`. Seuls les volumes de type `configMap`, `secret`, `emptyDir` et `persistentVolumeClaim` sont autorisés. | Kyverno restriction de volumes. | ✅ Implémenté |
| **Capabilities** (Gestion des capacités Linux) | Obligation de déclarer `capabilities.drop: ["ALL"]` pour tous les conteneurs. | [05-restrict-capabilities-enforce.yaml](file:///root/MasterPFE/k8s/kyverno-policies/enforce/05-restrict-capabilities-enforce.yaml) | ✅ Implémenté |
| **Run as Non-Root** (Exécution non-root) | Les conteneurs doivent obligatoirement déclarer `runAsNonRoot: true` et `runAsUser >= 1000`. | [01-no-root-containers-enforce.yaml](file:///root/MasterPFE/k8s/kyverno-policies/enforce/01-no-root-containers-enforce.yaml) et Dockerfiles | ✅ Implémenté |
| **ReadOnly Root Filesystem** (Système de fichiers en lecture seule) | Obligation d'activer `readOnlyRootFilesystem: true`. Les zones d'écriture temporaires doivent utiliser des volumes éphémères `emptyDir`. | Configuration `securityContext` des microservices dans [deployments](file:///root/MasterPFE/k8s/deployments/) et [base infra](file:///root/MasterPFE/infra/k8s/base/) | ✅ Implémenté |
| **Privilege Escalation** (Escalade de privilèges) | La directive `allowPrivilegeEscalation` doit être explicitement définie à `false`. | Intégré dans tous les manifests de déploiement d'application. | ✅ Implémenté |
| **Seccomp Profile** (Profil de sécurité Seccomp) | Obligation de spécifier un profil Seccomp, de préférence `RuntimeDefault`. | Déclaré dans `securityContext.seccompProfile.type` de tous les manifests de déploiement. | ✅ Implémenté |

---

## 3. Mappage de Conformité ISO 27001:2022

Mappage des contrôles de la norme internationale de sécurité des informations ISO/CEI 27001 aux pratiques de sécurité opérationnelle et d'ingénierie DevSecOps appliquées sur SecureRAG Hub.

| Code Contrôle | Titre du Contrôle ISO 27001 | Description de l'Implémentation DevSecOps | Preuves et Fichiers de Configuration |
| :--- | :--- | :--- | :--- |
| **A.5.15** | Contrôle des accès | Politique d'accès basée sur le rôle (RBAC) au niveau applicatif (Laravel Gate, JWT) et au niveau Kubernetes (ServiceAccounts, rôles restreints). Le chatbot n'accède qu'aux vecteurs autorisés. | RAG RBAC filter dans [qdrant_manager.py](file:///root/MasterPFE/embeding/services/knowledge-hub/app/vectorstore/qdrant_manager.py), [rbac-runtime-readonly.yaml](file:///root/MasterPFE/infra/k8s/base/rbac-runtime-readonly.yaml) |
| **A.8.12** | Prévention des fuites de données | Intégration de scans de secrets en pré-commit et dans le pipeline de build (Gitleaks) pour éviter l'exposition d'identifiants de base de données ou de clés API. | [.gitleaks.toml](file:///root/MasterPFE/.gitleaks.toml), [Jenkinsfile](file:///root/MasterPFE/Jenkinsfile) |
| **A.8.16** | Surveillance, archivage et audit | Déploiement de Falco pour la détection d'intrusion à chaud (ex: exécution de shell, montage suspect). Collecte centralisée et append-only des journaux système et d'application vers Loki. | [falcosidekick-deployment.yaml](file:///root/MasterPFE/k8s/deployments/falcosidekick-deployment.yaml), [loki-deployment.yaml](file:///root/MasterPFE/infra/k8s/observability/loki-deployment.yaml) |
| **A.8.20** | Sécurité des réseaux | Isolation stricte des microservices via NetworkPolicies K8s. Par défaut, tout trafic est interdit (`default-deny-all`), et seules les liaisons fonctionnelles minimales sont déclarées. Les bases vectorielles sont isolées de l'extérieur. | [network-policies](file:///root/MasterPFE/k8s/network-policies/), [10-chromadb-restricted-policy.yaml](file:///root/MasterPFE/k8s/network-policies/10-chromadb-restricted-policy.yaml) |
| **A.8.24** | Utilisation de la cryptographie | Gestion sécurisée des secrets dans HashiCorp Vault. Signature numérique des images avec Cosign. Chiffrement des sauvegardes PostgreSQL avec clés gérées (Restic). | [sign-images.sh](file:///root/MasterPFE/scripts/release/sign-images.sh), [postgres-backup-cronjob.yaml](file:///root/MasterPFE/infra/k8s/base/postgres-auth/postgres-backup-cronjob.yaml) |
| **A.8.25** | Cycle de développement sécurisé | Automatisation complète des contrôles de sécurité (SAST avec SonarQube, SCA et conteneurs avec Trivy, DAST avec OWASP ZAP) intégrés dans les pipelines Jenkins. | [Jenkinsfile](file:///root/MasterPFE/Jenkinsfile), [Jenkinsfile.recette](file:///root/MasterPFE/Jenkinsfile.recette) |
| **A.8.28** | Codage sécurisé | Validation systématique des requêtes Laravel (Form Requests) contre les injections SQL, et filtrage des entrées/sorties contre les injections de prompts et fuite de secrets. | Validation des formulaires Laravel dans [services-laravel/](file:///root/MasterPFE/services-laravel/), filtre de prompt dans [audit-security-service](file:///root/MasterPFE/infra/k8s/base/audit-security-service/) |
| **A.8.30** | Cycle de vie des logiciels externalisés | Gestion continue des dépendances logicielles et correctifs de sécurité via Renovate, alertant l'équipe sur les vulnérabilités de bibliothèques tierces. | [renovate.json](file:///root/MasterPFE/renovate.json) |

---

> [!NOTE]
> Cette matrice est mise à jour de manière continue à chaque modification majeure des pipelines CI/CD ou des politiques de sécurité d'admission.
