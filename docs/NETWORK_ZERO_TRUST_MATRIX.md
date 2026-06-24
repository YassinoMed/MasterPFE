# SecureRAG Hub - Zero Trust Network Policy Matrix

This document outlines the strict Cilium-based network microsegmentation enforced across the Kubernetes cluster.

## 1. Global Cluster Posture
| Policy Type | Status | Enforcement | Description |
|---|---|---|---|
| **Default Ingress** | `DENY` | Cluster-Wide | All incoming traffic is dropped unless explicitly matched by a `CiliumNetworkPolicy`. |
| **Default Egress** | `DENY` | Cluster-Wide | All outbound traffic is dropped. Prevents data exfiltration and lateral movement. |
| **DNS Resolution** | `ALLOW` | Cluster-Wide | Outbound UDP/TCP 53 is allowed ONLY to `kube-system/kube-dns`. |
| **API Server** | `ALLOW` | Cluster-Wide | Outbound TCP 443 is allowed ONLY to the Kubernetes API server endpoint. |

## 2. Namespace: `argocd`
| Component | Flow | Type | Destination | Protocol | Port/Path | Rules |
|---|---|---|---|---|---|---|
| `argocd-repo-server` | Egress | FQDN | `*.github.com`, `github.com` | TCP | `443` | Allowed by FQDN only (IPs dynamically resolved via Cilium DNS proxy). |

## 3. Namespace: `securerag-hub` (L7 Microsegmentation)
| Source (Identity) | Flow | Destination (Identity) | Protocol | Port | HTTP Method | HTTP Path |
|---|---|---|---|---|---|---|
| `portal-web` | Ingress | `auth-users` | TCP | `8080` | `POST` | `/api/v1/login` |
| `portal-web` | Ingress | `auth-users` | TCP | `8080` | `GET` | `/healthz` |

*(Note: Any other method, e.g., `PUT`, `DELETE`, or accessing `/api/v1/admin` from `portal-web` to `auth-users` will be actively blocked by Cilium's Envoy proxy with an HTTP 403 Forbidden).*
