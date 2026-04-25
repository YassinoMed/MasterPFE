# CI/CD Authority - SecureRAG Hub

## Source officielle

Jenkins est l'autorité CI/CD officielle de SecureRAG Hub.

Il porte les responsabilités suivantes :

- CI : lint, tests Laravel, couverture, audits dépendances, Semgrep, Gitleaks, Trivy filesystem, validation statique Kubernetes/Kyverno et Sonar optionnel ;
- supply chain : build, scan image, signature Cosign, vérification, SBOM, attestation, provenance et promotion par digest ;
- CD : déploiement Kubernetes par image immuable et validation post-déploiement.

## GitHub Actions

Les workflows sous `.github/workflows/` sont conservés en miroir legacy non autoritatif. Ils doivent rester limités à `workflow_dispatch`.

Ils ne doivent pas redevenir déclenchés sur `push` ou `pull_request` sans décision explicite, car cela créerait une double source de vérité avec Jenkins.

## Preuve

```bash
make ci-authority-report
cat artifacts/final/ci-authority-report.md
```

## Lecture soutenance

La formulation correcte est :

> Jenkins est l'autorité officielle CI/CD. GitHub Actions est conservé uniquement comme historique manuel non autoritatif.
