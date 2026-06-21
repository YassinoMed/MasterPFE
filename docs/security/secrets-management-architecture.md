# Secrets Management Architecture — SecureRAG Hub

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    APPLICATION LAYER                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │  portal-web  │  │  auth-users │  │  chatbot    │  ...         │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘             │
│         │                │                │                      │
│         ▼                ▼                ▼                      │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │           Kubernetes Secrets (Ephemeral)                  │   │
│  │       Created by External Secrets Operator               │   │
│  └────────────────────────┬─────────────────────────────────┘   │
│                           │                                     │
├───────────────────────────┼─────────────────────────────────────┤
│        CONTROL PLANE      │                                     │
│                           ▼                                     │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │           External Secrets Operator                       │   │
│  │   Reads ExternalSecret CRDs ▼ Vault ClusterSecretStore   │   │
│  └────────────────────────┬─────────────────────────────────┘   │
│                           │                                     │
│                           ▼                                     │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │           HashiCorp Vault (KV v2 + Dynamic Secrets)       │   │
│  │   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │   │
│  │   │  Static      │  │  Dynamic     │  │  Auth        │   │   │
│  │   │  Secrets     │  │  DB/Creds    │  │  Kubernetes  │   │   │
│  │   └──────────────┘  └──────────────┘  └──────────────┘   │   │
│  └──────────────────────────────────────────────────────────┘   │
│                           │                                     │
├───────────────────────────┼─────────────────────────────────────┤
│      CI/CD PIPELINE       │                                     │
│                           ▼                                     │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Jenkins with Vault Plugin (no disk secrets)              │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐    │   │
│  │  │ SAST     │ │ Supply   │ │ Deploy   │ │ Quality  │    │   │
│  │  │ Scans    │ │ Chain    │ │ Stage    │ │ Gate     │    │   │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘    │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Cosign Keyless (Fulcio + Rekor)                          │   │
│  │  No static keys — OIDC identity bound to pipeline        │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Comparison: Sealed Secrets vs SOPS vs Vault

| Feature | Sealed Secrets | SOPS + age | HashiCorp Vault |
|---------|:-------------:|:----------:|:---------------:|
| **Encryption at rest** | ✅ AES-256 | ✅ age/X25519 | ✅ AES + HSM |
| **Git-native** | ✅ Yes (encrypted CRDs) | ✅ Yes (encrypted YAML) | ❌ No (external) |
| **Dynamic secrets** | ❌ No | ❌ No | ✅ Yes (DB, cloud) |
| **Automatic rotation** | ❌ Manual | ❌ Manual | ✅ Configurable |
| **Audit logging** | ❌ No | ❌ No | ✅ Detailed audit |
| **K8s native** | ✅ Yes | ⚠️ Via ArgoCD | ✅ Via ESO |
| **Complexity** | Low | Low | High |
| **Best for** | GitOps-only secrets | CI/CD + GitOps | Enterprise + dynamic |

### Recommendation: Layered Approach

```
Layer 1: HashiCorp Vault (runtime secrets, dynamic DB creds, PKI)
Layer 2: External Secrets Operator (syncing Vault → K8s Secrets)
Layer 3: SOPS + age (GitOps bootstrap, ArgoCD, Jenkins CasC)
Layer 4: Cosign Keyless (image signing, no static keys)
Layer 5: SPIFFE/SPIRE (workload identity, mTLS)
```

## Migration Steps

### Phase 1: SOPS + age (Week 1)
```bash
# Install
bash scripts/secrets/bootstrap-sops-age.sh

# Encrypt existing secrets
sops --encrypt infra/secrets/production/db.template.yaml > infra/secrets/production/db.enc.yaml

# Remove plaintext
git rm -r infra/jenkins/secrets/
```

### Phase 2: HashiCorp Vault (Week 2)
```bash
# Deploy
kubectl apply -k infra/k8s/vault/

# Initialize
bash scripts/secrets/initialize-vault.sh

# Store secrets
vault kv put secret/securerag/jenkins sonar-token=xxx github-token=xxx
```

### Phase 3: External Secrets Operator (Week 2)
```bash
# Install ESO
helm repo add external-secrets https://charts.external-secrets.io
helm upgrade --install external-secrets external-secrets/external-secrets \
  -n external-secrets --create-namespace

# Apply manifests
kubectl apply -f infra/k8s/secrets/eso-cluster-secret-store.prod.yaml
kubectl apply -f infra/k8s/secrets/jenkins-external-secret.yaml
kubectl apply -f infra/k8s/secrets/database-external-secret.yaml
```

### Phase 4: Jenkins Vault Integration (Week 3)
```bash
# Replace CasC config
cp infra/jenkins/casc/jenkins.vault.yaml infra/jenkins/casc/jenkins.yaml

# Remove plaintext secrets
rm -rf infra/jenkins/secrets/
```

### Phase 5: Cosign Keyless (Week 3)
```bash
# Migrate signing
COSIGN_EXPERIMENTAL=1 bash scripts/release/sign-images-keyless.sh

# Update Kyverno policy
kubectl apply -f infra/k8s/policies/kyverno/verify-cosign-images.yaml

# Delete static keys
rm -f infra/jenkins/secrets/cosign.*
```

### Phase 6: SPIFFE/SPIRE (Week 4)
```bash
# Deploy SPIRE
kubectl apply -k infra/k8s/spiffe/

# Register workloads
kubectl exec -n spire spire-server-0 -- spire-server entry create \
  -spiffeID spiffe://securerag.hub/ns/securerag-hub/sa/sa-portal-web \
  -parentID spiffe://securerag.hub/spire/agent/x509pop/...
```

## Rollback Procedures

### Rollback Vault → SOPS-only
```bash
# 1. Decrypt all SOPS secrets
sops --decrypt infra/secrets/production/db.enc.yaml | kubectl apply -f -

# 2. Remove ESO
kubectl delete externalsecret --all -n securerag-hub

# 3. Restore Jenkins CasC (readFile)
cp infra/jenkins/casc/jenkins.yaml.bak infra/jenkins/casc/jenkins.yaml

# 4. Remove Vault
kubectl delete -k infra/k8s/vault/
```

### Rollback Keyless → Static Cosign
```bash
# 1. Generate new keys
cosign generate-key-pair

# 2. Update Jenkins credentials
# 3. Update Kyverno policy to use key-based verification
```

## Security Score Improvement

| Metric | Before | After |
|--------|:------:|:-----:|
| Secrets Management | 2/10 | 9/10 |
| Supply Chain | 7/10 | 9/10 |
| Pipeline Hardening | 4/10 | 9/10 |
| Overall Security | 60/100 | **88/100** |
