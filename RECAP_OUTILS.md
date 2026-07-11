# 🛠️ Récapitulatif des Outils - SecureRAG Hub

Ce document présente une vue d'ensemble des technologies, frameworks et outils DevSecOps intégrés au projet **SecureRAG Hub** (Master DSIR).

---

## 📊 Tableau Récapitulatif des Outils

| Domaine / Catégorie | Outil(s) utilisé(s) | Rôle & Description | Fichiers / Chemins associés | Niveau d'intégration / Statut |
| :--- | :--- | :--- | :--- | :--- |
| **Runtime & Framework** | **Laravel (PHP 8.2)** | Framework officiel pour les microservices (portail, auth, conversation, audit, chatbot manager). | [services-laravel/](file:///root/MasterPFE/services-laravel)<br>[platform/](file:///root/MasterPFE/platform) | **Actif (Runtime officiel)** |
| | **Python** | Prototypes legacy non retenus pour la production finale. | [services/](file:///root/MasterPFE/services) | **Legacy / Prototype** |
| **Conteneurisation & Registry** | **Docker** / **Harbor** | Construction des images conteneurisées et stockage dans un registre d'images local. | [Dockerfile.unified](file:///root/MasterPFE/Dockerfile.unified)<br>[.dockerignore](file:///root/MasterPFE/.dockerignore) | **Actif** |
| **Orchestration & Déploiement** | **Kubernetes (Kind)** | Cluster Kubernetes local pour l'exécution et le test des microservices. | [scripts/deploy/create-kind.sh](file:///root/MasterPFE/scripts/deploy/create-kind.sh) | **Actif** |
| | **Kustomize** | Gestion des manifests Kubernetes par couches (base, overlays dev, demo, production). | [infra/k8s/overlays/](file:///root/MasterPFE/infra/k8s/overlays) | **Actif (Principal)** |
| | **Helm** | Gestion des charts d'infrastructure (par exemple, couche de gouvernance IA). | [infra/helm/](file:///root/MasterPFE/infra/helm) | **Actif (Infrastructure)** |
| **CI/CD & Automatisation** | **Jenkins** | Moteur CI/CD officiel exécutant les pipelines d'intégration et de déploiement. | [Jenkinsfile](file:///root/MasterPFE/Jenkinsfile) (CI)<br>[Jenkinsfile.cd](file:///root/MasterPFE/Jenkinsfile.cd) (CD)<br>[Makefile](file:///root/MasterPFE/Makefile) | **Actif (Source de vérité)** |
| **Sécurité du Code (SAST & Linting)** | **Semgrep** | Analyse statique du code (SAST) basée sur 14 règles personnalisées (Python, PHP/Laravel, Docker). | [security/](file:///root/MasterPFE/security) | **Actif (Bloquant dans la CI)** |
| | **Gitleaks** | Détection de secrets et clés privées dans l'historique Git. | [.gitleaks.toml](file:///root/MasterPFE/.gitleaks.toml) | **Actif (Bloquant dans la CI)** |
| | **Hadolint** | Linter pour valider et sécuriser les Dockerfiles. | [.hadolint.yaml](file:///root/MasterPFE/.hadolint.yaml) | **Actif** |
| | **Checkov** | Analyse de sécurité statique pour l'Infrastructure-as-Code (manifestes Kubernetes). | Jenkinsfile (CI) | **Actif** |
| | **SonarQube** | Analyse globale de la qualité du code et couverture de test. | [sonar-project.properties](file:///root/MasterPFE/sonar-project.properties) | **Optionnel (Configuré)** |
| **Sécurité Supply Chain** | **Cosign** | Signature cryptographique et vérification des images de conteneurs (via clés ou keyless). | [scripts/release/](file:///root/MasterPFE/scripts/release) | **Actif (Obligatoire en CD)** |
| | **Trivy** | Scan des vulnérabilités des images et du système de fichiers (filesystem + image scanning). | [scripts/release/](file:///root/MasterPFE/scripts/release) | **Actif (Intégré aux phases CI/CD)** |
| | **Syft** | Génération de la nomenclature logicielle (SBOM) au format CycloneDX. | Jenkinsfile.cd (CD) | **Actif (Obligatoire en CD)** |
| | **Grype** | Analyse des vulnérabilités des SBOM générés par Syft. | Jenkinsfile.cd (CD) | **Actif (Obligatoire en CD)** |
| | **SLSA Provenance** | Génération et attestation de provenance (SLSA Level 3 progressif) pour certifier l'intégrité de la build. | [scripts/release/](file:///root/MasterPFE/scripts/release) (provenance.slsa.json) | **Intégration progressive** |
| **Politiques d'Admission** | **Kyverno** | Validation des règles de sécurité (PSS Restricted, signatures Cosign, contrôle des registres). | [infra/k8s/policies/kyverno/](file:///root/MasterPFE/infra/k8s/policies/kyverno) | **Actif (Enforce/Audit)** |
| | **OPA / Gatekeeper** | Outil complémentaire à Kyverno pour l'application de politiques complexes basées sur Rego. | [infra/k8s/opa-gatekeeper/](file:///root/MasterPFE/infra/k8s/opa-gatekeeper) | **Intégration progressive** |
| **Sécurité Réseau & Service Mesh** | **NetworkPolicies** | Politiques réseau Kubernetes strictes pour isoler les microservices. | [infra/k8s/network-policies/](file:///root/MasterPFE/infra/k8s/network-policies) | **Actif (Strict)** |
| | **Cilium** | CNI avec eBPF pour la sécurité réseau avancée, l'observabilité et le chiffrement du trafic. | [infra/k8s/cilium/](file:///root/MasterPFE/infra/k8s/cilium) | **Planifié / En cours (eBPF)** |
| | **Istio** | Service Mesh pour mTLS, gestion du trafic et observabilité (non utilisé par défaut). | [infra/k8s/istio/](file:///root/MasterPFE/infra/k8s/istio) | **Optionnel / Draft** |
| **Sécurité Runtime & SIEM** | **Falco** | Détection d'intrusions et d'anomalies en temps réel dans les conteneurs (ex. injection de shell). | [infra/k8s/falco/](file:///root/MasterPFE/infra/k8s/falco) | **Actif (Règles personnalisées)** |
| | **Wazuh** | Système SIEM pour la surveillance de la sécurité et la conformité réglementaire. | [infra/k8s/wazuh/](file:///root/MasterPFE/infra/k8s/wazuh) | **Configuré** |
| | **eBPF (Tetragon)** | Surveillance bas-niveau des appels système et du réseau. | [scripts/tetragon/](file:///root/MasterPFE/scripts/tetragon) | **Optionnel** |
| **Gestion des Secrets** | **SOPS** | Chiffrement des fichiers de secrets intégrés au dépôt Git (avec Age ou Vault). | [.sops.yaml](file:///root/MasterPFE/.sops.yaml)<br>[infra/secrets/](file:///root/MasterPFE/infra/secrets) | **Actif** |
| **GitOps** | **ArgoCD** | Déploiement continu déclaratif synchronisant l'état Git avec le cluster Kubernetes. | [infra/k8s/argocd/](file:///root/MasterPFE/infra/k8s/argocd) | **Actif (Configuré)** |
| **Observability & APM** | **Prometheus** / **Grafana** | Collecte de métriques (8+ ServiceMonitors) et visualisation via des dashboards, incluant le dashboard dédié **"Security Posture"** (vulnérabilités, alertes Falco, violations Kyverno). | [infra/k8s/monitoring/](file:///root/MasterPFE/infra/k8s/monitoring)<br>[infra/k8s/observability/](file:///root/MasterPFE/infra/k8s/observability) | **Actif** |
| | **Loki** / **Tempo** / **OTel** | Centralisation des logs, traçabilité distribuée et intégration OpenTelemetry. | [infra/k8s/observability/](file:///root/MasterPFE/infra/k8s/observability) | **Actif** |
| **Résilience & Sauvegardes** | **Chaos Mesh** | Injection contrôlée de pannes (PodChaos, NetworkChaos) pour tester la haute disponibilité. | [infra/k8s/chaos-mesh/](file:///root/MasterPFE/infra/k8s/chaos-mesh) | **Actif (Scripts de test)** |
| | **Velero** | Sauvegarde et restauration de l'état du cluster Kubernetes. | [scripts/dr/](file:///root/MasterPFE/scripts/dr)<br>[infra/k8s/velero/](file:///root/MasterPFE/infra/k8s/velero) | **Configuré (Scripts de test)** |
| **Sécurité Web (DAST)** | **OWASP ZAP** | Analyse dynamique de la sécurité des applications web (Dynamic Application Security Testing). | [scripts/zap-quality-gate.sh](file:///root/MasterPFE/scripts/zap-quality-gate.sh) | **Actif (Quality Gate)** |
| **Gestion des Dépendances** | **Renovate** | Automatisation de la mise à jour des dépendances du projet. | [renovate.json](file:///root/MasterPFE/renovate.json) | **Actif** |

---

## 💡 Principes d'Intégration DevSecOps

1. **Pipeline Tracé & Certifié (SLSA L3) :** La transition du code vers la production suit une chaîne stricte incluant le scan filesystem/images par Trivy, la signature Cosign, la vérification et la génération progressive d'attestations de provenance conformes aux standards SLSA Level 3.
2. **Admission Hybride (Kyverno & OPA/Gatekeeper) :** Combinaison de Kyverno pour les règles déclaratives Kubernetes standards (PSS restricted) et OPA/Gatekeeper pour les politiques de conformité complexes nécessitant la flexibilité de Rego.
3. **Segmentation Réseau Avancée (CNI Cilium) :** Application de NetworkPolicies Kubernetes strictes, avec une transition planifiée vers Cilium pour exploiter eBPF au niveau du noyau Linux (performances et visibilité réseau accrues).
4. **Visibilité Centralisée "Security Posture" :** Centralisation des alertes de sécurité runtime (Falco), des non-conformités d'admission (Kyverno/OPA) et des vulnérabilités de conteneurs (Trivy/Grype) au sein d'un dashboard Grafana unifié pour un audit en temps réel.

---

## 🔗 Liens d'Accès aux Outils (Local / IP Serveur)

Pour accéder aux interfaces des différents outils de monitoring et de gestion de la plateforme, utilisez les commandes `port-forward` suivantes (ou référez-vous au [guide complet](file:///root/.gemini/antigravity-ide/brain/e36f38ff-0265-4b93-9e0c-07ef2beabccf/monitoring_tools_recap.md)). 

> [!TIP]
> Si vous accédez à ces consoles depuis une autre machine sur le réseau local ou public (ex: serveur de recette `83.229.82.46`), ajoutez l'argument **`--address 0.0.0.0`** à la commande `kubectl port-forward` et remplacez `localhost` par l'IP du serveur (ex: `http://83.229.82.46:3000` pour Grafana).



*   📊 **Grafana (Observabilité / Security Posture)** : [http://localhost:3000](http://localhost:3000)
    `kubectl -n securerag-monitoring port-forward svc/grafana 3000:3000` *(admin / admin)*
*   📈 **Prometheus (Métriques)** : [http://localhost:9090](http://localhost:9090)
    `kubectl -n securerag-monitoring port-forward svc/prometheus 9090:9090`
*   🚨 **Alertmanager (Alertes)** : [http://localhost:9093](http://localhost:9093)
    `kubectl -n securerag-monitoring port-forward svc/alertmanager 9093:9093`
*   🛡️ **OpenSearch (SIEM Centralisé)** : [http://localhost:5601](http://localhost:5601)
    `kubectl port-forward -n opensearch svc/opensearch-dashboards 5601:5601` *(admin / admin)*
*   🌐 **Hubble UI (Cilium eBPF Réseau)** : [http://localhost:12000](http://localhost:12000)
    `kubectl port-forward -n kube-system svc/hubble-ui 12000:12000`
*   💥 **Chaos Mesh Dashboard** : [http://localhost:2333](http://localhost:2333)
    `kubectl port-forward -n chaos-mesh svc/chaos-dashboard 2333:2333`
*   📝 **Backstage IDP (Catalogue / Scorecards)** : [http://localhost:7007](http://localhost:7007)
    `kubectl port-forward -n backstage-system deploy/backstage 7007:7007`
*   🐙 **ArgoCD (GitOps)** : [https://localhost:8080](https://localhost:8080)
    `kubectl port-forward -n argocd svc/argocd-server 8080:443` *(admin / secret initial)*
*   🔒 **HashiCorp Vault (Secrets)** : [http://localhost:8200](http://localhost:8200)
    `kubectl port-forward -n vault vault-0 8200:8200`
*   🔍 **SonarQube (Qualité & SAST)** : [http://localhost:9000](http://localhost:9000) *(via `make sonarqube-up`)* *(admin / admin)*
*   📦 **MinIO Console (Sauvegardes / DR)** : [http://localhost:9001](http://localhost:9001)
    `kubectl port-forward -n minio svc/minio 9001:9001` *(minioadmin / minioadmin)*
*   🤖 **OpenWebUI (AIOps / Chatbot)** : [http://localhost:8080](http://localhost:8080)
    `kubectl port-forward -n aiops-system svc/openwebui 8080:8080`
*   ⚙️ **Jenkins (CI/CD)** : [http://localhost:8085](http://localhost:8085) *(Lancé via compose/VPS)*


