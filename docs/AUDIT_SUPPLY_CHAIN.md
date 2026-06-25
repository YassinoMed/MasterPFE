# Phase 7 — Supply Chain Security & Dependency Audit

Ce document présente l'audit de la chaîne d'approvisionnement logicielle (Supply Chain), incluant la génération de SBOM, la signature d'images (Cosign, Sigstore), le respect du standard SLSA et la gestion des vulnérabilités de dépendances.

---

## 1. Cadre de Référence de la Supply Chain

Le projet SecureRAG Hub intègre des contrôles avancés pour prévenir les attaques de type empoisonnement de dépendance ou falsification d'images (Tampering).

### 1.1 CycloneDX SBOM (Software Bill of Materials)
*   **Générateur** : Syft (`scripts/release/generate-sbom.sh`) est utilisé pour analyser les couches des images construites et générer un inventaire des paquets logiques (SBOM) au format standardisé CycloneDX JSON.
*   **Contrôle (Grype)** : Un scanner Grype est configuré pour auditer le fichier SBOM produit et interdire la promotion si des paquets tiers critiques ou obsolètes sont identifiés.
*   **Statut** : Le script de génération de SBOM a échoué historiquement en raison de l'absence du binaire Syft dans l'environnement d'exécution de l'agent de build Jenkins, ce qui a conduit à des fichiers d'attestation vides (`artifacts/release/sbom-cyclonedx-validation.md`).

### 1.2 Signature et Vérification Cosign / Sigstore
*   **Signature en CI/CD** : Cosign (`scripts/release/sign-images.sh`) signe les images de conteneurs avec une clé privée stockée dans Kubernetes/Jenkins.
*   **Vérification Admission (Kyverno)** : Le cluster Kind utilise des politiques Kyverno (`infra/k8s/policies/kyverno/verify-cosign-images.yaml`) pour interdire le démarrage de pods dont l'image n'est pas signée par la clé publique officielle.
*   **Statut de la Stack Sigstore** : Les scripts de déploiement d'une stack locale Rekor/Fulcio (`deploy-sigstore-stack.sh`) existent mais ne sont pas déployés en production, s'appuyant uniquement sur le mode paire de clés statique de Cosign.

---

## 2. Détection des Vulnérabilités & Écarts de Supply Chain (Findings)

### Finding SUP-01 : Binaire Cosign Manquant dans l'Agent Jenkins [CRITICAL]
*   **Description** : Les étapes de signature de `Jenkinsfile.cd` échouent systématiquement car le binaire `cosign` n'est pas installé dans l'image de base de l'agent Jenkins Docker.
*   **Impact** : Incapacité à signer les images poussées en production. Les politiques d'admission Kyverno bloquent alors le déploiement.
*   **Recommandation** : Ajouter l'installation de Cosign dans `infra/jenkins/Dockerfile` (Agent Jenkins).

### Finding SUP-02 : `--allow-insecure-registry` Toujours Actif (Bypass TLS) [HIGH]
*   **Description** : En raison d'un code orphelin dans `scripts/release/lib/common.sh` (ligne 73), l'option `--allow-insecure-registry` est systématiquement passée à Cosign pour toutes les vérifications.
*   **Impact** : Bypasse la vérification des certificats TLS du registre de conteneurs, exposant la chaîne de livraison à des attaques de type Man-in-the-Middle (MitM) permettant l'injection d'images malicieuses.
*   **Recommandation** : Supprimer l'option `--allow-insecure-registry` et configurer correctement les certificats CA internes sur les agents de build et le cluster.

### Finding SUP-03 : Échec de l'Attestation de Release (All Claims False) [HIGH]
*   **Description** : Le fichier d'attestation consolidé de la release (`artifacts/release/release-attestation.json`) indique que les 7 claims de sécurité obligatoires sont à `false`.
*   **Impact** : Aucune preuve cryptographique d'intégrité de la release n'est disponible pour les auditeurs de conformité.
*   **Recommandation** : Relancer le pipeline de CD après correction de l'environnement Cosign/Syft pour générer de vraies preuves.

### Finding SUP-04 : Dépendances Abandonnées et npm Audit Inefficace [MEDIUM]
*   **Description** : 
    *   Absence de fichier `package-lock.json` à la racine, rendant la commande `npm audit` inefficace.
    *   Détection de dépendances PHP obsolètes dans les microservices Laravel sans blocage du build CI par Trivy FS.
*   **Impact** : Risque d'introduire des paquets tiers vulnérables (ex. failles d'injection SQL ou RCE dans des packages tiers PHP).
*   **Recommandation** : Commiter les fichiers `package-lock.json` et configurer Trivy FS pour qu'il échoue en CI en cas de dépendance critique détectée.

---

## 3. Scoreboard Supply Chain Security

### Note Globale : 68/100

| Domaine d'Audit | Score | Justification |
| :--- | :--- | :--- |
| **Génération du SBOM** | 70/100 | Script et intégration technique complets, mais exécution en échec dans l'environnement Jenkins de base. |
| **Signature Cryptographique** | 60/100 | Kyverno configuré pour rejeter le non-signé, mais Cosign manquant dans l'agent Jenkins par défaut. Bypass TLS actif. |
| **Vérification de la Provenance** | 65/100 | Attestations de release générées avec des valeurs vides/fausses en l'absence de clé de signature fonctionnelle. |
| **Gestion des Dépendances** | 78/100 | Renovate actif et scans Trivy présents, mais npm audit inefficace et exceptions de dépendances non documentées. |
