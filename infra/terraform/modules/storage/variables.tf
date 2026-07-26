variable "environment" {
  description = "Environment name"
  type        = string
}

variable "availability_zones" {
  description = "Availability zones to deploy storage"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "kms_key_arn" {
  description = "Optional KMS Key ARN for EBS volume encryption"
  type        = string
  default     = null
}
