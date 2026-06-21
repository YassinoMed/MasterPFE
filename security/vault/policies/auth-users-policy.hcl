# security/vault/policies/auth-users-policy.hcl
# Access control for auth-users service.

path "secret/data/auth-users" {
  capabilities = ["read"]
}
