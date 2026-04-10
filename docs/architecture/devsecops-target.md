# DevSecOps Target Architecture — SecureRAG Hub

## Objectif
Décrire l’architecture DevSecOps cible de SecureRAG Hub dans une forme exploitable pour l’implémentation, la démonstration et le mémoire.

## Chaîne cible
1. Développeur pousse le code sur GitHub.
2. Jenkins CI exécute lint, tests, couverture et scans sécurité.
3. Un artefact OCI candidat est construit et publié dans la registry.
4. Le SBOM est généré.
5. L’image est signée avec Cosign.
6. Jenkins CD vérifie la signature, promeut le tag sans rebuild, puis déploie uniquement l’artefact vérifié.
7. `kind` exécute SecureRAG Hub avec Kustomize, politiques réseau et durcissement Kubernetes.
8. Les validations post-déploiement produisent des preuves archivables.

## Référentiel CI/CD
Jenkins est la source de vérité officielle.

Les workflows GitHub Actions encore présents dans le dépôt doivent être considérés comme hérités ou dépréciés, et non comme le pipeline de référence.

## Contrôles DevSecOps principaux
- tests automatisés
- couverture minimale
- Semgrep
- Gitleaks
- Trivy
- SBOM CycloneDX
- signature Cosign
- vérification de signature avant promotion et avant déploiement
- promotion d'artefacts sans reconstruction
- validation post-déploiement

## Cible Kubernetes
- `kind` pour la démonstration locale
- namespace `securerag-hub`
- base/overlay Kustomize
- `NetworkPolicy`
- `securityContext`
- `ResourceQuota`
- `LimitRange`
- `PodDisruptionBudget`
- `HorizontalPodAutoscaler` sur les points d'entree les plus critiques
- probes `readiness` / `liveness`
- policies Kyverno optionnelles pour l'admission et la verification d'images signees

## Runtime de démonstration
- mode standard : runtime complet avec `Qdrant` et `Ollama`
- mode démonstration : fallback documenté si `Ollama` est trop lourd ou instable
