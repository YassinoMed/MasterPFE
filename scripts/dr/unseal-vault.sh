#!/bin/bash
set -eo pipefail

echo "Waiting for Vault pods to be created..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=vault -n vault --timeout=120s || true

# Check if Vault is sealed
echo "Checking Vault seal status..."
SEAL_STATUS=$(kubectl exec -n vault vault-0 -- vault status -format=json | jq -r .sealed || echo "true")

if [ "$SEAL_STATUS" == "true" ]; then
    echo "Vault is sealed. Attempting to unseal using injected keys..."
    
    # In a real DR scenario, unseal keys should be fetched securely from KMS or a secret manager.
    # Here we simulate fetching the unseal keys from an environment variable or mocked file.
    
    UNSEAL_KEY_1=${VAULT_UNSEAL_KEY_1:-"mock_key_1"}
    UNSEAL_KEY_2=${VAULT_UNSEAL_KEY_2:-"mock_key_2"}
    UNSEAL_KEY_3=${VAULT_UNSEAL_KEY_3:-"mock_key_3"}

    # We do a try-catch for unseal because mock keys will fail if it's a real restored vault.
    kubectl exec -n vault vault-0 -- vault operator unseal "$UNSEAL_KEY_1" || echo "Unseal 1 failed (mock key?)"
    kubectl exec -n vault vault-0 -- vault operator unseal "$UNSEAL_KEY_2" || echo "Unseal 2 failed"
    kubectl exec -n vault vault-0 -- vault operator unseal "$UNSEAL_KEY_3" || echo "Unseal 3 failed"
    
    echo "Vault unseal sequence executed."
else
    echo "Vault is already unsealed or auto-unseal is configured."
fi
