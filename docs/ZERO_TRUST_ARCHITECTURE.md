# Zero Trust Architecture (BeyondCorp Style)

## Introduction
This document outlines the cryptographic workload-to-workload identity and Zero Trust network enforcement architecture implemented in the SecureRAG Hub Kubernetes cluster, adhering to the BeyondCorp philosophy.

## Core Principles
1. **Never Trust, Always Verify**: Network locality (e.g., being in the same namespace or on the same node) is not sufficient for access.
2. **Cryptographic Identity**: Every workload possesses a unique, cryptographically verifiable identity (SPIFFE ID).
3. **Mutual TLS (mTLS)**: All internal traffic is encrypted and mutually authenticated. No plaintext internal traffic is permitted.
4. **Least Privilege Enforcement**: Traffic is denied by default and explicitly allowed based on identity and intention.

## Architecture Components

### 1. SPIFFE/SPIRE (Identity Control Plane)
SPIRE (the SPIFFE Runtime Environment) acts as the foundation of our Zero Trust architecture.

- **SPIRE Server**: The central CA that manages and issues identities. It uses node attestation (via Kubernetes Projected Service Account Tokens - PSAT) to verify the identity of the physical/virtual nodes running in the cluster.
- **SPIRE Agent**: Runs as a DaemonSet on every node. It attests local workloads by interrogating the Kubernetes API to verify properties like Namespace, ServiceAccount, and Pod labels.
- **Kubernetes Workload Registrar**: A controller running alongside the SPIRE Server. It automatically watches for new Pods and creates SPIFFE entries for them. The resulting identity takes the form: `spiffe://cluster.local/ns/<namespace>/sa/<serviceaccount>`.

### 2. Istio (Data Plane Enforcement)
Istio acts as the enforcement point for network policies and handles the actual mTLS negotiation.

- **Envoy SDS Integration**: Instead of relying on Istio's built-in CA (Istiod), the Envoy sidecar proxies are configured via an `EnvoyFilter` (`spire-sds-integration`) to use the Secret Discovery Service (SDS) API. The proxies fetch their X.509 SVIDs (SPIFFE Verifiable Identity Documents) directly from the local SPIRE Agent over a secure Unix Domain Socket (`/run/spire/sockets/agent.sock`).
- **Strict mTLS**: Configured via `PeerAuthentication`, Istio drops any inbound connection that does not use mTLS.
- **Authorization Policies**: The `AuthorizationPolicy` manifests default to `DENY_ALL`. We then declare specific `ALLOW` rules evaluating the `source.principals` against the expected SPIFFE IDs. If `portal-web` attempts to connect to `auth-users-service`, the proxy verifies the cryptography of the SPIFFE ID before routing the request.

## Traffic Flow Example
1. Pod A (`portal-web`) attempts an HTTP request to Pod B (`auth-users-service`).
2. Pod A's Envoy proxy intercepts the request.
3. Pod A's Envoy establishes an mTLS connection with Pod B's Envoy proxy. Both proxies present their SPIFFE certificates obtained from SPIRE.
4. Pod B's proxy verifies Pod A's certificate against the SPIRE trust bundle.
5. Pod B's proxy evaluates the `allow-auth-users` AuthorizationPolicy. It checks if Pod A's SPIFFE ID (`cluster.local/ns/securerag-hub/sa/portal-web`) is in the allowed list.
6. The request is permitted and forwarded to the `auth-users-service` container.

## Security Posture & Compliance
This architecture fulfills strict Zero Trust and SOC2 requirements:
- **No static secrets**: Identities are short-lived and automatically rotated by SPIRE.
- **Network Segmentation**: Replaced IP-based firewall rules with cryptographic identity policies.
- **Tamper-proof**: Since workloads do not have access to the underlying keys (handled by the Envoy sidecar and SPIRE agent), identity spoofing is cryptographically prevented.
