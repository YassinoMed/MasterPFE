#!/usr/bin/env bash
# rotate-all-credentials.sh — P0 Rotation Plan
# SecureRAG Hub — Enterprise Secrets Rotation
#
# Assume all credentials exposed in infra/jenkins/secrets/ are COMPROMISED.
# This script generates replacement credentials and updates:
#   - GitHub tokens
#   - Sonar tokens
#   - Gmail app passwords
#   - kubeconfigs
#   - SSH deployment keys
#   - Cosign keys (→ keyless mode)
#   - Jenkins admin credentials
#
# Usage:
#   bash scripts/secrets/rotate-all-credentials.sh [--apply]
#
# Without --apply: dry-run mode (outputs commands only)
# With --apply:  executes rotation (requires human confirmation)

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { printf "${GREEN}[INFO]${NC}    %s\n" "$*"; }
warn()    { printf "${YELLOW}[WARN]${NC}    %s\n" "$*"; }
error()   { printf "${RED}[ERROR]${NC}   %s\n" "$*" >&2; }
step()    { printf "${BLUE}[STEP]${NC}    %s\n" "$*"; }
dryrun()  { printf "  📋 DRY-RUN: %s\n" "$*"; }
execute() { printf "  🚀 EXEC:    %s\n" "$*"; }

APPLY=false
if [ "${1:-}" = "--apply" ]; then
  APPLY=true
  warn "⚠️  APPLY MODE — this will ROTATE all credentials"
  warn "⚠️  Ensure you have out-of-band access to:"
  warn "    - GitHub (https://github.com/settings/tokens)"
  warn "    - SonarQube (admin UI)"
  warn "    - Gmail (app passwords)"
  warn "    - Kubernetes cluster"
  echo ""
  read -rp "Type 'ROTATE' to confirm: " CONFIRM
  if [ "${CONFIRM}" != "ROTATE" ]; then
    error "Aborted."
    exit 1
  fi
fi

SECRETS_DIR="${SECRETS_DIR:-infra/jenkins/secrets}"
VAULT_PATH="${VAULT_PATH:-secret/data/securerag/jenkins}"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  P0 — CREDENTIAL ROTATION PLAN"
echo "  All credentials in ${SECRETS_DIR} are considered COMPROMISED"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# ──────────────────────────────────────────────────────────────
# 1. GitHub Token
# ──────────────────────────────────────────────────────────────
step "1/8: Rotate GitHub Token"
echo "  Action: Generate new classic token at https://github.com/settings/tokens"
echo "  Scope: repo, workflow, read:packages"
echo "  Then update:"
echo "    - GitHub:     https://github.com/YassinoMed/MasterPFE/settings/secrets/actions"
echo "    - Jenkins:    Manage Jenkins → Credentials → github-token-secret"
echo "    - Secret:     infra/secrets/jenkins/credentials.enc.yaml"
echo ""

# ──────────────────────────────────────────────────────────────
# 2. Sonar Token
# ──────────────────────────────────────────────────────────────
step "2/8: Rotate Sonar Token"
echo "  Action: Generate new token at SonarQube Admin → Security → Tokens"
echo "  Then update:"
echo "    - Jenkins:    Manage Jenkins → Credentials → sonar-token"
echo "    - Secret:     infra/secrets/jenkins/credentials.enc.yaml"
echo ""

# ──────────────────────────────────────────────────────────────
# 3. Gmail App Password
# ──────────────────────────────────────────────────────────────
step "3/8: Rotate Gmail App Password"
echo "  Action: Generate new app password at https://myaccount.google.com/apppasswords"
echo "  Then update:"
echo "    - Jenkins:    Manage Jenkins → Credentials → gmail-app-password"
echo "    - Secret:     infra/secrets/jenkins/credentials.enc.yaml"
echo ""

# ──────────────────────────────────────────────────────────────
# 4. kubeconfig
# ──────────────────────────────────────────────────────────────
step "4/8: Rotate kubeconfig"
echo "  Action: Generate new kubeconfig with limited-scope ServiceAccount"
echo "  Commands:"
echo "    kubectl create sa jenkins-deployer -n jenkins-agents"
echo "    kubectl create clusterrolebinding jenkins-deployer \\"
echo "      --clusterrole=view --serviceaccount=jenkins-agents:jenkins-deployer"
echo "    kubectl create token jenkins-deployer -n jenkins-agents"
echo "  Store in: Vault ${VAULT_PATH} (key: kubeconfig)"
echo ""

# ──────────────────────────────────────────────────────────────
# 5. SSH Deployment Key
# ──────────────────────────────────────────────────────────────
step "5/8: Rotate SSH Deployment Key"
echo "  Action: Generate new SSH key pair"
echo "  Commands:"
if $APPLY; then
  ssh-keygen -t ed25519 -f /tmp/recette-deploy-key -N "" -C "jenkins@securerag-hub"
  echo "  ✅ Key generated at /tmp/recette-deploy-key"
  echo "  Add public key to recette VM: ~/.ssh/authorized_keys"
  echo "  Store private key in: Vault ${VAULT_PATH} (key: recette-deploy-key)"
else
  dryrun "ssh-keygen -t ed25519 -f /tmp/recette-deploy-key -N '' -C 'jenkins@securerag-hub'"
  dryrun "Store private key in Vault at ${VAULT_PATH}"
fi
echo ""

# ──────────────────────────────────────────────────────────────
# 6. Cosign Keys → Keyless Mode
# ──────────────────────────────────────────────────────────────
step "6/8: Migrate Cosign to Keyless Mode"
echo "  Action: Remove static keys, switch to OIDC-based keyless signing"
echo "  References:"
echo "    - GitHub:     .github/workflows/build-sign.yml (already keyless)"
echo "    - Jenkins:    Use cosign v2+ keyless mode (Fulcio + Rekor)"
echo "    - Kyverno:    Verify with keyless attestors (already configured)"
echo "  Cleanup:"
if $APPLY; then
  rm -f "${SECRETS_DIR}/cosign.key" "${SECRETS_DIR}/cosign.pub" "${SECRETS_DIR}/cosign.password"
  echo "  ✅ Static cosign keys removed from ${SECRETS_DIR}"
else
  dryrun "rm -f ${SECRETS_DIR}/cosign.key ${SECRETS_DIR}/cosign.pub ${SECRETS_DIR}/cosign.password"
fi
echo ""

# ──────────────────────────────────────────────────────────────
# 7. Jenkins Admin Password
# ──────────────────────────────────────────────────────────────
step "7/8: Rotate Jenkins Admin Password"
echo "  Action: Generate new random admin password"
if $APPLY; then
  NEW_PASS=$(python3 -c "import secrets; print(secrets.token_urlsafe(48))")
  echo "${NEW_PASS}" > "${SECRETS_DIR}/jenkins-admin-password"
  chmod 600 "${SECRETS_DIR}/jenkins-admin-password"
  echo "  ✅ New password written to ${SECRETS_DIR}/jenkins-admin-password"
  echo "  ⚠️  This file must be encrypted with SOPS or stored in Vault"
  echo "  Store in: Vault ${VAULT_PATH} (key: jenkins-admin-password)"
else
  dryrun "python3 -c 'import secrets; print(secrets.token_urlsafe(48))' > ${SECRETS_DIR}/jenkins-admin-password"
  dryrun "Store in Vault at ${VAULT_PATH}"
fi
echo ""

# ──────────────────────────────────────────────────────────────
# 8. Update Jenkins CasC to read from Vault
# ──────────────────────────────────────────────────────────────
step "8/8: Update Jenkins Configuration-as-Code"
echo "  Action: Switch Jenkins CasC from readFile to Vault plugin"
echo "  CasC file: infra/jenkins/casc/jenkins.yaml"
echo ""
echo "  Current (INSECURE):"
echo '    secret: "${readFile:/run/jenkins-secrets/sonar-token}"'
echo ""
echo "  Target (SECURE):"
echo '    secret: "${vault:secret/data/securerag/jenkins#sonar-token}"'
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "  ROTATION PLAN SUMMARY"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "  Credential              | Action                          | Priority"
echo "  ------------------------|---------------------------------|---------"
echo "  GitHub Token            | Regenerate at github.com        | P0"
echo "  Sonar Token             | Regenerate at SonarQube UI      | P0"
echo "  Gmail App Password      | Regenerate at Google            | P0"
echo "  kubeconfig              | Create limited-scope SA         | P0"
echo "  SSH Deploy Key          | Generate new ed25519 pair       | P0"
echo "  Cosign Keys             | Delete → keyless mode           | P0"
echo "  Jenkins Admin Password  | Generate random token           | P0"
echo "  CasC Config             | Switch to Vault plugin          | P1"
echo ""
echo "  All new secrets go to:"
echo "    1. HashiCorp Vault: ${VAULT_PATH}"
echo "    2. SOPS encrypted:  infra/secrets/jenkins/credentials.enc.yaml"
echo "    3. Jenkins:         Manage Jenkins → Credentials"
echo ""
echo "  Files to delete after rotation:"
echo "    rm -rf ${SECRETS_DIR}/"
echo ""
echo "═══════════════════════════════════════════════════════════════"
