#!/usr/bin/env bash
set -u

echo "=========================================="
echo "STARTING REAL DEVSECOPS EXPERIMENTAL SCAN"
echo "Date: $(date -u)"
echo "Host: $(hostname)"
echo "=========================================="

mkdir -p validation/terraform validation/ansible validation/security validation/kubernetes validation/performance validation/jenkins

# 1. TERRAFORM VALIDATION
echo "--- 1. TERRAFORM AUDIT ---" > validation/terraform/audit.log
cd infra/terraform 2>/dev/null || cd infra/
echo "=== terraform fmt ===" >> ../../validation/terraform/audit.log
terraform fmt -check . >> ../../validation/terraform/audit.log 2>&1 || true
echo "=== terraform init (backend local) ===" >> ../../validation/terraform/audit.log
terraform init -backend=false >> ../../validation/terraform/audit.log 2>&1 || true
echo "=== terraform validate ===" >> ../../validation/terraform/audit.log
terraform validate >> ../../validation/terraform/audit.log 2>&1 || true
echo "=== terraform providers ===" >> ../../validation/terraform/audit.log
terraform providers >> ../../validation/terraform/audit.log 2>&1 || true
echo "=== terraform state list ===" >> ../../validation/terraform/audit.log
terraform state list >> ../../validation/terraform/audit.log 2>&1 || true
cd /root/MasterPFE

# 2. ANSIBLE VALIDATION
echo "--- 2. ANSIBLE AUDIT ---" > validation/ansible/audit.log
ansible --version >> validation/ansible/audit.log 2>&1 || true
if [ -d "infra/ansible" ]; then
  cd infra/ansible
  echo "=== ansible syntax check ===" >> ../../validation/ansible/audit.log
  ansible-playbook --syntax-check site.yml playbooks/*.yml >> ../../validation/ansible/audit.log 2>&1 || true
  echo "=== ansible inventory ===" >> ../../validation/ansible/audit.log
  ansible-inventory --list >> ../../validation/ansible/audit.log 2>&1 || true
  cd /root/MasterPFE
fi

# 3. GITLEAKS SCAN
echo "--- 3. GITLEAKS SCAN ---" > validation/security/gitleaks.log
gitleaks detect --source . --verbose >> validation/security/gitleaks.log 2>&1 || true

# 4. SEMGREP SCAN
echo "--- 4. SEMGREP SCAN ---" > validation/security/semgrep.log
if which semgrep >/dev/null 2>&1; then
  semgrep scan --config auto . >> validation/security/semgrep.log 2>&1 || true
elif docker image inspect returntocorp/semgrep:latest >/dev/null 2>&1; then
  docker run --rm -v "$(pwd):/src" returntocorp/semgrep:latest semgrep scan --config auto /src >> validation/security/semgrep.log 2>&1 || true
else
  echo "SEMGREP_NOT_AVAILABLE" >> validation/security/semgrep.log
fi

# 5. TRIVY SCAN
echo "--- 5. TRIVY SCAN ---" > validation/security/trivy.log
echo "=== trivy fs ===" >> validation/security/trivy.log
trivy fs --severity HIGH,CRITICAL . >> validation/security/trivy.log 2>&1 || true
echo "=== trivy config ===" >> validation/security/trivy.log
trivy config infra/ >> validation/security/trivy.log 2>&1 || true

# 6. CHECKOV SCAN
echo "--- 6. CHECKOV SCAN ---" > validation/security/checkov.log
if which checkov >/dev/null 2>&1; then
  checkov -d infra/terraform/ >> validation/security/checkov.log 2>&1 || true
elif docker image inspect bridgecrew/checkov:latest >/dev/null 2>&1; then
  docker run --rm -v "$(pwd):/tf" bridgecrew/checkov:latest -d /tf/infra/terraform/ >> validation/security/checkov.log 2>&1 || true
else
  echo "CHECKOV_NOT_AVAILABLE" >> validation/security/checkov.log
fi

# 7. SYFT & GRYPE SCAN
echo "--- 7. SYFT & GRYPE SCAN ---" > validation/security/syft_grype.log
echo "=== Syft generate SBOM ===" >> validation/security/syft_grype.log
syft dir:. -o cyclonedx-json > validation/security/sbom.json 2>> validation/security/syft_grype.log || true
echo "=== Grype scan SBOM ===" >> validation/security/syft_grype.log
grype sbom:validation/security/sbom.json >> validation/security/syft_grype.log 2>&1 || true

# 8. KYVERNO POLICIES & REPORTS
echo "--- 8. KYVERNO AUDIT ---" > validation/security/kyverno.log
kubectl get clusterpolicies -o wide >> validation/security/kyverno.log 2>&1 || true
kubectl get policyreports -A >> validation/security/kyverno.log 2>&1 || true
kubectl get clusterpolicyreports >> validation/security/kyverno.log 2>&1 || true

# 9. FALCO AUDIT
echo "--- 9. FALCO AUDIT ---" > validation/security/falco.log
kubectl get pods -n falco -o wide >> validation/security/falco.log 2>&1 || true
FALCO_POD=$(kubectl get pods -n falco -l app.kubernetes.io/name=falco -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [ -n "$FALCO_POD" ]; then
  kubectl logs -n falco "$FALCO_POD" --tail=100 >> validation/security/falco.log 2>&1 || true
fi

# 10. TETRAGON & CILIUM AUDIT
echo "--- 10. TETRAGON & CILIUM AUDIT ---" > validation/security/tetragon_cilium.log
kubectl get crd | grep -Ei 'tetragon|cilium' >> validation/security/tetragon_cilium.log 2>&1 || true
kubectl get tracingpolicies -A >> validation/security/tetragon_cilium.log 2>&1 || true

# 11. ISTIO & SPIFFE AUDIT
echo "--- 11. ISTIO & SPIFFE AUDIT ---" > validation/security/istio_spiffe.log
kubectl get pods -A | grep -Ei 'istio|spire' >> validation/security/istio_spiffe.log 2>&1 || true
kubectl get crd | grep -Ei 'istio|spire' >> validation/security/istio_spiffe.log 2>&1 || true

# 12. VAULT & ESO AUDIT
echo "--- 12. VAULT & ESO AUDIT ---" > validation/security/vault_eso.log
kubectl get externalsecrets -A >> validation/security/vault_eso.log 2>&1 || true
kubectl get secretstores -A >> validation/security/vault_eso.log 2>&1 || true
kubectl get clustersecretstores >> validation/security/vault_eso.log 2>&1 || true

# 13. ARGO CD AUDIT
echo "--- 13. ARGO CD AUDIT ---" > validation/security/argocd.log
argocd app list >> validation/security/argocd.log 2>&1 || true

echo "=== SCAN COMPLETED ==="
