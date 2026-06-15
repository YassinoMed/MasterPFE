# Rapport d'Évaluation Complète DevSecOps — SecureRAG Hub

Ce document rassemble et synthétise l'ensemble des évaluations de sécurité, des audits de conformité, et de l'état d'avancement des contrôles DevSecOps sur la plateforme **SecureRAG Hub**. 

---

## 1. Synthèse Globale des Statuts

| Domaine d'Évaluation | Statut de Conformité | Mécanisme de Contrôle | Fichier(s) de Preuve |
| :--- | :---: | :--- | :--- |
| **A. Shift-Left & CI** | ✅ TERMINÉ | Scan statique de code, secrets et IaC | Reports `security/reports/*` |
| **B. Supply Chain Integrity** | ✅ TERMINÉ | Signatures Cosign, SBOM Syft, digest pinning | [supply-chain-evidence.md](../artifacts/release/supply-chain-evidence.md) |
| **C. Admission Control** | ✅ TERMINÉ | Kyverno (mode Audit & Enforce) | [kyverno-runtime-report.md](../artifacts/validation/kyverno-runtime-report.md) |
| **D. Network Segmentation** | ✅ TERMINÉ | Isolation par NetworkPolicies (Default Deny) | [10-chromadb-restricted-policy.yaml](../k8s/network-policies/10-chromadb-restricted-policy.yaml) |
| **E. Runtime Hardening** | ✅ TERMINÉ | PSS Restricted, drop capabilities, RO rootfs | [runtime-security-postdeploy.md](../artifacts/security/runtime-security-postdeploy.md) |
| **F. Secrets Lifecycle** | ✅ TERMINÉ | Chiffrement SOPS/age + configuration Vault | [secrets-management-hardening.md](security/secrets-management-hardening.md) |
| **G. SRE & Resilience** | ✅ TERMINÉ | CronJob de backup, drills de restauration | [postgres-backup-restore-cycle.md](../artifacts/backup/postgres-backup-restore-cycle.md) |
| **H. Runtime Auditing** | ✅ TERMINÉ | Détection d'intrusions système par Falco | [falco-runtime-proof.md](../artifacts/security/falco-runtime-proof.md) |

---

## 2. Résultats des Analyses Statiques & CI (Pipelines)

Voici l'état consolidé des barrières de sécurité automatiques déclenchées lors de la phase d'intégration continue (Jenkins CI) :

*   **Tests Applicatifs (Laravel/FastAPI)** : Couverture globale moyenne supérieure à **74%**, validant les Form Requests et le comportement des middlewares de sécurité.
*   **SAST (Semgrep)** : **0 vulnérabilité critique/haute** tolérée. Le Quality Gate Jenkins interrompt le build en cas de non-respect.
*   **Secrets Scan (Gitleaks)** : **0 secret détecté** dans l'historique des branches actives. Scan bloquant intégré en pré-commit et en CI.
*   **SCA & Vulnerability Scan (Trivy FS)** : Analyse systématique des dépendances (`composer.lock` et `requirements.txt`). Les alertes de sévérité critique sont patchées ou font l'objet d'exceptions justifiées (ex: dépendances système non exploitables en production).

---

## 3. Matrice de Fermeture DevSecOps (Ferme-Porte)

Cette table cartographie l'état d'exécution et de validation des 12 points de contrôle prioritaires requis pour la livraison en production :

| Bloc | Point de Contrôle | Verdict / Statut | Action de Vérification Réalisée |
| :--- | :--- | :---: | :--- |
| **Bloc A** | Preuve runtime imageID / digest | ✅ TERMINÉ | Vérification que les pods actifs consomment des images identifiées par leur digest immuable (`@sha256:hash`). |
| **Bloc A** | Logs, events et healthchecks | ✅ TERMINÉ | Surveillance active de la connectivité réseau du portail web Laravel vers les microservices. |
| **Bloc A** | HPA runtime (Scalability) | ✅ TERMINÉ | Validation du comportement de l'Horizontal Pod Autoscaler sans valeur inconnue (`<unknown>`). |
| **Bloc B** | Hardening workloads | ✅ TERMINÉ | Validation statique du durcissement des conteneurs via `audit-pod-security.sh`. |
| **Bloc C** | Supply chain complète | ✅ TERMINÉ | Génération d'attestations SBOM CycloneDX et signature cryptographique via Cosign. |
| **Bloc C** | Déploiement digest immuable | ✅ TERMINÉ | Déploiement en production utilisant exclusivement les digests d'images promus. |
| **Bloc C** | Provenance SLSA-style | ✅ TERMINÉ | Génération d'un enregistrement d'attestation de build non falsifiable. |
| **Bloc D** | Kyverno PolicyReports runtime | ✅ TERMINÉ | Collecte des rapports de politiques Kubernetes montrant une conformité à 100%. |
| **Bloc E** | PostgreSQL externe / Secret DB | ✅ TERMINÉ | Chiffrement et injection sécurisée des secrets d'accès à la base de données. |
| **Bloc E** | Backup / restore postgres | ✅ TERMINÉ | Simulation d'une restauration de données PostgreSQL dans un namespace isolé à partir d'une sauvegarde restic chiffrée. |
| **Bloc F** | Secrets management moderne | ✅ TERMINÉ | Isolement des secrets au repos et non-exposition dans les logs d'exécution ou les manifests GitOps. |
| **Bloc F** | Jenkins webhook / SCM proof | ✅ TERMINÉ | Webhook fonctionnel déclenchant automatiquement le pipeline Jenkins au push de commit. |

---

## 4. Durcissement Runtime et Admission (Kyverno & PSS)

La conformité aux Kubernetes Pod Security Standards (PSS) au profil **Restricted** a été validée via les mécanismes d'admission control (Kyverno) configurés en mode **Enforce** :

1.  **Exécution Non-Root** : Tous les microservices de production s'exécutent sous l'UID `10001` (`runAsNonRoot: true`). Aucun privilège super-utilisateur n'est consenti.
2.  **Système de fichiers en lecture seule** : La directive `readOnlyRootFilesystem: true` est en vigueur pour tous les conteneurs applicatifs. Les répertoires de stockage éphémère nécessaires (ex: `/tmp`, `/var/run`) sont montés sous forme de volumes virtuels `emptyDir` isolés en mémoire.
3.  **Restriction des Capabilities** : Suppression complète des capacités du noyau Linux via `capabilities.drop: ["ALL"]`.
4.  **NetworkPolicies** : Isolation hermétique des bases vectorielles (ChromaDB et Qdrant). L'ingress de ChromaDB est configuré pour n'accepter que les paquets en provenance directe du pod `chatbot-manager`.

---

## 5. Limites Honnêtes (Honest Limits)

*   **Runtime Python/RAG** : Dans le scénario de démonstration officiel, le scope cible en priorité le runtime durci basé sur les workloads Laravel. Le déploiement de la stack RAG Python reste optionnel et requiert la présence d'images de modèle pré-compilées compatibles localement.
*   **Infrastructure Local (Kind)** : Les tests de haute disponibilité (HA) et d'élasticité ont été émulés localement sur Kind. Dans un environnement de cloud public, les `StorageClass` et les LoadBalancers réseau s'appuieront sur les services managés natifs du Cloud Provider (AWS EKS, GCP GKE) via l'API standard de Kubernetes.
*   **Falco Host Access** : L'agent de détection système Falco nécessite un profil de sécurité Kubernetes assoupli (`privileged`) sur le namespace système `falco` pour capturer les appels système de l'hôte (syscalls). Cette exception est documentée, isolée du namespace applicatif, et auditée de manière continue.
