# SecureRAG Hub — DevSecOps Architecture Review

## 1. Executive Summary
Ce rapport présente un audit architectural complet de la plateforme **SecureRAG Hub**. Conçue comme une solution Cloud-Native moderne, l'infrastructure s'appuie sur Kubernetes, l'approche GitOps (ArgoCD) et des pratiques DevSecOps intégrées (Jenkins, Kyverno, Cilium, Falco). Au cours des dernières itérations, des avancées majeures ont été réalisées pour hisser la plateforme vers des standards de production (Supply Chain sécurisée, Zero Trust Network, Disaster Recovery). Toutefois, cette analyse met en lumière les forces actuelles, les axes d'optimisation restants et propose une roadmap pour atteindre une architecture "Enterprise-Grade".

## 2. Current Architecture Overview
- **Orchestration** : Cluster Kubernetes avec une séparation logique par namespaces (`securerag-hub`, `securerag-monitoring`, `securerag-backup`, `falco`, `kyverno`).
- **Gestion des Secrets** : HashiCorp Vault couplé à External Secrets Operator (ESO) pour la rotation et l'injection native.
- **Déploiement Continue (CD)** : ArgoCD orchestrant l'infrastructure et l'applicatif via des `ApplicationSet` et des vagues de synchronisation (`waves`).
- **Runtime Security** : Falco déployé via DaemonSet (eBPF) pour la détection des anomalies comportementales.
- **Microservices** : Architecture orientée API (API Gateway, Portal Web, Chatbot Manager, LLM Orchestrator).

## 3. CI/CD & GitOps Flow
Le flux de livraison est strictement découplé (Push pour la CI, Pull pour la CD) :
- **Continuous Integration (Jenkins)** : Le pipeline construit l'image, génère le SBOM (Syft), scanne les vulnérabilités (Trivy), signe l'image (Cosign) et la pousse sur le registre. Gitleaks est utilisé pour empêcher la fuite de secrets en amont.
- **Continuous Deployment (ArgoCD)** : Repose exclusivement sur des manifestes Git (Kustomize/Helm). La réconciliation automatique empêche toute dérive de configuration (Configuration Drift).

## 4. Security Analysis
La sécurité est traitée en profondeur (Defense in Depth) :
- **Admission Control** : Pod Security Admission (PSA) configuré en mode `baseline` (bloquant l'escalade système) couplé à Kyverno en mode `Audit` et `Enforce` pour les règles métier fines (interdiction des conteneurs root, contrôle des signatures Cosign).
- **Secrets Management** : Mature. Plus aucun secret statique n'est stocké en clair dans le dépôt grâce à ESO et HashiCorp Vault.

## 5. Kubernetes Architecture Review
L'architecture est robuste, s'appuyant fortement sur le modèle déclaratif.
- L'utilisation de Kustomize permet d'isoler les configurations d'environnement (Base vs Overlays).
- Les `sync-waves` d'ArgoCD garantissent que les fondations (policies, secrets, CRDs) sont déployées avant les applications métiers.

## 6. Supply Chain Security Review
Très haut niveau de maturité :
- **Transparence** : SBOM générés systématiquement.
- **Contrôle Qualité** : Arrêt du pipeline CI si des CVE `HIGH`/`CRITICAL` sont détectées.
- **Intégrité** : Toute image déployée sur le cluster doit être signée (Cosign), validée par une politique Kyverno en mode `Enforce`.

## 7. Observability Review
La pile d'observabilité est moderne et corrélée :
- **Métriques** : Prometheus.
- **Logs** : Promtail + Loki.
- **Traces** : OpenTelemetry Collector + Tempo.
- **Corrélation** : L'intégration dans Grafana permet de passer des traces aux logs de manière fluide. Des dashboards SLO (Latency, Error rate) sont en place.

## 8. Network Security Review
Implémentation avancée du **Zero Trust** via Cilium :
- Mode `default-deny` par défaut sur le réseau applicatif.
- Filtrage L7 (HTTP) via l'Envoy proxy intégré à Cilium, garantissant que seules les méthodes HTTP légitimes traversent les ports 8000/8080.
- `CiliumClusterwideNetworkPolicy` employée judicieusement pour sanctuariser les flux transverses (DNS, Observabilité).

## 9. Resilience & Disaster Recovery
Une stratégie de Backup formelle est implémentée :
- **Composants critiques** : Les états de `etcd`, `Vault` (Raft) et l'export `ArgoCD` sont sauvegardés via des CronJobs.
- **Externalisation** : Les archives sont chiffrées symétriquement (GPG) et poussées vers un stockage S3.
- Un script de validation de staging `dr-test.sh` et un *Runbook* de restauration existent, limitant drastiquement le RTO (Recovery Time Objective).

## 10. Performance Testing
- L'outil **k6** est intégré pour le test de charge applicatif. Actuellement utilisé en CI, les rapports sont stockés sous forme d'artefacts.
- *Axe d'amélioration* : Le streaming des métriques de k6 vers Prometheus n'est pas encore totalement automatisé.

---

## 11. Strengths
- Découplage CI/CD parfait (Jenkins + ArgoCD).
- Supply Chain blindée (SBOM + Scan + Signature + Vérification).
- Observabilité complète (Logs, Metrics, Traces OTLP).
- Micro-segmentation réseau L7 (Cilium).

## 12. Weaknesses & Gaps
- Manque de namespaces éphémères pour isoler les tests de charge en CI.
- Remontée des tests k6 vers Grafana encore manuelle ou basée sur des artefacts locaux.
- Falco est déployé mais l'alerting actif / réponse automatisée (ex: Falco Talon) manque.

## 13. Risk Analysis
- **Risque Opérationnel** : Perte de la clé GPG master des sauvegardes DR rendant toute restauration impossible.
- **Risque de Scalabilité** : Si les tests de charge tournent sur le même namespace de staging, ils peuvent saturer les ressources et fausser les métriques des autres services.

## 14. Scoring (Global + By Domain)
**Score Global : 8.5/10**

- CI/CD & GitOps : 9/10
- Kubernetes Architecture : 8/10
- Security & Policy : 9/10
- Supply Chain Security : 10/10
- Observability : 8/10
- Network Security : 9/10
- Resilience & DR : 8/10
- Performance Testing : 6/10

## 15. Target Architecture (Future State)
La plateforme cible sera un système auto-régulé où :
1. Chaque PR génère un namespace éphémère (Preview Environment).
2. k6 s'exécute contre ce namespace en poussant ses métriques temps réel sur Grafana.
3. En production, Falco (via Talon) réagit automatiquement aux intrusions (Network policy block, Pod Kill) sans intervention humaine.

## 16. Roadmap (Phases)

### Court Terme (0-3 mois)
- Industrialiser l'export k6 (`remote-write`) directement vers Prometheus.
- Configurer les namespaces éphémères (via l'ApplicationSet Pull Request Generator d'ArgoCD).

### Moyen Terme (3-6 mois)
- Implémenter **Falco Talon** pour la remédiation automatique des alertes de sécurité au runtime.
- Mettre en place un Chaos Engineering basique (ex: Litmus Chaos) pour éprouver la procédure de DR.

### Long Terme (6-12 mois)
- Déployer du Service Mesh complet (Istio ou Cilium Mesh) si le besoin en mTLS et routage avancé (Canary/Blue-Green) se fait sentir.
- Certification automatique et continue (Continuous Compliance) intégrée aux dashboards métiers.

## 17. Recommendations (Actionable Items)
1. **Sécuriser la clé DR** : Assurez-vous que la variable `ENCRYPTION_PASSWORD` du Disaster Recovery soit conservée dans un coffre-fort physique ou hors site.
2. **PR Namespaces** : Créer un ApplicationSet ArgoCD basé sur le générateur Pull Request GitHub/GitLab pour spawner dynamiquement des environnements.
3. **Dashboards k6** : Modifier les scripts k6 pour utiliser l'argument `-o experimental-prometheus-rw` et créer le dashboard Grafana associé.
