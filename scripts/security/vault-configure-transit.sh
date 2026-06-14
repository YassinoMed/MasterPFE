#!/usr/bin/env bash
# File: scripts/security/vault-configure-transit.sh
# Description: Configures Transit Engine in HashiCorp Vault for Encryption as a Service (EaaS).
# Usage: bash scripts/security/vault-configure-transit.sh

set -euo pipefail

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-root}"

echo ">> Checking Vault status at ${VAULT_ADDR}..."
export VAULT_ADDR
export VAULT_TOKEN

if ! vault status >/dev/null 2>&1; then
    echo "[ERROR] Vault is not accessible or sealed."
    exit 1
fi

echo ">> 1. Enabling Transit Secrets Engine..."
vault secrets enable transit || echo "[INFO] Transit engine might already be enabled."

echo ">> 2. Creating an Encryption Key for Jenkins..."
# Create an encryption key named "jenkins-key"
vault write -f transit/keys/jenkins-key

echo "--------------------------------------------------------"
echo "Vault Transit Engine configured successfully!"
echo "Jenkins can now use transit/encrypt/jenkins-key and transit/decrypt/jenkins-key"
echo "--------------------------------------------------------"
