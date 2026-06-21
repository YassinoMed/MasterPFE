#!/usr/bin/env bash
# bootstrap-sops-age.sh — Initialize SOPS + age for Secret encryption
# SecureRAG Hub — Enterprise Secrets Management
set -euo pipefail

SOPS_DIR="${SOPS_DIR:-infra/secrets}"
AGE_DIR="${HOME}/.config/sops/age"
AGE_KEY_FILE="${AGE_DIR}/keys.txt"
SOPS_CONFIG="${SOPS_CONFIG:-.sops.yaml}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { printf "${GREEN}[INFO]${NC}  %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }

# Phase 1: Install prerequisites
info "Phase 1/6: Checking prerequisites..."

if ! command -v sops &>/dev/null; then
  info "Installing SOPS v3.9.4..."
  SOPS_ARCH=$(uname -m)
  [ "$SOPS_ARCH" = "x86_64" ] && SOPS_ARCH="amd64"
  curl -fsSLo /usr/local/bin/sops \
    "https://github.com/getsops/sops/releases/download/v3.9.4/sops-v3.9.4.linux.${SOPS_ARCH}"
  chmod +x /usr/local/bin/sops
  info "SOPS installed: $(sops --version)"
fi

if ! command -v age &>/dev/null; then
  info "Installing age (age-keygen)..."
  AGE_ARCH=$(uname -m)
  [ "$AGE_ARCH" = "x86_64" ] && AGE_ARCH="amd64"
  curl -fsSLo /tmp/age.tar.gz \
    "https://github.com/FiloSottile/age/releases/download/v1.2.1/age-v1.2.1-linux-${AGE_ARCH}.tar.gz"
  tar -xzf /tmp/age.tar.gz -C /tmp age/age age/age-keygen
  install -m 0755 /tmp/age/age /usr/local/bin/age
  install -m 0755 /tmp/age/age-keygen /usr/local/bin/age-keygen
  rm -rf /tmp/age.tar.gz /tmp/age
  info "age installed: $(age --version)"
fi

# Phase 2: Generate age key pair
info "Phase 2/6: Generating age key pair..."
mkdir -p "${AGE_DIR}"

if [ -f "${AGE_KEY_FILE}" ]; then
  warn "Age key file already exists at ${AGE_KEY_FILE}"
  warn "Generate a new one only if rotating: rm ${AGE_KEY_FILE}"
else
  age-keygen -o "${AGE_KEY_FILE}"
  chmod 600 "${AGE_KEY_FILE}"
  info "Age key pair generated at ${AGE_KEY_FILE}"
fi

PUBLIC_KEY=$(grep "^# public key:" "${AGE_KEY_FILE}" | cut -d: -f2 | tr -d ' ')
info "Public key: ${PUBLIC_KEY}"

# Phase 3: Update .sops.yaml with the public key
info "Phase 3/6: Updating .sops.yaml with public key..."
if [ -f "${SOPS_CONFIG}" ]; then
  # Replace placeholder age key in .sops.yaml
  sed -i "s|age1qy4mt3l6l4q4l4g5l6l7l8l9l0l1l2l3l4l5l6l7l8l9l0l1l2l3l4l5l6l7l8|${PUBLIC_KEY}|g" "${SOPS_CONFIG}"
  info "Updated ${SOPS_CONFIG} with public key"
else
  error ".sops.yaml not found at ${SOPS_CONFIG}"
  exit 1
fi

# Phase 4: Create directory structure
info "Phase 4/6: Creating secret directories..."
mkdir -p "${SOPS_DIR}/production"
mkdir -p "${SOPS_DIR}/dev"
mkdir -p "${SOPS_DIR}/jenkins"
mkdir -p "${SOPS_DIR}/demo"

# Phase 5: Create encrypted secret templates
info "Phase 5/6: Creating encrypted secret templates..."

# Template for database secrets
cat > "${SOPS_DIR}/production/db.template.yaml" << 'TEMPLATE'
apiVersion: v1
kind: Secret
metadata:
  name: securerag-database-secrets
  namespace: securerag-hub
type: Opaque
stringData:
  DB_USERNAME: securerag
  DB_PASSWORD: CHANGE_ME_MINIMUM_20_CHARACTERS
  DB_SSLMODE: require
TEMPLATE

info "Template created at ${SOPS_DIR}/production/db.template.yaml"
info "Encrypt with: sops --encrypt ${SOPS_DIR}/production/db.template.yaml | tee ${SOPS_DIR}/production/db.enc.yaml"

# Template for Jenkins credentials
cat > "${SOPS_DIR}/jenkins/credentials.template.yaml" << 'TEMPLATE'
apiVersion: v1
kind: Secret
metadata:
  name: jenkins-credentials
  namespace: jenkins-agents
type: Opaque
stringData:
  sonar-token: ""
  github-token: ""
  gmail-user: ""
  gmail-app-password: ""
TEMPLATE

info "Template created at ${SOPS_DIR}/jenkins/credentials.template.yaml"

# Phase 6: Verify
info "Phase 6/6: Verifying SOPS configuration..."
if sops --config "${SOPS_CONFIG}" --verbose 2>&1 | head -5; then
  info "SOPS configuration valid"
else
  warn "SOPS config may need adjustments"
fi

# Verify encryption works
echo "test-secret-value" > /tmp/sops-test.txt
if sops --encrypt --config "${SOPS_CONFIG}" /tmp/sops-test.txt > /dev/null 2>&1; then
  info "SOPS encryption: OK"
else
  error "SOPS encryption test failed — check age key in .sops.yaml"
  exit 1
fi
rm -f /tmp/sops-test.txt

info ""
info "══════════════════════════════════════════════════════════════"
info "  SOPS + age bootstrap complete"
info ""
info "  Encrypt a secret:"
info "    sops --encrypt infra/secrets/production/db.yaml \\"
info "      | tee infra/secrets/production/db.enc.yaml"
info ""
info "  Decrypt for kubectl apply:"
info "    sops --decrypt infra/secrets/production/db.enc.yaml \\"
info "      | kubectl apply -f -"
info ""
info "  Public key: ${PUBLIC_KEY}"
info "══════════════════════════════════════════════════════════════"
