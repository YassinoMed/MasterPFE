# security/vault/policies/portal-web-policy.hcl
# Access control for portal-web service.

path "secret/data/portal-web" {
  capabilities = ["read"]
}
