# Plan d'Améliorations de la Chaîne DevSecOps — SecureRAG Hub

Ce document propose une feuille de route structurée pour moderniser et durcir la chaîne **DevSecOps** de **SecureRAG Hub**. L'objectif est d'atteindre un niveau de maturité cible de type **SLSA Level 3/4** et **OWASP SAMM Niveau 3**, tout en optimisant les métriques DORA de la plateforme.

---

## 📋 Synthèse du Diagnostic & Alignement Normatif

D'après le dernier audit de maturité (**Note globale : 88/100**), la plateforme dispose de fondations solides (SAST, SCA, signature Cosign de base, NetworkPolicies, détection Falco). Cependant, des points de vulnérabilité subsistent au niveau de la gestion des clés de signature, du stockage des secrets, du runtime non restrictif et de la dépendance à un cluster local `kind`.

```mermaid
radar-chart
    title Évolution de la Maturité DevSecOps (Actuel vs Cible)
    rimes: [Build, Test, Security, Deploy, Operate, Observe]
    Actuel: [85, 90, 92, 85, 80, 90]
    Cible: [95, 98, 98, 95, 95, 98]
```

---

## 🚀 Axes Stratégiques d'Amélioration

### Axe 1 : Sécurisation Avancée de la Supply Chain (Cible SLSA L3+)
L'objectif est de supprimer les clés de signature statiques et de garantir l'authenticité absolue de chaque artefact déployé.

*   **1.1 Signature sans clé (Sigstore Cosign Keyless) :**
    *   *Constat :* Utilisation d'une paire de clés statiques (`cosign.key`) stockée dans Jenkins.
    *   *Solution :* Configurer une fédération d'identité OIDC via Keycloak. Cosign utilisera des certificats éphémères signés par l'autorité **Fulcio** et enregistrés dans le journal de transparence **Rekor**.
    *   *Fichiers impactés :* [Jenkinsfile.cd](file:///root/MasterPFE/Jenkinsfile.cd), [scripts/release/sign-images.sh](file:///root/MasterPFE/scripts/release/sign-images.sh).
*   **1.2 Transition vers le mode "Enforce" de Kyverno :**
    *   *Constat :* Les politiques de sécurité (signature Cosign, SBOM, PSS) sont actuellement en mode `Audit`.
    *   *Solution :* Passer progressivement les politiques Kyverno en mode `Enforce` en commençant par les namespaces de staging/recette, puis en production pour bloquer à l'admission tout pod non conforme.
    *   *Fichiers impactés :* [infra/k8s/policies/kyverno/](file:///root/MasterPFE/infra/k8s/policies/kyverno/).
*   **1.3 Intégration et validation automatisée des SBOM :**
    *   *Constat :* Les SBOM CycloneDX sont générés mais pas systématiquement validés par rapport à des bases de vulnérabilités au niveau de l'admission control.
    *   *Solution :* Configurer Kyverno pour rejeter les déploiements d'images dont le SBOM contient des vulnérabilités critiques non corrigées ou des licences interdites.

---

### Axe 2 : Durcissement des Environnements de Build et Runtime (Zéro-Trust)
L'objectif est d'éliminer les risques de compromission et d'escalade de privilèges.

*   **2.1 Builds Docker sans privilèges (Dockerless Builds) :**
    *   *Constat :* L'agent Jenkins monte le socket Docker de l'hôte (`/var/run/docker.sock`), ce qui permet une escalade root sur le nœud.
    *   *Solution :* Migrer les builds vers **Kaniko** ou **Buildah** qui s'exécutent en mode non privilégié au sein de pods éphémères K8s.
    *   *Fichiers impactés :* [Jenkinsfile.cd](file:///root/MasterPFE/Jenkinsfile.cd), [infra/jenkins/Dockerfile](file:///root/MasterPFE/infra/jenkins/Dockerfile).
*   **2.2 Généralisation des images "Distroless" :**
    *   *Constat :* Certains microservices utilisent des images de base complètes avec shells et gestionnaires de paquets (`apt`/`apk`).
    *   *Solution :* Utiliser des images multi-stage basées sur `gcr.io/distroless/static` ou `gcr.io/distroless/base` pour supprimer la surface d'attaque en production (aucun shell ni outil système disponible).
    *   *Fichiers impactés :* [services/security-forensics-engine/Dockerfile](file:///root/MasterPFE/services/security-forensics-engine/Dockerfile), Dockerfiles des microservices Laravel.
*   **2.3 Restriction du trafic par défaut (Cilium NetworkPolicies) :**
    *   *Constat :* NetworkPolicies basiques.
    *   *Solution :* Exploiter les NetworkPolicies de niveau 7 (Cilium) pour restreindre non seulement les IPs/ports, mais aussi les verbes HTTP et les chemins d'API autorisés entre services.
    *   *Fichiers impactés :* [infra/k8s/network-policies/](file:///root/MasterPFE/infra/k8s/network-policies/).

---

### Axe 3 : Modernisation de la Gestion des Secrets
Passer d'un modèle de chiffrement statique dans Git à une gestion dynamique éphémère.

*   **3.1 Intégration de HashiCorp Vault avec External Secrets Operator (ESO) :**
    *   *Constat :* Les secrets sont chiffrés avec SOPS/age dans Git, mais les clés de déchiffrement restent statiques.
    *   *Solution :* Déployer HashiCorp Vault. Utiliser ESO pour synchroniser automatiquement les secrets Vault vers des objets Secret de Kubernetes de manière transparente.
    *   *Fichiers impactés :* [infra/k8s/secrets/](file:///root/MasterPFE/infra/k8s/secrets/), [scripts/deploy/deploy-vault-and-eso.sh](file:///root/MasterPFE/scripts/deploy/deploy-vault-and-eso.sh).
*   **3.2 Secrets dynamiques et rotation automatique :**
    *   *Constat :* Les accès aux bases de données et APIs externes sont statiques.
    *   *Solution :* Configurer le moteur de secrets de Vault pour générer des identifiants PostgreSQL éphémères (valides pour quelques heures) pour les services applicatifs Laravel, avec rotation automatique initiée par Vault.

---

### Axe 4 : Observabilité SecOps & Détection Intrusive au Runtime
Assurer la détection en temps réel et la réponse automatisée face aux menaces actives.

*   **4.1 Corrélation Falco / Tetragon vers Wazuh SIEM :**
    *   *Constat :* Les alertes Falco (eBPF) sont stockées localement et manquent d'une console de supervision centralisée.
    *   *Solution :* Interfacer Falco et Tetragon avec Wazuh SIEM via `falcosidekick`. Configurer des décodeurs personnalisés Wazuh pour générer des alertes de sécurité prioritaires sur les appels système anormaux.
    *   *Fichiers impactés :* [infra/k8s/falco/](file:///root/MasterPFE/infra/k8s/falco/), [infra/wazuh/](file:///root/MasterPFE/infra/wazuh/).
*   **4.2 Réponse automatique sur incident (Falco Talon) :**
    *   *Constat :* Détecter les menaces sans réagir de manière automatique laisse une fenêtre de vulnérabilité.
    *   *Solution :* Configurer Falco Talon pour qu'en cas de comportement suspect détecté (ex: exécution d'un shell dans un conteneur web), le pod compromis soit automatiquement isolé du réseau ou supprimé.
    *   *Fichiers impactés :* [infra/k8s/falco-talon/](file:///root/MasterPFE/infra/k8s/falco-talon/).
*   **4.3 Intégration des Logs d'Audit Kubernetes :**
    *   *Solution :* Rediriger les journaux d'audit du Control Plane K8s vers Wazuh pour tracer toutes les requêtes d'administration et les modifications de droits RBAC.

---

### Axe 5 : Résilience, Chaos Engineering & Performance Continue
Assurer que la sécurité n'impacte pas négativement la stabilité et la disponibilité.

*   **5.1 Tests de performance (k6) bloquants en CI :**
    *   *Constat :* k6 est disponible mais non bloquant.
    *   *Solution :* Intégrer les tests k6 dans la CI principale avec des seuils (SLO de performance de type p95 < 500ms). Si le commit dégrade les performances, la livraison est rejetée.
    *   *Fichiers impactés :* [Jenkinsfile.perf](file:///root/MasterPFE/Jenkinsfile.perf), [scripts/performance/run-k6-tests.sh](file:///root/MasterPFE/scripts/performance/run-k6-tests.sh).
*   **5.2 Déploiement Progressif avec validation automatisée des métriques :**
    *   *Constat :* Pas de validation automatisée des déploiements progressifs par métriques réelles.
    *   *Solution :* Activer les stratégies Canary via **Argo Rollouts** sur la passerelle web et le chatbot, avec validation automatique basée sur le taux d'erreur Prometheus avant la promotion à 100%.
    *   *Fichiers impactés :* [infra/k8s/argo-rollouts/](file:///root/MasterPFE/infra/k8s/argo-rollouts/).
*   **5.3 Chaos Engineering Planifié (Chaos Mesh) :**
    *   *Solution :* Injecter régulièrement des pannes (pertes réseau, crashs de base de données) via Chaos Mesh pour valider la tolérance aux pannes de l'application et la réactivité des alertes SecOps.
    *   *Fichiers impactés :* [infra/k8s/chaos-mesh/](file:///root/MasterPFE/infra/k8s/chaos-mesh/).

---

## 🗓️ Feuille de Route de Déploiement (Priorités & Effort)

| Priorité | Amélioration | Complexité | Impact Sécurité | Action recommandée |
| :--- | :--- | :---: | :---: | :--- |
| **P0 (Immédiat)** | **Suppression de Docker.sock** (Builds Kaniko/Buildah) | Medium | Élevé | Configurer le build dans un pod K8s non-privilégié. |
| **P0 (Immédiat)** | **Transition progressive vers Kyverno Enforce** | Low | Très élevé | Activer `Enforce` sur le namespace staging. |
| **P1 (Court terme)**| **Signature Keyless avec OIDC/Fulcio/Rekor** | High | Très élevé | Intégrer la signature éphémère dans le Jenkins CD. |
| **P1 (Court terme)**| **Intégration Vault + ESO (Secrets Dynamiques)**| Medium | Très élevé | Remplacer SOPS/age par des secrets stockés dans Vault. |
| **P1 (Court terme)**| **Centralisation des alertes Falco vers Wazuh** | Medium | Élevé | Configurer falcosidekick et les décodeurs Wazuh. |
| **P2 (Moyen terme)**| **Intégration k6 bloquant dans la CI** | Low | Moyen | Configurer le code de sortie k6 en fonction des SLOs. |
| **P2 (Moyen terme)**| **Validation des métriques Canary (Argo Rollouts)**| High | Élevé | Configurer l'AnalysisTemplate dans Argo Rollouts. |
| **P2 (Moyen terme)**| **Chaos Engineering automatisé** | Medium | Moyen | Planifier des scénarios d'injection de pannes. |

---

## 🎯 Indicateurs Clefs de Réussite (KPI)

1.  **Lead Time for Changes :** Rester sous la barre des **15 minutes** malgré l'ajout de contrôles (grâce au parallélisme des scans).
2.  **Maturité SLSA :** Atteindre officiellement le **SLSA Niveau 3**.
3.  **Taux de détection au runtime :** Interception de 100% des attaques simulées par les règles Falco/Tetragon.
4.  **Temps de réponse à l'admission :** Latence de Kyverno validation < **100ms** par ressource.
5.  **Score de Maturité Global :** Augmenter le score global de **88/100 à 97+/100**.
