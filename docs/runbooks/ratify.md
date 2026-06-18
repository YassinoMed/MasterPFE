# Ratify Runbook — Image Verification Admission Control

**Component:** Ratify  
**Namespace:** `ratify`  
**Key files:** `infra/k8s/ratify/`, `infra/k8s/policies/kyverno/verify-cosign-images.yaml`  
**Version:** 1.15.x

---

## 1. Checking Ratify Health

### Pod Status

```bash
# Check all Ratify pods
kubectl get pods -n ratify -l app.kubernetes.io/name=ratify

# Check deployment
kubectl get deployment -n ratify ratify

# Expected: 2/2 replicas ready for production
```

### Health Endpoint

```bash
# Check health endpoint (in-cluster)
kubectl run ratify-health-check --image=curlimages/curl:latest \
  --rm -it --restart=Never -- \
  curl -s http://ratify.ratify.svc.cluster.local:6001/health

# Expected response: {"status":"OK","checks":[{"name":"liveness","status":"OK"}]}

# Port-forward for external check
kubectl port-forward -n ratify svc/ratify 6001:6001 &
curl http://localhost:6001/health
kill %1
```

### Readiness Check

```bash
kubectl exec -n ratify deploy/ratify -- \
  wget -qO- http://localhost:6001/readyz

# Expected response: {"status":"ready"}
```

### Prometheus Metrics

Ratify exposes metrics on port `6001` at `/metrics`:

```bash
# Check metrics endpoint
kubectl port-forward -n ratify svc/ratify 6001:6001 &
curl http://localhost:6001/metrics | grep ratify_

# Key metrics to monitor:
# ratify_verification_total{type="cosign", result="success"}  — successful verifications
# ratify_verification_total{type="cosign", result="failure"}  — failed verifications
# ratify_verification_duration_seconds  — verification latency
# ratify_http_request_duration_seconds  — API latency
```

### Verification Alerts

If Ratify is unhealthy, a Prometheus alert fires:

```yaml
- alert: RatifyVerificationFailed
  expr: rate(ratify_verification_total{result="failure"}[5m]) > 0
  for: 2m
  labels:
    severity: critical
  annotations:
    summary: "Ratify image verification failures detected"
    description: "{{ $value }} verification failures per second"
```

---

## 2. Viewing Verification Logs

### Real-Time Logs

```bash
# Tail all Ratify pods
kubectl logs -n ratify -l app.kubernetes.io/name=ratify -f

# Filter by verification request
kubectl logs -n ratify -l app.kubernetes.io/name=ratify -f | \
  grep -E "verification|admission|Verifier"

# Filter by result
kubectl logs -n ratify -l app.kubernetes.io/name=ratify -f | \
  grep -E "\"result\":\"success\"|\"result\":\"failure\""
```

### Check Verification History

```bash
# View logs for a specific time period
kubectl logs -n ratify -l app.kubernetes.io/name=ratify \
  --since=1h --tail=100 | grep -E "VerifyResult|verificationResult"

# Archive logs for analysis
kubectl logs -n ratify -l app.kubernetes.io/name=ratify \
  --since=24h > /tmp/ratify-logs-$(date +%Y%m%d).log
```

### Structured Log Output

Ratify outputs structured JSON logs:

```json
{"level":"info","msg":"verification result","verifier":"cosign","subject":"registry.example.com/portal-web:v1.2.3","result":"success","duration_ms":1234}
{"level":"warn","msg":"verification result","verifier":"sbom","subject":"registry.example.com/auth-users:v2.0.1","result":"failure","reason":"SBOM verification failed: nested score 5/10 below threshold 7/10"}
{"level":"error","msg":"admission failed","subject":"registry.example.com/bad-image:latest","reason":"verification failed for all verifiers"}
```

---

## 3. Troubleshooting Admission Denials

### Identify Denied Pods

When a pod is denied by admission control:

```bash
# Check recent admission reviews (in Kyverno logs)
kubectl logs -n kyverno -l app.kubernetes.io/name=kyverno --tail=50 | \
  grep -i ratify

# Check Kyverno policy violations
kubectl get policyreports -A

# Check events
kubectl get events -n securerag-hub --field-selector reason=FailedCreate
```

### Common Admission Denial Reasons

#### Error: "no matching verifiers"

**Cause:** Ratify has no verifier configured for the image registry or signature type.

**Solution:**

```bash
# Check current verifier config
kubectl get configmap -n ratify ratify-config -o yaml

# Ensure verifier section has cosign, sbom, slsa entries
# Example configuration:
verifiers:
  - name: cosign
    artifactTypes: application/vnd.dev.cosign.artifact.sig.v1+json
    verifierPlugin: cosign
  - name: sbom
    artifactTypes: application/vnd.cyclonedx+json
    verifierPlugin: sbom
    nestedVerification:
      - name: trivy
        artifactTypes: application/vnd.aquasec.trivy.report+json
        minimumScore: 7.0
  - name: slsa
    artifactTypes: application/vnd.slsa.build.v1+json
    verifierPlugin: slsa
```

#### Error: "invalid signature"

**Cause:** Image is either not signed or signature does not match.

**Solution:**

```bash
# Step 1: Verify image is signed
cosign verify \
  --keyless \
  --certificate-identity-regexp ".*@example\.com" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  registry.example.com/portal-web:v1.2.3

# Step 2: If not signed, sign the image
cosign sign --keyless \
  --identity-token "$(gcloud auth print-identity-token)" \
  registry.example.com/portal-web:v1.2.3

# Step 3: If signature exists but fails, check trust store
kubectl exec -n ratify deploy/ratify -- \
  cat /usr/local/ratify/truststore/cosign/securerag-root/ca.crt
```

#### Error: "SBOM verification failed"

**Cause:** SBOM is missing, invalid, or Trivy scan score is below threshold.

**Solution:**

```bash
# Step 1: Check if SBOM exists in registry
oras discover \
  -o json \
  registry.example.com/portal-web:v1.2.3 | \
  jq '.references[] | select(.artifactType == "application/vnd.cyclonedx+json")'

# Step 2: If SBOM missing, generate and attach
trivy image --format cyclonedx \
  --output /tmp/portal-web.sbom \
  registry.example.com/portal-web:v1.2.3
oras attach \
  --artifact-type application/vnd.cyclonedx+json \
  registry.example.com/portal-web:v1.2.3 \
  /tmp/portal-web.sbom

# Step 3: If score too low, fix vulnerabilities and rebuild
# Or adjust the minimumScore threshold (not recommended for production)
```

#### Error: "SLSA provenance verification failed"

**Cause:** SLSA attestation is missing or fails verification.

**Solution:**

```bash
# Step 1: Check SLSA provenance
cosign verify-attestation --type slsaprovenance \
  --keyless \
  registry.example.com/portal-web:v1.2.3

# Step 2: If missing, ensure CI generates SLSA attestation
# In GitHub Actions:
# - name: Generate SLSA provenance
#   uses: slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@v2.0.0

# Step 3: Verify builder identity matches expected
kubectl exec -n ratify deploy/ratify -- \
  cat /usr/local/ratify/config.json | jq '.stores[0].certificates'
```

### Test Admission Decision

```bash
# Dry-run test a pod admission
cat <<EOF | kubectl apply --dry-run=server -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-ratify-admission
  namespace: securerag-hub
spec:
  containers:
    - name: test
      image: registry.example.com/portal-web:v1.2.3
EOF

# If denied, the error message will indicate why
```

### View Kyverno ClusterPolicy

```bash
# Check the Kyverno policy that invokes Ratify
kubectl get clusterpolicy securerag-verify-cosign-images -o yaml

# Look for the `verifyImages` block with `attestors` and `ratify` reference
```

---

## 4. Adding New Trust Policies

### Add a New Cosign Public Key Trust

```yaml
# Add to ratify-config ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: ratify-config
  namespace: ratify
data:
  config.json: |
    {
      "stores": {
        "version": "1.0.0",
        "plugins": [
          {
            "name": "oras",
            "localCachePath": "/usr/local/ratify/cache",
            "cosignEnabled": true
          }
        ]
      },
      "policies": {
        "version": "1.0.0",
        "plugin": {
          "name": "configPolicy",
          "artifactVerificationPolicies": {
            "registry.example.com/*": "trusted",
            "docker.io/library/*": "trusted"
          }
        }
      },
      "verifiers": [
        {
          "name": "cosign",
          "artifactTypes": "application/vnd.dev.cosign.artifact.sig.v1+json",
          "verifierPlugin": "cosign",
          "pluginConfig": {
            "keyless": {
              "trustRoots": [
                {
                  "name": "securerag-github-actions",
                  "key": "/usr/local/ratify/truststore/cosign/securerag-root/ca.crt"
                }
              ]
            }
          }
        }
      ]
    }
```

### Add a New SBOM Verification Policy

```yaml
verifiers:
  - name: sbom
    artifactTypes: application/vnd.cyclonedx+json
    verifierPlugin: sbom
    nestedVerification:
      - name: trivy
        artifactTypes: application/vnd.aquasec.trivy.report+json
        minimumScore: 8.0  # Increased threshold for stricter enforcement
```

### Add a New Registry Trust Policy

```yaml
policies:
  version: "1.0.0"
  plugin:
    name: "configPolicy"
    artifactVerificationPolicies:
      registry.example.com/*: "trusted"            # Our registry
      ghcr.io/my-org/*: "trusted"                  # GitHub Container Registry
      docker.io/library/alpine: "trusted"          # Specific official image
      docker.io/library/nginx: "trusted"           # Specific official image
      *: "skip"                                    # All others: skip verification
```

### Apply Policy Changes

```bash
# Edit the ConfigMap
kubectl edit configmap -n ratify ratify-config

# Ratify watches for config changes automatically (no restart needed)
# Wait ~30 seconds for hot-reload

# Verify new policy is active
kubectl logs -n ratify -l app.kubernetes.io/name=ratify --tail=20 | \
  grep -E "config|policy|verifier"
```

---

## 5. Updating Verification Configuration

### Hot-Reload Configuration

Ratify supports hot-reload of configuration changes. When you update the ConfigMap, Ratify picks up changes within 30 seconds.

```bash
# Update ConfigMap
kubectl apply -f infra/k8s/ratify/ratify-config.yaml

# Watch logs to confirm reload
kubectl logs -n ratify -l app.kubernetes.io/name=ratify -f | \
  grep -E "Configuration|reload|updated"

# Expected log line:
# "Configuration updated successfully"
```

### Update Trust Store Certificates

```bash
# Add a new CA certificate to the trust store
kubectl create configmap ratify-trust-store \
  --namespace ratify \
  --from-file=cosign/securerag-root=/path/to/new-ca.crt \
  --dry-run=client -o yaml | kubectl apply -f -

# Verify trust store
kubectl exec -n ratify deploy/ratify -- \
  ls -la /usr/local/ratify/truststore/cosign/
```

### Change Verification Mode

Switch between strict and permissive verification:

```yaml
# In ratify-config ConfigMap
policies:
  version: "1.0.0"
  plugin:
    name: "configPolicy"
    artifactVerificationPolicies:
      registry.example.com/*: "trusted"     # Must pass all verifiers
      # OR
      registry.example.com/*: "skip"        # Skip verification for testing
      # OR (not recommended for production)
      registry.example.com/*: "allow"       # Allow even if verification fails (logs only)
```

### Update Kyverno Policy Reference

If Ratify configuration changes, the Kyverno ClusterPolicy may need updating:

```bash
# Edit the Kyverno policy
kubectl edit clusterpolicy securerag-verify-cosign-images

# Update references to Ratify endpoint or configuration
```

---

## 6. Common Issues

### Issue: "verification failure: no signatures found"

**Cause:** Image was not signed with Cosign, or signature was not pushed to registry.

**Diagnosis:**

```bash
# Check if image has signatures
cosign verify \
  --keyless \
  registry.example.com/portal-web:v1.2.3 2>&1

# List all referrers (signatures, SBOMs, attestations)
oras discover -o tree registry.example.com/portal-web:v1.2.3
```

**Resolution:**

```bash
# Sign the image
cosign sign --keyless registry.example.com/portal-web:v1.2.3

# Verify the signature was pushed
cosign verify --keyless registry.example.com/portal-web:v1.2.3
```

### Issue: Ratify admission timeout

**Symptoms:**
- Pod stuck in `ContainerCreating`
- Kyverno logs: `"admission webhook call timed out"`
- Timeout after 30 seconds

**Diagnosis:**

```bash
# Check Ratify latency
kubectl exec -n ratify deploy/ratify -- \
  wget -qO- http://localhost:6001/metrics | \
  grep ratify_verification_duration_seconds

# Check network connectivity
kubectl run ratify-connect-test --image=curlimages/curl:latest \
  --rm -it --restart=Never -- \
  curl -s -o /dev/null -w "%{http_code}" \
  http://ratify.ratify.svc.cluster.local:6001/health

# Check if registry is reachable from Ratify
kubectl exec -n ratify deploy/ratify -- \
  wget -qO- --timeout=5 \
  https://registry.example.com/v2/ 2>&1
```

**Resolution:**

```bash
# Increase timeout in Kyverno policy
kubectl edit clusterpolicy securerag-verify-cosign-images
# webhookTimeoutSeconds: 30  →  60

# Check registry network policy
kubectl get ciliumnetworkpolicies -n ratify

# If registry is slow, add image pull timeout
# Increase Ratify resources
kubectl edit deployment -n ratify ratify
# resources:
#   requests:
#     memory: 256Mi
#     cpu: 200m
#   limits:
#     memory: 512Mi
#     cpu: 500m
```

### Issue: Ratify constantly restarts

**Cause:** ConfigMap parsing error, OOM, or liveness probe failure.

**Diagnosis:**

```bash
# Check crash reason
kubectl describe pod -n ratify -l app.kubernetes.io/name=ratify

# Check previous pod logs
kubectl logs -n ratify -l app.kubernetes.io/name=ratify --previous

# Check for OOM
kubectl top pod -n ratify -l app.kubernetes.io/name=ratify
```

**Resolution:**

```bash
# Fix ConfigMap syntax
kubectl get configmap -n ratify ratify-config -o yaml > /tmp/ratify-config.yaml
# Validate JSON syntax
python3 -m json.tool /tmp/ratify-config.yaml
kubectl apply -f /tmp/ratify-config.yaml

# Increase memory if OOM
kubectl set resources deployment -n ratify ratify \
  --limits memory=1Gi --requests memory=512Mi

# Force restart
kubectl rollout restart -n ratify deployment/ratify
```

### Issue: "verification skipped — no matching artifact"

**Cause:** Ratify is configured to skip verification for this registry or artifact type.

**Diagnosis:**

```bash
# Check policy configuration
kubectl get configmap -n ratify ratify-config -o yaml | \
  grep -A5 artifactVerificationPolicies

# Check if registry is explicitly listed
# If registry.example.com/* is missing, Ratify may use default
```

**Resolution:**

```yaml
# Add the registry to verification policies
artifactVerificationPolicies:
  registry.example.com/*: "trusted"
```

### Issue: Certificate validation fails

**Cause:** Trust store missing or incorrect CA certificate.

**Diagnosis:**

```bash
# Check trust store contents
kubectl exec -n ratify deploy/ratify -- \
  ls -la /usr/local/ratify/truststore/cosign/

# Inspect CA certificate
kubectl exec -n ratify deploy/ratify -- \
  openssl x509 -in /usr/local/ratify/truststore/cosign/securerag-root/ca.crt \
  -noout -text | head -10
```

**Resolution:**

```bash
# Regenerate and redeploy trust store
kubectl create configmap ratify-trust-store \
  --namespace ratify \
  --from-file=cosign/securerag-root=infra/k8s/ratify/certs/ca.crt \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl rollout restart -n ratify deployment/ratify
```

---

## Quick Reference

```bash
# Health check
kubectl exec -n ratify deploy/ratify -- wget -qO- http://localhost:6001/health

# View logs
kubectl logs -n ratify -l app.kubernetes.io/name=ratify -f

# View config
kubectl get configmap -n ratify ratify-config -o yaml

# Check metrics
kubectl port-forward -n ratify svc/ratify 6001:6001 &
curl http://localhost:6001/metrics

# Test admission
kubectl run test-ratify --image=registry.example.com/portal-web:v1.2.3 \
  --dry-run=server -n securerag-hub

# Check Kyverno policy
kubectl get clusterpolicy securerag-verify-cosign-images -o yaml

# Apply config changes
kubectl apply -f infra/k8s/ratify/ratify-config.yaml

# Restart Ratify
kubectl rollout restart -n ratify deployment/ratify

# Verify image signature manually
cosign verify --keyless registry.example.com/portal-web:v1.2.3

# List image referrers
oras discover -o tree registry.example.com/portal-web:v1.2.3
```
