# ─────────────────────────────────────────────────────────────────────────────
# ROOT main.tf — Orchestrates all modules
#
# This file is the "director". It calls each module and wires outputs of one
# module into inputs of the next. No AWS resources are created here directly.
#
# Module call syntax:
#   module "<label>" {
#     source = "./modules/<folder>"  ← local path (or Terraform Registry URL)
#     <input_variable> = <value>
#   }
#
# After terraform init, each module gets its own .terraform/modules/ entry.
# ─────────────────────────────────────────────────────────────────────────────

# ── Module 1: VPC (Network Foundation) ───────────────────────────────────────
# Creates: VPC, 4 subnets, IGW, EIP, NAT Gateway, 2 route tables + associations
module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  azs                  = var.azs
  enable_nat_gateway   = var.enable_nat_gateway
}

# ── Module 2: Security Groups ─────────────────────────────────────────────────
# Creates: bastion-sg (SSH from my_ip), private-ec2-sg (SSH from bastion-sg, HTTP)
# Depends on vpc module output: module.vpc.vpc_id
module "security_group" {
  source = "./modules/security_group"

  project_name = var.project_name
  vpc_id       = module.vpc.vpc_id # ← cross-module reference
  my_ip        = var.my_ip
}

# ── Module 3: EC2 Instances ───────────────────────────────────────────────────
# Creates: Bastion Host (public subnet), Dev Server (private subnet + Nginx)
# Depends on: both vpc and security_group module outputs
module "ec2" {
  source = "./modules/ec2"

  project_name      = var.project_name
  public_subnet_id  = module.vpc.public_subnet_ids[0]  # AZ-a public subnet
  private_subnet_id = module.vpc.private_subnet_ids[0] # AZ-a private subnet
  bastion_sg_id     = module.security_group.bastion_sg_id
  private_ec2_sg_id = module.security_group.private_ec2_sg_id
  key_name          = var.key_name
  instance_type     = var.instance_type
}
