variable "domain_name" {
  description = "Domain name for the enterprise Kubernetes platform"
  type        = string
  default     = "securerag.internal"
}

variable "api_lb_ip" {
  description = "Public or Internal IP address of the Kubernetes API Load Balancer"
  type        = string
}

variable "ingress_lb_ip" {
  description = "Public or Internal IP address of the Ingress Load Balancer"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
