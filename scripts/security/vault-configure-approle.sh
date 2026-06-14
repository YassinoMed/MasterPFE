#!/usr/bin/env bash
# File: scripts/security/vault-configure-approle.sh
# Description: Configures AppRole authentication and policies for Jenkins in HashiCorp Vault.
# Usage: bash scripts/security/vault-configure-approle.sh

set -euo pipefail

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-root}"

echo ">> Checking Vault status at ${VAULT_ADDR}..."
export VAULT_ADDR
export VAULT_TOKEN

if ! vault status >/dev/null 2>&1; then
    echo "[ERROR] Vault is not accessible or sealed. Please check VAULT_ADDR and VAULT_TOKEN."
    exit 1
fi

echo ">> 1. Enabling AppRole Auth Method..."
vault auth enable approle || echo "[INFO] AppRole might already be enabled."

echo ">> 2. Creating Jenkins Policy..."
cat <<EOF > /tmp/jenkins-vault-policy.hcl
# Access to standard secrets
path "secret/data/jenkins/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/data/cosign/*" {
  capabilities = ["read", "list"]
}

# Access to Transit Engine for EaaS
path "transit/encrypt/jenkins-key" {
  capabilities = ["update"]
}

path "transit/decrypt/jenkins-key" {
  capabilities = ["update"]
}
EOF

vault policy write jenkins-policy /tmp/jenkins-vault-policy.hcl
rm -f /tmp/jenkins-vault-policy.hcl

echo ">> 3. Creating Jenkins AppRole..."
vault write auth/approle/role/jenkins \
    secret_id_ttl=0 \
    token_num_uses=0 \
    token_ttl=1h \
    token_max_ttl=4h \
    secret_id_num_uses=0 \
    policies="jenkins-policy"

echo ">> 4. Retrieving Credentials for Jenkins..."
ROLE_ID=$(vault read -field=role_id auth/approle/role/jenkins/role-id)
SECRET_ID=$(vault write -f -field=secret_id auth/approle/role/jenkins/secret-id)

echo "--------------------------------------------------------"
echo "Vault AppRole configuration successful!"
echo "Please add the following credentials to Jenkins (Kind: Vault AppRole Credential):"
echo "Role ID: ${ROLE_ID}"
echo "Secret ID: ${SECRET_ID}"
echo "--------------------------------------------------------"
