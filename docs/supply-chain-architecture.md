# SecureRAG Hub: Supply Chain Security Architecture (SLSA Level 3+)

## Overview
This document describes the 100% secured, zero-trust DevSecOps supply chain designed to comply with SLSA Level 3+ and enterprise security requirements.

The core philosophy of this supply chain is:
- **No Unsigned Code**: Every container image deployed to production must be cryptographically signed.
- **Keyless Security**: Signatures use ephemeral keys via Cosign OIDC (Fulcio/Rekor) to eliminate secret management risks.
- **Enforced Transparency**: A valid SBOM (Software Bill of Materials) and SLSA Provenance attestation must be attached to the registry.
- **Policy Enforcement**: Kubernetes admission controllers (Kyverno) and GitOps (ArgoCD) act as gates to block non-compliant artifacts at deployment time.

## Architecture Diagram

```mermaid
flowchart TD
    subgraph GitRepository ["Source Code (Git)"]
        A[Commit Code]
    end

    subgraph CI_Pipeline ["Jenkins CI Pipeline"]
        B[1. Build Image]
        C[2. Scan (Trivy + SAST)]
        D[3. Generate SBOM (Syft)]
        E[4. Sign Image (Cosign Keyless)]
        F[5. SLSA Provenance]
        G[6. Push to Registry]
        H[7. Verify Signatures]
        I[8. Deploy via GitOps]
    end

    subgraph OCI_Registry ["Container Registry"]
        J[(Signed Image + Digest)]
        K[(SBOM Attestation)]
        L[(Provenance Attestation)]
    end

    subgraph K8s_Cluster ["Kubernetes Production Cluster"]
        M[ArgoCD GitOps Sync]
        N{Kyverno Admission Controller}
        O[Running Pods]
        
        M -->|1. Applies Manifests| N
        N -->|2. Verifies Signatures| OCI_Registry
        N -->|3. Validates SBOM & Provenance| OCI_Registry
        N -->|4. Blocks tags / Approves digests| O
    end

    A --> B
    B --> C
    C --> D
    D --> E
    E --> F
    F --> G
    G --> H
    H --> I
    I --> M
    
    G --> J
    D -.-> K
    F -.-> L
    E -.-> J
```

## Security Posture & Enforcement Mechanisms

### 1. Mandatory Signing (Cosign Keyless)
All images and their corresponding SBOM and Provenance files are signed using **Cosign Keyless mode**. This relies on an OIDC token from the CI provider (Jenkins/GitHub) and the Sigstore infrastructure (Fulcio/Rekor), preventing the need to store static private keys.
- **Script**: `cosign_sign.sh`

### 2. Mandatory SBOM
A CycloneDX/SPDX SBOM is generated during the CI process using Syft. The SBOM is uploaded directly to the OCI registry as a verifiable attestation bound to the image's SHA256 digest.
- **Script**: `sbom_generate.sh`

### 3. SLSA Provenance
A provenance record is generated containing the Git commit hash, pipeline identity, builder details, and execution timestamps. This proves that the artifact was genuinely built by our official, trusted CI system and has not been tampered with.

### 4. Kubernetes Admission Policy (Kyverno)
The cluster utilizes a strict Kyverno `ClusterPolicy` (`enforce-slsa-provenance`) to enforce zero-trust deployments:
- **Digest Only**: Rejects any pod specifying a mutable tag like `latest` or `dev`.
- **Signature Verification**: Interrogates the OCI registry to verify the Cosign Keyless signature against the expected CI issuer.
- **Attestation Enforcement**: Verifies the presence of the SBOM and the SLSA Provenance. Any image missing these artifacts is automatically rejected.

### 5. GitOps Hardening (ArgoCD)
ArgoCD is configured with strict sync policies (`prune: true`, `selfHeal: true`). The CI pipeline is strictly restricted to updating the `sha256:` digest of the target image in the Kubernetes deployment manifests. ArgoCD synchronizes these validated digests to the cluster.

### 6. Pipeline Fail-Fast Policy
The CI/CD pipeline consists of 8 sequential stages. Every stage runs under `set -euo pipefail`. If an image fails to build, scan, generate an SBOM, or obtain a keyless signature, the pipeline immediately halts and the GitOps deployment step is never executed. 

### 7. Continuous Runtime Verification
Once deployed, periodic jobs can scan the cluster to ensure no unsanctioned workloads have bypassed the admission controller, sending alerts to SIEM systems like Wazuh or Prometheus if violations occur.
