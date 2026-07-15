output "control_plane_ips" {
  description = "Private IPs of control planes"
  value       = aws_instance.control_plane[*].private_ip
}

output "control_plane_ids" {
  description = "IDs of control plane instances"
  value       = aws_instance.control_plane[*].id
}

output "control_plane_public_ips" {
  description = "Public IPs of control planes"
  value       = aws_instance.control_plane[*].public_ip
}

output "worker_ips" {
  description = "Private IPs of workers"
  value       = aws_instance.worker[*].private_ip
}

output "worker_ids" {
  description = "IDs of worker instances"
  value       = aws_instance.worker[*].id
}

output "worker_public_ips" {
  description = "Public IPs of workers"
  value       = aws_instance.worker[*].public_ip
}

output "ssh_private_key" {
  description = "Private SSH key (if generated dynamically)"
  value       = tls_private_key.deploy_key.private_key_pem
  sensitive   = true
}

output "key_name" {
  description = "Key pair name used for compute instances"
  value       = aws_key_pair.k8s_key.key_name
}
