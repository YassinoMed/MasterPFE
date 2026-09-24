# SecureRAG Hub — Diagrammes PlantUML

> Diagrammes d'architecture complets en PlantUML : déploiement, composants, et fonctionnement.
> À compiler avec `plantuml diagramme.puml` ou via l'extension VS Code "PlantUML".

---

## 1. Vue Contexte (niveau 1)

```plantuml
@startuml Context
!theme plain
top to bottom direction

actor "Développeur" as dev
actor "Auditeur PFE" as aud
actor "Utilisateur final" as user

rectangle "SecureRAG Hub" <<Plateforme>> as sys {
  
  rectangle "Couche Applicative" <<Applicatif>> {
    [portal-web (Blade)]
    [auth-users]
    [chatbot-manager]
    [conversation-service]
    [audit-security-service]
  }

  rectangle "Couche Sécurité" <<SecOps>> {
    [Jenkins CI/CD]
    [Semgrep/Gitleaks/Trivy]
    [Cosign Sign/Verify]
    [SBOM CycloneDX]
    [Kyverno Admission]
    [Falco Runtime]
    [Vault/ESO]
  }

  rectangle "Couche Données" <<Data>> {
    database "postgres-auth"
  }
}

user --> [portal-web (Blade)] : HTTP :30081
dev --> [Jenkins CI/CD] : git push / webhook
[Jenkins CI/CD] --> [portal-web (Blade)] : deploy images signées
[chatbot-manager] --> [postgres-auth] : persist
[conversation-service] --> [postgres-auth] : persist
[auth-users] --> [postgres-auth] : persistance

aud ..> [SecOps] : consulte rapports
@enduml
```

---

## 2. Diagramme de déploiement (niveau 2)

```plantuml
@startuml Deployment
!theme plain
left to right direction

cloud "Client"
  [Navigateur web]
  [kubectl / ArgoCD]

node "Machine Docker Host" {
  node "kind cluster: securerag-dev" {
    
    node "Namespace: securerag-hub" {
      artifact "Deployment: portal-web\nreplicas: 1..3, HPA\nNodePort 30081" as d1
      artifact "Deployment: auth-users\nreplicas: 1..3, HPA" as d2
      artifact "Deployment: chatbot-manager\nreplicas: 1..3, HPA" as d3
      artifact "Deployment: conversation-service\nreplicas: 1..3, HPA" as d4
      artifact "Deployment: audit-security-service\nreplicas: 1..3, HPA" as d5
      artifact "Deployment: postgres-auth\nreplicas: 1" as d6
      database "Secret: portal-admin-token" as sec
      database "ConfigMap: securerag-common-config" as cfg
    }

    node "Namespace: kube-system" {
      artifact "Deployment: metrics-server" as ms
    }

    node "Namespace: kyverno" {
      artifact "Kyverno admission controller" as kv
      artifact "Kyverno background\ncontroller" as kvb
    }

    node "Namespace: monitoring" {
      artifact "Prometheus" as prom
      artifact "Grafana" as graf
      artifact "Loki" as loki
      artifact "Alertmanager" as alert
      artifact "Falco" as falco
    }

    node "Namespace: argocd" {
      artifact "ArgoCD server\n+ Applications" as argo
    }
  }

  node "Jenkins (docker-compose)" {
    artifact "securerag-jenkins\n+ SonarQube" as jen
  }

  node "Registry OCI" {
    artifact "localhost:5001\ncontainer images" as reg
  }
}

[Navigateur web] --> [portal-web (Blade)] : HTTP
[kubectl / ArgoCD] --> [ArgoCD server\n+ Applications] : sync

[d1] --> [d2/d3/d4/d5] : REST
[d1] --> [d6] : postgres://
[d2] --> [d6] : postgres://
[ms] ..|> [d1] : metrics
[prom] ..|> [d1] : /metrics
[loki] ..|> [d1] : stdout logs
[falco] ..|> [d1] : syscalls
[kv] --> [K8s API] : validate/mutate

[jen] --> [reg] : push dev
[jen] --> [d1] : sign images\nkubectl apply

@enduml
```

---

## 3. Diagramme de composants (niveau 3)

```plantuml
@startuml Components
!theme plain

package "platform/portal-web (Laravel 12)" {
  
  [routes/web.php]
  [routes/api.php]
  
  package "Http" {
    [Controllers]
    [Middleware\nSecurityHeaders]
    [Middleware\nRequireAdminToken]
  }
  
  package "Services" {
    [PortalBackendClient]
    [DemoPortalData]
  }
  
  [views (Blade)]
  [database migrations]
}

package "services-laravel/shared-security" {
  [SecurityHeaders]
  [PrometheusMetricsMiddleware]
  [SsrfProtectionMiddleware]
}

package "services-laravel/auth-users-service" {
  [Auth Controllers]
  [User Management]
  [JWT validation]
  [Role & Permissions]
}

package "services-laravel/chatbot-manager-service" {
  [Chatbot Controllers]
  [Conversation orchestration]
}

package "services-laravel/conversation-service" {
  [Conversation Controllers]
  [Message persistence]
}

package "services-laravel/audit-security-service" {
  [Audit Controllers]
  [Security logging]
  [Compliance evidence]
}

package "scripts/ci" {
  [run-tests.sh]
  [collect-coverage.sh]
  [quality-gate.sh]
  [validate-kyverno-policies.sh]
}

package "scripts/release" {
  [generate-sbom.sh]
  [sign-images.sh]
  [verify-signatures.sh]
  [promote-by-digest.sh]
  [generate-provenance.sh]
  [run-supply-chain-execute.sh]
}

package "scripts/deploy" {
  [verify-and-deploy-kind.sh]
  [install-kyverno.sh]
  [start-sonarqube.sh]
}

[portal-web (Blade)] --> [auth-users-service] : HTTP /api/v1
[portal-web (Blade)] --> [chatbot-manager-service] : HTTP /api/v1
[portal-web (Blade)] --> [conversation-service] : HTTP /api/v1
[portal-web (Blade)] --> [audit-security-service] : HTTP /api/v1

[auth-users-service] --> [shared-security]
[chatbot-manager-service] --> [shared-security]
[conversation-service] --> [shared-security]
[audit-security-service] --> [shared-security]

[run-supply-chain-execute.sh] --> [generate-sbom.sh] --> [sign-images.sh] --> [verify-signatures.sh] --> [promote-by-digest.sh] --> [generate-provenance.sh]

[verify-and-deploy-kind.sh] --> [K8s apply]
[install-kyverno.sh] --> [K8s apply]

@enduml
```

---

## 4. Diagramme de fonctionnement (séquence CI/CD)

```plantuml
@startuml SequenceCI
!theme plain

actor Dev as dev
participant "Git" as git
participant "Jenkins (CI)" as jenkins
participant "Scanners\n(Semgrep/Gitleaks/Trivy)" as scan
participant "SonarQube" as sonar
participant "Build Artifact\n(OCI images)" as build
participant "Registry\nlocalhost:5001" as reg
participant "Cosign" as cosign
participant "Kyverno" as kyv
participant "K8s Cluster" as k8s

dev -> git : git push (branch feature)
git -> jenkins : webhook payload

jenkins -> jenkins : checkout scm
activate jenkins

jenkins -> scan : SAST + secrets + FS scan
activate scan
scan --> jenkins : rapports JSON
deactivate scan

jenkins -> sonar : sast analyse (si activé)
activate sonar
sonar --> jenkins : quality gate
deactivate sonar

jenkins -> jenkins : PHPUnit\n98.39% coverage

jenkins -> build : docker build\nsecurerag-hub-XX:dev
activate build
build --> reg : push images
deactivate build

jenkins -> cosign : sign images\n(key-pair dev)
activate cosign
cosign --> reg : signatures\nattached to digest
deactivate cosign

jenkins -> cosign : verify signatures\n5/5 PASS requis
activate cosign
cosign --> jenkins : signed OK
deactivate cosign

jenkins -> cosign : promote-by-digest\ndev → release-local
activate cosign
cosign --> reg : release tags
deactivate cosign

jenkins -> k8s : kustomize apply\ninfra/k8s/overlays/dev
activate k8s

k8s --> kyv : admission control\ncheck images signed
activate kyv
kyv --> jenkins : admission OK
deactivate kyv

k8s --> jenkins : rollout status\n6/6 pods Running
activate jenkins

jenkins -> jenkins : smoke-tests\nsecurity-smoke\nadversarial
jenkins -> jenkins : final-proof\narchive artifacts

jenkins --> dev : Slack / email\n✅ SUCCESS

deactivate k8s
deactivate jenkins

@enduml
```

---

## 5. Diagramme de fonctionnement (state machine — pipeline Jenkins)

```plantuml
@startuml StateJenkins
!theme plain
[*] --> Checkout

Checkout --> Tests : code présent
Checkout --> [*] : pas de changement

state Tests {
  [*] --> Unit
  [*] --> SAST
  [*] --> Secrets
  Unit : PHPUnit 98.39%
  SAST : Semgrep/Sonar/Gitleaks
  Secrets : Gitleaks
}

Tests --> Build

state Build {
  [*] --> Images
  [*] --> SBOM
  Images : docker build\ndev tags
  SBOM : CycloneDX\npar image
}

Build --> Sign : conditions remplies

state Sign {
  [*] --> SignDigest
  [*] --> AttestSBOM
  SignDigest : cosign sign<br/>securerag-hub-XX:dev
  AttestSBOM : SBOM attaché\nau digest
}

Sign --> Verify : tous signés

state Verify {
  [*] --> CosignVerify
  CosignVerify : cosign verify<br/>cosign verify --key pub
}

Verify --> Promote : toutes PASS

state Promote {
  [*] --> PromoteDigest
  PromoteDigest : dev → release-local\ndigest immutable
}

Promote --> Deploy : optionnel

state Deploy {
  [*] --> ApplyManifests
  [*] --> HealthChecks
  [*] --> ProbesReady
}

Deploy --> Validate : optionnel

state Validate {
  [*] --> Smoke
  [*] --> Adversarial
  [-] --> SecuritySmoke
}

Validate --> Report : terminé

state Report {
  [*] --> Evidence
  [*] --> FinalProof
}

Report --> [*] : ✅ / ❌
@enduml
```

---

## 6. Diagramme des classes (packages métier Laravel)

```plantuml
@startuml Classes
!theme plain
hide empty members
left to right direction

package "platform/portal-web" {
  
  abstract class Controller {
    + middleware()
  }
  
  class DashboardController {
    +admin(): View
    +user(): View
    +users(): View
    +roles(): View
    +apiAdmin(): JsonResponse
    +apiUser(): JsonResponse
  }
  
  Controller <|.. DashboardController
  
  class PortalBackendClient {
    -backends: array
    +users(): Collection
    +chatbots(): Collection
    +conversations(): Collection
    +auditSecurity(): Collection
  }
  
  DashboardController ..> PortalBackendClient
  
  class RequireAdminToken {
    +handle(Request, Closure): Response
  }
  
  class SecurityHeaders {
    +handle(Request, Closure): Response
  }
  
}

package "services-laravel/shared-security" {
  
  class PrometheusMetricsMiddleware {
    +handle(Request, Closure)
    +wantRouteMetrics(): bool
  }
  
  class SsrfProtectionMiddleware {
    +handle(Request, Closure)
  }
  
}

package "services-laravel/auth-users-service" {
  
  class AuthController {
    +register()
    +login()
    +logout()
    +refresh()
  }
  
  class UserController {
    +index()
    +show()
    +store()
    +update()
    +destroy()
  }
  
  class RoleController {
    +index()
    +assign()
  }
  
}

DashboardController ..> AuthController : HTTP
DashboardController ..> PrometheusMetricsMiddleware : via (shared-security)

@enduml
```

---

## 7. Carte des secrets (gestion des accès)

```plantuml
@startuml Secrets
!theme plain

rectangle "Fichier .gitignore\ndev & credentials" as gitignore {
}

rectangle "security/keys/" as keys {
  [cosign.key]
  [cosign.pub]
  [cosign.password.txt]
}

rectangle "Secrets Kubernetes" as k8ssecrets {
  [portal-admin-token]
  [postgres-credentials]
  [cosign-keypair]
}

rectangle "Vault / ESO" as vault {
  [ExternalSecretsOperator]
  [SOPS + age]
}

rectangle "Secrets Jenkins" as jen {
  [jenkins-admin-password]
  [github-token]
  [sonar-token]
}

gitignore ..|> keys : jamais committé
gitignore ..|> k8ssecrets : jamais en clair
jen ..> jenkins_ci
vault --> ESO --> K8sSecrets sync

@enduml
```

---

## 8. Index des liens croisés

| Document | Lien |
|---|---|
| Architecture globale | `README.md` + `README-DEVSECOPS.md` |
| Stats pipeline | `DEVSECOPS_CHAIN_RESULTS.md` |
| Benchmarks | `docs/benchmarks/COMPREHENSIVE_BENCHMARK.md` |
| Stratégies de déploiement | `infra/k8s/overlays/` |
| Stories sources | `docs/architecture/official-scope.md` |
| Politiques | `infra/k8s/policies/` |

---

*Tous les diagrammes sont compilables avec PlantUML v1.2024+. Pour un render PNG/SVG en local : `plantuml -tsvg docs/architecture/diagrammes-plantuml.md` (extension .puml en-tête).*
