# Matrice de Flux Réseau (Zero Trust Architecture)

Ce document répertorie l'ensemble des flux réseaux autorisés entre les différents composants de l'application SecureRAG Hub. Toute communication non listée ici est **bloquée par défaut** selon le principe du Zero Trust.

## 1. Flux Applicatifs Internes (securerag-hub)

| Source (Egress) | Destination (Ingress) | Port | Protocole | Niveau L7 (Cilium) |
| :--- | :--- | :--- | :--- | :--- |
| **api-gateway** | `auth-users`, `chatbot-manager`, `llm-orchestrator` | 8080 | TCP | HTTP `.*` |
| **portal-web** | `auth-users`, `chatbot-manager`, `conversation-service`, `audit-security-service` | 8000 | TCP | HTTP `.*` |
| **chatbot-manager** | `auth-users` | 8000 | TCP | HTTP `.*` |
| **llm-orchestrator** | `chatbot-manager`, `auth-users`, `security-auditor` | 8000/8080 | TCP | HTTP `.*` |
| **security-auditor** | `knowledge-hub` | 8080 | TCP | HTTP `.*` |
| **security-auditor** | `ollama` | 11434 | TCP | HTTP `.*` |
| **knowledge-hub** | `qdrant` | 6333 | TCP | (L4 seulement) |
| **auth-users** | `postgres-auth` | 5432 | TCP | (L4 seulement) |

*Note: Le trafic entrant global (Ingress / LoadBalancer) vers `api-gateway` et `portal-web` est autorisé depuis le cluster et l'extérieur.*

## 2. Flux d'Observabilité et d'Infrastructure (Transverse)

Ces flux utilisent une **CiliumClusterwideNetworkPolicy** pour s'affranchir des limitations inter-namespaces.

| Source (Namespace) | Destination | Port | Protocole | Fonction |
| :--- | :--- | :--- | :--- | :--- |
| **securerag-monitoring** (Prometheus) | Tous les pods (Cluster-wide) | 8000, 8080, 9000 | TCP | Scraping des métriques |
| Tous les namespaces | **otel-system** (`otel-collector`) | 4317, 4318 | TCP / HTTP | Export des traces/logs OTLP |
| Tous les namespaces | **kube-system** (`kube-dns`) | 53 | UDP / TCP | Résolution DNS globale |

## 3. Implémentation technique

La sécurité est implémentée via des **CiliumNetworkPolicy (CNP)**, offrant plusieurs avantages par rapport aux `NetworkPolicy` natives :
- **Filtrage L7** : Le proxy Envoy intégré à Cilium intercepte et valide que le trafic est bien une requête HTTP valide (pas de trafic binaire masqué).
- **Flexibilité inter-namespace** : Les règles `CiliumClusterwideNetworkPolicy` résolvent les conflits de monitoring observés avec les règles natives.
- **Migration Zero Downtime** : Déployées en parallèle des anciennes règles, elles prennent l'ascendant sans causer d'interruption.
