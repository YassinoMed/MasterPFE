# Production HA Readiness - SecureRAG Hub

- Overlay: `infra/k8s/overlays/production`
- Generated at UTC: `2026-04-17T06:18:34Z`

| Component | Control | Status | Evidence |
|---|---|---:|---|
| `portal-web` | Deployment rendered | TERMINÉ | `Deployment portal-web` |
| `portal-web` | replicas >= 3 | TERMINÉ | `replicas=3` |
| `portal-web` | RollingUpdate enabled | TERMINÉ | `strategy.type=RollingUpdate` |
| `portal-web` | rolling maxUnavailable=0 | TERMINÉ | `maxUnavailable=0` |
| `portal-web` | rolling maxSurge=1 | TERMINÉ | `maxSurge=1` |
| `portal-web` | minReadySeconds configured | TERMINÉ | `minReadySeconds=10` |
| `portal-web` | soft pod anti-affinity | TERMINÉ | `preferred anti-affinity on kubernetes.io/hostname` |
| `portal-web` | topology spread constraint | TERMINÉ | `topologyKey=kubernetes.io/hostname` |
| `portal-web` | readinessProbe | TERMINÉ | `all containers define readinessProbe` |
| `portal-web` | livenessProbe | TERMINÉ | `all containers define livenessProbe` |
| `portal-web` | startupProbe | TERMINÉ | `all containers define startupProbe` |
| `portal-web` | PDB rendered | TERMINÉ | `portal-web-pdb` |
| `portal-web` | PDB minAvailable coherent | TERMINÉ | `minAvailable=2, replicas=3` |
| `portal-web` | HPA rendered | TERMINÉ | `HorizontalPodAutoscaler portal-web` |
| `portal-web` | HPA minReplicas >= deployment floor | TERMINÉ | `minReplicas=3` |
| `portal-web` | HPA maxReplicas > minReplicas | TERMINÉ | `maxReplicas=9, minReplicas=3` |
| `portal-web` | HPA CPU and memory metrics | TERMINÉ | `metrics=cpu,memory` |
| `auth-users` | Deployment rendered | TERMINÉ | `Deployment auth-users` |
| `auth-users` | replicas >= 2 | TERMINÉ | `replicas=2` |
| `auth-users` | RollingUpdate enabled | TERMINÉ | `strategy.type=RollingUpdate` |
| `auth-users` | rolling maxUnavailable=0 | TERMINÉ | `maxUnavailable=0` |
| `auth-users` | rolling maxSurge=1 | TERMINÉ | `maxSurge=1` |
| `auth-users` | minReadySeconds configured | TERMINÉ | `minReadySeconds=10` |
| `auth-users` | soft pod anti-affinity | TERMINÉ | `preferred anti-affinity on kubernetes.io/hostname` |
| `auth-users` | topology spread constraint | TERMINÉ | `topologyKey=kubernetes.io/hostname` |
| `auth-users` | readinessProbe | TERMINÉ | `all containers define readinessProbe` |
| `auth-users` | livenessProbe | TERMINÉ | `all containers define livenessProbe` |
| `auth-users` | startupProbe | TERMINÉ | `all containers define startupProbe` |
| `auth-users` | PDB rendered | TERMINÉ | `auth-users-pdb` |
| `auth-users` | PDB minAvailable coherent | TERMINÉ | `minAvailable=1, replicas=2` |
| `auth-users` | HPA rendered | TERMINÉ | `HorizontalPodAutoscaler auth-users` |
| `auth-users` | HPA minReplicas >= deployment floor | TERMINÉ | `minReplicas=2` |
| `auth-users` | HPA maxReplicas > minReplicas | TERMINÉ | `maxReplicas=6, minReplicas=2` |
| `auth-users` | HPA CPU and memory metrics | TERMINÉ | `metrics=cpu,memory` |
| `chatbot-manager` | Deployment rendered | TERMINÉ | `Deployment chatbot-manager` |
| `chatbot-manager` | replicas >= 2 | TERMINÉ | `replicas=2` |
| `chatbot-manager` | RollingUpdate enabled | TERMINÉ | `strategy.type=RollingUpdate` |
| `chatbot-manager` | rolling maxUnavailable=0 | TERMINÉ | `maxUnavailable=0` |
| `chatbot-manager` | rolling maxSurge=1 | TERMINÉ | `maxSurge=1` |
| `chatbot-manager` | minReadySeconds configured | TERMINÉ | `minReadySeconds=10` |
| `chatbot-manager` | soft pod anti-affinity | TERMINÉ | `preferred anti-affinity on kubernetes.io/hostname` |
| `chatbot-manager` | topology spread constraint | TERMINÉ | `topologyKey=kubernetes.io/hostname` |
| `chatbot-manager` | readinessProbe | TERMINÉ | `all containers define readinessProbe` |
| `chatbot-manager` | livenessProbe | TERMINÉ | `all containers define livenessProbe` |
| `chatbot-manager` | startupProbe | TERMINÉ | `all containers define startupProbe` |
| `chatbot-manager` | PDB rendered | TERMINÉ | `chatbot-manager-pdb` |
| `chatbot-manager` | PDB minAvailable coherent | TERMINÉ | `minAvailable=1, replicas=2` |
| `chatbot-manager` | HPA rendered | TERMINÉ | `HorizontalPodAutoscaler chatbot-manager` |
| `chatbot-manager` | HPA minReplicas >= deployment floor | TERMINÉ | `minReplicas=2` |
| `chatbot-manager` | HPA maxReplicas > minReplicas | TERMINÉ | `maxReplicas=6, minReplicas=2` |
| `chatbot-manager` | HPA CPU and memory metrics | TERMINÉ | `metrics=cpu,memory` |
| `conversation-service` | Deployment rendered | TERMINÉ | `Deployment conversation-service` |
| `conversation-service` | replicas >= 2 | TERMINÉ | `replicas=2` |
| `conversation-service` | RollingUpdate enabled | TERMINÉ | `strategy.type=RollingUpdate` |
| `conversation-service` | rolling maxUnavailable=0 | TERMINÉ | `maxUnavailable=0` |
| `conversation-service` | rolling maxSurge=1 | TERMINÉ | `maxSurge=1` |
| `conversation-service` | minReadySeconds configured | TERMINÉ | `minReadySeconds=10` |
| `conversation-service` | soft pod anti-affinity | TERMINÉ | `preferred anti-affinity on kubernetes.io/hostname` |
| `conversation-service` | topology spread constraint | TERMINÉ | `topologyKey=kubernetes.io/hostname` |
| `conversation-service` | readinessProbe | TERMINÉ | `all containers define readinessProbe` |
| `conversation-service` | livenessProbe | TERMINÉ | `all containers define livenessProbe` |
| `conversation-service` | startupProbe | TERMINÉ | `all containers define startupProbe` |
| `conversation-service` | PDB rendered | TERMINÉ | `conversation-service-pdb` |
| `conversation-service` | PDB minAvailable coherent | TERMINÉ | `minAvailable=1, replicas=2` |
| `conversation-service` | HPA rendered | TERMINÉ | `HorizontalPodAutoscaler conversation-service` |
| `conversation-service` | HPA minReplicas >= deployment floor | TERMINÉ | `minReplicas=2` |
| `conversation-service` | HPA maxReplicas > minReplicas | TERMINÉ | `maxReplicas=8, minReplicas=2` |
| `conversation-service` | HPA CPU and memory metrics | TERMINÉ | `metrics=cpu,memory` |
| `audit-security-service` | Deployment rendered | TERMINÉ | `Deployment audit-security-service` |
| `audit-security-service` | replicas >= 2 | TERMINÉ | `replicas=2` |
| `audit-security-service` | RollingUpdate enabled | TERMINÉ | `strategy.type=RollingUpdate` |
| `audit-security-service` | rolling maxUnavailable=0 | TERMINÉ | `maxUnavailable=0` |
| `audit-security-service` | rolling maxSurge=1 | TERMINÉ | `maxSurge=1` |
| `audit-security-service` | minReadySeconds configured | TERMINÉ | `minReadySeconds=10` |
| `audit-security-service` | soft pod anti-affinity | TERMINÉ | `preferred anti-affinity on kubernetes.io/hostname` |
| `audit-security-service` | topology spread constraint | TERMINÉ | `topologyKey=kubernetes.io/hostname` |
| `audit-security-service` | readinessProbe | TERMINÉ | `all containers define readinessProbe` |
| `audit-security-service` | livenessProbe | TERMINÉ | `all containers define livenessProbe` |
| `audit-security-service` | startupProbe | TERMINÉ | `all containers define startupProbe` |
| `audit-security-service` | PDB rendered | TERMINÉ | `audit-security-service-pdb` |
| `audit-security-service` | PDB minAvailable coherent | TERMINÉ | `minAvailable=1, replicas=2` |
| `audit-security-service` | HPA rendered | TERMINÉ | `HorizontalPodAutoscaler audit-security-service` |
| `audit-security-service` | HPA minReplicas >= deployment floor | TERMINÉ | `minReplicas=2` |
| `audit-security-service` | HPA maxReplicas > minReplicas | TERMINÉ | `maxReplicas=6, minReplicas=2` |
| `audit-security-service` | HPA CPU and memory metrics | TERMINÉ | `metrics=cpu,memory` |

## Interpretation

Statut global: TERMINÉ. L'overlay production rend les controles HA statiques attendus.

## Limite runtime

Cette validation est statique. Les preuves runtime exigent un cluster actif, metrics-server et `kubectl get deploy,pods,pdb,hpa -n securerag-hub`.
