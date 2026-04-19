# SecureRAG Hub — Diagrammes Mermaid pas à pas DevSecOps

Ce document fournit des diagrammes Mermaid prêts à copier dans le mémoire, la soutenance ou la documentation technique. Le périmètre est strictement DevSecOps, Kubernetes, sécurité, supply chain, observabilité, résilience et preuves.

## 1. Vue globale DevSecOps

```mermaid
flowchart LR
  A["Développeur / Git"] --> B["Jenkins CI"]
  B --> C["Contrôles qualité et sécurité"]
  C --> D["Build images OCI"]
  D --> E["Supply chain"]
  E --> F["Promotion par digest"]
  F --> G["Jenkins CD"]
  G --> H["Kubernetes production-like"]
  H --> I["Preuves runtime"]
  I --> J["Support pack final"]
```

## 2. Gouvernance du dépôt

```mermaid
flowchart TD
  A["Monorepo SecureRAG Hub"] --> B["platform/portal-web"]
  A --> C["services-laravel/*"]
  A --> D["infra/k8s + kind + jenkins"]
  A --> E["scripts/ci release deploy validate"]
  A --> F["security/"]
  A --> G["docs/"]
  A --> H["artifacts/"]

  D --> I["Manifests versionnés"]
  E --> J["Automatisation reproductible"]
  F --> K["Règles sécurité"]
  G --> L["Runbooks et mémoire"]
  H --> M["Preuves archivées"]
```

## 3. Déclenchement CI Jenkins

```mermaid
sequenceDiagram
  participant Dev as Développeur
  participant Git as Dépôt Git
  participant Jenkins as Jenkins CI
  participant Artifacts as Artefacts CI

  Dev->>Git: push / merge request
  Git->>Jenkins: webhook ou déclenchement manuel
  Jenkins->>Git: checkout
  Jenkins->>Jenkins: lint, tests, scans
  Jenkins->>Artifacts: archive rapports
```

## 4. Pipeline CI qualité

```mermaid
flowchart LR
  A["Checkout"] --> B["make lint"]
  B --> C["Tests Laravel"]
  C --> D["Couverture"]
  D --> E["Audit dépendances"]
  E --> F{"Quality Gate CI"}
  F -->|OK| G["Artefacts CI archivés"]
  F -->|KO| H["Pipeline bloqué"]
```

## 5. Contrôles sécurité code

```mermaid
flowchart TD
  A["Code source"] --> B["Semgrep SAST"]
  A --> C["Gitleaks secrets"]
  A --> D["Trivy filesystem"]
  A --> E["Composer audit"]
  A --> F["npm audit si lockfile"]
  A --> G["Sonar optionnel"]

  B --> H{"Gate sécurité"}
  C --> H
  D --> H
  E --> H
  F --> H
  G --> H

  H -->|PASS| I["CI continue"]
  H -->|FAIL| J["Correction requise"]
```

## 6. Validation statique Kubernetes

```mermaid
flowchart LR
  A["Manifests Kustomize"] --> B["Render dev"]
  A --> C["Render demo"]
  A --> D["Render production"]
  B --> E["Resource guards"]
  C --> E
  D --> E
  E --> F["Ultra hardening"]
  F --> G["Rapports sécurité statiques"]
```

## 7. Construction des images OCI

```mermaid
flowchart LR
  A["Sources Laravel officielles"] --> B["Dockerfiles production"]
  B --> C["docker build"]
  C --> D["Tag image"]
  D --> E["Push localhost:5001"]
  E --> F["Image candidate"]
```

## 8. Scan image Trivy

```mermaid
flowchart TD
  A["Image candidate"] --> B["Trivy image scan"]
  B --> C{"Vulnérabilité critique ?"}
  C -->|Non| D["Scan PASS"]
  C -->|Oui| E["Release bloquée"]
  D --> F["image-scan-summary.txt"]
  E --> G["Correction image ou dépendance"]
```

## 9. Génération SBOM Syft

```mermaid
flowchart LR
  A["Image candidate"] --> B["Syft"]
  B --> C["SBOM CycloneDX"]
  C --> D["artifacts/sbom"]
  D --> E["sbom-index.txt"]
  E --> F["Preuve de composition logicielle"]
```

## 10. Signature Cosign

```mermaid
flowchart LR
  A["Image scannée"] --> B["Clé Cosign ou identité keyless"]
  B --> C["cosign sign"]
  C --> D["Signature OCI"]
  D --> E["sign-summary.txt"]
```

## 11. Vérification Cosign

```mermaid
flowchart TD
  A["Image signée"] --> B["cosign verify"]
  B --> C{"Signature valide ?"}
  C -->|Oui| D["Image vérifiée"]
  C -->|Non| E["Release bloquée"]
  D --> F["verify-summary.txt"]
  E --> G["Investigation supply chain"]
```

## 12. Promotion par digest

```mermaid
flowchart LR
  A["Image vérifiée"] --> B["Résolution digest"]
  B --> C["Promotion tag cible"]
  C --> D["promotion-digests.txt"]
  D --> E["Artefact immuable"]
  E --> F["Déploiement no-rebuild"]
```

## 13. Gate release obligatoire

```mermaid
flowchart TD
  A["Preuves release"] --> B["Trivy présent"]
  A --> C["SBOM présent"]
  A --> D["Signature présente"]
  A --> E["Verify présent"]
  A --> F["Digest présent"]
  B --> G{"Evidence gate"}
  C --> G
  D --> G
  E --> G
  F --> G
  G -->|Complet| H["Release autorisée"]
  G -->|Manquant| I["Release bloquée"]
```

## 14. Déploiement CD sans rebuild

```mermaid
flowchart LR
  A["Digest promu"] --> B["Jenkins CD"]
  B --> C["Verify pre-deploy"]
  C --> D["Kustomize production"]
  D --> E["kubectl apply"]
  E --> F["Rollout status"]
  F --> G["Smoke tests"]
  G --> H["Runtime evidence"]
```

## 15. Architecture Kubernetes production-like

```mermaid
flowchart TD
  A["Namespace securerag-hub"] --> B["portal-web replicas 3"]
  A --> C["auth-users replicas 2"]
  A --> D["chatbot-manager replicas 2"]
  A --> E["conversation-service replicas 2"]
  A --> F["audit-security-service replicas 2"]

  A --> G["NetworkPolicies"]
  A --> H["PDB"]
  A --> I["HPA"]
  A --> J["ResourceQuota / LimitRange"]
  A --> K["Pod Security restricted"]

  B --> L["NodePort 30081"]
```

## 16. Durcissement Kubernetes

```mermaid
flowchart TD
  A["Deployment"] --> B["ServiceAccount dédié"]
  A --> C["runAsNonRoot"]
  A --> D["allowPrivilegeEscalation false"]
  A --> E["readOnlyRootFilesystem true"]
  A --> F["seccomp RuntimeDefault"]
  A --> G["drop ALL capabilities"]
  A --> H["requests / limits"]
  A --> I["readiness / liveness / startup probes"]
```

## 17. Séparation production / legacy

```mermaid
flowchart TD
  A["Runtime Kubernetes"] --> B["Overlay production officiel"]
  A --> C["Legacy exclu"]

  B --> D["5 workloads Laravel officiels"]
  B --> E["Validation cluster clean"]
  B --> F["NodePort portail officiel"]

  C --> G["Pas de kustomization legacy déployable"]
  C --> H["Cleanup contrôlé"]
  C --> I["Preuves honnêtes"]
```

## 18. metrics-server et HPA runtime

```mermaid
flowchart LR
  A["Cluster actif"] --> B["metrics-server installé"]
  B --> C["APIService Available"]
  C --> D["kubectl top nodes"]
  C --> E["kubectl top pods"]
  D --> F["HPA targets"]
  E --> F
  F --> G{"<unknown> absent ?"}
  G -->|Oui| H["HPA runtime TERMINÉ"]
  G -->|Non| I["HPA PARTIEL"]
  H --> J["hpa-runtime-report.md"]
```

## 19. Kyverno Audit

```mermaid
flowchart TD
  A["Cluster Kubernetes"] --> B["Installer Kyverno"]
  B --> C["CRDs Kyverno"]
  C --> D["Pods Kyverno Ready"]
  D --> E["Apply policies Audit"]
  E --> F["ClusterPolicies"]
  F --> G["PolicyReports"]
  G --> H["Rapport Kyverno runtime"]
```

## 20. Préparation Kyverno Enforce

```mermaid
flowchart TD
  A["PolicyReports Audit"] --> B{"Violations corrigées ?"}
  B -->|Non| C["Rester en Audit"]
  B -->|Oui| D{"Supply chain signée ?"}
  D -->|Non| E["Enforce interdit"]
  D -->|Oui| F["Test Enforce prudent"]
  F --> G["Rollback possible"]
```

## 21. Secrets management

```mermaid
flowchart TD
  A["Secrets strategy"] --> B["Aucun secret réel dans Git"]
  A --> C["Bootstrap local"]
  A --> D["Credentials Jenkins"]
  A --> E["Secrets Kubernetes"]
  A --> F["Rotation documentée"]

  B --> G[".env.example uniquement"]
  C --> H["scripts/secrets"]
  D --> I["infra/jenkins/secrets local"]
  E --> J["secretRef workloads"]
```

## 22. DB externe, backup et restore

```mermaid
flowchart LR
  A["Workloads Laravel"] --> B["DB externe PostgreSQL"]
  B --> C["Backup"]
  C --> D["Archive backup"]
  D --> E["Restore test"]
  E --> F{"Restore OK ?"}
  F -->|Oui| G["Preuve résilience données"]
  F -->|Non| H["Runbook incident"]
```

## 23. Observabilité runtime

```mermaid
flowchart TD
  A["Cluster runtime"] --> B["Deployments / Pods / Services"]
  A --> C["PDB / HPA"]
  A --> D["Events Kubernetes"]
  A --> E["Logs applicatifs"]
  A --> F["kubectl top"]
  A --> G["Kyverno PolicyReports"]

  B --> H["observability-snapshot.md"]
  C --> H
  D --> H
  E --> H
  F --> H
  G --> H
```

## 24. Support pack final

```mermaid
flowchart LR
  A["Artefacts CI"] --> F["Support pack"]
  B["Artefacts release"] --> F
  C["Artefacts Kubernetes"] --> F
  D["Artefacts sécurité"] --> F
  E["Runbooks"] --> F
  F --> G["Archive finale"]
  G --> H["Mémoire / Soutenance"]
```

## 25. Tableau d’état final

```mermaid
flowchart TD
  A["Collecte preuves"] --> B["TERMINÉ"]
  A --> C["PARTIEL"]
  A --> D["PRÊT_NON_EXÉCUTÉ"]
  A --> E["DÉPENDANT_DE_L_ENVIRONNEMENT"]

  B --> F["Contrôle prouvé"]
  C --> G["Contrôle incomplet"]
  D --> H["Scripts prêts mais non lancés"]
  E --> I["Dépend de Docker/kind/registry/outils"]

  F --> J["Tableau final global"]
  G --> J
  H --> J
  I --> J
```

## 26. Chaîne complète de preuves

```mermaid
flowchart LR
  A["CI reports"] --> B["Security reports"]
  B --> C["Image scan"]
  C --> D["SBOM"]
  D --> E["Signature"]
  E --> F["Verify"]
  F --> G["Digest promotion"]
  G --> H["Deploy evidence"]
  H --> I["Runtime evidence"]
  I --> J["Support pack"]
```

