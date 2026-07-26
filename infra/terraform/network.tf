# Network Infrastructure Definition

module "enterprise_network" {
  source = "./modules/network"

  environment = var.environment
  vpc_cidr    = var.vpc_cidr
}
