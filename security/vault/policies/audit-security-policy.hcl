# security/vault/policies/audit-security-policy.hcl
# Access control for audit-security-service.

path "secret/data/audit-security-service" {
  capabilities = ["read"]
}
