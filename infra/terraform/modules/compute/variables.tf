variable "environment" {
  description = "Environment name"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for instance deployment"
  type        = list(string)
}

variable "control_plane_sg_id" {
  description = "Security group ID for control planes"
  type        = string
}

variable "worker_sg_id" {
  description = "Security group ID for workers"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance size"
  type        = string
  default     = "t3.medium"
}

variable "ami_id" {
  description = "AMI ID for Ubuntu Server"
  type        = string
  default     = "" # Will lookup Ubuntu 24.04 LTS if empty
}

variable "ssh_public_key" {
  description = "Public key path or content for SSH access"
  type        = string
  default     = ""
}
