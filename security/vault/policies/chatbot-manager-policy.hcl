# security/vault/policies/chatbot-manager-policy.hcl
# Access control for chatbot-manager service.

path "secret/data/chatbot-manager" {
  capabilities = ["read"]
}
