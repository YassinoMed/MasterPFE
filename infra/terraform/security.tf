# Security Groups & Firewall Rules Infrastructure Definition

module "enterprise_security" {
  source = "./modules/security"

  environment = var.environment
  vpc_id      = module.enterprise_network.vpc_id
}
