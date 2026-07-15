output "loadbalancer_sg_id" {
  description = "The ID of the Load Balancer security group"
  value       = aws_security_group.loadbalancer.id
}

output "control_plane_sg_id" {
  description = "The ID of the Control Plane security group"
  value       = aws_security_group.control_plane.id
}

output "worker_sg_id" {
  description = "The ID of the Worker security group"
  value       = aws_security_group.worker.id
}
