terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "staging"
}

module "network" {
  source          = "../../modules/network"
  environment     = var.environment
  vpc_cidr        = "10.2.0.0/16"
  public_subnets  = ["10.2.1.0/24", "10.2.2.0/24"]
  private_subnets = ["10.2.10.0/24", "10.2.11.0/24", "10.2.12.0/24"]
}

module "security" {
  source      = "../../modules/security"
  vpc_id      = module.network.vpc_id
  environment = var.environment
}

module "compute" {
  source              = "../../modules/compute"
  environment         = var.environment
  subnet_ids          = module.network.private_subnet_ids
  control_plane_sg_id = module.security.control_plane_sg_id
  worker_sg_id        = module.security.worker_sg_id
  instance_type       = "t3.medium"
  ami_id              = "ami-0e86e20dae9224db8"
}

module "storage" {
  source      = "../../modules/storage"
  environment = var.environment
}

module "loadbalancer" {
  source             = "../../modules/loadbalancer"
  environment        = var.environment
  vpc_id             = module.network.vpc_id
  public_subnet_ids  = module.network.public_subnet_ids
  control_plane_ids  = module.compute.control_plane_ids
  loadbalancer_sg_id = module.security.loadbalancer_sg_id
}
