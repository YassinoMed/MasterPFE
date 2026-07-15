variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs to deploy the NLB"
  type        = list(string)
}

variable "control_plane_ids" {
  description = "List of control plane instance IDs"
  type        = list(string)
}

variable "loadbalancer_sg_id" {
  description = "Load balancer security group ID"
  type        = string
}
