# Chapitre Mémoire : Perspectives d'Amélioration et Axes d'Évolution de la Chaîne DevSecOps

## Statut : DISPONIBLE (STYLE ACADÉMIQUE)

Ce document présente une section rédigée en français académique et formel, destinée à être insérée dans le mémoire de projet de fin d'études de SecureRAG Hub. Il s'agit d'une analyse critique de l'état actuel de la chaîne DevSecOps et des axes d'amélioration identifiés par l'audit de sécurité.

---

## 1. Évaluation de la Maturité DevSecOps et Méthodologie d'Audit

L'évaluation de la maturité DevSecOps de la plateforme SecureRAG Hub a été conduite selon une méthodologie structurée couvrant cinq piliers fondamentaux : la gestion des identités et des secrets (IAM), la sécurité du code et de l'intégration continue (SAST/SCA), la sécurité de l'infrastructure et des conteneurs (IaC), le monitoring et la réponse aux incidents, ainsi que la documentation et la modélisation des menaces. Cette approche multidimensionnelle permet d'obtenir une vision exhaustive de la posture de sécurité de l'environnement.

Le résultat de cette évaluation attribue à l'environnement un score global de **78 sur 100**, le classant dans la catégorie « **Bon** » (environnement sécurisé mais perfectible) selon la grille de maturité DevSecOps suivante :

| Niveau | Plage | Description |
|--------|:-----:|-------------|
| Critique | 0 – 40 | Risques majeurs de compromission, absence de pratiques de base |
| Insuffisant | 41 – 60 | Pratiques élémentaires manquantes, contrôles partiels |
| Bon | 61 – 80 | Environnement sécurisé, couverture solide, perfectible |
| Excellent | 81 – 100 | État de l'art DevSecOps, défense en profondeur mature |

Ce score reflète des fondations architecturales solides (Pod Security Standards *Restricted*, NetworkPolicy *default-deny*, signature Cosign, SBOM CycloneDX) tout en identifiant des axes d'amélioration précis qui, une fois implémentés, porteraient l'environnement au niveau « Excellent ».

---

## 2. Axes d'Amélioration Identifiés

### 2.1 Intégration du Test Dynamique de Sécurité Applicative (DAST)

La chaîne CI/CD actuelle couvre extensivement les analyses statiques (SAST via Semgrep, SCA via Trivy, détection de secrets via Gitleaks). Cependant, l'absence de **tests dynamiques de sécurité applicative** (DAST) constitue la lacune la plus significative du pipeline de sécurité. Le DAST analyse une application *en cours d'exécution* en lui envoyant des requêtes HTTP malicieuses afin de détecter des vulnérabilités exploitables telles que les injections XSS, les absences de tokens CSRF, les en-têtes de sécurité manquants (CSP, HSTS, X-Frame-Options) ou les fuites d'informations serveur.

L'outil recommandé est **OWASP ZAP** (Zed Attack Proxy), un scanner open source maintenu par l'OWASP Foundation. Son intégration dans le pipeline CD sous forme de stage conditionnel (`RUN_DAST`) a été implémentée, permettant un scan *baseline* automatisé contre le portail déployé. Ce scan s'exécute après la validation post-déploiement, garantissant que l'application est dans un état fonctionnel avant l'analyse dynamique.

L'apport du DAST complète le SAST sans le remplacer : là où l'analyse statique identifie des *anti-patterns* dans le code source, le test dynamique confirme leur *exploitabilité effective* dans le contexte d'exécution réel, réduisant significativement le taux de faux positifs.

### 2.2 Migration vers la Signature Keyless (OIDC) pour la Supply Chain

L'infrastructure actuelle de signature d'images repose sur une paire de clés cryptographiques Cosign stockée comme identifiant Jenkins. Bien que fonctionnelle, cette approche présente un risque inhérent : la compromission de la clé privée permettrait à un attaquant de signer des images malveillantes qui seraient acceptées par les politiques d'admission Kyverno.

La migration vers le mode **keyless** via OpenID Connect (OIDC) et l'infrastructure Sigstore (Fulcio pour l'émission de certificats éphémères, Rekor pour le log de transparence) élimine ce risque en liant chaque signature à l'identité OIDC du pipeline CI/CD. Ainsi, une image signée porte non seulement la preuve de son intégrité cryptographique, mais également l'*attribution d'identité* vérifiable : quel workflow, dans quel dépôt, à quel commit, a produit cette signature.

Cette évolution représente l'état de l'art en matière de *Software Supply Chain Security* et s'aligne avec les recommandations du framework SLSA (Supply-chain Levels for Software Artifacts).

### 2.3 Passage des Politiques Kyverno en Mode Enforce

Les sept politiques Kyverno déployées (Pod Security baseline, restriction des registres d'images, vérification Cosign, interdiction des volumes hostPath, restriction de l'exposition des services, contrôle des workloads, audit des valeurs en clair) fonctionnent actuellement en mode **Audit**. Ce mode génère des rapports de conformité (`PolicyReport`) sans bloquer les ressources non conformes.

La décision architecturale de maintenir le mode Audit est documentée et justifiée par les contraintes de l'environnement local Kind (registre insécurisé `localhost:5001`, résolution DNS interne). Cependant, pour un déploiement production, le passage en mode **Enforce** est impératif. Un overlay Kustomize (`infra/k8s/policies/kyverno-enforce/`) est préparé à cet effet, permettant une bascule progressive politique par politique. Les conditions préalables incluent une période d'observation *zero-violation* de 14 jours et un registre d'images sécurisé accessible par le webhook Kyverno.

### 2.4 Centralisation des Secrets avec HashiCorp Vault

La gestion des secrets par SOPS+age constitue une solution efficace pour les environnements de taille modeste. Néanmoins, elle présente des limitations en termes de **rotation automatique**, d'**audit granulaire** et de **scalabilité multi-cluster**. L'architecture cible prévoit la migration vers HashiCorp Vault couplé à l'External Secrets Operator (ESO).

Vault apporte une rotation automatique des secrets via son mécanisme de *lease*, un audit trail complet de chaque accès, et un contrôle d'accès granulaire basé sur des politiques HCL. L'ESO assure la synchronisation bidirectionnelle entre Vault et les Kubernetes Secrets natifs, rendant la migration transparente pour les applications consommatrices.

Les templates d'intégration (`ClusterSecretStore`, `ExternalSecret`) sont déjà préparés dans le répertoire `infra/secrets/external-secrets/`, démontrant la faisabilité architecturale de cette évolution.

### 2.5 Renforcement de l'Observabilité et de la Réponse aux Incidents

L'observabilité de la plateforme repose sur une stack Prometheus/Grafana/Loki/Alertmanager correctement architecturée. L'audit a identifié deux axes d'amélioration :

**Premièrement**, l'activation de **Falcosidekick** pour le routage des alertes runtime. Sans ce composant, les détections Falco (reverse shell, escalade de privilèges, accès à des fichiers sensibles) restent dans les logs locaux du DaemonSet sans notification vers l'équipe d'exploitation. L'activation de Falcosidekick avec routage vers Loki et Alertmanager transforme une détection passive en une capacité de réponse active.

**Deuxièmement**, l'enrichissement des règles d'alerte Prometheus avec cinq nouvelles alertes couvrant : la détection d'anomalies CPU (indicateur de cryptomining), les erreurs `ImagePullBackOff` (signal de rupture supply chain), les accès anormaux aux Secrets Kubernetes (exfiltration de credentials), la saturation des ResourceQuota (planification de capacité), et le désalignement des réplicas de déploiement (détection de drift).

### 2.6 Audit Logging Kubernetes Natif

L'activation de l'audit logging natif de Kubernetes constitue une couche de traçabilité complémentaire à Falco. Là où Falco opère au niveau des appels système (syscalls) via eBPF, l'audit logging Kubernetes trace les opérations au niveau de l'API Server : créations de pods, modifications de RBAC, accès aux secrets, et exécutions de commandes dans les conteneurs (`pods/exec`).

Une politique d'audit a été définie, ciblant les ressources sensibles du namespace `securerag-hub` avec un niveau `RequestResponse` pour les opérations les plus critiques (Secrets, pods/exec) et `Metadata` pour les opérations de modification standard.

### 2.7 Détection Précoce de Secrets avec Pre-commit Hooks

Le pipeline CI bloque les commits contenant des secrets via Gitleaks en stage `CI_SECURITY_STATIC`. Cependant, cette détection intervient *après* que le secret a été poussé dans l'historique Git. L'ajout de hooks pre-commit (Gitleaks + ShellCheck + validation YAML) déplace la détection **en amont du commit**, appliquant le principe *shift-left* à sa forme la plus radicale : le secret n'atteint jamais le dépôt distant.

---

## 3. Impact des Améliorations sur la Posture de Sécurité

L'implémentation de l'ensemble des améliorations décrites ci-dessus permettrait d'augmenter le score de maturité DevSecOps de **78/100 à 91/100**, franchissant le seuil du niveau « Excellent ». Le tableau suivant résume l'impact attendu par pilier :

| Pilier | Score Actuel | Gain Estimé | Score Cible |
|--------|:------------:|:-----------:|:-----------:|
| IAM & Gestion des Secrets | 17/20 | +1 (Vault roadmap) | 18/20 |
| SAST/SCA/DAST | 18/20 | +2 (DAST ZAP) | 20/20 |
| Supply Chain Security | 16/15 | — (déjà excellent) | 16/15 |
| IaC & Conteneurs | 14/20 | +4 (Enforce, audit policy) | 18/20 |
| Monitoring & Incidents | 8/15 | +5 (Falcosidekick, alertes) | 13/15 |
| Documentation | 5/5 | — | 5/5 |
| **Total** | **78/100** | **+13** | **91/100** |

---

## 4. Conclusion

L'analyse critique de la chaîne DevSecOps de SecureRAG Hub démontre une maturité significative pour un projet de fin d'études. Les fondations architecturales — Pod Security Standards *Restricted*, signature cryptographique Cosign, SBOM CycloneDX, provenance SLSA, détection runtime Falco alignée MITRE ATT&CK — dépassent les standards habituels des plateformes universitaires et s'approchent des pratiques industrielles.

Les axes d'amélioration identifiés ne relèvent pas de lacunes fondamentales mais d'optimisations progressives, confirmant que l'architecture a été conçue avec une vision d'évolution à long terme. La préparation des templates ExternalSecrets, de l'overlay Kyverno Enforce, et de la documentation DAST illustrent cette approche : chaque amélioration future est architecturalement anticipée, réduisant le coût et le risque de sa mise en œuvre.

Cette démarche d'amélioration continue incarne le principe fondamental du DevSecOps : la sécurité n'est pas un état final à atteindre, mais un processus itératif de renforcement permanent.

---

*Section rédigée pour le mémoire PFE — SecureRAG Hub, juin 2026*
