# Propositions d'Amélioration de la Chaîne DevSecOps — SecureRAG Hub

Ce document présente des propositions concrètes et actionnables pour renforcer la sécurité, la fiabilité et l'automatisation de la chaîne DevSecOps de **SecureRAG Hub**. Ces propositions sont basées sur l'architecture observée (Kubernetes, ArgoCD, Vault, Kyverno, Falco, Jenkins, k6).

---

## 1. Gestion des Secrets et Cryptographie

### A. Intégration Native de HashiCorp Vault avec *External Secrets Operator* (ESO)
Actuellement, les secrets (comme `securerag-common-secrets`) sont générés ou appliqués via des scripts de développement. 
- **Limites actuelles** : Risque d'exposition locale des fichiers de secrets, manque de rotation automatique.
- **Recommandation** : Remplacer l'injection manuelle ou via script par **External Secrets Operator** (ESO) couplé à HashiCorp Vault.
  - Vault stocke les secrets de manière sécurisée (chiffrée au repos).
  - Un objet `ExternalSecret` dans Kubernetes se charge de récupérer automatiquement la valeur depuis Vault et de créer/mettre à jour le secret Kubernetes natif.
  - La rotation des secrets dans Vault met à jour automatiquement les pods associés (via des outils comme Reloader).

### B. Chiffrement GitOps avec Mozilla SOPS
- **Recommandation** : Utiliser **SOPS (Secrets OPerations)** avec une clé d'âge (Age) ou une clé KMS pour chiffrer les secrets directement dans le dépôt Git.
  - Cela permet de versionner les secrets chiffrés en toute sécurité dans Git (GitOps complet) sans exposer les clés privées.
  - ArgoCD peut déchiffrer les secrets à la volée lors de la synchronisation via le plugin `argocd-vault-plugin` ou le générateur SOPS.

---

## 2. Sécurité du Pipeline CI/CD (Shift Left)

### A. Analyse Statique de Sécurité (SAST) et Secrets (Gitleaks)
- **Recommandation** : Renforcer l'usage de Gitleaks et de Semgrep dans le pipeline de pré-commit et Jenkins.
  - Configurer un crochet (hook) de pré-commit bloquant afin d'empêcher les développeurs de pousser des clés API ou des mots de passe.
  - Ajouter une étape Jenkins exécutant `gitleaks detect --source=. --verbose` à chaque Pull Request pour casser le build en cas de fuite de secret.

### B. Validation des Images de Conteneurs (SCA & OCI Signing)
- **Recommandation** : Mettre en œuvre la signature d'images avec **Cosign** (Sigstore).
  - Après la construction de l'image Docker dans Jenkins, signer l'image à l'aide de Cosign.
  - Utiliser un contrôleur d'admission dans Kubernetes (ex. Kyverno ou Policy Controller) pour **refuser** l'exécution de tout conteneur dont l'image n'est pas signée par la clé privée de l'entreprise.
  - Utiliser **Trivy** pour analyser les vulnérabilités système (CVE) des images et bloquer le déploiement si des vulnérabilités critiques ou hautes sont détectées.

---

## 3. Sécurité Kubernetes et GitOps

### A. Réparation et Durcissement de Kyverno
Actuellement, les pods de Kyverno sont en `CrashLoopBackOff`.
- **Action prioritaire** : Diagnostiquer et réparer Kyverno.
- **Recommandation** : Configurer des politiques Kyverno en mode **Enforce** (bloquant) pour interdire :
  - Les conteneurs s'exécutant en tant que `root`.
  - Le partage de l'espace de nommage de l'hôte (`hostNetwork`, `hostPID`).
  - L'élévation de privilèges (`allowPrivilegeEscalation: false`).
  - Les systèmes de fichiers racine en écriture (`readOnlyRootFilesystem: true` sauf pour `/tmp`).

### B. Migration vers le standard natif *Pod Security Admission* (PSA)
Depuis Kubernetes 1.25+, PSA est intégré de manière native et offre trois profils : `privileged`, `baseline` et `restricted`.
- **Recommandation** : Utiliser PSA pour appliquer le profil `restricted` au namespace `securerag-hub` :
  ```yaml
  apiVersion: v1
  kind: Namespace
  metadata:
    name: securerag-hub
    labels:
      pod-security.kubernetes.io/enforce: restricted
  ```
  Cela remplace Kyverno pour les validations de sécurité de base des Pods avec un coût en performance nul (zéro overhead).

### C. Environnements Éphémères pour les Tests
- **Recommandation** : Configurer des environnements éphémères (Preview Environments) par Pull Request.
  - Utiliser ArgoCD ApplicationSet pour créer dynamiquement un namespace temporaire (ex. `securerag-pr-12`) lors de l'ouverture d'une PR.
  - Lancer les tests de fumée (Smoke Tests) et de charge (k6) dans ce namespace éphémère.
  - Supprimer automatiquement le namespace à la fermeture de la PR. Cela évite d'impacter le namespace de développement partagé.

---

## 4. Sécurité d'Exécution (Runtime Security)

### A. Restauration de Falco et Alerting Actif
Falco est actuellement en `CrashLoopBackOff`.
- **Action prioritaire** : Résoudre les problèmes d'installation du module noyau Falco ou eBPF.
- **Recommandation** : Configurer **Falco Talon** pour réagir automatiquement aux anomalies de sécurité détectées en cours d'exécution :
  - Si Falco détecte un terminal ouvert dans un pod en production (`Terminal shell in container`), Falco Talon peut automatiquement tuer le pod suspect ou bloquer l'adresse IP source.
  - Intégrer les alertes Falco avec Slack/Teams ou un webhook pour avertir instantanément l'équipe sécurité (SecOps).

---

## 5. Industrialisation des Tests de Performance

### A. Export en Temps Réel vers Prometheus / Grafana Cloud
Plutôt que d'exporter les résultats k6 dans des fichiers JSON locaux puis de les transférer par `kubectl cp` :
- **Recommandation** : Activer le module de télémesure natif de k6 vers Prometheus.
  - Lancer k6 avec l'option de sortie Prometheus Remote Write :
    `k6 run -o experimental-prometheus-rw ...`
  - Les métriques de performance (latence, taux d'erreurs, requêtes par seconde) sont poussées en temps réel dans le Prometheus du cluster.
  - Créer un tableau de bord Grafana dédié aux tests k6 pour visualiser les goulots d'étranglement en direct.

---

## Synthèse de la Feuille de Route DevSecOps

| Étape | Action | Impact | Complexité | Priorité |
| :--- | :--- | :--- | :--- | :--- |
| **1** | Réparer Kyverno & Falco (CrashLoops) | Sécurité d'Admission & Runtime | Moyenne | 🚨 Critique |
| **2** | Intégrer External Secrets Operator (ESO) | Élimination des secrets en clair | Haute | ⭐ Haute |
| **3** | Ajouter la signature d'images (Cosign) | Intégrité de la chaîne logiciellle | Moyenne | ⭐ Haute |
| **4** | Mettre en place des namespaces PR éphémères | Isolation des tests de charge | Haute | 📅 Moyenne |
| **5** | Exporter k6 directement vers Prometheus | Observabilité temps réel | Faible | 📅 Moyenne |
