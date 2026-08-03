# ─────────────────────────────────────────────────────────────────────────────
# ROOT OUTPUTS
#
# After `terraform apply`, these values are printed to your terminal.
# They are also accessible via: terraform output <name>
# In CI/CD pipelines, outputs are often read by downstream steps.
# ─────────────────────────────────────────────────────────────────────────────

# ── Network ────────────────────────────────────────────────────────────────────

output "vpc_id" {
  description = "VPC ID — use this to verify the correct VPC in AWS Console"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public Subnet IDs (Bastion Host + NAT Gateway live here)"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private Subnet IDs (Dev Server lives here)"
  value       = module.vpc.private_subnet_ids
}

output "nat_gateway_id" {
  description = "NAT Gateway ID (null if enable_nat_gateway = false)"
  value       = module.vpc.nat_gateway_id
}

# ── Compute ────────────────────────────────────────────────────────────────────

output "bastion_public_ip" {
  description = "Bastion Host public IP — step 1 of your SSH jump path"
  value       = module.ec2.bastion_public_ip
}

output "dev_server_private_ip" {
  description = "Dev Server private IP — SSH to this from inside Bastion"
  value       = module.ec2.dev_server_private_ip
}

output "ami_id_used" {
  description = "Amazon Linux 2023 AMI ID resolved by the data source"
  value       = module.ec2.ami_id_used
}

# ── Ready-to-Use SSH Commands ─────────────────────────────────────────────────
# These save you from mentally constructing the SSH commands after every apply.

output "step1_ssh_to_bastion" {
  description = "Run this command on your LOCAL machine to SSH into Bastion"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ec2-user@${module.ec2.bastion_public_ip}"
  sensitive = true
}

output "step2_ssh_to_dev_server" {
  description = "Run this command INSIDE Bastion to reach the private Dev Server"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ec2-user@${module.ec2.dev_server_private_ip}"
  sensitive = true
}

output "step3_test_nginx" {
  description = "Run this INSIDE Dev Server to verify Nginx is serving the web app"
  value       = "curl http://localhost"
}
