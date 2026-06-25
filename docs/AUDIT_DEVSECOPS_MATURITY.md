# Phase 2 — Évaluation de la Maturité DevSecOps

Ce rapport évalue la maturité globale des pratiques DevSecOps de la plateforme **SecureRAG Hub** selon les standards de l'industrie (DORA, SLSA, NIST SSDF, OWASP SAMM, CNCF et DSOMM).

---

## 1. Modèles de Référence

### 1.1 Métriques DORA (DevOps Research and Assessment)

| Métrique DORA | Niveau Théorique | Statut Réel & Preuves |
| :--- | :--- | :--- |
| **Deployment Frequency** (Fréquence de déploiement) | **High** (Plusieurs fois par semaine) | Automatisé via `Jenkinsfile.cd`. Renovate déclenche des pulls hebdomadaires de mise à jour. |
| **Lead Time for Changes** (Temps de livraison d'un commit) | **Medium** (De quelques heures à un jour) | Le pipeline CI complet prend environ 12 à 15 minutes en raison de l'empilement des scans de sécurité (Semgrep, Sonar, Checkov, Trivy, OWASP DC). |
| **Change Failure Rate** (Taux d'échec des déploiements) | **Low** (< 5%) | Très bas en raison des 11 Quality Gates bloquants interdisant la promotion d'images vulnérables ou non signées. |
| **Time to Restore Service** (Temps de rétablissement - MTTR) | **High** (< 1 heure) | Estimé à 32 secondes pour un pod crash (auto-heal) et 9 secondes par scale-up HPA. Script de DR automatique présent. |

### 1.2 Niveau de Conformité SLSA (Supply-chain Levels for Software Artifacts)
La plateforme vise le niveau **SLSA Level 3** :
*   **Build scripté (SLSA 1)** : Oui, via `Jenkinsfile` et `Makefile`.
*   **Provenance générée (SLSA 2)** : Oui, SBOM CycloneDX généré avec Syft et signatures d'images via Cosign.
*   **Provenance non falsifiable (SLSA 3)** : Partiellement atteint. Le pipeline de build s'exécute dans un agent Jenkins isolé, mais les clés Cosign privées sont stockées sous forme de secrets Kubernetes/Jenkins statiques plutôt que dans un KMS matériel ou via Sigstore Keyless (Rekor/Fulcio) pleinement opérationnel en production.

### 1.3 NIST SSDF (Secure Software Development Framework - SP 800-218)
*   **PO (Prepare the Organization)** : Présence d'ADR (Architecture Decision Records) et de guides d'incidentologie.
*   **PS (Protect the Software)** : Intégrité garantie par signatures Cosign, exclusion des secrets par pre-commit et Gitleaks.
*   **PW (Produce Well-Secured Software)** : SAST (Semgrep/SonarQube) et SCA (Trivy/OWASP DC) exécutés à chaque pull request.
*   **RV (Respond to Vulnerabilities)** : Alertes automatisées par Prometheus Rule et audits nocturnes.

### 1.4 OWASP SAMM (Software Assurance Maturity Model)
*   **Governance** (Policy & Compliance) : Niveau 2 (Politiques Kyverno appliquées en mode enforce).
*   **Design** (Security Architecture) : Niveau 2 (Zero-Trust au niveau réseau K8s par défaut).
*   **Implementation** (Secure Build & Deploy) : Niveau 3 (Toutes les images promues par digest cryptographique sans rebuild).
*   **Verification** (Security Testing) : Niveau 2.5 (DAST ZAP actif en recette, SAST actif).
*   **Operations** (Incident Management) : Niveau 2 (Falco + Falco Talon implémentés).

---

## 2. Grille de Maturité DSOMM (DevSecOps Maturity Model)

### Note DevSecOps Globale : 88/100

```
  Build      [████████████████████] 85%
  Test       [█████████████████████] 90%
  Security   [██████████████████████] 92%
  Deploy     [████████████████████] 85%
  Operate    [███████████████████] 80%
  Observe    [█████████████████████] 90%
```

### 2.1 Build (Note : 85/100)
*   **Points Forts :** Utilisation d'images multi-stage durcies (Distroless PHP pour `portal-web`). Linter Docker (`hadolint`) et Shell (`shellcheck`) intégrés.
*   **Points Faibles :** L'agent Jenkins exécute des builds Docker en montant le socket Docker hôte (`/var/run/docker.sock`), ce qui présente un risque d'escalade de privilèges sur le nœud de build (privilèges root requis pour le daemon docker).

### 2.2 Test (Note : 90/100)
*   **Points Forts :** Taux de couverture de code minimum fixé à 85% bloquant (`COVERAGE_MIN=85` dans `secure-quality-gate.sh`). Tests unitaires automatisés pour tous les microservices Laravel.
*   **Points Faibles :** Les tests fonctionnels de performance k6 et les tests de charge ne sont pas intégrés de manière bloquante dans le pipeline principal, ils sont exécutés manuellement ou via pipeline séparé.

### 2.3 Security (Note : 92/100)
*   **Points Forts :** Intégration de 11 barrières de sécurité (Gitleaks, Semgrep rules custom, Trivy FS, Trivy Image, Checkov, Kube-score, OPA Gatekeeper). Le pipeline bloque l'exécution si une faille critique/haute est trouvée.
*   **Points Faibles :** SARIF n'est pas généré nativement dans le pipeline principal CI Jenkins, masquant les alertes structurées de Semgrep dans SonarQube.

### 2.4 Deploy (Note : 85/100)
*   **Points Forts :** Déploiement Kustomize avec sync-waves ordonnées dans ArgoCD. Promotion cryptographique par Digest (`pin-overlay-digests.sh`) garantissant que l'image exécutée en production est identique à celle testée en CI.
*   **Points Faibles :** Pas de déploiement progressif actif de type Canary ou Blue-Green automatique validé par métriques Prometheus applicatives (bien que configuré dans les stratégies argo-rollouts, non activé sur la prod par défaut).

### 2.5 Operate (Note : 80/100)
*   **Points Forts :** Durcissement des namespaces Kubernetes (PSA restricted), NetworkPolicies strictes default-deny. Détection eBPF avec Falco + Talon.
*   **Points Faibles :** Tetragon (Runtime Enforcement) est désactivé par défaut. Secrets stockés en clair dans les fichiers `.env` commités historiquement (résolus par rotation mais traces Git existantes).

### 2.6 Observe (Note : 90/100)
*   **Points Forts :** Stack complète Prometheus, Grafana, Loki et Alertmanager. 28 ServiceMonitors configurés. Dashboards SRE / SLO dédiés.
*   **Points Faibles :** Stockage des métadonnées et logs en mode `emptyDir` (non persistant) par défaut sur la configuration de base, entraînant la perte des métriques au redémarrage des pods d'observabilité. Tracing distribué (Tempo / OpenTelemetry) désactivé dans le fichier de configuration principal.
