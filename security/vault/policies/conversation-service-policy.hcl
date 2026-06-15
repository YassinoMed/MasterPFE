# security/vault/policies/conversation-service-policy.hcl
# Access control for conversation-service.

path "secret/data/conversation-service" {
  capabilities = ["read"]
}
