# Compute & Virtual Machine Infrastructure Definition

module "enterprise_compute" {
  source = "./modules/compute"

  environment         = var.environment
  subnet_ids          = module.enterprise_network.private_subnet_ids
  control_plane_sg_id = module.enterprise_security.control_plane_sg_id
  worker_sg_id        = module.enterprise_security.worker_sg_id
  instance_type       = var.instance_type
}
