output "loadbalancer_dns_name" {
  description = "The DNS name of the Load Balancer"
  value       = aws_lb.k8s_api.dns_name
}

output "loadbalancer_arn" {
  description = "The ARN of the Load Balancer"
  value       = aws_lb.k8s_api.arn
}
