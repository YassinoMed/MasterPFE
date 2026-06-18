# Security Incidents Runbook — SecureRAG Hub

> **Scope:** Security events detected by Falco, Kyverno, and audit logs.
> **Audience:** DevSecOps on-call. Always activate the **Incident Command System** for confirmed security incidents.

---

## 1. Falco Alert — Container Escape Attempt

### Symptoms
- Falco alert with priority `CRITICAL` and rule `Container escape detected`
- Unusual processes or file writes in container
- `kubectl describe pod` shows unexpected syscall activity
- Falco log: `Notice: A shell was spawned in a container with an attached terminal`

### Triage

```bash
# Identify the offending pod
kubectl get pods -n securerag-hub -o wide | grep <pod-name>

# Snapshot pod details
kubectl describe pod <pod> -n securerag-hub > artifacts/security/escape-pod-details-$(date +%s).txt

# Capture pod logs
kubectl logs <pod> -n securerag-hub --tail=500 > artifacts/security/escape-pod-logs-$(date +%s).txt

# Check image digest
kubectl get pod <pod> -n securerag-hub \
  -o jsonpath='{.status.containerStatuses[*].imageID}'

# Run on-demand image scan
trivy image --severity HIGH,CRITICAL <image>@<digest>

# Check Falco event details
kubectl -n falco logs -l app.kubernetes.io/name=falco --since=15m | grep -A10 <pod-name>
```

### Containment

```bash
# Step 1: Cordon the node to prevent scheduling
kubectl cordon <node>

# Step 2: Scale deployment to 0
kubectl scale deploy/<deployment> --replicas=0 -n securerag-hub

# Step 3: Isolate the pod (network level)
kubectl label pod <pod> security-incident=contained -n securerag-hub

# Step 4: Take forensic memory dump if possible
# kubectl exec <pod> -n securerag-hub -- cat /proc/1/mem > memory.dump

# Step 5: Report to Security Lead immediately
```

### Eradication

1. Remove compromised image from registry (or invalidate digest)
2. Rotate all secrets that the pod had access to
3. Scan host node for persistence mechanisms
4. Review audit logs for lateral movement
5. Patch vulnerability or update base image

### Recovery

1. Rebuild container from verified, signed base image
2. Re-deploy with fresh secrets and certificates
3. Run full security scan before reconnecting to network
4. Monitor aggressively for 24 hours post-recovery
5. Initiate security postmortem

---

## 2. Falco Alert — Reverse Shell Detected

### Symptoms
- Falco alert: `Reverse shell detected` or `Netcat spawned in container`
- Unexpected outbound connections from pod
- High egress network traffic to unknown IPs
- Shell history shows `nc`, `bash -i`, or `python -c 'import pty'`

### Triage

```bash
# Identify the pod and check outbound connections
kubectl exec <pod> -n securerag-hub -- ss -tunap 2>/dev/null || \
  kubectl exec <pod> -n securerag-hub -- netstat -tunap 2>/dev/null

# Check active processes
kubectl exec <pod> -n securerag-hub -- ps aux

# Capture network connection logs
kubectl logs <pod> -n securerag-hub --tail=200 > artifacts/security/reverse-shell-logs.txt

# Block egress traffic immediately
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: isolate-<pod>
  namespace: securerag-hub
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/instance: <instance>
  policyTypes:
    - Egress
  egress: []
EOF
```

### Containment

1. **Immediately apply egress-deny NetworkPolicy** to affected pod
2. **Cordon the node** to prevent spread to other pods
3. **Scale down deployment** to 0 replicas
4. **Capture all logs and evidence** before pod is terminated
5. **Report to Security Lead** with IP addresses and timestamps

### Eradication

1. Block outbound IPs at firewall level
2. Rotate all credentials accessible to the compromised pod
3. Check if the reverse shell persisted (cron, SSH keys, backdoor binaries)
4. Review CI/CD pipeline for supply chain compromise
5. Rebuild from trusted base image

### Recovery

1. Apply stronger NetworkPolicy (default-deny egress with allowlist)
2. Enable Falco rule: `Modify: Detect shell spawned inside container`
3. Deploy updated pod with minimal base image (distroless)
4. Monitor for 48 hours with enhanced logging
5. Conduct full security audit of deployment pipeline

---

## 3. Kyverno Policy Violation

### Symptoms
- Kyverno `PolicyReport` shows new `fail` results
- Pod admission denied with `policy <name> blocked this request`
- Grafana dashboard for Kyverno violations spikes
- `kubectl get policyreport -A` shows new failures

### Triage

```bash
# List all policy reports
kubectl get policyreport -A

# Show detailed policy violations
kubectl describe policyreport -n securerag-hub

# Check specific policy details
kubectl describe clusterpolicy <policy-name>

# Identify offending resource
kubectl get policyreport -n securerag-hub -o json | \
  jq '.results[] | select(.result=="fail") | {policy: .policy, resource: .resources, message: .message}'

# Check Kyverno logs
kubectl logs -n kyverno -l app.kubernetes.io/name=kyverno --tail=50
```

### Containment

1. **If enforce mode:** The admission is already blocked — no action needed for containment
2. **If audit mode:**
   - Determine if the violation is a true or false positive
   - If true positive: apply remediation (fix resource, update image, rotate secret)
   - If false positive: create an `exceptions` Kyverno resource
3. **For active violations in cluster:**
   - Identify and tag violating resources: `kubectl label <resource> kyverno/needs-review=true`
   - Quarantine if necessary by isolating network access

### Eradication

1. **True positive:** Fix the root cause (e.g., use allowed base image, add required labels)
2. **False positive:** Tune the policy rule to exclude known-good patterns
3. **Remediate existing resources:**
   - `kubectl annotate <resource> --overwrite policies.kyverno.io/remediate=yes`
   - Or manually patch the resource to comply

### Recovery

1. Verify remediation: `kubectl get policyreport -n securerag-hub -w`
2. Re-apply admission for new resources once policy passes
3. Document the violation pattern in the security runbook
4. Review policy coverage and adjust severity if needed
5. Consider promoting audit-mode policies to enforce-mode after validation

### Example: Kyverno Exception

```yaml
apiVersion: kyverno.io/v2
kind: PolicyException
metadata:
  name: exception-<policy-name>
  namespace: securerag-hub
spec:
  exceptions:
    - policyName: <policy-name>
      ruleNames:
        - <rule-name>
  match:
    any:
      - resources:
          kinds:
            - Pod
          namespaces:
            - securerag-hub
          names:
            - <specific-pod-name>
```

---

## 4. Secrets Exposure

### Symptoms
- Secret committed to Git repository
- Secret logged in plaintext in application logs
- Unauthorized access to Kubernetes secrets via `kubectl get secrets`
- SIEM alert for credential usage from unexpected IP
- Secret detected by `trufflehog` or `git-secrets` scan

### Triage

```bash
# Check if secret exists in expected location
kubectl get secret <name> -n securerag-hub -o jsonpath='{.data}'

# Check who accessed the secret (if audit logging enabled)
kubectl logs -n kube-system -l component=kube-apiserver --tail=1000 | \
  grep "get.*secrets" | grep <secret-name>

# Check if secret appears in logs
kubectl logs -n securerag-hub -l app.kubernetes.io/name=<app> --tail=500 | \
  grep -iE "<secret-pattern>"

# Check recent commits for secrets
git log -p --all | grep -iE "<secret-pattern>" | head -20

# Run secret scanner
trufflehog git file://. --since-commit HEAD~10 --only-verified
```

### Containment

1. **Immediate: Rotate the exposed secret**
   - Generate new secret value
   - Update Kubernetes Secret resource: `kubectl create secret generic <name> --from-literal=<key>=<new-value> -n securerag-hub --dry-run=client -o yaml | kubectl apply -f -`
   - Restart all deployments using the secret: `kubectl rollout restart deploy -n securerag-hub -l <selector>`
2. **If committed to Git:**
   - Use `git filter-branch` or `bfg-repo-cleaner` to remove from history
   - Rotate the secret (history scrubbing does NOT invalidate exposure)
   - Notify GitHub/GitLab security team if token exposed in public repo
3. **If logged to external system (Splunk, Loki, CloudWatch):**
   - Purge log entries containing the secret (if retention policy allows)
   - Configure log scrubbing/masking for the detected pattern

### Eradication

1. Implement secrets detection in CI/CD pipeline (pre-commit hook, CI scan)
2. Replace hardcoded secrets with Kubernetes Secrets or external vault
3. Enable encryption at rest for Secret resources
4. Review RBAC permissions for `get` secrets access
5. Implement secret rotation policy (90-day max lifetime)

### Recovery

1. Verify all services are using the new secret
2. Confirm old secret is no longer valid
3. Remove exposed secret from all systems (Git history, logs, CI variables)
4. Add secret detection to pre-commit hooks: `.husky/pre-commit`
5. Postmortem to identify prevention gaps

---

## 5. Unauthorized Access Attempt

### Symptoms
- Failed authentication logs from unknown IPs
- API Gateway returns 401/403 repeatedly
- Falco alert: `Unexpected inbound connection`
- Kyverno policy violation for RBAC changes
- SIEM alert for brute force or credential stuffing

### Triage

```bash
# Check API Gateway access logs
kubectl logs -n securerag-hub -l app.kubernetes.io/name=api-gateway --tail=200 | \
  grep -E "401|403|Unauthorized"

# Check auth service logs for failed attempts
kubectl logs -n securerag-hub -l app.kubernetes.io/name=auth-service --tail=200 | \
  grep -iE "failed login|invalid token|brute force"

# Identify source IPs
kubectl logs -n securerag-hub -l app.kubernetes.io/name=api-gateway --tail=500 | \
  grep "401" | awk '{print $NF}' | sort | uniq -c | sort -rn | head -10

# Check for compromised service accounts
kubectl get events -n securerag-hub | grep -iE "forbidden|unauthorized|denied"

# Check audit logs for RBAC changes
kubectl get events --all-namespaces | grep -iE "clusterrole|rolebinding|serviceaccount"
```

### Containment

1. **Rate limit the offending IPs at the gateway level**
   - Apply Istio rate limit or Nginx `limit_req`
   - Or update WAF rules to block IPs
2. **If brute force attack:**
   - Enable account lockout after N failed attempts
   - Implement CAPTCHA for login endpoints
   - Temporarily disable affected user accounts
3. **If token theft:**
   - Rotate JWT signing key
   - Force re-authentication for all users
   - Revoke specific tokens
4. **If service account abuse:**
   - Revoke and recreate the service account
   - Update permissions to least-privilege

### Eradication

1. Implement Web Application Firewall (WAF) with rate limiting
2. Enable IP allowlist/blocklist for sensitive endpoints
3. Deploy fail2ban or equivalent for HTTP-level attacks
4. Implement multi-factor authentication for all user accounts
5. Add anomaly detection on authentication patterns

### Recovery

1. Verify rate limiting is working effectively
2. Confirm no further unauthorized access attempts succeed
3. Review and update incident response playbook
4. Notify affected users if personal data potentially exposed
5. Security postmortem with detailed attack timeline

---

## 6. General Security Incident Checklist

- [ ] Incident declared in `#securerag-incidents`
- [ ] Security Lead notified
- [ ] Evidence collection initiated (logs, pod spec, network captures)
- [ ] Containment applied (network isolation, pod quarantine, credential rotation)
- [ ] Eradication completed (vulnerability patched, image rebuilt)
- [ ] Recovery verified (service restored, monitoring clean)
- [ ] Postmortem initiated
- [ ] Regulatory notification assessed (if required)
- [ ] Runbook updated with lessons learned
