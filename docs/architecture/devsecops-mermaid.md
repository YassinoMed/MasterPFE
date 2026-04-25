# SecureRAG Hub — Diagrammes Mermaid DevSecOps

Ce document regroupe les diagrammes Mermaid principaux de la chaine DevSecOps du projet \texttt{SecureRAG Hub}. Chaque bloc peut etre copie tel quel dans un document Markdown, un README, une documentation interne ou un support de soutenance compatible Mermaid.

## 1. Vue globale DevSecOps

```mermaid
flowchart LR
  A["GitHub Monorepo"] --> B["Jenkins CI"]
  A --> C["Jenkins CD"]

  B --> B1["Lint"]
  B --> B2["Tests + Coverage"]
  B --> B3["Semgrep"]
  B --> B4["Gitleaks"]
  B --> B5["Trivy FS"]
  B --> B6["Artefacts CI"]

  C --> C1["Verify"]
  C --> C2["Promote"]
  C --> C3["Deploy"]
  C --> C4["Validate"]
  C --> C5["Artefacts CD"]

  C3 --> D["Cluster kind"]
  D --> D1["Services Laravel"]
  D --> D2["portal-web"]
  D --> D3["NetworkPolicies"]
  D --> D4["Kyverno audit ready"]
```

## 2. Pipeline CI Jenkins

```mermaid
flowchart TD
  A["Commit / Push"] --> B["Job Jenkins CI"]
  B --> C["Checkout du repo"]
  C --> D["make lint"]
  D --> E["make test"]
  E --> F["Semgrep"]
  F --> G["Gitleaks"]
  G --> H["Trivy filesystem"]
  H --> I["Archivage rapports"]
  I --> J["Statut CI"]
```

## 3. Pipeline CD et supply chain

```mermaid
flowchart LR
  A["Images OCI locales"] --> B["Generate SBOM (Syft)"]
  B --> C["Sign images (Cosign)"]
  C --> D["Verify signatures"]
  D --> E["Promote verified tag"]
  E --> F["Release tag pret au deploy"]

  B --> B1["artifacts/sbom"]
  C --> C1["sign-summary.txt"]
  D --> D1["verify-summary.txt"]
  E --> E1["promotion-summary.txt"]
```

## 4. Job Jenkins CD

```mermaid
flowchart TD
  A["Job Jenkins CD"] --> B["Verifier le tag source"]
  B --> C["Promouvoir sans rebuild"]
  C --> D["Verifier le tag promu"]
  D --> E["Deploy sur kind"]
  E --> F["Validation post-deploiement"]
  F --> G["Collecte de preuves"]
  G --> H["Artefacts finaux"]
```

## 5. Deploiement Kubernetes local

```mermaid
flowchart LR
  A["Docker local"] --> B["Registry cluster-side securerag-registry:5000"]
  B --> C["Cluster kind"]
  C --> D["Overlay officiel avec images @sha256"]
  D --> E["portal-web"]
  D --> F["auth-users"]
  D --> G["chatbot-manager"]
  D --> H["conversation-service"]
  D --> I["audit-security-service"]
```

## 6. Securite du cluster

```mermaid
flowchart TD
  A["Namespace securerag-hub"] --> B["NetworkPolicy"]
  A --> C["SecurityContext"]
  A --> D["ResourceQuota"]
  A --> E["LimitRange"]
  A --> F["PodDisruptionBudget"]
  A --> G["HPA"]
  A --> H["Kyverno"]

  H --> H1["Pod Security Policy (Audit)"]
  H --> H2["Cosign Verify Policy (Audit ou Enforce)"]

  G --> G1["metrics-server requis"]
```

## 7. Addons du cluster

```mermaid
flowchart LR
  A["Cluster kind"] --> B["metrics-server"]
  A --> C["Kyverno"]

  B --> B1["kubectl top nodes"]
  B --> B2["kubectl top pods"]
  B --> B3["HPA avec CPU reelle"]

  C --> C1["ClusterPolicy Ready"]
  C --> C2["Audit mode"]
  C --> C3["Enforce mode"]
```

## 8. Gestion des secrets

```mermaid
flowchart TD
  A["Secrets Strategy"] --> B["Local dev"]
  A --> C["Jenkins"]
  A --> D["Kubernetes"]

  B --> B1["security/secrets/.env.local"]
  B --> B2["bootstrap-local-secrets.sh"]

  C --> C1["cosign-private-key"]
  C --> C2["cosign-public-key"]
  C --> C3["cosign-password"]

  D --> D1["kubectl create secret"]
  D --> D2["securerag-common-secrets"]
  D --> D3["secretRef dans les workloads"]
```

## 9. Runtime officiel vs legacy

```mermaid
flowchart LR
  A["Choix runtime"] --> B["Officiel Laravel-first"]
  A --> C["Legacy RAG/Ollama"]

  B --> B1["portal-web"]
  B --> B2["auth-users"]
  B --> B3["chatbot-manager"]
  B --> B4["conversation-service"]
  B --> B5["audit-security-service"]

  C --> C1["Sources Python absentes"]
  C --> C2["Build/deploy officiel exclu"]
  C --> C3["Revalidation requise avant retour"]
```

## 10. Validation et preuves

```mermaid
flowchart TD
  A["make validate"] --> B["smoke-tests.sh"]
  A --> C["security-smoke.sh"]
  A --> D["e2e-functional-flow.sh"]
  A --> E["rag-smoke.sh legacy opt-in"]
  A --> F["security-adversarial-advanced.sh"]
  A --> G["generate-validation-report.sh"]
  A --> H["collect-runtime-evidence.sh"]

  H --> I["artifacts/validation"]
  I --> I1["validation-summary.md"]
  I --> I2["k8s-pods.txt"]
  I --> I3["k8s-hpa.txt"]
  I --> I4["k8s-resourcequota.txt"]
  I --> I5["k8s-kyverno-policies.txt"]
```

## 11. Campagne finale de reference

```mermaid
flowchart LR
  A["run-reference-campaign.sh"] --> B["Verify"]
  B --> C["Promote"]
  C --> D["Deploy"]
  D --> E["Validate"]
  E --> F["Collect evidence"]

  A --> G["Mode execute"]
  A --> H["Mode dry-run"]

  F --> I["artifacts/final/reference-campaign-summary.md"]
  F --> J["artifacts/final/rendered-overlay.yaml"]
  F --> K["artifacts/final/cluster-context.txt"]
```

## 12. Gouvernance CI/CD

```mermaid
flowchart TD
  A["Source d'autorite CI/CD"] --> B["Jenkins"]
  A --> C["GitHub Actions legacy"]

  B --> B1["CI officielle"]
  B --> B2["CD officielle"]

  C --> C1["workflow_dispatch uniquement"]
  C --> C2["Historique / fallback"]
  C --> C3["Pas de double execution"]
```
