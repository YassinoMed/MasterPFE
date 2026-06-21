# security/vault/policies/jenkins-ci-policy.hcl
# Access control for Jenkins CI/CD pipeline.

# Allow listing and managing static secrets in KV engine
path "secret/data/jenkins/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/metadata/jenkins/*" {
  capabilities = ["list", "read"]
}

# Allow using Transit engine for on-the-fly encryption/decryption (replacing SOPS)
path "transit/keys/*" {
  capabilities = ["create", "read", "list"]
}

path "transit/encrypt/jenkins-cosign-key" {
  capabilities = ["update"]
}

path "transit/decrypt/jenkins-cosign-key" {
  capabilities = ["update"]
}
