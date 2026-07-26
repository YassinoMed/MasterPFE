output "api_fqdn" {
  description = "FQDN for Kubernetes API Endpoint"
  value       = "k8s-api.${var.domain_name}"
}

output "wildcard_apps_fqdn" {
  description = "Wildcard FQDN for Ingress applications"
  value       = "*.apps.${var.domain_name}"
}
